# CCTV 산업안전 관제 시스템 - 결함 및 위험 분석 보고서

> **문서 분류:** 보안등급 - 내부용
> **작성 기준:** 소스코드 전수 검토 (backend/, frontend/)
> **검토 관점:** 안전-필수(safety-critical) 시스템 아키텍처 리뷰
> **최종 갱신:** 2026-02-11

---

## 1. 개요 및 검토 소견

본 문서는 CCTV 기반 화기작업 안전관제 시스템의 소스코드를 전수 검토한 결과,
발견된 결함(defect), 보안 취약점(vulnerability), 설계 부채(design debt),
동시성 문제(concurrency issue)를 심각도별로 분류하여 기술한다.

**총평:** 이 시스템은 산업 현장에서 작업자의 생명과 직결되는 안전 관제 시스템이다.
그러나 현재 코드베이스는 프로토타입 수준의 품질로, 프로덕션 배포에 필요한
최소한의 안전장치조차 갖추지 못하고 있다. 인증/인가 부재, 단일 프로세스 아키텍처,
테스트 전무, DB 마이그레이션 부재, 이벤트 ID 충돌 가능성 등은 안전-필수 시스템에서
절대 용납할 수 없는 수준의 결함이다. 이 시스템이 실제 산업 현장에 배포될 경우,
안전 이벤트의 누락, 오탐, 미탐이 발생하여 인명 사고로 직결될 수 있다.

---

## 2. 심각도 정의

| 심각도 | 정의 | 영향 범위 | 조치 기한 |
|--------|------|-----------|-----------|
| **CRITICAL** | 시스템 장애, 데이터 손실, 안전 이벤트 누락 가능. 인명 피해와 직결. | 전체 시스템 | 즉시 (배포 차단) |
| **HIGH** | 주요 기능 오작동, 보안 침해 가능. 시스템 신뢰성 훼손. | 주요 모듈 | 1주 이내 |
| **MEDIUM** | 특정 조건에서 오동작, 운영 불편. 우회 가능하나 기술 부채 누적. | 개별 기능 | 1개월 이내 |
| **LOW** | 사소한 문제, 이식성/유지보수성 저하. 당장 장애 미유발. | 부분적 | 다음 스프린트 |

---

## 3. 심각도 매트릭스 요약

| 분류 | CRITICAL | HIGH | MEDIUM | LOW | 합계 |
|------|----------|------|--------|-----|------|
| 버그 (Bugs) | 2 | 3 | 3 | 1 | 9 |
| 보안 취약점 (Security) | 2 | 3 | 2 | 1 | 8 |
| 설계 부채 (Design Debt) | 2 | 4 | 3 | 1 | 10 |
| 동시성 문제 (Concurrency) | 0 | 2 | 2 | 0 | 4 |
| **합계** | **6** | **12** | **10** | **3** | **31** |

---

## 4. 버그 (Bugs)

### BUG-001 [CRITICAL] AlarmManager._next_event_id 인메모리 카운터 - DB auto-increment 미동기화

- **파일:** `backend/app/core/alarm_manager.py` (37행, 57-58행)
- **현상:** `AlarmManager.__init__`에서 `self._next_event_id = 1`로 하드코딩 초기화한다.
  이 카운터는 순수 인메모리 변수이며, DB의 `Event.id` auto-increment 값과
  어떠한 동기화도 수행하지 않는다.
- **재현 시나리오:**
  1. 시스템 가동 중 이벤트 100건 생성 (DB id: 1~100, 메모리 id: 1~100)
  2. 서버 재시작
  3. `_next_event_id`가 1로 리셋
  4. 새 이벤트 생성 시 메모리 id=1 부여, DB에는 id=101로 저장
  5. `_save_to_db`가 `event_data["id"] = db_event.id`로 덮어쓰지만,
     이미 `_unacknowledged` 딕셔너리에는 메모리 id=1로 등록된 상태
  6. `acknowledge_event(101)`을 호출해도 `_unacknowledged`에 키가 1이므로 실패
  7. 미확인 알람이 영구적으로 해제 불가능한 상태로 누적
- **근본 원인:** 이벤트 ID 생성 책임이 DB와 애플리케이션 레이어에 이중으로 존재하며,
  양쪽 간 동기화 메커니즘이 전무하다.
- **영향도:** 서버 재시작마다 알람 확인(acknowledge) 기능 전면 장애. 안전 관제
  운용자가 경보를 해제할 수 없어 경보 피로(alarm fatigue) 유발. 실제 위험 상황에서
  운용자가 모든 경보를 무시하게 되는 최악의 시나리오가 발생할 수 있다.
- **수정 방안:**
  1. 이벤트 ID 생성을 DB에 완전히 위임 (DB insert 후 반환된 ID만 사용)
  2. `_unacknowledged` 딕셔너리의 키를 DB ID 기준으로 관리
  3. 시작 시 DB에서 미확인 이벤트를 로드하여 `_unacknowledged` 복원
- **수정 우선순위:** P0 - 즉시 수정, 배포 차단 사유

---

### BUG-002 [CRITICAL] AlarmService 사운드 에셋 미존재 - 알람 무음 장애

- **파일:** `frontend/lib/services/alarm_service.dart` (17-27행),
  `frontend/pubspec.yaml` (45-46행)
- **현상:** `AlarmService.playAlarm()`은 `sounds/alarm_critical.wav`,
  `sounds/alarm_warning.wav`, `sounds/alarm_info.wav` 파일을 참조한다.
  그러나 `pubspec.yaml`에서 에셋 선언이 주석 처리되어 있다:
  ```yaml
  # assets:
  #   - assets/sounds/
  ```
  Flutter는 pubspec.yaml에 선언되지 않은 에셋에 접근할 수 없으므로,
  `AssetSource(soundFile)` 호출 시 반드시 예외가 발생한다.
- **catch 블록의 치명적 결함:** 예외 발생 시 catch 블록이 빈 주석만 남기고
  아무 조치도 하지 않는다 (`// fallback: sound file missing`).
  이는 안전-필수 시스템에서 가장 위험한 패턴이다. 경보 알림의 핵심인 청각 경보가
  완전히 무음 상태로 운용되며, 시스템 어디에서도 이 사실을 보고하지 않는다.
- **재현:** 어떤 심각도의 이벤트가 발생해도 소리가 나지 않는다. 100% 재현.
- **영향도:** 산업안전보건법 제38조에 의거, 위험 예방을 위한 필요 조치를
  이행하지 않는 것에 해당할 수 있다. 작업자가 시각적 알림을 놓친 경우
  안전 이벤트를 인지할 수단이 전무하다.
- **수정 방안:**
  1. 사운드 에셋 파일을 실제로 생성하여 `assets/sounds/` 디렉토리에 배치
  2. `pubspec.yaml` 에셋 선언 주석 해제
  3. catch 블록에서 Windows 시스템 비프음(`SystemSound.play`) fallback 구현
  4. 사운드 재생 실패 시 로그 및 UI 알림 표시 (무음 상태 명시적 통보)
- **수정 우선순위:** P0 - 즉시 수정, 배포 차단 사유

---

### BUG-003 [HIGH] ROI 좌표 정규화 휴리스틱 - 비표준 해상도 오동작

- **파일:** `backend/app/core/roi_manager.py` (34-49행)
- **현상:** `add_roi()` 메서드는 ROI 좌표가 픽셀 공간인지 정규화 공간(0~1)인지
  판별하기 위해 휴리스틱 로직을 사용한다:
  ```python
  if px_maxx > 1300: scale_x = 1920.0
  if px_maxy > 800: scale_y = 1080.0
  ```
  이 로직은 오직 1280x720과 1920x1080 두 가지 해상도만 가정한다.
