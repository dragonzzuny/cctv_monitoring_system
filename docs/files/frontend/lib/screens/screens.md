# frontend/lib/screens/ (전체)

## main_control_screen.dart
- 메인 화면. 키보드 단축키 (Space=재생/정지, Esc=알람 닫기)
- 레이아웃: 70/30 분할 (왼쪽: 비디오+규정, 오른쪽: ROI상태+체크리스트+타임라인)
- 카메라 드롭다운 선택기 (AppBar)
- 헤더 버튼: 설정, ROI 편집기, 이력
- AlarmPopup 오버레이
- 리스크: 복잡한 레이아웃이지만 잘 구조화됨. KeyboardListener로 포커스 관리.

## camera_settings_screen.dart
- 카메라 CRUD 폼
- 소스 타입: file (파일 선택) / rtsp (URL 입력)
- TextEditingController 기반 폼 관리
- 리스크: 입력 검증 UI 수준만 (서버 검증 의존)

## roi_editor_screen.dart
- 스냅샷 이미지 위에 ROI 폴리곤 그리기
- CustomPainter (RoiPainter) 사용
- 클릭으로 포인트 추가, BoxFit.contain 좌표 변환
- zone_type (warning/danger), color 선택
- 리스크: 좌표 변환이 BoxFit.contain에 의존 — 이미지 비율 불일치 시 부정확 가능

## event_history_screen.dart
- 이벤트 목록 (필터: 심각도, 타입, 인정 여부)
- 통계 표시 (심각도별 카운트)
- 이벤트 상세 다이얼로그 (스냅샷 이미지 포함)
- 리스크: 경미. 대량 이벤트 시 페이지네이션 필요할 수 있음.

## 테스트 제안
- 각 화면 Widget 테스트
- 카메라 선택 → 비디오 연결 통합 테스트
- ROI 좌표 변환 정확성 테스트
