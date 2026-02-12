# backend/app/core/video_processor.py

## 역할
비디오 소스(파일/RTSP) 캡처, 프레임 읽기/시킹, 탐지 결과 오버레이 그리기, JPEG 인코딩, base64 변환, 스냅샷 생성.

## 핵심 알고리즘
- `stream_frames()`: async generator. FPS 제어(time.time() 기반), 프레임 스킵(최대 5프레임), 탐지+인코딩 수행
- `seek()`: cv2.CAP_PROP_POS_MSEC 설정 후 5프레임 grab하여 버퍼 플러시 (휴리스틱)
- `draw_rois()`: Shapely Polygon → 좌표 변환 → cv2.fillPoly (반투명 오버레이)
- `put_korean_text()`: OpenCV → PIL Image → 한국어 폰트 렌더링 → OpenCV 변환 (비효율적)

## 입출력
- **입력**: 카메라 소스 URL (파일 경로 또는 RTSP URL)
- **출력**: base64 인코딩된 JPEG 프레임 + 탐지 결과 dict

## 런타임 동작
- `read_frame()`: 파일 소스 EOF 시 처음으로 루프백
- `_current_raw_frame`: 마지막 원본 프레임 보관 (스냅샷용, ~6MB)
- SYNC 블로킹 호출이 async generator 안에 존재 → 이벤트 루프 차단

## 리스크
- CRITICAL: detect(), read_frame(), imencode()가 모두 sync 블로킹 — 이벤트 루프 차단
- HIGH: put_korean_text()에서 BGR→RGB→PIL→RGB→BGR 4번 변환 — 성능 낭비
- HIGH: 파일 손상 시 read_frame() 무한 루프 가능
- MEDIUM: _current_raw_frame 복사 없이 참조 → 동시 접근 시 데이터 경합
- MEDIUM: Windows 폰트 경로 하드코딩 — Linux 배포 불가
- LOW: JPEG quality 미설정 (기본 95%, 대역폭 낭비)

## 수정 포인트
- SRP 위반: 최소 4개 클래스로 분리 필요 (Capture, Encoder, Annotator, Snapshot)
- asyncio.to_thread()로 블로킹 호출 래핑 필요

## 테스트 제안
- 파일 소스 열기/읽기/시킹 테스트
- EOF 루프백 테스트
- 프레임 인코딩 크기/품질 테스트
- 한국어 텍스트 렌더링 테스트
