# K. 메모리 및 리소스 분석 (Memory & Resource Analysis)

> 작성 기준: 30년 경력 시니어 아키텍트
> 대상 시스템: CCTV SAFE-YOLO Industrial Monitoring System
> 작성일: 2026-02-11

---

## 종합 평가: 리소스 관리가 사실상 존재하지 않는다

이 시스템은 메모리 할당/해제에 대한 의도적 설계가 전무하다. Python GC에 전적으로 의존하며, GPU 메모리 관리도 부재하다.

---

## 1. 메모리 누수 분석

### 1.1 RuleEngine._person_states 무한 누적

```python
class RuleEngine:
    def __init__(self):
        self._person_states = {}  # track_id → PersonState

    def evaluate(self, ...):
        for det in detections:
            if det.track_id not in self._person_states:
                self._person_states[det.track_id] = PersonState(...)
            # ❌ 삭제 로직이 없다!
```

**영향:**
- 24시간 스트리밍, 평균 10명/프레임, 15fps → 하루 최대 수만 개의 고유 track_id
- PersonState당 ~200 bytes → 10,000 track_id = ~2MB
- 심각하지 않아 보이지만, dict 오버헤드 + 해시 테이블 리사이징으로 실제 메모리는 3~5x

**수정 방안:** TTL 기반 만료 (마지막 목격 후 60초 지나면 삭제)

### 1.2 RuleEngine._detection_states 누적

```python
self._detection_states = {}  # (event_type, roi_id) → DetectionState
```

ROI 수 × 이벤트 타입 수만큼 항목이 생성된다. ROI가 삭제되어도 이전 상태가 남는다. ROI가 빈번히 수정되면 고아 상태가 누적된다.

### 1.3 YOLO model.track(persist=True) 내부 상태

YOLO의 `persist=True` 옵션은 프레임 간 트래킹 상태를 유지한다. ultralytics 내부적으로 이전 프레임의 feature map, 트래킹 버퍼 등을 보존한다. 이 버퍼의 크기는 추적 대상 수에 비례하여 증가하며, 명시적인 리셋 메커니즘이 코드에 없다.

### 1.4 BoT-SORT 트래커 내부 버퍼

```python
class BoTSORTTracker:
    def __init__(self):
        self.tracker = BOTSORT(args)
        # 내부: 칼만 필터 상태, ReID 특징 벡터, 트랙 히스토리
```

BoT-SORT는 각 추적 대상에 대해:
- 칼만 필터 상태 (8차원 벡터)
- ReID 특징 벡터 (128~2048차원)
- 트랙 히스토리 (최근 N 프레임)

장기 실행 시 "lost" 상태의 트랙이 timeout까지 메모리를 차지한다.

### 1.5 VideoProcessor._current_raw_frame

```python
class VideoProcessor:
    def __init__(self):
        self._current_raw_frame = None  # np.ndarray 참조 유지

    def read_frame(self):
        ret, frame = self._cap.read()
        self._current_raw_frame = frame  # 이전 프레임 GC 대기
```

1080p 프레임: 1920 × 1080 × 3 = ~6.2MB. 매 프레임 새 배열 할당, 이전 배열은 GC 대기.

### 1.6 프론트엔드 StreamController.broadcast()

```dart
_frameController = StreamController<StreamFrame>.broadcast();
```

broadcast 스트림은 리스너가 없어도 이벤트를 버퍼링하지 않지만, 늦게 구독한 리스너는 이전 프레임을 못 받는다. 리스너가 느리면 내부 큐에 쌓일 수 있다.

---

## 2. 캐시 누적 분석

### 2.1 PIL ImageFont 캐시

```python
def put_korean_text(img, text, position, ...):
    font = ImageFont.truetype("C:/Windows/Fonts/malgun.ttf", font_size)
```

매 호출시 `ImageFont.truetype()`를 호출한다. PIL 내부적으로 캐시할 수 있지만, 명시적 캐시가 없어 크기별로 폰트 객체가 생성될 수 있다.

### 2.2 전역 탐지기 상수 유지

```python
_detector_instance: Optional[BaseDetector] = None
```

RF-DETR Medium 모델: GPU 메모리 ~200~500MB, 시스템 메모리 ~200MB
YOLO 모델: GPU 메모리 ~100~300MB, 시스템 메모리 ~100MB

스트리밍이 종료되어도 모델은 메모리에 상주한다. 명시적 해제 메커니즘이 없다.

### 2.3 _lastTotalDurationMs 캐시

