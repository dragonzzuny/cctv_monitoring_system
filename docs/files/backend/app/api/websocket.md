# backend/app/api/websocket.py

## 역할
WebSocket 엔드포인트. 실시간 비디오 스트리밍(카메라별), 이벤트 구독, 명령 처리 (start/stop/seek/reload_rois).

## 핵심 로직
- **ConnectionManager**: asyncio.Lock으로 연결 관리, 브로드캐스트
- **websocket_stream()**: 150줄+ 단일 함수. VideoProcessor 생성 → 명령 루프 → 스트리밍 루프 → 탐지 → 규칙 평가 → 이벤트 생성/저장 → 프레임 전송
- **websocket_events()**: 이벤트 전용 구독 (acknowledge 지원)
- 명령 폴링: asyncio.wait_for(receive_json, timeout=0.01) 으로 10ms마다 명령 확인

## 입출력
- **입력**: WebSocket 연결, 카메라 ID, JSON 명령 (action: start/stop/seek/reload_rois)
- **출력**: JSON 프레임 데이터 (type, frame_base64, detection, events, metadata)

## 런타임 동작
- 연결별 VideoProcessor, ROIManager, RuleEngine 인스턴스 생성
- 프레임 루프 중 명령 수신 → stop/seek/reload_rois 처리
- metadata 메시지: 파일 소스일 때 total_duration_ms 전송

## 리스크
- CRITICAL: God Module — 모든 비즈니스 로직이 이 파일에 집중
- CRITICAL: sync 블로킹 호출이 async 핸들러 내에서 실행
- HIGH: 명령 폴링 10ms timeout이 탐지 80ms 블로킹 동안 무효
- HIGH: 전역 detector 인스턴스 공유 (카메라간 트래킹 오염)
- MEDIUM: 에러 시 리소스 정리 불완전 (VideoProcessor release)
- MEDIUM: 브로드캐스트가 순차적 — 느린 구독자가 빠른 구독자 차단

## 수정 포인트
- StreamService로 비즈니스 로직 분리
- asyncio.to_thread()로 블로킹 래핑
- 카메라별 탐지기 인스턴스

## 테스트 제안
- WebSocket 연결/해제 테스트
- start/stop/seek 명령 테스트
- 비정상 종료 시 리소스 정리 테스트
- 다중 연결 동시성 테스트
