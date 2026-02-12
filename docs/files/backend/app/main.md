# backend/app/main.py

## 역할
FastAPI 애플리케이션 진입점. 서버 초기화, 미들웨어 설정, 라우터 등록, 정적 파일 마운트.

## 핵심 로직
- `lifespan()`: 시작 시 `init_db()`, 종료 시 DB 엔진 dispose
- CORS: `allow_origins=["*"]` ← **보안 취약점**
- StaticFiles: `/snapshots` 경로로 스냅샷 이미지 제공 (인증 없음)
- 6개 REST 라우터 + 1개 WebSocket 라우터 등록

## 입출력
- **입력**: HTTP/WebSocket 요청
- **출력**: JSON 응답, WebSocket 프레임

## 런타임 동작
- uvicorn 단일 워커, 0.0.0.0:8001
- asyncio 이벤트 루프 사용

## 설정 의존성
- `app.config.settings` (포트, DB URL 등)

## 수정 위험 포인트
- CORS 설정 변경 시 프론트엔드 연결 영향
- lifespan에서 에러 시 서버 시작 실패
- 라우터 prefix 변경 시 프론트엔드 API URL 모두 변경 필요

## 리스크
- CRITICAL: CORS allow_origins=["*"]
- HIGH: 인증 미들웨어 없음
- MEDIUM: 스냅샷 파일 무인증 접근

## 테스트 제안
- CORS 정책 테스트
- lifespan 초기화/종료 테스트
- 라우터 등록 확인 테스트
