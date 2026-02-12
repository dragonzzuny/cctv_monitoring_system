# frontend/lib/main.dart

> 작성 기준: 30년 경력 시니어 아키텍트
> 작성일: 2026-02-11

---

## 역할
Flutter 애플리케이션 진입점. 윈도우 매니저 초기화, Riverpod 프로바이더 스코프 설정, MaterialApp 테마/라우팅 정의.

## 핵심 로직 (66줄)

### main() 함수
1. `WidgetsFlutterBinding.ensureInitialized()` — Flutter 엔진 초기화
2. `windowManager.ensureInitialized()` — Windows 데스크톱 윈도우 매니저
3. WindowOptions 설정:
   - **크기**: 1600×900 (고정 초기값)
   - **최소 크기**: 1280×720
   - **타이틀**: 'CCTV 안전관제 시스템'
4. `ProviderScope` → `SafetyMonitorApp` 실행

### SafetyMonitorApp
- MaterialApp with Material 3, Dark 테마
- `ColorScheme.fromSeed(seedColor: Colors.blue, brightness: Brightness.dark)`
- 폰트: NotoSansKR 주석 처리 (비활성화)
- 라우트 4개:
  | 경로 | 화면 |
  |------|------|
  | `/` | MainControlScreen |
  | `/settings` | CameraSettingsScreen |
  | `/roi_editor` | RoiEditorScreen |
  | `/history` | EventHistoryScreen |

## 리스크

| # | 심각도 | 내용 |
|---|--------|------|
| 1 | MEDIUM | **윈도우 크기 하드코딩** — 1600×900 고정. 12대 카메라 그리드 뷰 전환 시 더 큰 해상도나 적응형 레이아웃이 필요할 수 있음. |
| 2 | MEDIUM | **Named Routes 사용** — Flutter 커뮤니티에서 deprecated 추세. go_router 등으로 전환 권장 (딥링크, 가드, 중첩 라우팅 지원). |
| 3 | LOW | **에러 바운더리 없음** — 위젯 트리에서 예외 발생 시 빨간 에러 화면 표시. `ErrorWidget.builder` 커스터마이징이나 글로벌 에러 핸들러 미설정. |
| 4 | LOW | **NotoSansKR 폰트 주석 처리** — 한국어 텍스트 렌더링 시 시스템 폰트 폴백에 의존. 일관된 UI를 위해 폰트 에셋 포함 필요. |
| 5 | LOW | **12대 동시 뷰 미고려** — 현재 라우트 구조가 단일 카메라 중심. 멀티 카메라 그리드 뷰를 위한 라우트/화면 추가 필요. |

## 수정 포인트
- 글로벌 에러 핸들러 추가: `FlutterError.onError`, `PlatformDispatcher.instance.onError`
- go_router 전환으로 라우팅 현대화
- 12대 카메라 그리드 뷰 라우트 추가 (`/grid`)
- 윈도우 크기를 사용자 설정으로 저장 (SharedPreferences)
