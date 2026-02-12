# frontend/lib/widgets/video_player_widget.dart

## 역할
비디오 스트리밍 표시 위젯. WebSocket으로 수신된 base64 프레임을 디코딩하여 Image.memory로 렌더링. 재생/정지/시킹 컨트롤, 진행 바 (파일 소스), 연결 상태 표시.

## 핵심 로직
- **_currentFrameBytes**: base64Decode된 JPEG 바이트 (매 build()마다 디코딩)
- **_connectToCamera()**: 선택된 카메라 변경 감지 → 스트림 연결
- **_buildProgressBar()**: 파일 소스일 때만 Slider 표시, 시킹 지원
- **_calculateProgress()**: totalDuration 0일 때 WS 캐시에서 폴백
- **_handleSeek()**: value * duration → targetMs → seek 명령

## 입출력
- **입력**: StreamState (via Riverpod watch), Camera 정보
- **출력**: 비디오 프레임 + 탐지 오버레이 + 컨트롤 UI

## 리스크
- HIGH: base64Decode가 build() 메서드 내에서 실행 — 매 위젯 리빌드마다 디코딩 (성능)
- MEDIUM: gaplessPlayback=true로 2프레임 동시 메모리 유지 (~12MB)
- MEDIUM: 카메라 변경 감지가 build()에서 수행 — 사이드 이펙트
- LOW: _isSeeking 상태로 시킹 중 진행바 잠금 (적절한 처리)

## 수정 포인트
- base64Decode를 StreamState/Provider 레벨로 이동 (build 밖으로)
- Binary WebSocket 전환 시 Image.memory 대신 RawImage/Texture 사용

## 테스트 제안
- 프레임 표시 위젯 테스트 (valid/invalid bytes)
- 진행 바 시킹 테스트
- 카메라 전환 시 재연결 테스트
- 연결 에러 상태 표시 테스트
