# I. 성능 실험 계획 (Performance Experiment Plan)

> 작성 기준: 30년 경력 시니어 아키텍트
> 대상 시스템: CCTV SAFE-YOLO Industrial Monitoring System
> 작성일: 2026-02-11

---

## 1. 핵심 성능 지표 (KPIs)

| KPI | 현재 추정치 | 목표 | 측정 방법 |
|-----|-----------|------|----------|
| Frame-to-Display 지연 | 300~500ms | < 200ms | 타임스탬프 주입 → 표시 시간 비교 |
| 탐지 추론 시간/프레임 | 30~100ms | < 50ms | torch.cuda.Event 타이밍 |
| WebSocket 프레임 전송율 | 10~15fps | 15fps 안정 | 프레임 카운터/초 |
| 카메라당 메모리 사용량 | ~800MB 추정 | < 500MB | tracemalloc + RSS 모니터링 |
| 카메라당 CPU 사용률 | ~50%+ 추정 | < 30% | psutil.Process.cpu_percent() |
| GPU 활용률 | ~30~40% | > 80% | nvidia-smi / torch.cuda.utilization() |
| 이벤트 처리 지연 | 불명확 | < 100ms | 탐지→DB저장 타임스탬프 차이 |
| API 응답 시간 (p99) | 불명확 | < 200ms | middleware 타이밍 |
| WS 연결 설정 시간 | 불명확 | < 500ms | 연결 시작→첫 프레임 도착 |
| 프론트엔드 프레임 렌더 시간 | ~20~30ms 추정 | < 16ms (60fps) | Flutter DevTools |

---

## 2. 프로파일링 계획

### 2.1 Python CPU 프로파일링

```python
# cProfile로 함수별 프로파일링
import cProfile
import pstats

profiler = cProfile.Profile()
profiler.enable()
# ... 프레임 처리 실행 ...
profiler.disable()
stats = pstats.Stats(profiler)
stats.sort_stats('cumulative')
stats.print_stats(20)

# py-spy로 프로덕션 프로파일링 (낮은 오버헤드)
# py-spy record -o profile.svg --pid <PID>
```

**측정 대상:**
- `video_processor.stream_frames()` 전체 루프
- `detector.detect()` 호출
- `rule_engine.evaluate()` 호출
- `base64.b64encode()` 호출
- `cv2.imencode()` 호출
- JSON 직렬화

### 2.2 메모리 프로파일링

```python
# tracemalloc으로 메모리 스냅샷
import tracemalloc

tracemalloc.start()
# ... 30초 동안 스트리밍 ...
snapshot = tracemalloc.take_snapshot()
top_stats = snapshot.statistics('lineno')
for stat in top_stats[:20]:
    print(stat)

# memory_profiler로 함수별 메모리
# @profile
# def stream_frames():
#     ...
```

### 2.3 GPU 프로파일링

```python
# PyTorch CUDA 이벤트 기반 타이밍
start_event = torch.cuda.Event(enable_timing=True)
end_event = torch.cuda.Event(enable_timing=True)

start_event.record()
results = model.predict(frame)
end_event.record()
torch.cuda.synchronize()
inference_ms = start_event.elapsed_time(end_event)

# nvidia-smi 반복 모니터링
# nvidia-smi --query-gpu=utilization.gpu,utilization.memory,memory.used --format=csv -l 1
```

### 2.4 프론트엔드 프로파일링

- Flutter DevTools → Performance 탭
- Widget rebuild 추적 (debugPrintRebuildDirtyWidgets)
- Frame timing (SchedulerBinding.instance.addTimingsCallback)
- 메모리 탭으로 Image 캐시 모니터링

### 2.5 네트워크 프로파일링

```python
# WebSocket 프레임 크기/시간 측정
import time

frame_sizes = []
frame_times = []

async def instrumented_send(websocket, data):
    frame_sizes.append(len(data))
    start = time.monotonic()
    await websocket.send_json(data)
    frame_times.append(time.monotonic() - start)
```

