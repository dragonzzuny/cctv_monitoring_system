# backend/app/core/tracker.py

## 역할
BoT-SORT 트래커 래퍼. ultralytics BOTSORT 사용, 실패 시 인덱스 기반 단순 폴백.

## 핵심 로직
- BoTSORTTracker: ultralytics.trackers.BOTSORT 래핑
- update(): raw_detections [x1,y1,x2,y2,score,cls] → 트래킹 결과 [x1,y1,x2,y2,track_id,conf,cls]
- 폴백: import 실패 시 SimpleFallbackTracker (1000+i 오프셋 ID)

## 리스크
- HIGH: 폴백 트래커는 진짜 트래킹이 아님 — 프레임마다 ID가 리셋됨 (1000, 1001, ...) → 입/퇴장 감지, 체류시간 계산 완전 무효화
- MEDIUM: BoT-SORT 내부 상태가 스레드 안전하지 않음
- LOW: tracker 초기화 실패 시 경고만 로깅, 에러 전파 없음

## 수정 포인트
- 폴백 트래커 사용 시 사용자에게 명시적 경고
- 트래커 인스턴스를 카메라별로 생성

## 테스트 제안
- 연속 프레임에서 트래킹 ID 유지 테스트
- 폴백 트래커 동작 확인
