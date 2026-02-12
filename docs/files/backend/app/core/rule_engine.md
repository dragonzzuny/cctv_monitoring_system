# backend/app/core/rule_engine.py

## 역할
안전 규칙 평가 엔진. ROI 침입 탐지, PPE 미착용 감지, 소화기 부재 감지, 입/퇴장 추적. 오탐 방지를 위한 지속성/쿨다운 메커니즘.

## 핵심 알고리즘
- **지속성 검증 (Persistence)**: 이벤트가 N프레임 연속 감지되어야 확정 (오탐 방지)
- **쿨다운 (Cooldown)**: 동일 이벤트가 N초 이내 재발생 시 무시
- **헬멧 근접성 검사**: person 바운딩박스 상단 40% 영역 내에 helmet이 100px 이내에 있는지 확인
- **입/퇴장 추적**: track_id 기반으로 ROI 진입/이탈 감지, 체류 시간 계산

## 이벤트 타입
ROI_INTRUSION, PPE_HELMET_MISSING, PPE_MASK_MISSING, FIRE_EXTINGUISHER_MISSING, WARNING_ZONE_INTRUSION, DANGER_ZONE_INTRUSION, PERSON_ENTRANCE, PERSON_EXIT

## 입출력
- **입력**: DetectionResult, ROI 목록, 프레임 해상도
- **출력**: List[Dict] (이벤트 데이터), ROI 메트릭 (인원수, 체류시간)

## 런타임 동작
- WebSocket 연결별 인스턴스 생성 (상태 격리는 올바름)
- _person_states: track_id별 PersonState (무한 누적!)
- _detection_states: (event_type, roi_id)별 DetectionState

## 리스크
- HIGH: _person_states 무한 누적 — 메모리 누수
- HIGH: 프레임 카운트 기반 지속성 — FPS 변동 시 시간 부정확
- MEDIUM: 헬멧 100px 매직 넘버 — 해상도에 따라 부정확
- MEDIUM: 모든 규칙이 단일 evaluate() 메서드 — OCP 위반
- LOW: 마스크 근접성 검사 미구현 (ROI 내 존재만 확인)

## 수정 포인트
- _person_states TTL 기반 정리 추가
- 프레임 카운트 → 실제 시간 기반 지속성
- Strategy 패턴으로 규칙 분리
- 매직 넘버 → 설정으로 추출

## 테스트 제안
- ROI 침입 감지 정확성 (경계값)
- PPE 미착용 감지 (헬멧 있음/없음)
- 쿨다운 동작 테스트
- 지속성 프레임 카운트 테스트
- 입/퇴장 추적 테스트
- 체류 시간 계산 정확성
