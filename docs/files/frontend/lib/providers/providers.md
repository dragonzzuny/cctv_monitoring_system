# frontend/lib/providers/ (전체)

## camera_provider.dart
- CamerasNotifier: fetchCameras, addCamera, updateCamera, deleteCamera
- camerasProvider: AsyncNotifierProvider (카메라 목록)
- selectedCameraProvider: StateProvider<Camera?> (현재 선택 카메라)
- 리스크: 경미. 표준 CRUD 패턴.

## stream_provider.dart → 별도 문서 참조

## event_provider.dart
- EventsNotifier: loadEvents (필터), addEvent, acknowledgeEvent/All
- ActiveAlarmNotifier: showAlarm (3초 후 자동 숨김), hideAlarm
- activeAlarmProvider: StateNotifierProvider (팝업 알람 상태)
- 리스크: addEvent 중복 방지 없음 (같은 이벤트 2번 추가 가능)

## roi_provider.dart
- RoisNotifier: selectedCamera 의존, loadRois, addRoi, updateRoi, deleteRoi
- RoiEditingNotifier: ROI 편집 상태 관리 (포인트 추가/삭제/이동)
- 리스크: 카메라 변경 시 ROI 리로드 타이밍 이슈 가능

## checklist_provider.dart
- ChecklistNotifier: loadChecklists, createDefaultChecklist, updateItem, resetChecklist, autoCheckItem
- 리스크: autoCheckItem이 탐지 결과 기반이지만 호출 경로가 불명확

## providers.dart (barrel file)
- 모든 provider와 서비스 provider export
- webSocketServiceProvider, apiServiceProvider, alarmServiceProvider 정의
- 리스크: webSocketService baseUrl 하드코딩

## 테스트 제안
- 각 Notifier 상태 전이 테스트
- 카메라 변경 시 연쇄 상태 업데이트 테스트
- 이벤트 중복 추가 방지 테스트
