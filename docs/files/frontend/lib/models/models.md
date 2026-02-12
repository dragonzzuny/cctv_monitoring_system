# frontend/lib/models/ (전체 데이터 모델)

> 작성 기준: 30년 경력 시니어 아키텍트
> 작성일: 2026-02-11

---

## 역할
Flutter 프론트엔드의 데이터 모델 계층. JSON 직렬화/역직렬화, 백엔드 API 응답 매핑, UI 상태 표현을 담당한다.

---

## models.dart (배럴 파일, 5줄)
```dart
export 'camera.dart';
export 'roi.dart';
export 'event.dart';
export 'checklist.dart';
export 'detection.dart';
```
- 단순 re-export. 리스크 없음.

---

## camera.dart (63줄)

### Camera 클래스
- **필드**: id, name, source, sourceType, isActive, createdAt, updatedAt
- **팩토리**: `Camera.fromJson()` — snake_case → camelCase 수동 매핑
- **직렬화**: `toJson()` — createdAt, updatedAt 누락 (생성 시 불필요하므로 의도적)

### CameraCreate 클래스
- **필드**: name, source, sourceType (기본값: 'file')
- **직렬화**: `toJson()` — 3개 필드만 전송

### 리스크
| # | 심각도 | 내용 |
|---|--------|------|
| 1 | HIGH | **fromJson에서 null 체크 없음** — `json['id']`가 null이면 `int` 타입 위반으로 런타임 크래시. 백엔드 스키마가 변경되면 즉시 전체 카메라 기능 불능. |
| 2 | MEDIUM | **sourceType이 일반 String** — 'file'과 'rtsp' 외의 값이 들어와도 컴파일러가 잡지 못함. 백엔드의 source_type과 동기화 필요. |
| 3 | MEDIUM | **toJson()에서 createdAt/updatedAt 직렬화 안 함** — 현재는 의도적이지만, PUT 요청 시 서버에서 이 필드를 기대하면 문제 발생 가능. |
| 4 | LOW | **immutable이지만 copyWith() 미제공** — 상태 업데이트 시 새 인스턴스 생성이 번거로움. |

### 백엔드 스키마 불일치 위험
```
백엔드 CameraResponse:
  - source_url (str)     ← 필드명
  - description (str)    ← 프론트엔드에 없음!

프론트엔드 Camera:
  - source (String)      ← source_url → source 로 변환? 불명확
  - updatedAt (DateTime) ← 백엔드에 없음!
```
**이 불일치는 API 연동 시 런타임 에러의 주요 원인이다.**

---

## event.dart (101줄)

### Severity enum
```dart
enum Severity {
  info('INFO'),
  warning('WARNING'),
  critical('CRITICAL');
}
```
- `fromString()`: 매칭 실패 시 `Severity.info`로 폴백 — **위험: 알 수 없는 심각도를 "정보"로 격하**

### EventType enum
```dart
enum EventType {
  roiIntrusion('ROI_INTRUSION'),
  ppeHelmetMissing('PPE_HELMET_MISSING'),
  ppeMaskMissing('PPE_MASK_MISSING'),
  fireExtinguisherMissing('FIRE_EXTINGUISHER_MISSING');
}
```
- `fromString()`: 매칭 실패 시 `EventType.roiIntrusion`으로 폴백 — **위험: 알 수 없는 이벤트를 ROI 침입으로 분류**
- `displayName`: 한국어 UI 텍스트 하드코딩 — i18n 불가

### SafetyEvent 클래스
- **필드**: id, cameraId, eventType, severity, message, roiId?, snapshotPath?, detectionData?, isAcknowledged, acknowledgedAt?, createdAt
- **computed**: `severityEnum`, `eventTypeEnum` — String을 Enum으로 변환

### 리스크
| # | 심각도 | 내용 |
|---|--------|------|
| 1 | **CRITICAL** | **eventType과 severity가 String으로 저장** — Enum을 정의해놓고도 실제 필드는 String. computed getter로 변환하는 이중 구조. 타입 안전성 무의미. |
| 2 | HIGH | **fromString 폴백이 위험한 기본값** — 알 수 없는 severity를 info로, 알 수 없는 eventType을 roiIntrusion으로 변환. 디버깅 시 원인 파악 극히 어려움. |
| 3 | HIGH | **detectionData 파싱 취약** — `json['detection_data'] is String ? null : ...` 조건으로 String일 때 null 처리하지만, 이는 백엔드가 JSON 문자열을 반환하는 경우를 우회하는 것으로 근본 원인 미해결. |
| 4 | MEDIUM | **fromJson에서 null safety 부족** — `json['id']`, `json['camera_id']` 등 필수 필드에 대한 null 처리 없음. |
| 5 | LOW | **copyWith() 미제공** — acknowledged 상태 변경 시 새 인스턴스 생성 불편. |

