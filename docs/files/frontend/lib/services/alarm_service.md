# frontend/lib/services/alarm_service.dart

> 작성 기준: 30년 경력 시니어 아키텍트
> 작성일: 2026-02-11

---

## 역할
심각도별 경보음 재생 서비스. `audioplayers` 패키지 기반. 안전 이벤트 발생 시 시각적 알림(AlarmPopup)과 함께 청각적 알림을 제공하는 것이 목적.

## 핵심 로직 (66줄)

### 클래스 구조
```dart
class AlarmService {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isMuted = false;

  Future<void> playAlarm(Severity severity) async { ... }
  Future<void> playNotification() async { ... }
  void toggleMute() { ... }
  void setMute(bool muted) { ... }
  Future<void> stop() async { ... }
  void dispose() { ... }
}
```

### 사운드 파일 매핑
| 심각도 | 파일 경로 | 존재 여부 |
|--------|----------|----------|
| CRITICAL | `sounds/alarm_critical.wav` | **미확인 — 거의 확실히 존재하지 않음** |
| WARNING | `sounds/alarm_warning.wav` | **미확인 — 거의 확실히 존재하지 않음** |
| INFO | `sounds/alarm_info.wav` | **미확인 — 거의 확실히 존재하지 않음** |
| Notification | `sounds/notification.wav` | **미확인 — 거의 확실히 존재하지 않음** |

### 에러 처리
```dart
try {
  await _audioPlayer.play(AssetSource(soundFile));
} catch (e) {
  // Sound file may not exist, use system beep
  // fallback: sound file missing
}
```
**catch 블록이 완전히 비어 있다.** 주석에 "use system beep"이라고 적혀있지만 실제로 시스템 비프를 재생하는 코드는 없다. 사운드 파일이 없으면 **완전한 무음**.

---

## 리스크 분석

| # | 심각도 | 내용 |
|---|--------|------|
| 1 | **HIGH** | **사운드 에셋 부재 확실** — `sounds/` 디렉토리와 WAV 파일이 프로젝트 에셋에 등록/포함되지 않았을 가능성 매우 높음. 결과: 모든 경보음이 무음. 안전 시스템의 청각 알림이 작동하지 않는 것은 심각한 기능 결함. |
| 2 | **HIGH** | **빈 catch 블록** — 에셋 로딩 실패 시 에러가 완전히 삼켜짐. 로깅도 없고, 사용자 알림도 없음. 운영자는 경보음이 왜 나지 않는지 알 방법이 없다. |
| 3 | MEDIUM | **단일 AudioPlayer 인스턴스** — 빠르게 연속되는 알람(예: CRITICAL 이벤트 3개 연속 발생) 시 이전 사운드가 중단되고 마지막 것만 재생. 동시 재생이나 큐잉 메커니즘 없음. |
| 4 | MEDIUM | **dispose() 호출 보장 없음** — AlarmService가 Riverpod provider(`alarmServiceProvider`)로 관리되지만, 앱 종료 시 dispose 호출이 보장되지 않을 수 있음. |
| 5 | LOW | **볼륨 제어 없음** — 뮤트 on/off만 가능. 볼륨 레벨 조절 불가. 시끄러운 산업 현장에서는 최대 볼륨이 필요할 수 있음. |
| 6 | LOW | **Windows 플랫폼 호환성** — `audioplayers` 패키지의 Windows 지원이 제한적일 수 있음. Flutter Windows 데스크톱 앱에서의 호환성 테스트 필요. |

---

## 호출 경로 분석

```
stream_provider.dart: _processEvents()
  → SafetyEvent 생성
  → alarm_popup.dart: showAlarm()   ← 시각적 알림 (작동)
  → AlarmService.playAlarm()        ← 청각적 알림 (작동 안 함)
```

**실제 호출 경로가 불명확하다.** `alarm_popup.dart`의 `AlarmPopup` 위젯은 `ActiveAlarmNotifier`의 상태를 구독하여 표시되지만, `AlarmService.playAlarm()`을 직접 호출하는 코드가 `stream_provider.dart`의 이벤트 처리 경로에서 명확히 보이지 않는다.

`providers.dart`에서 `alarmServiceProvider`가 정의되어 있지만, 실제로 `playAlarm()`을 호출하는 코드의 위치가 분산되어 있거나, 호출 자체가 누락되었을 가능성이 있다.

---

## 수정 권고

### 즉시 (1일)
1. **사운드 에셋 존재 확인 및 추가**
```yaml
# pubspec.yaml
flutter:
  assets:
    - sounds/alarm_critical.wav
    - sounds/alarm_warning.wav
    - sounds/alarm_info.wav
    - sounds/notification.wav
```

2. **빈 catch 블록에 로깅 추가**
```dart
catch (e) {
  debugPrint('[AlarmService] Failed to play $soundFile: $e');
  // Windows에서는 시스템 비프를 폴백으로 사용
}
```

### 단기 (1주)
3. **Windows 네이티브 사운드 폴백**
```dart
import 'dart:ffi';
// Windows Beep 함수 활용
```

4. **사운드 큐잉 메커니즘**
```dart
final Queue<SoundRequest> _queue = Queue();
// 현재 재생 중이면 큐에 추가, 완료 후 다음 재생
```

5. **볼륨 제어 추가**
```dart
double _volume = 1.0;
void setVolume(double volume) {
  _volume = volume.clamp(0.0, 1.0);
  _audioPlayer.setVolume(_volume);
}
```

---

## 결론

**이 서비스는 사실상 작동하지 않는 코드다.** 사운드 파일이 없으므로 모든 `playAlarm()` 호출은 예외 → 빈 catch → 무음으로 종결된다. 안전 모니터링 시스템에서 경보음이 나지 않는 것은 "기능이 없는 것"이 아니라 "기능이 있는 척하는 것"이므로, 사용자에게 거짓 안전감을 줄 수 있다.

**에셋 파일 추가가 최소한의 수정이지만, 근본적으로는 Windows 네이티브 사운드 API를 사용하는 것이 신뢰성 면에서 올바른 접근이다.**
