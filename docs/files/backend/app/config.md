# backend/app/config.py

## 역할
Pydantic Settings 기반 전역 설정. 탐지기 타입, 신뢰도 임계값, FPS, 클래스 이름, DB URL, 이벤트 지속/쿨다운 시간 등 모든 설정 관리.

## 핵심 설정값
| 설정 | 값 | 비고 |
|------|---|------|
| DETECTOR_TYPE | "rfdetr" | "yolo" 또는 "rfdetr" |
| YOLO_CONFIDENCE_THRESHOLD | 0.5 | |
| RFDETR_CONFIDENCE_THRESHOLD | 0.35 | |
| VIDEO_FPS | 15 | 목표 프레임률 |
| DETECTION_PERSISTENCE_SECONDS | 2.0 | 이벤트 확정까지 대기 시간 |
| DETECTION_COOLDOWN_SECONDS | 30.0 | 동일 이벤트 재발생 방지 시간 |
| DATABASE_URL | sqlite+aiosqlite:///./safety_monitor.db | 하드코딩 |
| CLASS_NAMES | 11개 PPE 클래스 | RF-DETR 학습 클래스와 매칭 |

## 리스크
- MEDIUM: DATABASE_URL 하드코딩 (환경변수로 오버라이드 가능하지만 기본값이 로컬 파일)
- LOW: Windows 전용 폰트 경로 하드코딩
- LOW: JPEG_QUALITY 설정 없음 (기본값 95 사용)

## 수정 포인트
- .env 파일 지원은 Pydantic Settings가 자동 제공하나 .env 파일이 없음
- CLASS_NAMES 변경 시 모델 재학습 필요

## 테스트 제안
- 환경변수 오버라이드 테스트
- 잘못된 DETECTOR_TYPE 처리 테스트
