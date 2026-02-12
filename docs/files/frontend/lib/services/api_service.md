# frontend/lib/services/api_service.dart

## 역할
Dio 기반 REST API 클라이언트. 백엔드의 모든 REST 엔드포인트 호출 메서드 제공.

## 핵심 로직
- baseUrl: 'http://localhost:8001' 하드코딩
- 카메라 CRUD: getCameras, getCamera, createCamera, updateCamera, deleteCamera
- ROI CRUD: getRois, createRoi, updateRoi, deleteRoi
- 이벤트: getEvents, getEventStats, acknowledgeEvent, acknowledgeAllEvents
- 체크리스트: getChecklists, createDefaultChecklist, updateChecklistItem, resetChecklist
- 스트림: getSnapshot (바이너리 응답)

## 리스크
- HIGH: baseUrl 하드코딩 — 배포 시 수정 필요, 설정 파일이나 환경 변수에서 읽어야 함
- MEDIUM: 에러 핸들링이 Dio 기본 예외에 의존 — 구조화된 에러 처리 없음
- MEDIUM: 인증 토큰 헤더 미지원 — 인증 추가 시 인터셉터 필요
- LOW: getSnapshot의 바이너리 응답 처리 (responseType: ResponseType.bytes)

## 수정 포인트
- baseUrl을 SharedPreferences 또는 설정에서 읽기
- Dio 인터셉터로 인증 토큰 자동 주입
- 에러 인터셉터로 공통 에러 처리

## 테스트 제안
- 각 API 호출 mock 테스트
- 에러 응답 처리 테스트
- 네트워크 타임아웃 처리 테스트
