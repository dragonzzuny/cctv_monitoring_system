# frontend/lib/widgets/ (전체)

## video_player_widget.dart → 별도 문서 참조

## detection_overlay.dart
- **DetectionInfoOverlay**: 탐지 요약 (인원수, 헬멧, 마스크, 소화기 카운트 + ROI 메트릭)
- **DetectionBoxOverlay**: CustomPainter로 바운딩 박스 그리기 (클래스별 색상, track_id 표시)
- 리스크: ROI 메트릭 표시가 null 체크 기반, 빈 상태 처리 양호

## roi_status_panel.dart
- 실시간 ROI 존 상태 (인원수, 체류시간)
- StreamState의 roiMetrics 사용
- 리스크: roiMetrics가 null이면 빈 패널, 에러 표시 없음

## alarm_popup.dart
- WARNING/CRITICAL 이벤트 시 모달 팝업
- 인정(acknowledge) 버튼
- 리스크: 알람 사운드 재생 실패 (AlarmService의 에셋 미존재)

## timeline_panel.dart
- 최근 이벤트 목록 (심각도별 아이콘/색상)
- 인정(acknowledge) 버튼
- 리스크: 경미

## checklist_panel.dart
- 안전 체크리스트 (진행률 바, 체크/언체크)
- 기본 템플릿 자동 생성
- 리스크: 경미

## safety_regulation_panel.dart
- **하드코딩된 안전 규정 표시** — API/Provider 미사용!
- 리스크: MEDIUM — DB 변경 시 UI 반영 안 됨. API 연동 필요.

## status_bar.dart
- 하단 상태 바 (연결, 카메라, 스트림, 탐지 정보)
- 리스크: 경미

## 테스트 제안
- 각 위젯 Golden 테스트
- 알람 팝업 표시/닫기 테스트
- safety_regulation_panel API 연동 후 테스트