- **실패 케이스:**
  - 2560x1440 (QHD): `px_maxx=2560 > 1300`이므로 `scale_x=1920`으로 오정규화
    -> ROI가 실제보다 133% 크게 계산됨
  - 1024x768 (XGA): `px_maxx=1024 < 1300`이므로 `scale_x=1280`으로 오정규화
    -> ROI가 실제보다 80% 크기로 계산됨
  - 640x480 (VGA): `px_maxx=640 < 1300`이므로 `scale_x=1280`으로 오정규화
    -> ROI가 실제보다 50% 크기로 계산됨
  - 4K(3840x2160): 동일한 문제 발생
- **근본 원인:** 해상도 정보를 ROI 생성 시점에 전달받지 않고 좌표값 범위에서
  역추론하려는 근본적으로 잘못된 접근 방식이다.
- **영향도:** 비표준 해상도 카메라 사용 시 ROI 영역이 왜곡되어 위험 구역 침입
  감지가 실패하거나, 안전한 영역을 위험으로 오판한다.
- **수정 방안:**
  1. `add_roi()`에 `source_width`, `source_height` 파라미터 추가
  2. 프론트엔드에서 ROI 생성 시 실제 영상 해상도를 함께 전송
  3. DB에 ROI가 생성된 기준 해상도를 저장
  4. 휴리스틱 제거, 명시적 좌표 변환 사용
- **수정 우선순위:** P1 - 1주 이내

---

### BUG-004 [HIGH] safety_regulation_panel.dart 하드코딩 - DB 법령 데이터 미연동

- **파일:** `frontend/lib/widgets/safety_regulation_panel.dart` (32-55행)
- **현상:** 안전 법령 패널이 4개의 `_RegulationCard`를 `const` 리터럴로 하드코딩하고 있다.
  백엔드에 `SafetyRegulation` 모델과 `regulations` API 라우터가 존재함에도
  이를 전혀 사용하지 않는다. DB에 법령을 추가/수정/삭제해도 UI에 반영되지 않는다.
- **코드 증거:**
  ```dart
  children: const [
    _RegulationCard(
      category: '산업안전보건법',
      title: '제38조(안전조치)',
      // ...하드코딩된 내용...
    ),
    // ...3개 더 하드코딩...
  ],
  ```
  파일 상단에 `import '../providers/providers.dart';`와
  `import '../services/services.dart';`가 있지만 실제로는 사용되지 않는다.
  `ConsumerWidget`을 상속받으면서도 `ref`를 한 번도 사용하지 않는다.
- **영향도:** 법령 개정 시 앱 재배포 필요. 관리자가 DB를 통해 법령을 관리할 수
  없어 운영 유연성이 전무하다. 시스템의 핵심 기능 중 하나가 사실상 정적 HTML
  수준의 기능만 제공한다.
- **수정 방안:**
  1. `RegulationProvider` 생성하여 `GET /api/regulations` 연동
  2. `ConsumerWidget`의 `ref`를 통해 provider 데이터 구독
  3. 로딩/에러 상태 처리 추가
- **수정 우선순위:** P1 - 1주 이내

---

### BUG-005 [HIGH] tracker.py 폴백 트래커 - 가짜 추적 ID 문제

- **파일:** `backend/app/core/tracker.py` (62-72행, 90-98행)
- **현상:** `BoTSORTTracker`는 ultralytics BOTSORT 초기화 실패 시 또는
  `tracker.update()` 예외 발생 시 폴백 로직을 실행한다:
  ```python
  # 초기화 실패 시 (62-72행):
  for i, det in enumerate(detections):
      tracked.append([..., i + 1, ...])  # ID = 인덱스 + 1

  # 런타임 예외 시 (90-98행):
  for i, det in enumerate(detections):
      tracked.append([..., 1000 + i, ...])  # ID = 1000 + 인덱스
  ```
- **문제점:**
  1. 인덱스 기반 ID는 프레임 간 동일 객체를 추적하지 못한다.
     프레임 1에서 사람 A가 index=0(id=1), 사람 B가 index=1(id=2)이지만,
     프레임 2에서 사람 B가 먼저 감지되면 index=0(id=1)을 받게 된다.
  2. 폴백 모드에서 `RuleEngine`의 `PERSON_ENTRANCE`/`PERSON_EXIT` 로직이
     매 프레임마다 새로운 사람이 들어오고 나가는 것으로 판단한다.
  3. `1000+i` 오프셋은 실제 BOTSORT track_id와 충돌할 가능성이 있다.
- **영향도:** 트래커 장애 시 체류시간 계산 불가, 입/퇴장 이벤트 폭주,
  경보 피로 유발. 특히 폴백 모드 진입 사실이 UI에 표시되지 않아
  운용자는 시스템이 정상 작동한다고 오인한다.
- **수정 방안:**
  1. 폴백 모드 진입 시 명시적 경고 이벤트 발생 (운용자에게 통보)
  2. 폴백 모드에서는 `track_id=None` 반환하여 추적 의존 기능 비활성화
  3. IoU 기반 단순 트래커를 실질적 폴백으로 구현
  4. track_id 네임스페이스 분리 (폴백 ID에 음수 사용 등)
- **수정 우선순위:** P1 - 1주 이내

---

### BUG-006 [MEDIUM] VideoProcessor.seek() 버퍼 플러시 - 5프레임 grab 휴리스틱

- **파일:** `backend/app/core/video_processor.py` (220-225행)
- **현상:**
  ```python
  # Force codec buffer update
  for _ in range(5):
      self.cap.grab()
  ```
  `cv2.VideoCapture.set(CAP_PROP_POS_FRAMES)`로 탐색 후 코덱 버퍼를
  갱신하기 위해 5프레임을 grab하는데, 이 값은 코덱별 GOP(Group of Pictures)
  구조를 전혀 고려하지 않은 매직 넘버이다.
- **실패 케이스:**
  - H.264 Long GOP (GOP=30): 이전 I-프레임에서 디코딩을 시작해야 하므로
    5프레임 grab으로는 정확한 위치에 도달하지 못함
  - MJPEG: 모든 프레임이 I-프레임이므로 grab이 불필요 (성능 낭비)
  - RTSP 스트림: `source_type == "file"` 조건으로 보호되지만, 향후
    코드 변경 시 RTSP에 적용되면 스트림 지연 유발
- **영향도:** 특정 코덱/컨테이너 조합에서 탐색 후 이전 프레임이 표시되거나,
  화면이 깨져 보일 수 있다. 타임라인 탐색 기능의 신뢰성 저하.
- **수정 방안:**
  1. `CAP_PROP_POS_FRAMES` 설정 후 `read()`로 실제 프레임을 가져와
     PTS(Presentation Time Stamp) 검증
  2. 목표 타임스탬프와 실제 타임스탬프의 오차가 허용 범위 내인지 확인하는
     루프로 대체
  3. 매직 넘버 5를 설정 가능한 파라미터로 외부화
- **수정 우선순위:** P2 - 1개월 이내

---

### BUG-007 [MEDIUM] RuleEngine 지속성 윈도우 - 프레임 카운팅 기반 타이밍 불일치

- **파일:** `backend/app/core/rule_engine.py` (119-165행)
- **현상:** `_check_persistence()`는 `frames_in_window` 리스트에 프레임별
  탐지 여부를 기록하고, `frame_threshold`(20) / `frame_window`(30) 비율로
  지속성을 판단한다. 동시에 `persistence_seconds`(2.0초) 기반 시간 검증도 수행한다.
- **문제점:**
  1. 프레임 전달 속도가 일정하지 않다. `stream_frames()`의 프레임 스킵 로직
     (video_processor.py 496-502행)에 의해 최대 5프레임이 건너뛸 수 있다.
  2. 탐지 추론 시간이 프레임별로 다르다 (GPU 부하에 따라 가변).
  3. `DETECTION_FRAME_THRESHOLD=20`, `DETECTION_FRAME_WINDOW=30`이면
     약 2초(15fps 기준)에 해당하지만, 프레임 스킵 시 실제 경과 시간은
     2초보다 길어진다.
  4. 결과적으로 빠른 장면에서는 지속성 판단이 느려지고,
     느린 장면에서는 지속성 판단이 빨라지는 비대칭 문제가 발생한다.