---

## 3. 실험 시나리오

### 실험 1: Base64 vs Binary WebSocket

**가설:** Binary 프레임 전송이 Base64 대비 대역폭 33% 절감, 지연 20% 감소

**방법:**
```
A 그룹 (현재): frame → JPEG → base64 → JSON → WebSocket text
B 그룹 (개선): frame → JPEG → WebSocket binary

측정:
1. 프레임당 전송 크기 (bytes)
2. 인코딩 시간 (ms) - base64 vs 없음
3. WebSocket 전송 시간 (ms)
4. 프론트엔드 디코딩 시간 (ms)
5. 대역폭 사용량 (Mbps)

실험 조건:
- 동일 영상 소스 (1080p, 15fps)
- 100프레임 반복 3회
- JPEG quality=85 고정
```

**예상 결과:**
| 지표 | Base64 JSON | Binary | 차이 |
|------|------------|--------|------|
| 프레임 크기 | ~150KB | ~100KB | -33% |
| 인코딩 시간 | ~2ms | ~0ms | -100% |
| 전송 시간 | ~5ms | ~3ms | -40% |

### 실험 2: 탐지 프레임 스킵율

**가설:** 매 3번째 프레임만 탐지하면 CPU 60% 절감, 정확도 손실 < 5%

**방법:**
```
스킵율 변화: 1(매프레임), 2(매2번째), 3, 5, 10

측정:
1. 프레임당 평균 탐지 시간 (amortized)
2. CPU 사용률
3. 탐지 누락율 (빠르게 이동하는 객체 기준)
4. 트래킹 ID 유지 안정성
5. 이벤트 생성 지연 (ms)

실험 조건:
- 동일 테스트 비디오 (사람 이동, 입퇴장 시나리오)
- 300프레임 반복 5회
```

### 실험 3: JPEG 품질 vs 대역폭

**가설:** JPEG quality 70이 quality 95 대비 파일 크기 50% 감소, 시각 품질 차이 미미

**방법:**
```
JPEG quality 변화: 50, 60, 70, 80, 85, 90, 95

측정:
1. 프레임 크기 (bytes)
2. SSIM (Structural Similarity Index)
3. 탐지 정확도 변화 (JPEG 아티팩트가 탐지에 미치는 영향)
4. 인코딩 시간 (ms)

실험 조건:
- 동일 원본 프레임 100개
- 다양한 장면 (밝음/어둠, 사람 많음/적음)
```

### 실험 4: GPU 배치 추론

**가설:** 4프레임 배치 추론이 GPU 활용률 3x 향상

**방법:**
```
배치 크기: 1, 2, 4, 8, 16

측정:
1. 배치당 총 추론 시간 (ms)
2. 프레임당 평균 추론 시간 (ms)
3. GPU 활용률 (%)
4. GPU 메모리 사용량 (MB)
5. 대기 시간 (배치 채울 때까지)

실험 조건:
- RF-DETR Medium 모델
- 1080p 프레임
- CUDA warm-up 후 100회 반복
```

**예상 결과:**
| 배치 크기 | 총 추론 (ms) | 프레임당 (ms) | GPU 활용률 |
|----------|-------------|-------------|----------|
| 1 | 33 | 33 | ~40% |
| 2 | 40 | 20 | ~60% |
| 4 | 55 | 14 | ~80% |
| 8 | 80 | 10 | ~90% |

### 실험 5: SQLite vs PostgreSQL 쓰기 성능

**가설:** PostgreSQL이 동시 쓰기 10x 향상

**방법:**
```
동시 쓰기 워커: 1, 5, 10, 20, 50

측정:
1. 초당 이벤트 삽입 수
2. 쓰기 지연 시간 p50/p99
3. 락 대기 시간
4. 커넥션 풀 사용률

실험 조건:
- 동일한 이벤트 스키마
- SQLite (WAL 모드) vs PostgreSQL 14
- 1000 이벤트 삽입 벤치마크
```

