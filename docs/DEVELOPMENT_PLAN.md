# F. 개발 계획 (Development Plan)

> 작성 기준: 30년 경력 시니어 아키텍트의 실무 개발 로드맵
> 대상 시스템: CCTV SAFE-YOLO Industrial Monitoring System
> 작성일: 2026-02-11

---

## 1. 개발 마일스톤 (Development Milestones)

### Phase 1: 긴급 수정 및 보안 강화 (1~2주)

**목표: 프로덕션 배포 최소 조건 충족**

| # | 작업 | 파일 | 우선순위 | 예상 공수 |
|---|------|------|---------|----------|
| 1.1 | JWT 기반 인증/인가 추가 | 신규: auth/, middleware | CRITICAL | 3일 |
| 1.2 | CORS 정책 수정 (allow_origins=["*"] 제거) | main.py | CRITICAL | 0.5일 |
| 1.3 | AlarmManager 이벤트 ID DB 동기화 | alarm_manager.py | CRITICAL | 0.5일 |
| 1.4 | 깨진 알람 오디오 서비스 수정 또는 제거 | alarm_service.dart, pubspec.yaml | HIGH | 0.5일 |
| 1.5 | WebSocket 명령 입력 검증 | websocket.py | HIGH | 1일 |
| 1.6 | 카메라 소스 경로 검증/샌드박싱 | cameras.py, config.py | HIGH | 1일 |
| 1.7 | safety_regulation_panel API 연동 | safety_regulation_panel.dart | MEDIUM | 0.5일 |
| 1.8 | .gitignore 추가 (DB, 로그, 모델, 스냅샷) | .gitignore | HIGH | 0.5일 |

**검증 기준:**
- [ ] 인증 없이 API 접근 불가 확인
- [ ] CORS가 허용된 도메인만 통과 확인
- [ ] 서버 재시작 후 이벤트 ID 연속성 확인

### Phase 2: 아키텍처 안정화 (2~4주)

**목표: 유지보수 가능한 코드베이스 구축**

