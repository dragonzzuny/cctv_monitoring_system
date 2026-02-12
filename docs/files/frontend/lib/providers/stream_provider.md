# frontend/lib/providers/stream_provider.dart

## 역할
스트림 상태 관리 (Riverpod StateNotifier). 연결, 재생/정지, 시킹, ROI 리로드, 이벤트 처리, 알람 트리거.

## 핵심 로직
- **StreamState**: isConnected, isPlaying, currentPosition, totalDuration, currentFrame, error
- **connect()**: 기존 구독 해제 → 500ms 대기 → WS 연결 → 프레임 리스너 등록 → auto-start
- **프레임 리스너**: 빈 frameBase64 → 메타데이터 업데이트, 일반 프레임 → 상태 업데이트 + 이벤트 처리
- **이벤트 처리**: 프레임의 events 배열에서 SafetyEvent 파싱 → eventsProvider 추가 → 비INFO 심각도 시 activeAlarmProvider 트리거

## 리스크
- HIGH: SRP 위반 — Provider가 이벤트 파싱, 알람 트리거까지 수행 (Feature Envy)
- MEDIUM: 500ms 하드코딩된 연결 지연 — 네트워크 조건에 따라 부족/과다
- MEDIUM: 이벤트 파싱 에러 무시 (빈 catch)
- LOW: seek() 시 currentFrameBytes를 null로 설정하지만 provider가 아닌 widget에서 관리

## 수정 포인트
- 이벤트 처리 로직을 별도 서비스/provider로 분리
- 연결 재시도 로직 추가

## 테스트 제안
- connect/disconnect 상태 전이 테스트
- 프레임 수신 시 상태 업데이트 테스트
- seek 시 position 업데이트 테스트
- 이벤트 파싱 테스트