- **영향도:** 경보 발생 타이밍이 불안정하여 빠르게 이동하는 작업자에 대한
  감지가 지연되거나, 느린 장면에서 오탐이 증가할 수 있다.
- **수정 방안:**
  1. 프레임 카운팅을 완전히 제거하고 순수 시간 기반 슬라이딩 윈도우로 전환
  2. 각 탐지 기록에 실제 타임스탬프를 포함
  3. 윈도우 내 탐지 비율을 시간 가중 평균으로 계산
- **수정 우선순위:** P2 - 1개월 이내

---

### BUG-008 [MEDIUM] WebSocket stream_frames() 제네릭 Exception 삼킴

- **파일:** `backend/app/api/websocket.py` (186-188행, 311-326행),
  `backend/app/core/video_processor.py` (434-507행)
- **현상:** 웹소켓 핸들러와 스트림 프레임 생성기 전역에서 `except Exception`으로
  모든 예외를 포착하되, 대부분의 경우 `pass`하거나 로그만 남긴다:
  ```python
  except asyncio.TimeoutError:
      pass  # 249행, 325행
  ```
  ```python
  except Exception as e:
      logger.error(f"WebSocket error: {e}")  # 336행
  ```
- **문제점:**
  1. `MemoryError`, `SystemExit`, `KeyboardInterrupt`까지 포착하여
     시스템 종료를 방해할 수 있다
  2. DB 연결 실패, 디스크 풀, GPU 메모리 부족 등 복구 불가능한 오류가
     조용히 삼켜져서 시스템이 정상인 것처럼 계속 동작한다
  3. 클라이언트에게 오류 상황이 전달되지 않아 운용자는 스트리밍이
     정상이라고 오인한다
- **영향도:** 시스템 장애 진단 불가. 조용한 실패(silent failure)로 인해
  안전 이벤트가 누락되어도 아무도 인지하지 못하는 상황 발생.
- **수정 방안:**
  1. `except Exception`을 구체적 예외 타입으로 분리
  2. 복구 불가능한 오류 발생 시 클라이언트에게 에러 메시지 전송 후 연결 종료
  3. 연속 N회 오류 발생 시 스트림 자동 중단 및 관리자 알림
  4. `BaseException` 계열(`SystemExit`, `KeyboardInterrupt`)은 재발생시키기
- **수정 우선순위:** P2 - 1개월 이내

---

### BUG-009 [LOW] put_korean_text() 윈도우 전용 폰트 경로 하드코딩

- **파일:** `backend/app/core/video_processor.py` (26-31행)
- **현상:**
  ```python
  font_paths = [
      "C:/Windows/Fonts/malgun.ttf",
      "C:/Windows/Fonts/gulim.ttc",
      "C:/Windows/Fonts/batang.ttc",
  ]
  ```
  한글 폰트 경로가 Windows 전용으로 하드코딩되어 있다.
- **영향도:** Linux/macOS 배포, Docker 컨테이너 환경에서 한글 텍스트 렌더링 실패.
  `ImageFont.load_default()` 폴백은 한글을 지원하지 않아 깨진 문자가 표시된다.
  스냅샷 이미지의 이벤트 정보가 읽을 수 없게 되어 사후 분석에 지장을 초래한다.
- **수정 방안:**
  1. `matplotlib.font_manager` 또는 환경변수로 폰트 경로 설정
  2. 배포 패키지에 NotoSansKR 폰트 번들 포함
  3. Docker 이미지에 한글 폰트 패키지 설치 스크립트 추가
- **수정 우선순위:** P3 - 다음 스프린트

---

## 5. 보안 취약점 (Security Vulnerabilities)

### SEC-001 [CRITICAL] 인증/인가 전면 부재

- **파일:** `backend/app/main.py` (전체), `backend/app/api/routes/*.py` (전체),
  `backend/app/api/websocket.py` (전체)
- **현상:** 시스템의 모든 REST API 엔드포인트와 WebSocket 엔드포인트에
  인증(authentication) 및 인가(authorization) 메커니즘이 전혀 구현되어 있지 않다.
  API 키, JWT 토큰, 세션 쿠키, Basic Auth 등 어떤 인증 수단도 존재하지 않는다.
- **공격 시나리오:**
  1. 네트워크 접근 가능한 누구나 `GET /api/cameras`로 전체 카메라 목록 열람
  2. `DELETE /api/cameras/{id}`로 카메라 구성 삭제 -> 관제 시스템 무력화
  3. `POST /api/rois/`로 모든 ROI를 안전 영역으로 변경 -> 위험 감지 우회
  4. `POST /api/events/{id}/acknowledge`로 모든 경보 자동 확인 -> 경보 무력화
  5. `ws://host:8001/ws/stream/{id}`로 실시간 영상 스트림 무단 열람
  6. `PUT /api/cameras/{id}`로 카메라 소스를 악성 RTSP 스트림으로 변경
- **법적 위험:** 산업안전보건법 위반, 개인정보보호법 위반 (CCTV 영상은 개인정보에
  해당), 중대재해처벌법 위반 가능성.
- **영향도:** 시스템의 모든 기능이 무방비 상태. 악의적 공격자가 안전 관제 시스템을
  완전히 무력화할 수 있어, 이는 곧 인명 피해로 직결된다.
- **수정 방안:**
  1. JWT 기반 인증 미들웨어 구현 (FastAPI `Depends`를 활용한 인증 의존성)
  2. 역할 기반 접근 제어(RBAC): 관리자, 운용자, 뷰어 역할 분리
  3. WebSocket 연결 시 토큰 검증 (쿼리 파라미터 또는 첫 메시지에서 인증)
  4. API 키 또는 OAuth 2.0 클라이언트 인증 추가
  5. 영상 스트림 접근에 대한 감사 로깅(audit logging) 필수 구현
- **수정 우선순위:** P0 - 즉시 수정, 배포 차단 사유

---

### SEC-002 [CRITICAL] CORS allow_origins=["*"] 무제한 허용

- **파일:** `backend/app/main.py` (60-66행)
- **현상:**
  ```python
  app.add_middleware(
      CORSMiddleware,
      allow_origins=["*"],
      allow_credentials=True,
      allow_methods=["*"],
      allow_headers=["*"],
  )
  ```
  모든 출처(origin)에서의 교차 출처 요청을 허용하며, 심지어
  `allow_credentials=True`와 함께 사용되고 있다.
- **공격 시나리오:**
  1. 공격자가 악성 웹사이트를 생성
  2. 피해자가 해당 웹사이트를 방문 (같은 네트워크에서)
  3. 악성 JavaScript가 `http://관제서버:8001/api/cameras` 등에 요청
  4. CORS가 모두 허용이므로 응답을 정상적으로 읽기 가능
  5. 카메라 설정 변경, ROI 삭제, 경보 확인 등 모든 조작 가능
- **참고:** `allow_origins=["*"]`와 `allow_credentials=True`의 조합은
  브라우저의 CORS 보안 모델을 완전히 무력화한다.
  주석에 `# TODO: In production, restrict`이라고 적혀 있으나
  이는 안전-필수 시스템에서 TODO로 남겨둘 사항이 아니다.
- **영향도:** SEC-001과 결합 시, 인트라넷 내 어떤 웹 브라우저에서든
  관제 시스템에 무제한 접근 가능.
