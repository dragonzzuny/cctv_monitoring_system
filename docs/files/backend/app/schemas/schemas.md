# backend/app/schemas/ (전체 Pydantic 스키마)

## 역할
API 입출력 데이터 검증 및 직렬화. Pydantic v2 BaseModel 기반. 모든 REST 엔드포인트와 WebSocket 프레임에서 사용.

---

## camera.py (37줄)
- **CameraBase**: name, source_type ('file'/'rtsp'), source_url, description, is_active
- **CameraCreate**: CameraBase 상속 (생성용)
- **CameraResponse**: CameraBase + id, created_at (Config: from_attributes=True)
- **리스크**: source_url에 대한 포맷/경로 검증 없음. source_type이 Literal이 아닌 일반 str.

## roi.py (46줄)
- **ROIBase**: name, zone_type ('warning'/'danger'), points (str — JSON 문자열), color, camera_id
- **ROICreate**: ROIBase 상속
- **ROIResponse**: ROIBase + id, created_at
- **리스크**:
  - points가 str 타입으로 JSON 파싱이 API 핸들러에서 수동 수행됨 → List[Point] 타입으로 변경 필요
  - zone_type이 Literal이 아닌 일반 str → 잘못된 값 입력 가능
  - 좌표 범위 검증 없음 (음수, 1초과)

## event.py (41줄)
- **EventBase**: event_type, severity ('INFO'/'WARNING'/'CRITICAL'), description, camera_id
- **EventCreate**: EventBase 상속
- **EventResponse**: EventBase + id, created_at, acknowledged, acknowledged_at, snapshot_path
- **리스크**: event_type이 enum이 아닌 일반 str. severity도 Literal 미사용.

## detection.py (52줄)
- **DetectionBox**: class_id, class_name, confidence, x1/y1/x2/y2, center_x/center_y, track_id (Optional)
- **DetectionResult**: frame_number, timestamp, detections (List[DetectionBox]), persons_count, helmets_count, masks_count, fire_extinguishers_count
- **StreamFrame**: camera_id, frameBase64 (Field alias 'frame_base64'), detection (Optional), currentMs, totalMs, events (list), roiMetrics (Optional), raw_frame (excluded from serialization)
- **SafetyStatus**: status, active_violations, persons_in_danger, roi_status
- **리스크**:
  - StreamFrame.raw_frame이 `exclude=True`로 직렬화에서 제외되지만 메모리에는 존재
  - DetectionResult의 카운트 필드 4개가 고정 — 새 카테고리(gloves, vest 등) 추가 시 스키마 변경 필요

## checklist.py (59줄)
- **ChecklistItemBase**: name, description, is_checked, checked_at, auto_check_type
- **ChecklistBase**: title, camera_id
- **ChecklistResponse**: ChecklistBase + id, items (List[ChecklistItemResponse]), created_at
- **리스크**: 경미

## regulations.py (16줄)
- **SafetyRegulationResponse**: id, name, category, description, reference_law
- **리스크**: 프론트엔드 safety_regulation_panel.dart가 이 스키마를 사용하지 않음

---

## 공통 리스크
- **Pydantic v2 strict mode 미사용**: 타입 강제(coercion)가 활성화되어 잘못된 타입도 자동 변환
- **Validator 부재**: 커스텀 validator가 전혀 없음. 비즈니스 규칙 검증이 스키마 레벨에서 수행되지 않음
- **Enum 미사용**: source_type, zone_type, severity, event_type 등이 모두 일반 str → Literal 또는 Enum으로 변경 필요

## 테스트 제안
- 각 스키마의 유효/무효 입력 테스트
- JSON 직렬화/역직렬화 라운드트립 테스트
- boundary 값 (빈 문자열, None, 음수 등) 테스트
