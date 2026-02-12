# backend/app/core/detection.py

## 역할
다중 백엔드 객체 탐지 모듈. BaseDetector ABC, YOLODetector, RFDETRDetector 구현. 전역 싱글턴 팩토리.

## 핵심 알고리즘
- **YOLODetector**: ultralytics YOLO.track() 사용 (내장 트래킹, persist=True)
- **RFDETRDetector**: rfdetr 라이브러리 predict() + BoT-SORT 외부 트래커
- **_map_category()**: 클래스명 → 카테고리 매핑 (person, helmet, mask, fire_extinguisher 등)
- **get_detector()**: 전역 싱글턴 팩토리 (if/else 분기)

## 입출력
- **입력**: np.ndarray (BGR 프레임), frame_number, timestamp
- **출력**: DetectionResult (DetectionBox 리스트 + 카운트)

## 런타임 동작
- 모델은 첫 호출 시 lazy 로딩
- RF-DETR: checkpoint에서 state_dict 추출, 12클래스 detection head 재초기화, strict=False 로딩
- 전역 싱글턴으로 모든 WebSocket 연결이 동일 인스턴스 공유

## 리스크
- CRITICAL: 전역 싱글턴 — 테스트 불가, 다중 카메라 시 트래킹 상태 오염
- CRITICAL: YOLO track(persist=True) — 다른 카메라 프레임이 트래킹 상태 오염
- HIGH: strict=False 로딩 — 일부 가중치가 랜덤 초기화 상태일 수 있음
- HIGH: Exception catch + 빈 결과 반환 — 탐지 실패 침묵
- MEDIUM: _map_category() 두 탐지기에 중복 구현 — DRY 위반
- MEDIUM: get_detector() if/else — OCP 위반

## 수정 포인트
- 싱글턴 → FastAPI DI 또는 카메라별 인스턴스 풀
- _map_category()를 BaseDetector로 올리기
- get_detector()를 Registry 패턴으로 변경

## 테스트 제안
- 모킹된 모델로 detect() 파이프라인 테스트
- _map_category() 매핑 정확성 테스트
- 모델 미로드 시 동작 테스트
- 빈 프레임/None 입력 처리 테스트