### 코드 냄새: Enum과 String의 이중 구조
```dart
// SafetyEvent 내부
final String eventType;    // ← String으로 저장
final String severity;     // ← String으로 저장

// 사용 시
Severity get severityEnum => Severity.fromString(severity);  // ← 매번 변환
EventType get eventTypeEnum => EventType.fromString(eventType);  // ← 매번 변환
```
**Enum을 만들어 놓고 사용하지 않는 전형적인 "하다 만" 패턴이다.** eventType과 severity를 처음부터 Enum 타입으로 저장해야 한다.

---

## roi.dart (94줄)

### Point 클래스
- **필드**: x, y (double)
- **직렬화**: 양방향 (fromJson/toJson)
- `(json['x'] as num).toDouble()` — 안전한 변환 패턴

### ROI 클래스
- **필드**: id, cameraId, name, points (List<Point>), color, zoneType, isActive, createdAt, updatedAt
- **팩토리**: `fromJson()` — points 배열 파싱 포함
- **직렬화**: `toJson()` — createdAt, updatedAt 제외

### ROICreate 클래스
- **필드**: cameraId, name, points, color (기본: '#FF0000'), zoneType (기본: 'warning')

### 리스크
| # | 심각도 | 내용 |
|---|--------|------|
| 1 | HIGH | **zoneType이 일반 String** — 'warning'과 'danger' 외 값 허용. Enum 미사용. 백엔드도 동일한 문제. |
| 2 | MEDIUM | **좌표 범위 검증 없음** — Point의 x, y에 음수나 1.0 초과 값이 들어와도 모델 레벨에서 차단 불가. |
| 3 | MEDIUM | **최소 포인트 수 미검증** — 빈 리스트나 1~2개 포인트로 ROI 생성 가능 (유효한 폴리곤 불가). |
| 4 | LOW | **fromJson에서 zoneType 기본값** — `json['zone_type'] ?? 'warning'` — null 방어적이지만 백엔드가 항상 반환해야 하는 필드. |

### 백엔드 스키마 불일치
```
백엔드 ROI 스키마:
  - points: str (JSON 문자열!)

프론트엔드 ROI 모델:
  - points: List<Point> (파싱된 객체!)
```
**백엔드는 points를 JSON 문자열로 저장하고, API 응답에서도 문자열 또는 파싱된 리스트를 반환할 수 있다. 이 불일치가 직렬화 에러의 잠재적 원인이다.**

---

## detection.dart (123줄)

### DetectionBox 클래스
- **필드**: classId, className, confidence, x1/y1/x2/y2, centerX/centerY, trackId?
- **computed**: `width`, `height` — 바운딩 박스 크기

### DetectionResult 클래스
- **필드**: frameNumber, timestamp, detections (List<DetectionBox>), personsCount, helmetsCount, masksCount, fireExtinguishersCount

### StreamFrame 클래스
- **필드**: cameraId, frameBase64, currentMs, totalMs, detection?, events, rois, roiMetrics

### 리스크
| # | 심각도 | 내용 |
|---|--------|------|
| 1 | **CRITICAL** | **StreamFrame.frameBase64가 String** — 매 프레임마다 수십~수백KB의 base64 문자열이 Dart 힙에 할당됨. 30fps 기준 초당 ~30회 GC 압력. 이것이 프론트엔드 성능 병목의 핵심. |
| 2 | HIGH | **DetectionResult의 카운트 필드 4개 고정** — 새 탐지 카테고리(vest, gloves 등) 추가 시 모델/백엔드/프론트엔드 3곳 동시 변경 필요. `Map<String, int> counts`로 변경해야 확장 가능. |
| 3 | HIGH | **StreamFrame.events가 `List<Map<String, dynamic>>`** — 타입 안전성 없음. `List<SafetyEvent>`로 변경해야 함. |
| 4 | HIGH | **StreamFrame.rois가 `List<Map<String, dynamic>>`** — 동일 문제. 타입 없는 맵 사용. |
| 5 | MEDIUM | **StreamFrame.roiMetrics가 `Map<String, dynamic>`** — 구조화된 모델 없이 동적 맵 사용. UI에서 접근 시 키 오타 위험. |
| 6 | MEDIUM | **fromJson에서 대량 null 합체 (`??`)** — 백엔드 응답 구조가 변경되면 조용히 기본값으로 폴백하여 버그 은폐. |
| 7 | LOW | **DetectionBox의 좌표가 절대 픽셀값** — 다양한 해상도에서 사용 시 스케일링 로직이 UI 계층에 산재. |

