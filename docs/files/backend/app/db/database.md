# backend/app/db/database.py, models.py, seed_data.py

## database.py
- Async SQLAlchemy 엔진 (aiosqlite)
- AsyncSessionLocal 팩토리
- get_db() 의존성 (예외 시 rollback)
- 리스크: SQLite 단일 쓰기 제한, 테스트용 DB 팩토리 없음

## models.py
- 6개 ORM 모델: Camera, ROI, Event, Checklist, ChecklistItem, SafetyRegulation
- Event에 인덱스: (camera_id, created_at), (acknowledged), (severity)
- Camera cascade: ROI, Event, Checklist 연쇄 삭제
- 리스크: 마이그레이션 시스템(Alembic) 없음, timezone-aware datetime 기본값

## seed_data.py
- 5개 안전 규정 시드 데이터 (한국 산업안전법)
- 리스크: 중복 삽입 방지가 name 기반 체크만

## 테스트 제안
- DB 초기화/시드 테스트
- 모델 CRUD 테스트
- 캐스케이드 삭제 테스트
- 인덱스 쿼리 성능 테스트
