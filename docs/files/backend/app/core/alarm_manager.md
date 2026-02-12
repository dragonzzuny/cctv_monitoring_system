# backend/app/core/alarm_manager.py

## 역할
안전 이벤트 큐 처리, WebSocket 구독자 브로드캐스트, 스냅샷 저장, DB 이벤트 영속화.

## 핵심 로직
- asyncio.Queue 기반 이벤트 큐
- 구독자(subscriber) 패턴: WebSocket 이벤트 채널로 실시간 알림
- 스냅샷: 날짜별 디렉토리에 cv2.imwrite (이벤트 정보 오버레이)
- DB 저장: SQLAlchemy async session으로 Event 모델 생성

## 입출력
- **입력**: 이벤트 데이터 dict + 프레임(스냅샷용)
- **출력**: DB 저장 + WebSocket 브로드캐스트 + 파일 시스템 스냅샷

## 리스크
- CRITICAL: _next_event_id 인메모리 카운터 — 서버 재시작 시 ID 충돌/리셋
- HIGH: asyncio.Queue 백프레셔 없음 — 이벤트 폭주 시 메모리 누적
- MEDIUM: 스냅샷 저장 보존 정책 없음 — 디스크 무한 사용
- MEDIUM: 스냅샷 저장이 스트리밍 파이프라인 블로킹 가능
- LOW: 구독자 리스트 동시 수정 가능성 (async 컨텍스트)

## 수정 포인트
- _next_event_id → DB max(id) + 1 동기화
- Queue에 maxsize 설정
- 스냅샷 디스크 사용량 모니터링 + 자동 정리

## 테스트 제안
- 이벤트 큐 처리 순서 테스트
- 구독자 브로드캐스트 테스트
- 스냅샷 파일 생성 테스트
- DB 이벤트 영속화 테스트