- **수정 방안:**
  1. `allow_origins`를 프론트엔드 배포 도메인으로 제한
  2. 환경 변수로 허용 출처 목록 관리
  3. `allow_credentials=True`를 사용하려면 와일드카드 금지 (브라우저가 차단하지만
     모든 브라우저가 이를 올바르게 구현하는 것은 아님)
- **수정 우선순위:** P0 - 즉시 수정, 배포 차단 사유

---

### SEC-003 [HIGH] WebSocket 명령 입력 검증 부재

- **파일:** `backend/app/api/websocket.py` (186-243행, 311-326행)
- **현상:** WebSocket으로 수신되는 JSON 명령에 대한 입력 검증이 전혀 없다:
  ```python
  data = await asyncio.wait_for(websocket.receive_text(), timeout=0.1)
  command = json.loads(data)
  if command.get("action") == "start":
      # ...어떤 검증도 없이 바로 실행
  elif command.get("action") == "seek":
      position_ms = command.get("position_ms", 0)
      processor.seek(position_ms)  # 음수, 극대값 등 검증 없음
  ```
- **공격 벡터:**
  - `position_ms`에 극단적 음수 값 전달: `cv2.CAP_PROP_POS_FRAMES`에 음수 전달 시
    동작 미정의
  - `position_ms`에 `float('inf')` 또는 `float('nan')` 전달: 연산 오류
  - 예상치 못한 `action` 값으로 조건 분기 우회
  - 초대형 JSON 페이로드로 메모리 고갈 공격 (DoS)
  - `camera_id`에 SQL injection 문자열 전달 (URL 경로 파라미터이므로
    직접적 SQL injection은 불가하나, 방어적 프로그래밍 관점에서 검증 필요)
- **영향도:** 서비스 거부, 비정상 상태 유발, 메모리 고갈.
- **수정 방안:**
  1. Pydantic 모델로 WebSocket 메시지 스키마 정의 및 검증
  2. 허용된 `action` 값의 화이트리스트 검증
  3. 수치 파라미터의 범위 검증 (0 <= position_ms <= total_duration_ms)
  4. 메시지 크기 제한 (최대 1KB 등)
- **수정 우선순위:** P1 - 1주 이내

---

### SEC-004 [HIGH] 카메라 source_url 경로 탐색 취약점

- **파일:** `backend/app/api/routes/cameras.py` (22-31행),
  `backend/app/core/video_processor.py` (116-119행)
- **현상:** `CameraCreate`로 전달된 `source` 필드가 검증 없이
  `cv2.VideoCapture(self.source)`에 직접 전달된다:
  ```python
  db_camera = Camera(
      name=camera.name,
      source=camera.source,  # 검증 없음
      source_type=camera.source_type
  )
  ```
- **공격 시나리오:**
  - `source: "../../../../etc/passwd"` -> 시스템 파일 접근 시도
  - `source: "rtsp://malicious-server/stream"` -> SSRF(Server-Side Request Forgery)
  - `source: "http://internal-network/admin"` -> 내부 네트워크 스캔
  - OpenCV의 FFmpeg 백엔드는 다양한 프로토콜을 지원하므로
    `concat:`, `pipe:` 등의 프로토콜 핸들러를 통한 추가 공격 가능
- **영향도:** 서버 파일 시스템 접근, 내부 네트워크 공격, 원격 코드 실행 가능성.
- **수정 방안:**
  1. `source_type=="file"`인 경우 허용된 디렉토리 내 경로만 허용 (화이트리스트)
  2. `source_type=="rtsp"`인 경우 RTSP URL 형식 검증 및 허용 IP 대역 제한
  3. 경로 정규화(`os.path.realpath`) 후 기준 디렉토리 하위인지 검증
  4. `..` 포함 여부 검사 (경로 탐색 방지)
- **수정 우선순위:** P1 - 1주 이내

---

### SEC-005 [HIGH] SQLite 데이터베이스 및 ML 모델 Git 저장소 포함

- **파일:** `backend/app/config.py` (22행, 27행)
- **현상:** 설정 파일에서 데이터베이스와 모델 경로가 프로젝트 내부를 가리킨다:
  ```python
  DATABASE_URL: str = "sqlite+aiosqlite:///./safety_monitor.db"
  MODELS_DIR: Path = BASE_DIR / "models"
  ```
  `.gitignore` 설정이 부적절할 경우 (또는 존재하지 않을 경우),
  데이터베이스 파일(이벤트 이력, 카메라 정보)과 학습된 ML 모델 가중치 파일이
  Git 저장소에 커밋될 수 있다.
- **위험:**
  1. 데이터베이스에 CCTV 이벤트 이력, 카메라 위치/경로 등 민감 정보 포함
  2. ML 모델 가중치는 지적 재산 (학습 비용이 수백만 원 이상)
  3. Git 히스토리에 한번 들어간 파일은 `git rm`으로도 완전 삭제 불가
     (`git filter-branch` 또는 BFG 필요)
  4. 저장소가 공개되거나 유출 시 모든 민감 정보 노출
- **영향도:** 민감 정보 유출, 지적 재산 유출, 개인정보보호법 위반 가능.
- **수정 방안:**
  1. `.gitignore`에 `*.db`, `*.pth`, `*.pt`, `models/`, `snapshots/` 추가
  2. 이미 커밋된 경우 `git filter-repo`로 히스토리에서 제거
  3. ML 모델은 DVC, S3, Artifact Registry 등 별도 저장소에서 관리
  4. DB는 배포 환경에서 PostgreSQL 등 운영급 DBMS로 교체
- **수정 우선순위:** P1 - 1주 이내

---

### SEC-006 [MEDIUM] API 및 WebSocket 속도 제한(Rate Limiting) 부재

- **파일:** `backend/app/main.py` (전체)
- **현상:** 어떤 엔드포인트에도 속도 제한이 적용되어 있지 않다.
  REST API, WebSocket 연결, 정적 파일(스냅샷) 모두 무제한 요청 가능.
- **공격 시나리오:**
  1. `GET /api/events`를 초당 수천 회 요청 -> DB 부하 유발
  2. WebSocket 연결을 수백 개 열기 -> 서버 리소스 고갈
  3. 대량의 `POST /api/cameras/` 요청 -> DB 테이블 비대화
  4. 스냅샷 디렉토리 정적 파일 대량 요청 -> 디스크 I/O 포화
- **영향도:** 서비스 거부(DoS) 공격에 취약. 단일 프로세스 아키텍처와 결합 시
  전체 시스템 마비 가능.
- **수정 방안:**
  1. `slowapi` 또는 `fastapi-limiter` 라이브러리로 IP별 속도 제한 추가
  2. WebSocket 최대 동시 연결 수 제한
  3. 리버스 프록시(Nginx) 레벨에서의 추가 속도 제한
- **수정 우선순위:** P2 - 1개월 이내

---

### SEC-007 [MEDIUM] 스냅샷 파일 접근 제어 부재

- **파일:** `backend/app/main.py` (69행)
- **현상:**
  ```python
  app.mount("/snapshots", StaticFiles(directory=str(settings.SNAPSHOTS_DIR)), name="snapshots")
  ```
  스냅샷 디렉토리가 `StaticFiles`로 마운트되어 있으며, 별도의 접근 제어가 없다.
  스냅샷 파일명은 예측 가능한 패턴(`event_{id}_{type}_{time}.jpg`)이므로
  순차적으로 열거하여 모든 스냅샷을 다운로드할 수 있다.
- **위험:** 스냅샷에는 산업 현장 영상이 포함되며, 작업자 얼굴이 촬영될 수 있다.
  이는 개인정보에 해당하며, 무단 접근 시 개인정보보호법 위반이다.
- **영향도:** CCTV 영상 캡처 무단 열람. 개인정보 유출.
- **수정 방안:**
  1. 정적 파일 마운트 제거, API 엔드포인트를 통한 접근 제어
  2. 인증된 사용자만 스냅샷 다운로드 가능하도록 제한
  3. 스냅샷 파일명에 UUID 사용 (열거 공격 방지)
  4. 일정 기간 경과 후 자동 삭제 정책 적용