```dart
double _lastTotalDurationMs = 0.0;
```

disconnect 시 0.0으로 리셋되지만, 연결 중에는 이전 값이 남아 있어 카메라 전환 시 이전 카메라의 duration이 표시될 수 있다.

---

## 3. GPU/모델 리소스 분석

### 3.1 GPU 메모리 관리 부재

```python
class RFDETRDetector:
    def load_model(self):
        # 모델 로드 후 GPU로 이동
        if torch.cuda.is_available():
            target_model.cuda()
        # ❌ GPU 메모리 사용량 확인 없음
        # ❌ OOM 핸들링 없음
        # ❌ 메모리 예약 없음
```

**문제점:**
- `torch.cuda.empty_cache()` 호출 없음 → GPU 메모리 단편화
- OOM 발생 시 프로세스 크래시 (전체 서비스 중단)
- GPU 메모리 사용량 모니터링 없음

### 3.2 모델 언로딩 없음

스트림이 모두 종료되어도 모델이 GPU에 상주한다. 유일한 해제 시점은 프로세스 종료 시다.

```python
# 필요하지만 없는 코드:
def unload_model(self):
    if self.model is not None:
        del self.model
        torch.cuda.empty_cache()
        self._is_loaded = False
```

### 3.3 strict=False 모델 로딩

```python
target_model.load_state_dict(state_dict, strict=False)
```

`strict=False`는 체크포인트에 없는 가중치를 랜덤 초기화된 상태로 남긴다. 이는 일부 레이어가 학습되지 않은 랜덤 가중치로 추론하는 것을 의미한다. 탐지 정확도에 직접적 영향을 줄 수 있다.

### 3.4 추론 중 임시 텐서

```python
# detect() 호출마다 생성되는 임시 텐서
results = self.model.predict(frame)  # 입력 텐서, 중간 특징맵, 출력 텐서
raw_detections = np.column_stack([...])  # NumPy 배열
```

매 프레임 수십~수백 MB의 GPU 메모리가 할당/해제된다. `torch.no_grad()` 컨텍스트 매니저 사용 여부가 코드에 명시되어 있지 않다 (rfdetr 라이브러리 내부에 의존).

---

## 4. 이미지 버퍼 분석

### 4.1 프레임당 메모리 할당 체인

```
프레임 파이프라인 메모리 사용량:

1. cv2.VideoCapture.read()
   → np.ndarray (1920×1080×3) = 6.2MB

2. frame.copy() (annotated frame용)
   → np.ndarray 복사 = 6.2MB (추가)

3. draw_detections() / draw_rois()
   → 기존 배열에 in-place 수정 (추가 할당 적음)

4. put_korean_text()
   → PIL Image.fromarray(frame_rgb) = 6.2MB (RGB 변환)
   → PIL Image → np.ndarray 변환 = 6.2MB
   → cv2.cvtColor(BGR) = 6.2MB

5. cv2.imencode('.jpg', frame)
   → bytes buffer ~50~150KB

6. base64.b64encode(encoded)
   → str ~67~200KB

7. JSON 직렬화 (전체 프레임 데이터)
   → str ~70~220KB

총 피크 메모리 (단일 프레임): ~31MB+ (이미지 데이터만)
```

### 4.2 15fps에서의 할당 속도

```
프레임당 ~31MB × 15fps = ~465MB/초의 메모리 할당/해제

Python GC가 처리해야 하는 부하:
- Generation 0 GC 빈번 발생
- 대형 객체는 Generation 2로 직접 이동
- GC pause가 프레임 지연에 영향
```

### 4.3 프론트엔드 메모리 체인

```dart
// WebSocket → 문자열 메시지
message = "{'type':'frame','frame_base64':'...'}"  // ~200KB

// JSON 파싱
data = jsonDecode(message);  // Map 객체 ~200KB

// StreamFrame 생성
frame = StreamFrame.fromJson(data);  // 객체 + base64 문자열 참조

// base64 디코딩
_currentFrameBytes = base64Decode(frame.frameBase64);  // Uint8List ~100KB

// Image.memory 렌더링
Image.memory(_currentFrameBytes!, gaplessPlayback: true);
// 내부적으로 JPEG → 비트맵 디코드 (~6MB)
// gaplessPlayback: 이전 프레임 + 새 프레임 = 2프레임 동시 유지

프론트엔드 프레임당 피크: ~12MB+ (디코딩된 비트맵 2개)
```

---

## 5. 리소스 수명주기 관리