### 실험 6: 프론트엔드 렌더링 최적화

**가설:** RawImage 또는 Texture 위젯이 Image.memory 대비 디코딩 시간 40% 감소

**방법:**
```
A: Image.memory(bytes, gaplessPlayback: true)
B: RawImage + ui.decodeImageFromList
C: Texture widget (GPU 직접 렌더링)

측정:
1. 프레임 디코딩 시간 (ms)
2. Widget build 시간 (ms)
3. 메모리 사용량
4. jank 빈도 (16ms 초과 프레임 비율)
```

### 실험 7: 프로세스 분리 영향

**가설:** 탐지를 별도 프로세스로 분리하면 이벤트 루프 블로킹 제거

**방법:**
```
A: 현재 (단일 프로세스, async에서 sync 호출)
B: asyncio.to_thread() 래핑
C: multiprocessing.Process + 큐
D: 별도 서비스 + Redis 큐

측정:
1. WebSocket 응답 지연 (명령 → 응답)
2. 다른 연결에 대한 영향 (카메라 2개 동시)
3. 프레임 전송 jitter (fps 변동성)
4. 전체 처리량 (frames/sec across all cameras)
5. IPC 오버헤드
```

### 실험 8: ROI 체크 최적화

**가설:** R-tree 공간 인덱스가 ROI 10개 이상에서 80% 성능 향상

**방법:**
```
ROI 수 변화: 1, 5, 10, 20, 50
탐지 수 변화: 5, 10, 20, 50

A: Shapely contains() 순차 호출
B: rtree 공간 인덱스 + Shapely

측정:
1. ROI 체크 총 시간 (ms)
2. 탐지당 ROI 체크 시간 (μs)
```

### 실험 9: WebSocket 압축

**가설:** permessage-deflate 압축이 프레임 크기 20% 추가 감소, 오버헤드 < 5ms

**방법:**
```
A: 압축 없음
B: permessage-deflate (기본 설정)
C: permessage-deflate (window_bits=12)

측정:
1. 전송 데이터 크기
2. 압축/해제 시간 (ms)
3. CPU 사용률 변화
4. 프레임 전송율 영향
```

### 실험 10: VideoCapture 풀링

**가설:** 커넥션 풀링이 VideoCapture 열기 시간 90% 감소 (파일 소스)

**방법:**
```
A: 매 연결 시 새 cv2.VideoCapture 생성
B: 카메라별 VideoCapture 풀 (최대 3개 유지)

측정:
1. 연결 설정 시간 (ms)
2. 첫 프레임까지 시간 (ms)
3. 메모리 사용량
4. 파일 디스크립터 수
```

---

## 4. 측정 인프라

### 4.1 인스트루멘테이션 코드

```python
# 공통 타이밍 데코레이터
import time
import functools
from collections import defaultdict

_metrics = defaultdict(list)

def timed(name):
    def decorator(func):
        @functools.wraps(func)
        async def async_wrapper(*args, **kwargs):
            start = time.monotonic()
            result = await func(*args, **kwargs)
            _metrics[name].append(time.monotonic() - start)
            return result

        @functools.wraps(func)
        def sync_wrapper(*args, **kwargs):
            start = time.monotonic()
            result = func(*args, **kwargs)
            _metrics[name].append(time.monotonic() - start)
            return result

        if asyncio.iscoroutinefunction(func):
            return async_wrapper
        return sync_wrapper
    return decorator

# 사용 예시
@timed("detection.inference")
def detect(self, frame):
    ...

@timed("encoding.jpeg")
def encode_frame(self, frame):
    ...
```

### 4.2 벤치마크 스크립트 구조