| # | 작업 | 파일 | 우선순위 | 예상 공수 |
|---|------|------|---------|----------|
| 2.1 | 테스트 프레임워크 구축 (pytest, conftest, fixtures) | tests/ 전체 | CRITICAL | 2일 |
| 2.2 | 핵심 모듈 단위 테스트 작성 (rule_engine, detection, roi_manager) | tests/ | CRITICAL | 5일 |
| 2.3 | WebSocket 통합 테스트 작성 | tests/test_websocket.py | HIGH | 2일 |
| 2.4 | Alembic DB 마이그레이션 시스템 도입 | alembic/ | HIGH | 1일 |
| 2.5 | 전역 싱글턴 → FastAPI Depends() DI 전환 | core/*.py, api/*.py | HIGH | 3일 |
| 2.6 | websocket.py 비즈니스 로직 분리 → StreamService 클래스 | services/stream_service.py | HIGH | 2일 |
| 2.7 | 구조화된 로깅 도입 (structlog/python-json-logger) | 전체 | MEDIUM | 1일 |
| 2.8 | 에러 핸들링 표준화 (커스텀 예외 계층) | core/exceptions.py | MEDIUM | 1일 |
| 2.9 | CI/CD 파이프라인 구축 (GitHub Actions) | .github/workflows/ | HIGH | 1일 |
| 2.10 | 프론트엔드 Widget/Provider 테스트 작성 | frontend/test/ | MEDIUM | 3일 |
| 2.11 | 환경 변수 기반 설정 관리 (.env) | config.py, .env.example | MEDIUM | 0.5일 |

**검증 기준:**
- [ ] 테스트 커버리지 60% 이상
- [ ] CI 파이프라인에서 자동 테스트 통과
- [ ] DB 스키마 변경이 마이그레이션으로 관리됨
- [ ] 전역 싱글턴 0개

### Phase 3: 성능 최적화 (1~2개월)

**목표: 단일 서버에서 최대 성능 달성**

| # | 작업 | 파일 | 우선순위 | 예상 공수 |
|---|------|------|---------|----------|
| 3.1 | Binary WebSocket 프레임 전송 (base64 제거) | websocket.py, websocket_service.dart | HIGH | 3일 |
| 3.2 | asyncio.to_thread()로 블로킹 호출 래핑 | websocket.py, video_processor.py | HIGH | 1일 |
| 3.3 | 탐지 프로세스 분리 (multiprocessing) | core/detection_worker.py | HIGH | 5일 |
| 3.4 | 프레임 파이프라인 (Producer-Consumer, 백프레셔) | core/frame_pipeline.py | HIGH | 3일 |
| 3.5 | JPEG 인코딩 품질 최적화 (quality=75) | video_processor.py | MEDIUM | 0.5일 |
| 3.6 | 탐지 프레임 스킵 전략 (매 N번째 프레임) | video_processor.py | MEDIUM | 1일 |
| 3.7 | ROI 체크 최적화 (공간 인덱스) | roi_manager.py | LOW | 2일 |
| 3.8 | Flutter Image 디코딩 최적화 | video_player_widget.dart | MEDIUM | 1일 |
| 3.9 | PostgreSQL 마이그레이션 | database.py, models.py, docker-compose | HIGH | 3일 |
| 3.10 | Redis 캐시 레이어 도입 | services/cache.py | MEDIUM | 2일 |

**검증 기준:**
- [ ] 단일 카메라 스트리밍 지연 < 200ms
- [ ] 5개 동시 카메라 스트리밍 가능
- [ ] 탐지 프레임률 15fps 유지
- [ ] 메모리 사용량 카메라당 500MB 미만

### Phase 4: 확장성 확보 (2~3개월)

**목표: 수평 확장 가능한 아키텍처**

| # | 작업 | 우선순위 | 예상 공수 |
|---|------|---------|----------|
| 4.1 | Docker 컨테이너화 | HIGH | 2일 |
| 4.2 | docker-compose 개발 환경 | HIGH | 1일 |
| 4.3 | 마이크로서비스 분해 (API/Stream/Detection/Notification) | HIGH | 2주 |
| 4.4 | 메시지 큐 도입 (Redis Streams 또는 RabbitMQ) | HIGH | 1주 |
| 4.5 | Kubernetes 배포 매니페스트 | MEDIUM | 1주 |
| 4.6 | Prometheus + Grafana 모니터링 스택 | HIGH | 3일 |
| 4.7 | 분산 추적 (OpenTelemetry) | MEDIUM | 2일 |
| 4.8 | 자동 스케일링 정책 (HPA) | MEDIUM | 2일 |
| 4.9 | GPU 리소스 스케줄링 | LOW | 1주 |
| 4.10 | 로드 밸런서 구성 (WebSocket sticky sessions) | HIGH | 2일 |

---

## 2. 기술 부채 상환 계획

### Priority 1: 보안 부채 (즉시)

```
현재 상태:
  ├── 인증: 없음 ❌
  ├── 인가: 없음 ❌
  ├── CORS: allow_origins=["*"] ❌
  ├── HTTPS: 미지원 ❌
  ├── 입력 검증: 부분적 ⚠️
  └── 감사 로그: 없음 ❌

목표 상태:
  ├── 인증: JWT + API Key ✅
  ├── 인가: RBAC (admin/operator/viewer) ✅
  ├── CORS: 화이트리스트 기반 ✅
  ├── HTTPS: TLS 1.3 ✅
  ├── 입력 검증: Pydantic strict mode + 커스텀 밸리데이터 ✅
  └── 감사 로그: 모든 변경 작업 기록 ✅
```

### Priority 2: 테스트 부채 (Phase 2)

```
현재: 1개 테스트, 커버리지 ~0.5%
목표: 커버리지 80%+

필요한 테스트:
  ├── Unit Tests
  │   ├── rule_engine: 규칙별 개별 테스트, 경계값 테스트
  │   ├── detection: 모킹된 모델로 파이프라인 테스트
  │   ├── roi_manager: 좌표 변환, 폴리곤 검증
  │   ├── alarm_manager: 이벤트 큐, 구독자 알림
  │   └── video_processor: 프레임 인코딩, 시킹
  ├── Integration Tests
  │   ├── WebSocket 스트리밍 플로우
  │   ├── REST API CRUD
  │   └── DB 마이그레이션
  ├── Frontend Tests
  │   ├── Provider 단위 테스트
  │   ├── Widget 테스트
  │   └── Integration 테스트
  └── E2E Tests
      └── 전체 스트리밍 시나리오
```

### Priority 3: 아키텍처 부채 (Phase 2~3)

| 부채 | 현재 | 목표 |
|------|------|------|
| 전역 싱글턴 | 3개 global 변수 | FastAPI DI |
| God Module | websocket.py 150줄 함수 | Service 계층 분리 |
| 모놀리스 | 단일 프로세스 | 최소 3개 서비스 |
| SQLite | 단일 쓰기 제한 | PostgreSQL |
| 동기 블로킹 | asyncio에서 sync 호출 | to_thread() + 프로세스 분리 |

### Priority 4: 운영 부채 (Phase 3~4)

| 부채 | 현재 | 목표 |
|------|------|------|
| CI/CD | 없음 | GitHub Actions |
| 모니터링 | 없음 | Prometheus + Grafana |
| 로깅 | print 수준 | 구조화된 JSON 로그 |
| 컨테이너 | 없음 | Docker + K8s |
| 시크릿 관리 | 하드코딩 | Vault 또는 K8s Secrets |

---

## 3. 코드 규칙 제안

### 3.1 명명 규칙 (Naming Conventions)

**Python (Backend):**
```python
# 클래스: PascalCase
class DetectionWorker:

# 함수/메서드: snake_case
def process_frame():

# 상수: UPPER_SNAKE_CASE
MAX_FRAME_BUFFER_SIZE = 100

# private: _prefix
def _internal_method():

# 파일: snake_case
detection_worker.py
```

**Dart (Frontend):**
```dart
// 클래스: PascalCase
class StreamNotifier

// 변수/함수: camelCase
void connectToStream()

// 상수: camelCase with k prefix or UPPER_SNAKE
const kMaxRetries = 3;

// 파일: snake_case
stream_provider.dart
```

### 3.2 에러 핸들링 패턴

```python
# 금지: 빈 except
try:
    ...
except:  # ❌ 절대 금지
    pass

# 금지: 광범위 Exception
try:
    ...
except Exception:  # ❌ 구체적 예외 사용
    pass

# 권장: 구체적 예외 + 로깅 + 전파
try:
    result = detector.detect(frame)
except ModelNotLoadedError:
    logger.error("Detection model not loaded", exc_info=True)
    raise
except InferenceError as e:
    logger.warning(f"Inference failed: {e}", exc_info=True)
    return DetectionResult.empty(frame_number)
```

### 3.3 로깅 표준

```python
# 구조화된 로깅 필수
logger.info("frame_processed",
    camera_id=camera_id,
    frame_number=frame_num,
    detection_count=len(detections),
    processing_time_ms=elapsed_ms
)

# 로그 레벨 기준:
# DEBUG: 개발 시 상세 정보 (프레임 데이터, 좌표 등)
# INFO: 정상 작동 이벤트 (연결, 스트림 시작/종료)
# WARNING: 복구 가능한 문제 (재연결, 폴백 사용)
# ERROR: 복구 불가능한 문제 (모델 로드 실패, DB 접근 불가)
# CRITICAL: 시스템 중단 수준 (GPU OOM, 전체 서비스 다운)
```

### 3.4 테스트 요구사항

- **모든 PR은 관련 테스트를 포함해야 한다**
- 새 기능: 단위 테스트 + 통합 테스트 필수
- 버그 수정: 재현 테스트 필수
- 최소 커버리지: 80% (신규 코드), 60% (기존 코드)
- 핵심 모듈 (detection, rule_engine): 90% 이상

### 3.5 PR 리뷰 체크리스트

- [ ] 테스트 포함 여부
- [ ] 에러 핸들링 적절성
- [ ] 보안 검토 (입력 검증, 인증)
- [ ] 성능 영향 검토
- [ ] 로깅 적절성
- [ ] 문서 업데이트 필요 여부
- [ ] 하드코딩된 값 없음
- [ ] 전역 상태 변경 없음

---

## 4. 릴리즈 전략

### 4.1 버전 관리 (SemVer)

```
MAJOR.MINOR.PATCH

현재: 1.0.0 (초기 버전)
Phase 1 완료 후: 1.1.0 (보안 강화)
Phase 2 완료 후: 1.2.0 (안정화)
Phase 3 완료 후: 2.0.0 (아키텍처 변경 - Breaking)
Phase 4 완료 후: 3.0.0 (마이크로서비스 전환 - Breaking)
```

### 4.2 브랜치 전략

```
main ─────────────────────────────────────>
  │                    │
  └── release/1.1.0    └── release/1.2.0
  │                    │
  └── feature/auth     └── feature/binary-ws
  └── feature/tests    └── feature/detection-worker
  └── fix/alarm-id     └── fix/memory-leak
```

- `main`: 항상 배포 가능 상태
- `release/*`: 릴리즈 후보, 버그 수정만 허용
- `feature/*`: 기능 개발 브랜치
- `fix/*`: 버그 수정 브랜치
- `hotfix/*`: 긴급 수정 (main에서 분기)

### 4.3 롤백 절차

1. 즉시 롤백: 이전 Docker 이미지로 전환 (< 5분)
2. DB 롤백: Alembic downgrade (< 10분)
3. 전체 롤백: Git revert + 재배포 (< 30분)

### 4.4 피처 플래그

```python
# config.py에 피처 플래그 관리
FEATURE_FLAGS = {
    "binary_websocket": False,     # Phase 3에서 활성화
    "detection_worker": False,     # Phase 3에서 활성화
    "gpu_batching": False,         # Phase 4에서 활성화
    "microservices": False,        # Phase 4에서 활성화
}
```

---

## 5. 리소스 계획

### 5.1 팀 구성 (최소)

| 역할 | 인원 | 책임 |
|------|------|------|
| 백엔드 시니어 | 1 | 아키텍처 리팩토링, 성능 최적화 |
| 백엔드 주니어 | 1 | 테스트 작성, API 개발 |
| 프론트엔드 | 1 | Flutter 최적화, 테스트 |
| ML 엔지니어 | 0.5 | 모델 최적화, GPU 관리 |
| DevOps | 0.5 | CI/CD, 모니터링, 인프라 |

### 5.2 기술 역량 요구사항

- Python async/concurrency 깊은 이해
- FastAPI 의존성 주입 패턴
- PyTorch 모델 최적화 (ONNX, TensorRT)
- WebSocket/실시간 시스템 경험
- Docker/Kubernetes 경험
- Flutter 성능 최적화

### 5.3 교육 필요 사항

| 주제 | 대상 | 기간 |
|------|------|------|
| asyncio 동시성 패턴 | 백엔드 팀 | 2일 |
| 테스트 주도 개발 (TDD) | 전체 팀 | 3일 |
| Docker/K8s 기초 | 전체 팀 | 2일 |
| GPU 추론 최적화 | ML 엔지니어 | 1주 |
| 보안 개발 (Secure SDLC) | 전체 팀 | 1일 |

---

## 6. 리스크 관리

| 리스크 | 확률 | 영향 | 완화 방안 |
|--------|------|------|----------|
| Phase 1 보안 패치 지연 | 높음 | CRITICAL | 전담 인력 배정, 일일 진척 확인 |
| 테스트 작성 공수 과소평가 | 높음 | HIGH | 2주 버퍼 확보, 핵심 모듈 우선 |
| DB 마이그레이션 데이터 유실 | 중간 | CRITICAL | 마이그레이션 전 전체 백업, 스테이징 환경 검증 |
| 바이너리 WS 전환 호환성 문제 | 중간 | HIGH | 기존/신규 프로토콜 병행 기간 설정 |
| 프로세스 분리 후 통신 오버헤드 | 낮음 | MEDIUM | 프로토타입 벤치마크 먼저 수행 |
| GPU OOM 운영 중 발생 | 높음 | HIGH | GPU 메모리 모니터링 + OOM killer 정책 |

---

## 최종 권고

**이 프로젝트는 "기술 부채의 복리 이자"가 이미 원금을 초과하기 시작한 상태다.**

Phase 1(보안)과 Phase 2(안정화)를 건너뛰고 기능 추가에 집중하면, 6개월 내에 유지보수 불가능한 상태에 도달할 것이다. 당장 기능이 동작한다는 것은 품질을 의미하지 않는다.

**보안 강화 → 테스트 → 리팩토링 → 최적화** 순서는 절대적이며, 이 순서를 변경해서는 안 된다.