### 5.1 VideoProcessor 수명주기 문제

```python
class VideoProcessor:
    def open(self, source):
        self._cap = cv2.VideoCapture(source)  # 열림

    def release(self):
        if self._cap:
            self._cap.release()  # 닫힘
```

**문제:** `release()`가 호출되지 않는 시나리오:
- WebSocket 비정상 종료 (네트워크 끊김)
- 예외 발생 후 정리 코드 미실행
- `__del__` 없음 (GC 의존)

```python
# 없는 것: 컨텍스트 매니저 패턴
class VideoProcessor:
    async def __aenter__(self):
        return self
    async def __aexit__(self, *args):
        self.release()
```

### 5.2 WebSocket 연결 수명주기

```python
# websocket.py
async def websocket_stream(websocket, camera_id):
    manager.connect(websocket)
    try:
        # ... 스트리밍 로직 ...
    except WebSocketDisconnect:
        manager.disconnect(websocket)
    finally:
        # VideoProcessor 정리?
        processor.release()  # 일부 경로에서만 호출
```

`finally` 블록에서 모든 리소스를 정리하는지 확인 필요. 특히 `processor`, `roi_manager`, `rule_engine` 인스턴스.

### 5.3 스냅샷 파일 정리 없음

```python
class AlarmManager:
    def _save_snapshot(self, event, frame):
        filepath = f"snapshots/{date_dir}/{event_id}.jpg"
        cv2.imwrite(filepath, frame)
        # ❌ 이전 스냅샷 정리 로직 없음
        # ❌ 디스크 사용량 확인 없음
        # ❌ 보존 정책 없음
```

스냅샷이 무한정 누적된다. 디스크 가용 공간을 체크하지 않으므로, 디스크 풀 시 시스템 전체에 영향.

---

## 6. 메모리 프로파일링 권고

### 6.1 추천 도구

| 도구 | 용도 | 오버헤드 |
|------|------|---------|
| tracemalloc | 파이썬 메모리 할당 추적 | 중간 (~10%) |
| objgraph | 객체 참조 그래프 시각화 | 낮음 |
| memory_profiler | 함수별 메모리 사용량 | 높음 (~30%) |
| nvidia-smi | GPU 메모리 모니터링 | 없음 |
| torch.cuda.memory_stats() | PyTorch GPU 상세 통계 | 없음 |
| psutil | 프로세스 RSS/VMS 모니터링 | 없음 |
| Flutter DevTools Memory | Dart 객체 메모리 | 중간 |

### 6.2 핵심 모니터링 포인트

```python
# 주기적 메모리 리포팅 (30초마다)
import psutil, torch

def report_memory():
    process = psutil.Process()
    mem = process.memory_info()
    print(f"RSS: {mem.rss / 1024**2:.1f}MB, VMS: {mem.vms / 1024**2:.1f}MB")

    if torch.cuda.is_available():
        allocated = torch.cuda.memory_allocated() / 1024**2
        reserved = torch.cuda.memory_reserved() / 1024**2
        print(f"GPU Allocated: {allocated:.1f}MB, Reserved: {reserved:.1f}MB")
```

### 6.3 예상 메모리 베이스라인

| 컴포넌트 | 시스템 메모리 | GPU 메모리 |
|---------|-------------|-----------|
| Python 프로세스 기본 | ~50MB | - |
| FastAPI + uvicorn | ~30MB | - |
| RF-DETR Medium 모델 | ~200MB | ~300MB |
| YOLO 모델 | ~100MB | ~200MB |
| VideoProcessor (1카메라) | ~50MB | - |
| RuleEngine + ROIManager | ~10MB | - |
| 프레임 파이프라인 (피크) | ~100MB | ~200MB |
| **합계 (1카메라)** | **~440MB** | **~500MB** |
| **합계 (5카메라)** | **~640MB** | **~700MB** |

---

## 최종 권고

1. **즉시:** `_person_states`에 TTL 기반 정리 로직 추가
2. **즉시:** 스냅샷 보존 정책 구현 (30일 자동 삭제)
3. **단기:** 프레임 파이프라인 메모리 풀링 (numpy 배열 재사용)
4. **단기:** GPU 메모리 모니터링 + OOM 그레이스풀 핸들링
5. **중기:** put_korean_text() PIL 변환 제거 (OpenCV 직접 렌더링 또는 프론트엔드 오버레이)
6. **중기:** VideoProcessor 컨텍스트 매니저 패턴 적용