```
benchmarks/
├── bench_detection.py      # 탐지 단독 벤치마크
├── bench_encoding.py       # 인코딩 방식 비교
├── bench_websocket.py      # WebSocket 전송 벤치마크
├── bench_database.py       # DB 쓰기 벤치마크
├── bench_roi.py            # ROI 체크 벤치마크
├── bench_e2e.py            # 전체 파이프라인 벤치마크
├── conftest.py             # 공통 픽스처 (테스트 비디오, 모델)
└── report_generator.py     # 결과 시각화 (matplotlib)
```

### 4.3 대시보드 설계

```
Grafana 대시보드 패널:
├── Row 1: 프레임 파이프라인
│   ├── 캡처 시간 히스토그램
│   ├── 탐지 시간 히스토그램
│   ├── 인코딩 시간 히스토그램
│   └── 전송 시간 히스토그램
├── Row 2: 시스템 리소스
│   ├── CPU 사용률 (프로세스별)
│   ├── 메모리 사용량 (RSS)
│   ├── GPU 활용률
│   └── GPU 메모리
├── Row 3: 네트워크
│   ├── WebSocket 연결 수
│   ├── 초당 프레임 전송율
│   ├── 대역폭 사용량
│   └── 프레임 드롭율
└── Row 4: 데이터베이스
    ├── 초당 쿼리 수
    ├── 쿼리 지연 시간
    ├── 연결 풀 상태
    └── 테이블 크기
```

---

## 5. 성공 기준 및 의사결정 프레임워크

### 5.1 실험 승인 기준

| 실험 | 최소 성공 기준 | 채택 기준 |
|------|-------------|----------|
| Base64 → Binary | 대역폭 20% 감소 | 대역폭 30%+ 감소 AND 지연 10%+ 감소 |
| 프레임 스킵 | 정확도 손실 < 10% | 정확도 손실 < 5% AND CPU 40%+ 감소 |
| JPEG 품질 | SSIM > 0.85 | SSIM > 0.90 AND 크기 40%+ 감소 |
| GPU 배치 | 프레임당 시간 20%+ 감소 | 프레임당 시간 50%+ 감소 |
| PostgreSQL | 동시 쓰기 3x+ 향상 | 동시 쓰기 5x+ AND p99 < 50ms |
| 프론트엔드 | jank 20%+ 감소 | 16ms 초과 프레임 < 5% |
| 프로세스 분리 | 이벤트 루프 블로킹 제거 | 다중 카메라에서 fps 변동 < 10% |

### 5.2 의사결정 매트릭스

```
          낮은 노력    높은 노력
         ┌────────────┬────────────┐
높은 영향 │ 즉시 실행    │ 계획 실행    │
         │ (실험 1,3,5) │ (실험 4,7)  │
         ├────────────┼────────────┤
낮은 영향 │ 여유 시 실행  │ 재고         │
         │ (실험 9,10)  │ (실험 8)    │
         └────────────┴────────────┘
```

### 5.3 실험 우선순위

1. **실험 1** (Base64 → Binary): 가장 낮은 노력으로 가장 큰 대역폭 개선
2. **실험 3** (JPEG 품질): 한 줄 변경으로 즉시 효과
3. **실험 7** (프로세스 분리): 아키텍처 개선의 핵심 전제
4. **실험 2** (프레임 스킵): CPU 절감의 핵심
5. **실험 5** (PostgreSQL): 확장성의 필수 전제

---

## 실험 일정

| 주차 | 실험 | 담당 |
|------|------|------|
| 1주차 | 측정 인프라 구축 + 베이스라인 측정 | 백엔드 시니어 |
| 2주차 | 실험 1 (Binary WS) + 실험 3 (JPEG) | 백엔드 시니어 |
| 3주차 | 실험 2 (프레임 스킵) + 실험 6 (프론트엔드) | 백엔드 + 프론트엔드 |
| 4주차 | 실험 7 (프로세스 분리) | 백엔드 시니어 |
| 5주차 | 실험 4 (GPU 배치) + 실험 5 (PostgreSQL) | ML 엔지니어 + 백엔드 |
| 6주차 | 실험 8,9,10 (선택적) + 결과 종합 | 전체 팀 |