### 메모리 영향 분석 (30fps 기준)
```
StreamFrame 1개당 메모리:
├── frameBase64: ~100KB (640x480 JPEG → base64)
├── detections: ~2KB (10개 박스 기준)
├── events: ~1KB
├── roiMetrics: ~0.5KB
└── 총합: ~103.5KB

30fps × ~103.5KB = ~3.1MB/sec Dart 힙 할당
→ Dart GC가 초당 ~3MB 해제해야 함
→ 프레임 드롭/UI 멈춤의 직접 원인
```

---

## checklist.dart (89줄)

### ChecklistItem 클래스
- **필드**: id, checklistId, itemType, description, isChecked, autoChecked, checkedAt?, createdAt
- **copyWith()**: isChecked, autoChecked만 변경 가능

### Checklist 클래스
- **필드**: id, cameraId, name, isActive, items (List<ChecklistItem>), createdAt, updatedAt
- **computed**: `checkedCount`, `totalCount`, `progress`

### 리스크
| # | 심각도 | 내용 |
|---|--------|------|
| 1 | LOW | **itemType이 일반 String** — Enum 미사용이지만, 체크리스트 항목 타입이 한정적이므로 심각도 낮음. |
| 2 | LOW | **copyWith이 부분적** — checkedAt 업데이트가 불가. isChecked=true 시 checkedAt도 갱신해야 하지만 불가능. |

---

## 공통 문제 종합

### 1. 코드 생성 미사용
```dart
// 현재: 수동 fromJson/toJson (에러 프론)
factory Camera.fromJson(Map<String, dynamic> json) {
  return Camera(
    id: json['id'],       // ← 키 오타 시 런타임 크래시
    name: json['name'],   // ← null 시 런타임 크래시
  );
}

// 권장: freezed + json_serializable (컴파일 타임 안전)
@freezed
class Camera with _$Camera {
  factory Camera({
    required int id,
    required String name,
    @JsonKey(name: 'source_url') required String source,
    @JsonKey(name: 'source_type') required String sourceType,
  }) = _Camera;
  factory Camera.fromJson(Map<String, dynamic> json) => _$CameraFromJson(json);
}
```

### 2. 백엔드-프론트엔드 스키마 불일치 목록

| 필드 | 백엔드 | 프론트엔드 | 상태 |
|------|--------|-----------|------|
| Camera.source | source_url | source | **불일치 의심** |
| Camera.description | description (str) | — | **프론트엔드 누락** |
| Camera.updatedAt | — | updatedAt | **백엔드 누락** |
| ROI.points | str (JSON 문자열) | List<Point> | **타입 불일치** |
| Event.severity | str | String (Enum 존재하나 미사용) | **타입 불일치** |
| Event.eventType | str | String (Enum 존재하나 미사용) | **타입 불일치** |
| StreamFrame.events | dict 리스트 | `List<Map>` | **비구조화** |

### 3. 불변성 및 동등성

모든 모델이 `==` 연산자와 `hashCode`를 오버라이드하지 않는다. Riverpod의 상태 비교가 참조 동등성에 의존하게 되어, 동일 데이터의 새 인스턴스 생성 시 불필요한 리빌드가 발생한다.

**freezed 패키지 도입으로 모든 문제를 일괄 해결할 수 있다:**
- immutable 보장
- copyWith 자동 생성
- == / hashCode 자동 생성
- fromJson / toJson 자동 생성
- null safety 컴파일 타임 검증

---

## 테스트 제안
- 각 모델의 fromJson 유효/무효 입력 테스트 (null 필드, 누락 필드, 잘못된 타입)
- Enum fromString 폴백 동작 테스트
- toJson → fromJson 라운드트립 테스트
- StreamFrame 메모리 할당 벤치마크
- 백엔드 실제 응답과 프론트엔드 모델 호환성 통합 테스트
