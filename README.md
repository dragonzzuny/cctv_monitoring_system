# CCTV 기반 화기작업 안전관제 시스템

화기작업 현장의 안전관리를 위한 CCTV 기반 실시간 모니터링 시스템입니다.

## 주요 기능

- **실시간 영상 모니터링**: WebSocket 기반 실시간 영상 스트리밍
- **YOLO 객체 탐지**: 작업자, 안전모, 마스크, 소화기 탐지
- **ROI (관심영역) 설정**: 드래그&드롭 방식 ROI 편집
- **안전 규칙 자동 검사**: PPE 착용 여부, 소화기 비치 여부 자동 확인
- **알람 시스템**: 오탐 방지 로직 적용, 경고 팝업 및 사운드
- **체크리스트**: 자동/수동 체크 지원
- **이벤트 이력**: 필터링 및 통계 기능

## 프로젝트 구조

```
cctv_yolo/
├── backend/                 # FastAPI 백엔드
│   ├── app/
│   │   ├── main.py         # 앱 진입점
│   │   ├── config.py       # 설정
│   │   ├── api/            # REST API 및 WebSocket
│   │   ├── core/           # 핵심 로직
│   │   ├── db/             # 데이터베이스
│   │   └── schemas/        # Pydantic 스키마
│   ├── models/             # YOLO 모델 (best.pt)
│   └── requirements.txt
├── frontend/               # Flutter 프론트엔드
│   ├── lib/
│   │   ├── main.dart
│   │   ├── screens/        # 화면
│   │   ├── widgets/        # 위젯
│   │   ├── providers/      # 상태관리
│   │   ├── services/       # API 서비스
│   │   └── models/         # 데이터 모델
│   └── pubspec.yaml
├── run_backend.bat         # 백엔드 실행
└── run_frontend.bat        # 프론트엔드 실행
```

## 설치 및 실행

### 1. 백엔드 설정

```bash
cd backend
pip install -r requirements.txt
```

### 2. YOLO 모델 배치

`backend/models/` 폴더에 `best.pt` 파일을 복사합니다.

### 3. 백엔드 실행

```bash
cd backend
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

또는 `run_backend.bat` 실행

### 4. 프론트엔드 설정 및 실행

```bash
cd frontend
flutter pub get
flutter run -d windows
```

또는 `run_frontend.bat` 실행

## API 문서

백엔드 실행 후 다음 URL에서 API 문서 확인:
- Swagger UI: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc

## 주요 API 엔드포인트

### 카메라
- `POST /api/cameras/` - 카메라 등록
- `GET /api/cameras/` - 카메라 목록
- `GET /api/cameras/{id}` - 카메라 상세

### ROI
- `POST /api/rois/` - ROI 생성
- `GET /api/rois/?camera_id={id}` - ROI 목록

### 이벤트
- `GET /api/events/` - 이벤트 목록
- `POST /api/events/{id}/acknowledge` - 이벤트 확인

### 체크리스트
- `POST /api/checklists/camera/{id}/default` - 기본 체크리스트 생성
- `PUT /api/checklists/items/{id}` - 체크리스트 항목 수정

### WebSocket
- `ws://localhost:8000/ws/stream/{camera_id}` - 영상 스트리밍
- `ws://localhost:8000/ws/events` - 이벤트 알림

## 탐지 클래스

| 클래스 | 설명 |
|--------|------|
| person | 작업자 |
| helmet | 안전모 |
| mask | 마스크 |
| fire_extinguisher | 소화기 |

## 알람 시스템

### 이벤트 타입
| 타입 | 심각도 | 조건 |
|-----|--------|------|
| ROI_INTRUSION | INFO | 작업자 ROI 진입 |
| PPE_HELMET_MISSING | WARNING | 안전모 미착용 |
| PPE_MASK_MISSING | WARNING | 마스크 미착용 |
| FIRE_EXTINGUISHER_MISSING | WARNING | 소화기 미비치 |

### 오탐 방지
- 2초 지속 판정
- 30초 쿨다운
- 30프레임 중 20프레임 이상 탐지

## 키보드 단축키

| 키 | 기능 |
|----|------|
| Space | 재생/일시정지 |
| Esc | 팝업 닫기 |

## 기술 스택

- **백엔드**: Python, FastAPI, SQLite, SQLAlchemy, Ultralytics YOLO
- **프론트엔드**: Flutter, Riverpod, Dio, WebSocket
- **AI**: YOLOv8

## 라이선스

사내 전용