- **수정 우선순위:** P2 - 1개월 이내

---

### SEC-008 [LOW] HTTPS/WSS 미적용

- **파일:** `backend/app/main.py` (109-116행),
  `frontend/lib/services/api_service.dart` (9행),
  `frontend/lib/services/websocket_service.dart` (19행)
- **현상:** 서버는 HTTP/WS로만 실행되며, TLS 설정이 전혀 없다.
  프론트엔드도 `http://localhost:8001`과 `ws://localhost:8001`을 사용한다.
- **위험:** 네트워크 스니핑으로 실시간 영상 스트림, API 요청/응답,
  이벤트 데이터 등 모든 통신 내용이 평문으로 노출된다.
- **영향도:** 중간자 공격(MITM), 데이터 도청. 산업 현장 네트워크가
  물리적으로 격리되지 않은 경우 심각한 위협이 된다.
- **수정 방안:**
  1. TLS 인증서 적용 (Let's Encrypt 또는 사내 CA)
  2. uvicorn SSL 설정 또는 리버스 프록시(Nginx)를 통한 TLS 종단
  3. 프론트엔드 URL을 환경별로 구성 가능하도록 설정 외부화
- **수정 우선순위:** P3 - 다음 스프린트

---

## 6. 설계 부채 (Design Debt)

### DEBT-001 [CRITICAL] 전역 가변 싱글톤 - 생명주기 관리 부재

- **파일:** `backend/app/core/detection.py` (288-300행),
  `backend/app/core/roi_manager.py` (270-278행),
  `backend/app/core/alarm_manager.py` (297-305행),
  `backend/app/api/websocket.py` (116행)
- **현상:** 시스템의 핵심 컴포넌트들이 모듈 레벨 전역 변수로 관리된다:
  ```python
  # detection.py
  _detector_instance: Optional[BaseDetector] = None
  def get_detector() -> BaseDetector: ...

  # roi_manager.py
  _roi_manager_instance: Optional[ROIManager] = None
  def get_roi_manager() -> ROIManager: ...

  # alarm_manager.py
  _alarm_manager_instance: Optional[AlarmManager] = None
  def get_alarm_manager() -> AlarmManager: ...

  # websocket.py
  manager = ConnectionManager()
  ```
- **문제점:**
  1. **생명주기 관리 없음:** 생성은 지연(lazy) 초기화되나, 소멸/정리(cleanup)
     로직이 전혀 없다. `lifespan` 핸들러에서 DB만 정리하고 검출기, ROI 관리자,
     알람 관리자는 방치한다.
  2. **테스트 불가능:** 전역 상태를 교체/리셋할 수 없어 단위 테스트에서
     격리가 불가능하다. 테스트 간 상태 오염 발생.
  3. **순환 의존:** `get_detector()`를 여러 모듈에서 직접 호출하여
     암묵적 의존성이 코드 전역에 산재한다.
  4. **GPU 리소스 누수:** `RFDETRDetector`가 보유한 PyTorch 모델이 명시적으로
     해제되지 않아, 장시간 운용 시 GPU 메모리 누수 가능.
- **영향도:** 시스템 장시간 운용 시 메모리/GPU 리소스 누수, 테스트 불가능으로
  인한 회귀 버그 방치, 모듈 간 결합도 증가로 유지보수 비용 급증.
- **수정 방안:**
  1. FastAPI 의존성 주입(Dependency Injection) 패턴으로 전환
  2. `lifespan` 핸들러에서 모든 컴포넌트의 생성/소멸 관리
  3. 인터페이스 기반 추상화로 테스트 시 Mock 주입 가능하도록 설계
  4. `app.state`에 애플리케이션 스코프 객체 저장
- **수정 우선순위:** P0 - 아키텍처 수준 리팩터링 필요

---

### DEBT-002 [CRITICAL] 단일 프로세스 아키텍처 - 확장 불가

- **파일:** `backend/app/main.py` (전체 구조)
- **현상:** 하나의 Python 프로세스에서 다음을 모두 처리한다:
  1. FastAPI REST API 서빙
  2. WebSocket 실시간 스트리밍
  3. OpenCV 비디오 캡처/디코딩
  4. RF-DETR/YOLO 딥러닝 추론 (GPU 집약)
  5. BoT-SORT 객체 추적
  6. 규칙 엔진 평가
  7. SQLite 데이터베이스 I/O
  8. 이미지 인코딩(JPEG)/스냅샷 저장
- **문제점:**
  1. **Python GIL:** CPU 집약적 작업(추론, 이미지 처리)이
     async I/O 이벤트 루프를 블로킹한다.
  2. **수평 확장 불가:** SQLite는 다중 프로세스 동시 쓰기를 지원하지 않아
     워커를 여러 개 실행할 수 없다.
  3. **장애 전파:** 한 카메라의 비디오 디코딩이 실패하면
     다른 카메라의 스트리밍과 API 응답 모두 지연된다.
  4. **GPU 경합:** 여러 카메라의 추론이 동일 GPU에서 직렬화되어
     카메라 수 증가 시 FPS가 급격히 저하된다.
  5. **메모리 압박:** 카메라당 비디오 프레임 버퍼 + 추론 텐서 + base64 인코딩
     결과가 단일 프로세스 메모리에 누적된다.
- **영향도:** 카메라 3대 이상 동시 운용 시 실시간 성능 보장 불가.
  안전-필수 시스템에서 실시간 감지 지연은 직접적 안전 위험이다.
- **수정 방안:**
  1. API 서버와 추론 엔진을 별도 프로세스로 분리
  2. 프로세스 간 통신에 Redis Pub/Sub 또는 메시지 큐(RabbitMQ) 사용
  3. 카메라별 독립 추론 워커 프로세스 실행
  4. SQLite를 PostgreSQL로 교체하여 다중 워커 동시 접근 지원
  5. 비디오 디코딩을 별도 스레드/프로세스로 분리 (`multiprocessing.Process`)
- **수정 우선순위:** P0 - 아키텍처 수준 재설계 필요

---

### DEBT-003 [HIGH] 오류 전파 체계 부재 - 조용한 실패 패턴 만연

- **파일:** 전체 코드베이스
- **현상:** 시스템 전역에서 오류를 로그만 남기고 삼키는 패턴이 반복된다:
  ```python
  # alarm_manager.py:209
  except Exception as e:
      logger.error(f"Failed to save event to database: {e}")
      # DB 저장 실패해도 아무 조치 없이 계속 진행

  # roi_manager.py:76
  except Exception as e:
      logger.error(f"Error adding ROI {roi_id}: {e}")
      # ROI 추가 실패해도 무시

  # detection.py:92
  except Exception as e:
      logger.error(f"YOLO Detection error: {e}")
      # 탐지 오류 시 빈 결과 반환 (정상인 것처럼)
  ```
  프론트엔드도 동일한 패턴:
  ```dart
  // websocket_service.dart:71
  } catch (e) {
      // parse error ignored
  }

  // alarm_service.dart:30
  } catch (e) {
      // fallback: sound file missing
  }
  ```
- **영향도:** 시스템이 부분적으로 고장난 상태에서 정상인 것처럼 동작.
  운용자는 DB에 이벤트가 저장되지 않거나, 탐지가 중단되었거나,
  알람 소리가 나지 않는 것을 인지할 수 없다.
- **수정 방안:**
  1. 결과 타입 패턴(`Result[T, E]`) 도입하여 오류를 호출자에게 명시적 전달
  2. 핵심 기능 실패 시 시스템 상태 표시기(health indicator) 업데이트
  3. 프론트엔드 UI에 시스템 상태 대시보드 추가 (DB 연결, 추론 상태, 트래커 상태)
  4. 연속 N회 실패 시 관리자 알림 (이메일/SMS/Slack)
- **수정 우선순위:** P1 - 1주 이내

---

### DEBT-004 [HIGH] 데이터베이스 마이그레이션 부재

- **파일:** `backend/app/db/database.py` (44-47행)
- **현상:**
  ```python
  async def init_db():
      async with engine.begin() as conn:
          await conn.run_sync(Base.metadata.create_all)
  ```
  `create_all`은 기존 테이블이 없을 때만 생성하고, 기존 테이블의 스키마 변경은
  처리하지 않는다. Alembic 등의 마이그레이션 도구가 설정되어 있지 않다.
- **문제점:**
  1. 모델에 컬럼을 추가해도 기존 DB에 반영되지 않음
  2. 컬럼 타입 변경, 인덱스 추가 등 스키마 변경이 불가능
  3. 업데이트 시 수동으로 DB를 삭제/재생성해야 하며, 이는 모든 데이터 손실을 의미
  4. 롤백 불가능 (이전 버전의 스키마로 되돌릴 수 없음)
- **영향도:** 시스템 업데이트마다 이벤트 이력, 카메라 설정, ROI 설정 등
  모든 운용 데이터가 유실될 위험이 있다.
- **수정 방안:**
  1. Alembic 설정 및 초기 마이그레이션 생성
  2. 모든 스키마 변경을 마이그레이션 스크립트로 관리
  3. CI/CD 파이프라인에서 마이그레이션 검증 자동화
  4. 백업/복원 스크립트 작성
- **수정 우선순위:** P1 - 1주 이내

---

### DEBT-005 [HIGH] 테스트 커버리지 전무

- **파일:** `backend/tests/test_rule_engine_tracking.py` (유일한 테스트 파일),
  `frontend/test/widget_test.dart` (Flutter 기본 생성 파일)
- **현상:** 전체 코드베이스에 테스트 파일이 사실상 1개뿐이며,
  그마저도 `test_stay_time_calculation()` 단 하나의 테스트 함수만 포함한다.
  이 테스트조차 `if __name__ == "__main__":`으로 실행되며, pytest 표준을 따르지 않는다.
  또한 `RuleEngine.evaluate()`에 존재하지 않는 `current_time` 키워드 인수를
  전달하고 있어 실제로 실행이 되지 않을 가능성이 높다.
- **미검증 영역:**
  - REST API 엔드포인트 (0개 테스트)
  - WebSocket 스트리밍 (0개 테스트)
  - ROI 좌표 정규화 (0개 테스트)
  - 탐지 파이프라인 (0개 테스트)
  - 알람 매니저 (0개 테스트)
  - 프론트엔드 위젯/프로바이더 (0개 테스트)
  - 에지 케이스, 경계값, 오류 경로 (0개 테스트)
- **영향도:** 코드 변경 시 회귀 버그를 자동으로 감지할 수단이 전무.
  안전-필수 시스템에서 이는 용납할 수 없는 수준이다.
  IEC 61508 등 안전 표준은 최소 MC/DC 커버리지를 요구한다.
- **수정 방안:**
  1. pytest + pytest-asyncio 기반 백엔드 테스트 프레임워크 구축
  2. 최소 목표: 핵심 경로(critical path) 80% 커버리지
  3. API 통합 테스트 (FastAPI TestClient 사용)
  4. 탐지/추적 모듈 단위 테스트 (Mock 프레임 사용)
  5. 프론트엔드: Flutter widget test, golden test
  6. 프로퍼티 기반 테스트(Hypothesis)로 ROI 좌표 정규화 검증
- **수정 우선순위:** P1 - 지속적 개선 (매 스프린트 커버리지 증가)

---

### DEBT-006 [HIGH] CI/CD 파이프라인 부재

- **파일:** 프로젝트 루트 (`.github/workflows/`, `Jenkinsfile` 등 부재)
- **현상:** 자동화된 빌드, 테스트, 배포 파이프라인이 존재하지 않는다.
  배포는 수동으로 `START_APP.bat` (run_backend.bat + run_frontend.bat)을
  실행하는 방식으로 추정된다.
- **문제점:**
  1. 코드 변경 후 자동 테스트 실행 불가
  2. 린트/정적 분석 자동 검사 부재
  3. 빌드 재현성 미보장 (개발자 환경에 의존)
  4. 배포 이력 추적 불가
  5. 롤백 절차 미수립
- **영향도:** 버그가 포함된 코드가 검증 없이 프로덕션에 배포될 수 있다.
- **수정 방안:**
  1. GitHub Actions 또는 Jenkins 파이프라인 구성
  2. PR 생성 시 자동 테스트 + 린트 실행
  3. Docker 기반 빌드로 환경 재현성 확보
  4. 배포 자동화 및 버전 태깅
- **수정 우선순위:** P1 - 1주 이내

---

### DEBT-007 [MEDIUM] ML 모델 파일 저장소 관리 부재

- **파일:** `backend/app/config.py` (27행)
- **현상:** `MODELS_DIR: Path = BASE_DIR / "models"`로 설정되어 있으며,
  ML 모델 가중치 파일(`best.pt`, `checkpoint_best_ema.pth`)이 프로젝트
  디렉토리 내에 직접 포함된다.
- **문제점:**
  1. 모델 파일은 수백 MB~수 GB로, Git 저장소 크기를 비대하게 만듦
  2. 모델 버전 관리 불가 (어떤 모델이 어떤 성능 지표를 가졌는지 추적 불가)
  3. 모델 A/B 테스트 또는 롤백이 불가능
  4. 여러 개발자/서버 간 모델 동기화 수동 관리 필요
- **수정 방안:**
  1. DVC(Data Version Control)로 모델 버전 관리
  2. S3/GCS 등 오브젝트 스토리지에 모델 저장
  3. 모델 레지스트리(MLflow, Weights & Biases) 도입
  4. 서버 시작 시 모델 자동 다운로드 로직 구현
- **수정 우선순위:** P2 - 1개월 이내

---

### DEBT-008 [MEDIUM] 프론트엔드 ApiService baseUrl 하드코딩

- **파일:** `frontend/lib/services/api_service.dart` (9행),
  `frontend/lib/services/websocket_service.dart` (19행)
- **현상:**
  ```dart
  ApiService({this.baseUrl = 'http://localhost:8001'})
  WebSocketService({this.baseUrl = 'ws://localhost:8001'});
  ```
  백엔드 서버 주소가 소스코드에 하드코딩되어 있다.
- **문제점:**
  1. 서버 IP/포트 변경 시 소스 수정 및 재빌드 필요
  2. 개발/스테이징/프로덕션 환경별 주소 전환 불가
  3. 빌드된 바이너리가 localhost에 고정되어 다른 머신에서 사용 불가
  4. 다중 서버 구성 (로드밸런서 뒤) 시 대응 불가
- **수정 방안:**
  1. 환경변수 또는 설정 파일에서 URL 로드
  2. Flutter의 `--dart-define` 또는 환경별 빌드 구성 활용
  3. 런타임 설정 화면에서 서버 주소 변경 가능하도록 UI 추가
- **수정 우선순위:** P2 - 1개월 이내

---

### DEBT-009 [MEDIUM] 설정 관리 체계 부재

- **파일:** `backend/app/config.py` (전체)
- **현상:** `pydantic_settings`의 `BaseSettings`를 사용하고 `env_file = ".env"`를
  지정했지만, 실제 `.env` 파일이 프로젝트에 포함되어 있지 않으며,
  대부분의 설정이 기본값으로 하드코딩되어 있다.
- **문제점:**
  1. 시크릿(DB 비밀번호, API 키 등)을 환경변수로 관리하는 체계 미수립
  2. 환경별 설정 분리가 안 되어 있어 개발/운영 환경 혼재 가능
  3. `DEBUG: bool = False` 등의 보안 관련 설정이 기본값에 의존
  4. `settings.py`가 즉시 `Settings()` 인스턴스를 생성하여
     모듈 임포트 시점에 설정이 고정됨
- **수정 방안:**
  1. 환경별 `.env` 파일 템플릿 제공 (`.env.example`)
  2. 시크릿 관리 도구(Vault, AWS Secrets Manager) 도입
  3. 필수 환경 변수 누락 시 시작 실패하도록 검증 추가
- **수정 우선순위:** P2 - 1개월 이내

---

### DEBT-010 [LOW] 한국어 전용 UI - 국제화(i18n) 미지원

- **파일:** `frontend/lib/` 전체
- **현상:** 모든 UI 문자열이 한국어로 하드코딩되어 있다.
  국제화 프레임워크(flutter_localizations, intl ARB 파일 등)가 설정되어 있지 않다.
- **영향도:** 다국적 사업장 또는 외국인 작업자 환경에서 사용 불가.
  당장의 장애는 아니나, 확장성에 제약.
- **수정 방안:**
  1. Flutter `intl` 패키지 기반 ARB 파일 국제화 구성
  2. 백엔드 이벤트 메시지도 메시지 코드 + 파라미터 방식으로 변경
- **수정 우선순위:** P3 - 다음 스프린트

---

## 7. 경쟁 조건 및 동시성 문제 (Race Conditions & Concurrency)

### RACE-001 [HIGH] 전역 검출기 인스턴스 다중 WebSocket 공유 - 스레드 안전성 미보장

- **파일:** `backend/app/core/detection.py` (288-300행),
  `backend/app/core/video_processor.py` (427행)
- **현상:** `get_detector()`가 반환하는 전역 싱글톤 검출기 인스턴스를
  모든 WebSocket 연결의 `stream_frames()`에서 공유한다:
  ```python
  # video_processor.py:427
  self.detector = get_detector()
  ```
  `RFDETRDetector`는 내부적으로 `BoTSORTTracker` 인스턴스를 보유하며,
  이 트래커는 이전 프레임의 추적 상태를 내부에 유지한다.
- **문제점:**
  1. 카메라 A의 프레임으로 업데이트된 트래커 상태가
     카메라 B의 프레임 추적에 영향을 미친다.
  2. asyncio 이벤트 루프에서 여러 `stream_frames()` 코루틴이 인터리빙되므로,
     `tracker.update(detections_cam_A, frame_cam_A)` 직후에
     `tracker.update(detections_cam_B, frame_cam_B)`가 호출되어
     카메라 간 추적 상태가 혼합된다.
  3. PyTorch 모델 자체는 `forward()` 호출이 stateless하지만,
     BoTSORT의 Camera Motion Compensation(GMC)은 이전 프레임을 참조하므로
     완전히 비안전(thread-unsafe)하다.
- **재현 시나리오:**
  1. 카메라 2대를 동시에 스트리밍 시작
  2. 양쪽 카메라에서 track_id가 교차 오염되어 동일 사람에게
     매 프레임 다른 ID가 부여됨
  3. 체류시간 계산, 입/퇴장 이벤트 모두 오동작
- **영향도:** 다중 카메라 동시 운용 시 객체 추적 전면 장애.
  카메라별 체류시간, 입/퇴장 이벤트, ROI 침입 감지 모두 신뢰 불가.
- **수정 방안:**
  1. 카메라(또는 WebSocket 연결)별 독립 검출기+트래커 인스턴스 생성
  2. 검출 모델만 공유하고 트래커는 별도 인스턴스로 분리
  3. GPU 메모리 제약 고려하여 검출 모델 풀링 + 트래커 개별화
- **수정 우선순위:** P1 - 1주 이내

---

### RACE-002 [HIGH] ROI Manager 전역 인스턴스 vs WebSocket 개별 인스턴스 - 상태 불일치

- **파일:** `backend/app/api/routes/rois.py` (56-57행, 162-167행),
  `backend/app/api/websocket.py` (163행)
- **현상:** REST API의 ROI 라우터는 전역 ROI Manager를 업데이트한다:
  ```python
  # rois.py:56
  roi_manager = get_roi_manager()
  roi_manager.add_roi(db_roi.id, roi.points, roi.name, roi.color)
  ```
  그러나 WebSocket 핸들러는 카메라별 독립 ROI Manager를 생성한다:
  ```python
  # websocket.py:163
  roi_manager = ROIManager()  # 새 인스턴스
  ```
- **문제점:**
  1. REST API로 ROI를 수정하면 전역 인스턴스만 업데이트되고,
     활성 WebSocket 연결의 ROI Manager에는 반영되지 않음
  2. WebSocket에서 `reload_rois` 명령으로 DB에서 재로드해야만 동기화됨
  3. `reload_rois` 없이는 REST API와 WebSocket의 ROI 상태가 영구적으로 불일치
  4. 전역 ROI Manager는 어디에서도 사용되지 않는 고아 상태가 될 수 있음
     (WebSocket은 자체 인스턴스 사용, REST API만 전역 인스턴스 사용)
- **영향도:** 관리자가 REST API로 위험 구역 ROI를 추가/변경해도,
  이미 스트리밍 중인 카메라에는 적용되지 않는다.
  새로운 위험 구역이 감지되지 않는 안전 공백이 발생한다.
- **수정 방안:**
  1. ROI 변경 시 모든 활성 WebSocket 연결에 자동 동기화 이벤트 전송
  2. 또는 중앙 ROI 관리자를 두고 변경 이벤트를 발행/구독 패턴으로 전파
  3. REST API에서 ROI 변경 시 자동으로 `reload_rois` 트리거
  4. 전역 ROI Manager를 제거하고 DB를 단일 진실 원천(Single Source of Truth)으로 사용
- **수정 우선순위:** P1 - 1주 이내

---

### RACE-003 [MEDIUM] StreamController.broadcast() - 늦은 리스너 프레임 유실

- **파일:** `frontend/lib/services/websocket_service.dart` (29행, 141행)
- **현상:**
  ```dart
  _frameController = StreamController<StreamFrame>.broadcast();
  ```
  `broadcast()` 스트림 컨트롤러를 사용하므로, 리스너가 구독(listen)하기
  전에 추가된 프레임은 유실된다.
- **문제점:**
  1. `connectToStream()`이 스트림을 반환하고, 호출자가 `listen()`하기까지의
     시간차 동안 수신된 프레임이 버려진다.
  2. 메타데이터 메시지(`type: "metadata"`)가 유실되면 `totalDuration`이
     설정되지 않아 타임라인 슬라이더가 0으로 표시된다.
  3. Flutter의 rebuild 사이클에서 provider가 재구독될 때 프레임 유실 가능.
- **영향도:** 간헐적으로 타임라인 정보 누락, 스트림 시작 시 첫 몇 프레임 유실.
  사용자 경험 저하이나 안전 기능에 직접적 영향은 제한적.
- **수정 방안:**
  1. `StreamController` 생성과 `listen()` 호출을 원자적으로 수행
  2. `broadcast()` 대신 단일 구독 컨트롤러 사용 (리스너가 1개인 경우)
  3. 메타데이터는 별도 `Completer`로 전달하여 유실 방지
- **수정 우선순위:** P2 - 1개월 이내

---

### RACE-004 [MEDIUM] AlarmManager 구독자 목록 순회 중 변경 가능

- **파일:** `backend/app/core/alarm_manager.py` (213-221행, 223-237행)
- **현상:**
  ```python
  async def _notify_subscribers(self, event_data):
      for subscriber_id, callback in self._subscribers.items():
          try:
              if asyncio.iscoroutinefunction(callback):
                  await callback(event_data)
              # ...
  ```
  `_notify_subscribers()`가 `self._subscribers`를 순회하는 동안,
  콜백 함수 내부에서 `unsubscribe()`가 호출될 수 있다 (예: WebSocket
  연결이 끊어져 콜백 실행 중 예외 발생 후 정리 로직에서 구독 해제).
- **문제점:**
  1. Python 3에서 딕셔너리 순회 중 크기 변경 시 `RuntimeError` 발생
  2. asyncio에서 `await callback(event_data)` 실행 중 다른 코루틴이
     `subscribe()` 또는 `unsubscribe()`를 호출할 수 있음
  3. `.items()` 반환값은 뷰(view) 객체이므로 딕셔너리 변경이 반영됨
- **재현:** 여러 WebSocket 클라이언트가 연결/연결해제를 빈번히 반복하면서
  동시에 이벤트가 발생하는 경우.
- **영향도:** 이벤트 알림 도중 `RuntimeError`로 일부 구독자에게
  알림이 전달되지 않을 수 있다.
- **수정 방안:**
  1. 순회 전 `list(self._subscribers.items())`로 복사본 사용
  2. `asyncio.Lock`으로 구독자 목록 접근 동기화
  3. 구독/구독해제를 큐에 넣고 순회 후 일괄 처리
- **수정 우선순위:** P2 - 1개월 이내

---

## 8. 종합 수정 우선순위 로드맵

### Phase 0: 즉시 조치 (배포 차단 사유 해소) - 1~3일

| ID | 항목 | 심각도 | 예상 공수 |
|----|------|--------|-----------|
| SEC-001 | 인증/인가 구현 (최소 JWT) | CRITICAL | 2일 |
| SEC-002 | CORS 제한 | CRITICAL | 0.5시간 |
| BUG-001 | 이벤트 ID DB 위임 | CRITICAL | 0.5일 |
| BUG-002 | 알람 사운드 에셋 + 폴백 | CRITICAL | 0.5일 |

### Phase 1: 긴급 수정 - 1주 이내

| ID | 항목 | 심각도 | 예상 공수 |
|----|------|--------|-----------|
| BUG-003 | ROI 좌표 정규화 명시적 해상도 전달 | HIGH | 1일 |
| BUG-004 | 법령 패널 API 연동 | HIGH | 1일 |
| BUG-005 | 트래커 폴백 모드 개선 | HIGH | 1일 |
| SEC-003 | WebSocket 입력 검증 | HIGH | 0.5일 |
| SEC-004 | 카메라 소스 경로 검증 | HIGH | 0.5일 |
| SEC-005 | .gitignore + 히스토리 정리 | HIGH | 0.5일 |
| DEBT-003 | 오류 전파 체계 수립 | HIGH | 2일 |
| DEBT-004 | Alembic 마이그레이션 도입 | HIGH | 1일 |
| DEBT-006 | CI/CD 파이프라인 기본 구성 | HIGH | 1일 |
| RACE-001 | 카메라별 트래커 인스턴스 분리 | HIGH | 1일 |
| RACE-002 | ROI 동기화 메커니즘 | HIGH | 1일 |

### Phase 2: 안정화 - 1개월 이내

| ID | 항목 | 심각도 | 예상 공수 |
|----|------|--------|-----------|
| DEBT-001 | 전역 싱글톤 DI 패턴 전환 | CRITICAL | 3일 |
| DEBT-002 | 다중 프로세스 아키텍처 재설계 | CRITICAL | 2주 |
| DEBT-005 | 테스트 커버리지 확보 (핵심 경로 80%) | HIGH | 2주 (지속) |
| BUG-006 | 비디오 탐색 PTS 기반 검증 | MEDIUM | 1일 |
| BUG-007 | 시간 기반 지속성 윈도우 전환 | MEDIUM | 1일 |
| BUG-008 | 제네릭 Exception 처리 정비 | MEDIUM | 1일 |
| SEC-006 | 속도 제한 적용 | MEDIUM | 0.5일 |
| SEC-007 | 스냅샷 접근 제어 | MEDIUM | 0.5일 |
| DEBT-007 | ML 모델 외부 저장소 이전 | MEDIUM | 1일 |
| DEBT-008 | 프론트엔드 URL 설정 외부화 | MEDIUM | 0.5일 |
| DEBT-009 | 설정 관리 체계 수립 | MEDIUM | 0.5일 |
| RACE-003 | StreamController 프레임 유실 방지 | MEDIUM | 0.5일 |
| RACE-004 | AlarmManager 구독자 목록 동기화 | MEDIUM | 0.5일 |

### Phase 3: 품질 개선 - 다음 분기

| ID | 항목 | 심각도 | 예상 공수 |
|----|------|--------|-----------|
| BUG-009 | 크로스플랫폼 폰트 지원 | LOW | 0.5일 |
| SEC-008 | HTTPS/WSS 적용 | LOW | 0.5일 |
| DEBT-010 | 국제화(i18n) 지원 | LOW | 2일 |

---

## 9. 위험 영향도 매트릭스

```
발생 가능성
높음 ┃ SEC-001   BUG-002  DEBT-002
     ┃ SEC-002   RACE-001
     ┃
중간 ┃ BUG-001   BUG-005  SEC-003
     ┃ RACE-002  SEC-004  DEBT-003
     ┃ BUG-008   DEBT-005
     ┃
낮음 ┃ BUG-003   BUG-006  BUG-009
     ┃ SEC-008   DEBT-010 RACE-003
     ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━
       낮음      중간      높음
                      영향도(심각도)
```

**적색 영역 (즉시 조치):** SEC-001, SEC-002, BUG-001, BUG-002, DEBT-002
- 발생 가능성 높음 + 영향도 높음: 시스템이 현재 상태로 운용되면
  이 결함들은 반드시 발현된다. 인명 피해와 법적 책임이 따른다.

**황색 영역 (긴급 수정):** BUG-003~005, SEC-003~005, RACE-001~002, DEBT-001,003~006
- 특정 조건에서 발현되며, 발현 시 안전 기능에 직접적 영향.

**녹색 영역 (계획 수정):** BUG-006~009, SEC-006~008, DEBT-007~010, RACE-003~004
- 영향이 제한적이거나 발생 가능성이 낮으나, 기술 부채로 누적됨.

---

## 10. 결론

본 시스템은 31건의 결함이 식별되었으며, 이 중 CRITICAL 6건, HIGH 12건이다.
**안전-필수 시스템으로서 현재 상태는 프로덕션 배포에 적합하지 않다.**

가장 시급한 문제는 다음 세 가지이다:

1. **인증 전면 부재 (SEC-001, SEC-002):** 누구나 시스템을 조작할 수 있다.
   이는 안전 관제 시스템의 존재 의미를 근본적으로 부정하는 결함이다.

2. **이벤트 ID 충돌 및 알람 무음 (BUG-001, BUG-002):** 경보 시스템이
   사실상 작동하지 않는다. 경보가 울리지 않고, 경보를 해제할 수도 없다.

3. **단일 프로세스 + 전역 상태 (DEBT-001, DEBT-002):** 다중 카메라 운용 시
   추적 데이터가 교차 오염되고, 시스템 확장이 불가능하다.

이 세 가지 문제가 해결되기 전까지, 이 시스템에 대한 어떠한 프로덕션 배포도
승인할 수 없다. 산업안전보건법 제38조 및 중대재해처벌법 제4조에 명시된
사업주의 안전 조치 의무를 이 시스템이 충족하지 못하기 때문이다.

---

> **면책 조항:** 본 문서는 소스 코드 정적 분석에 기반한 기술 검토 결과이며,
> 법률 자문을 대체하지 않습니다. 법적 준수 여부에 대한 최종 판단은
> 관련 법률 전문가의 자문을 받으시기 바랍니다.
