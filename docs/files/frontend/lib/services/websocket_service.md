# frontend/lib/services/websocket_service.dart

## 역할
WebSocket 클라이언트. 스트림 채널(프레임 수신)과 이벤트 채널(알림 수신) 관리. 명령 전송 (start/stop/seek/reload_rois).

## 핵심 로직
- **connectToStream()**: broadcast StreamController 생성, 'frame'/'metadata' 타입 메시지 파싱, totalDurationMs 캐시
- **sendStreamCommand()**: JSON 명령 WebSocket으로 전송
- **disconnectStream()**: 채널 닫기, _lastTotalDurationMs 리셋
- **connectToEvents()**: 이벤트 전용 WebSocket 채널

## 입출력
- **입력**: WebSocket 메시지 (JSON 문자열)
- **출력**: Stream<StreamFrame>, Stream<Map<String, dynamic>>

## 리스크
- HIGH: baseUrl 하드코딩 ('ws://localhost:8001') — 배포 시 변경 필요
- HIGH: 에러 파싱이 빈 catch 블록 — 프레임 손실 감지 불가
- MEDIUM: broadcast StreamController — 늦은 구독자 프레임 유실
- MEDIUM: 자동 재연결 없음 — 수동 재연결만 가능
- LOW: _lastTotalDurationMs 캐시가 카메라 전환 시 이전 값 잔존 가능

## 수정 포인트
- baseUrl을 설정에서 읽기
- 에러 로깅 추가
- 자동 재연결 메커니즘 (지수 백오프)

## 테스트 제안
- 메시지 파싱 정확성 테스트 (frame, metadata)
- 연결/해제 수명주기 테스트
- 비정상 JSON 처리 테스트
