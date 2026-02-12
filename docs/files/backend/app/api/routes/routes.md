# backend/app/api/routes/ (전체)

## cameras.py
- Camera CRUD (GET list, GET by id, POST, PUT, DELETE)
- DELETE: selectinload로 연관 ROI/Event/Checklist 로드 후 cascade 삭제
- 리스크: 인증 없음, source_url 미검증

## stream.py
- GET /snapshot/{camera_id}: 새 VideoProcessor 생성 → 프레임 캡처 → JPEG 응답 → release
- GET /stream/{camera_id}/info: 스트리밍 정보
- POST /stream/{camera_id}/seek: placeholder (WS로 처리)
- 리스크: 스냅샷마다 새 VideoProcessor 생성 (리소스 낭비), release 누락 가능

## events.py
- Event CRUD + 필터링 (카메라, 타입, 심각도, 날짜, 인정 여부)
- GET /stats: 그룹별 집계
- POST /acknowledge/{id}, POST /acknowledge-all
- 리스크: 인증 없음, 날짜 필터 SQL 인젝션 가능성 낮음(ORM 사용)

## rois.py
- ROI CRUD, points를 JSON 문자열로 직렬화/역직렬화
- 리스크: 좌표 범위 미검증, 유효 폴리곤 미검증

## checklists.py
- Checklist CRUD, 기본 템플릿 생성, 항목 체크/언체크, 리셋
- auto_check_item: 탐지 결과 기반 자동 체크
- 리스크: 경미 (기능적 이슈 없음)

## regulations.py
- GET /regulations: 카테고리별 안전 규정 조회
- 리스크: 프론트엔드 safety_regulation_panel.dart가 이 API를 사용하지 않음 (하드코딩)

## 테스트 제안
- 각 라우트 CRUD 테스트
- 필터링 조합 테스트
- 잘못된 입력 처리 테스트
