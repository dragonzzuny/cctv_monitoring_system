# CCTV 기반 화기작업 안전관제 시스템: 상세 기능 명세서 및 구현 방안

## 목차

1.  [프로젝트 개요](#1-프로젝트-개요)
    *   [목적](#11-목적)
    *   [적용 시나리오](#12-적용-시나리오)
2.  [시스템 아키텍처](#2-시스템-아키텍처)
    *   [권장 구조](#21-권장-구조)
    *   [논리적 구성도 및 데이터 흐름](#22-논리적-구성도-및-데이터-흐름)
3.  [데이터셋 분석 및 AI 모델 설계](#3-데이터셋-분석-및-AI-모델-설계)
    *   [데이터셋 분석](#31-데이터셋-분석)
    *   [AI 모델 설계](#32-AI-모델-설계)
4.  [상세 기능 명세서](#4-상세-기능-명세서)
    *   [영상 입력/재생 기능](#41-영상-입력재생-기능)
    *   [사용자 정의 위험영역(ROI) 설정 기능](#42-사용자-정의-위험영역roi-설정-기능)
    *   [AI 기반 객체 인식(Detection) 기능](#43-AI-기반-객체-인식detection-기능)
    *   [작업 이벤트/행위 기반 경고 기능](#44-작업-이벤트행위-기반-경고-기능)
    *   [법령/사내규정 DB 기반 체크리스트 자동 생성 기능](#45-법령사내규정-DB-기반-체크리스트-자동-생성-기능)
    *   [알림/이력/증빙 저장 기능](#46-알림이력증빙-저장-기능)
    *   [UI/UX (Flutter) 화면 구성](#47-UIUX-Flutter-화면-구성)
    *   [개발 범위 (MVP)](#48-개발-범위-MVP)
    *   [리스크 및 주의사항](#49-리스크-및-주의사항)
    *   [산출물 (Deliverables)](#410-산출물-deliverables)
5.  [모듈별 구현 방안 및 API 명세](#5-모듈별-구현-방안-및-API-명세)
    *   [모듈별 구현 방안](#51-모듈별-구현-방안)
    *   [API 명세](#52-API-명세)
    *   [데이터 흐름 상세](#53-데이터-흐름-상세)
6.  [DB 스키마 및 체크리스트 템플릿 설계](#6-DB-스키마-및-체크리스트-템플릿-설계)
    *   [데이터베이스 스키마 설계](#61-데이터베이스-스키마-설계)
    *   [체크리스트 템플릿 (화기작업) 설계](#62-체크리스트-템플릿-화기작업-설계)
    *   [AI 매핑 조건 상세](#63-AI-매핑-조건-상세)

---

# 1. 프로젝트 개요

## 1.1 목적

본 프로젝트는 제철소 및 중대사업장 작업 현장의 CCTV 영상(또는 저장 영상)을 활용하여 실시간 안전관제 모니터링 시스템을 개발하는 것을 목표로 한다. 주요 목적은 다음과 같다:

*   **사람 인식 및 위험영역 진입 감지**: 작업 현장에 대한 사람 인식을 수행하고, 사용자 정의 위험영역(ROI)으로의 진입을 감지한다.
*   **화기작업 안전요건 자동 점검**: 개인 보호 장비(PPE), 소화기 비치, 불티 방지 조치 등 화기작업 안전 요건을 자동으로 점검한다.
*   **법령/사내규정 기반 체크리스트 자동 생성 및 확인**: 관련 법령 및 사내규정을 기반으로 체크리스트를 자동 생성하고, AI를 통해 확인 가능한 항목은 자동으로 체크한다.

이를 통해 작업 현장의 안전을 강화하고, 위험 발생 가능성을 사전에 감지하여 사고를 예방하는 데 기여한다.

## 1.2 적용 시나리오

시스템의 적용 시나리오는 우선순위에 따라 다음과 같이 정의된다.

*   **화기작업 (MVP)**: 용접, 용단, 그라인딩 등 불꽃이나 고열을 수반하는 작업에 우선적으로 적용된다.
*   **고소작업 (확장)**: 2m 이상 높이에서의 작업 시 안전대 착용, 난간 설치 여부 등을 감지하는 기능으로 확장될 수 있다.
*   **기타 위험작업 (확장)**: 밀폐공간 작업, 중량물 취급, 크레인 작업 등 다양한 위험 작업으로의 확장을 고려한다.

# 2. 시스템 아키텍처

제안된 시스템 아키텍처는 역할 분리를 통해 안정성과 확장성을 확보하는 데 중점을 둔다. Flutter/Dart는 사용자 인터페이스(UI) 및 대시보드 역할을 담당하며, AI/비디오 처리 서버는 Python 기반으로 실시간 영상 처리 및 AI 추론을 수행한다. 별도의 DB 서버는 시스템 운영에 필요한 데이터를 저장한다.

## 2.1 권장 구조

| 모듈 | 기술 스택 | 주요 역할 |
|:---|:---|:---|
| **관제 UI/대시보드 (프론트엔드)** | Flutter (Dart) | 사용자 인터페이스 제공, 실시간 모니터링 화면, 설정 관리, 이벤트 로그 표시 |
| **AI/비디오 처리 서버 (백엔드)** | Python | RTSP/HTTP 스트림 디코딩, AI 객체 인식(YOLO), 객체 트래킹, ROI 진입 판단, 룰 엔진(법령/규정 매핑), 이벤트 생성, 알림 처리 |
| **DB 서버** | (미정) | 규정, 체크리스트 템플릿, 카메라 프로파일, 이벤트 로그, 체크리스트 인스턴스 등 시스템 데이터 저장 |

## 2.2 논리적 구성도 및 데이터 흐름

시스템은 다음과 같은 논리적 구성 요소를 가지며, 데이터는 아래와 같은 흐름으로 처리된다.

1.  **Video Ingest**: CCTV 스트림(RTSP/HTTP) 또는 저장된 영상 파일을 입력받는다.
2.  **Inference Engine (YOLO)**: 입력된 영상 프레임에서 AI 객체 인식 모델(YOLO)을 사용하여 `Person`, `PPE`, `FireExtinguisher` 등 정의된 객체를 탐지한다.
3.  **Tracking + ROI 판단**: 탐지된 객체들을 트래킹하고, 사용자 정의 위험영역(ROI)과의 상호작용(진입, 체류 등)을 판단한다.
4.  **Rule Engine (법령 체크리스트 매핑)**: ROI 판단 결과 및 객체 탐지 정보를 기반으로 사전 정의된 안전 규칙(법령/사내규정)을 평가하고, 위반 사항 발생 시 이벤트를 트리거한다.
5.  **Event/Checklist Service (API)**: 룰 엔진에서 생성된 이벤트를 처리하고, 관련 체크리스트를 DB에서 로드하거나 생성하여 상태를 관리한다.
6.  **Flutter UI (관제 화면)**: Event/Checklist Service에서 발생한 이벤트 및 체크리스트 상태를 실시간으로 수신하여 사용자에게 시각적으로 제공한다.

**데이터 흐름 요약:**

*   **프레임** → **탐지 결과 (JSON)** → **ROI/룰 판단** → **이벤트 생성**
*   **이벤트 발생 시** → **체크리스트 로드/생성** → **UI로 스트리밍 (WebSocket 등)**
*   **자동 체크 업데이트** → **DB 반영 + UI 갱신**

---

# 3. 데이터셋 분석 및 AI 모델 설계

## 3.1 데이터셋 분석

제공된 데이터셋은 총 4189개의 이미지와 37674개의 객체 어노테이션으로 구성되어 있으며, 훈련(train), 검증(val), 테스트(test) 세트로 분할되어 있다. 각 세트의 비율은 다음과 같다.

| 세트 | 이미지 수 | 비율 |
|:---|:---|:---|
| **Train** | 3727 | 89.0% |
| **Validation** | 247 | 5.9% |
| **Test** | 215 | 5.1% |
| **Total** | 4189 | 100.0% |

### 3.1.1 클래스별 객체 분포

데이터셋에 포함된 10가지 클래스별 객체 수는 다음과 같다.

| ID | Class Name | Count | Percentage |
|:---|:---|:---|:---|
| 0 | helmet | 5068 | 13.5% |
| 1 | gloves | 1445 | 3.8% |
| 2 | vest | 4753 | 12.6% |
| 3 | boots | 1597 | 4.2% |
| 4 | goggles | 518 | 1.4% |
| 5 | mask | 1700 | 4.5% |
| 6 | person | 12117 | 32.2% |
| 7 | machinery | 5346 | 14.2% |
| 8 | vehicle | 1628 | 4.3% |
| 9 | safety_cone | 3502 | 9.3% |
| **Total Objects** | **37674** | **100.0%** |

**분석:**

*   `person` 클래스가 전체 객체의 32.2%로 가장 높은 비중을 차지하며, 이는 사람 중심의 안전 관제 시스템에 적합한 데이터 분포이다.
*   `helmet`, `vest`, `machinery`, `safety_cone` 클래스도 비교적 높은 비중을 차지하고 있어, 기본적인 안전 장비 및 현장 구성 요소 인식이 용이할 것으로 예상된다.
*   `goggles`, `gloves`, `boots`, `mask`, `vehicle` 클래스는 상대적으로 낮은 비중을 차지하고 있어, 해당 클래스에 대한 모델의 성능 확보를 위해 추가적인 데이터 증강 또는 파인튜닝 전략이 필요할 수 있다.

## 3.2 AI 모델 설계

### 3.2.1 객체 인식 모델 (MVP 기준)

MVP(Minimum Viable Product) 단계에서는 화기작업 안전 관제에 필수적인 객체들을 중심으로 모델을 설계한다. 제공된 데이터셋과 기획서 내용을 바탕으로 다음과 같은 객체 인식을 목표로 한다.

*   **인식 대상**: `Person`, `Helmet`, `Mask`, `FireExtinguisher` (소화기), `SparkShield/FireBlanket` (불티방지 가림막/방염포) 등
    *   제공된 데이터셋에는 `gloves`, `vest`, `boots`, `goggles` 클래스가 포함되어 있으나, MVP에서는 기획서에 명시된 `PPE 2종 + 소화기 1종`을 우선적으로 고려한다. 구체적인 PPE 2종은 `Helmet`과 `Mask`로 선정하며, 소화기는 `FireExtinguisher`로 한다. `SparkShield/FireBlanket`는 확장 기능으로 분류되었으나, 화기작업의 핵심 안전요소이므로 MVP에 포함하는 것을 고려한다.
*   **모델 구조**: 단일 멀티클래스 모델을 권장한다. 이는 한 번의 추론으로 여러 객체를 동시에 탐지하여 실시간 처리 효율성을 높일 수 있다. YOLO(You Only Look Once) 계열의 모델이 실시간 객체 인식에 적합하다.
*   **실시간 부하 제어**: `Person` 객체 존재 및 ROI 진입 시에만 룰 평가를 강화하는 트리거 방식을 도입하여 불필요한 연산을 줄이고 시스템 부하를 효율적으로 관리한다.

### 3.2.2 학습 전략 (MVP)

*   **베이스 모델**: 공개된 PPE 및 소화기 관련 데이터셋을 활용하여 베이스 모델을 사전 학습시킨다.
*   **파인튜닝**: 현장 CCTV 영상에서 200~500장 정도의 이미지를 빠르게 라벨링하여 베이스 모델을 파인튜닝한다. 이는 제철소 현장의 도메인 갭을 줄이고 실제 환경에 최적화된 모델을 구축하는 데 필수적이다.
*   **클래스 최소화**: MVP 단계에서는 6~10개 내외의 핵심 클래스에 집중하여 모델의 복잡도를 낮추고 학습 효율을 높인다.

### 3.2.3 확장 고려 사항

*   **행동 인식**: 용접, 그라인딩 등 복잡한 행동 인식을 위해서는 추가적인 데이터셋 구축 및 시공간 정보를 활용하는 모델(예: 비디오 트랜스포머) 도입을 고려할 수 있다.
*   **가연물 정밀 탐지**: `Can/Jerrycan/Drum`과 같은 가연물 탐지를 위해서는 해당 객체에 대한 추가 데이터 수집 및 라벨링이 필요하다.
*   **도메인 갭 해소**: 주간/야간, 역광, 다양한 거리 등 현장 환경의 변화에 강인한 모델을 구축하기 위해 다양한 조건의 현장 데이터를 지속적으로 수집하고 학습에 반영해야 한다.

---

# 4. 상세 기능 명세서

본 문서는 CCTV 기반 화기작업 안전관제 시스템의 핵심 기능을 상세하게 정의한다. 각 기능은 시스템의 목적 달성을 위한 필수적인 요소이며, 개발자가 명확하게 이해하고 구현할 수 있도록 구체적으로 기술한다.

## 4.1 영상 입력/재생 기능

### 4.1.1 입력 소스 관리

*   **기능 설명**: 시스템은 다양한 영상 소스로부터 데이터를 입력받을 수 있어야 한다. 이는 실시간 모니터링 및 과거 영상 분석을 모두 지원하기 위함이다.
*   **세부 기능**:
    *   **저장 영상**: 로컬 또는 네트워크 경로에 저장된 영상 파일(예: `C:\Users\PYJ\Desktop\ppe_yolo_project\archive\source_files`와 같은 경로)을 입력 소스로 설정하고 재생할 수 있다.
    *   **실시간 스트림**: RTSP(Real Time Streaming Protocol) 또는 HTTP 스트림을 통해 CCTV와 같은 실시간 영상 소스를 입력받을 수 있다.
*   **요구사항**:
    *   다양한 영상 코덱 및 컨테이너 포맷 지원 (예: H.264, H.265, MP4, AVI).
    *   영상 소스 추가, 수정, 삭제 기능.
    *   각 영상 소스에 대한 연결 상태 모니터링.

### 4.1.2 모드 관리

*   **기능 설명**: 시스템은 실시간 모니터링 모드와 저장 영상 재생 모드를 제공하여 사용자가 목적에 따라 유연하게 시스템을 활용할 수 있도록 한다.
*   **세부 기능**:
    *   **Live 모드**: 실시간으로 입력되는 영상 스트림을 모니터링하며, 객체 탐지 및 룰 평가 결과를 즉시 반영하여 알림을 발생시킨다.
    *   **Replay 모드**: 저장된 영상을 재생하며, Live 모드와 동일한 탐지 및 알림 기능을 수행한다. 이는 시스템의 테스트, 데모, 검증 및 사후 분석에 활용된다.
*   **요구사항**:
    *   모드 간 전환 시 시스템 상태 및 설정 유지.
    *   Replay 모드에서 영상 재생 속도 조절 기능 (빨리 감기, 느리게 감기).
    *   Replay 모드에서 특정 시점으로 이동 기능.

## 4.2 사용자 정의 위험영역(ROI) 설정 기능

### 4.2.1 ROI 정의 및 관리

*   **기능 설명**: 사용자가 영상 화면 위에 직접 다각형 형태의 관심 영역(ROI)을 설정하여 특정 구역에서의 작업 또는 위험 상황을 정의할 수 있도록 한다.
*   **세부 기능**:
    *   **다각형 ROI 그리기**: 마우스 인터페이스를 통해 영상 위에 자유롭게 다각형 형태의 ROI를 그릴 수 있다.
    *   **ROI 타입 지정**: 설정된 ROI에 대해 “출입 금지 구역”, “주의 구역”, “작업 구역” 등 구역 타입을 지정할 수 있다.
    *   **ROI 버퍼 설정**: 설정된 ROI를 중심으로 일정 반경(예: 작업 반경)의 버퍼 영역을 추가로 설정할 수 있다.
*   **요구사항**:
    *   ROI의 추가, 수정, 삭제 기능.
    *   ROI의 크기 및 형태 조절 기능.
    *   ROI의 시각적 피드백 (색상, 투명도 등).

### 4.2.2 ROI 프로파일 저장/불러오기

*   **기능 설명**: 각 카메라별로 설정된 ROI 정보를 프로파일 형태로 저장하고 불러올 수 있어, 동일한 환경에서 반복적인 설정 작업을 최소화한다.
*   **세부 기능**:
    *   **프로파일 저장**: 현재 설정된 ROI 정보를 카메라 ID와 매핑하여 저장한다.
    *   **프로파일 불러오기**: 특정 카메라 ID에 저장된 ROI 프로파일을 불러와 적용한다.
*   **요구사항**:
    *   프로파일 목록 관리 (생성, 삭제, 이름 변경).
    *   프로파일 내보내기/가져오기 기능 (선택 사항).

## 4.3 AI 기반 객체 인식(Detection) 기능

### 4.3.1 객체 인식 대상

*   **기능 설명**: 시스템은 CCTV 영상 내에서 화기작업 안전 관리에 필요한 주요 객체들을 실시간으로 탐지한다.
*   **MVP 인식 대상**:
    *   **Person (사람)**: 작업자 및 기타 인원.
    *   **PPE (개인 보호 장비)**: `Helmet` (안전모), `Mask` (마스크).
    *   **Fire safety (소화 안전 장비)**: `FireExtinguisher` (소화기).
*   **확장 인식 대상**:
    *   `Goggles` (보안경), `FaceShield/WeldingMask` (용접면/차광면).
    *   `SparkShield/FireBlanket` (불티방지 가림막/방염포).
    *   `Can/Jerrycan/Drum` (캔/말통/드럼) 등 가연물.
*   **요구사항**:
    *   높은 정확도와 실시간 처리 속도.
    *   다양한 환경 조건(조명, 시점, 객체 크기 등)에서의 강인한 성능.

### 4.3.2 모델 구조 및 부하 제어

*   **기능 설명**: 효율적인 객체 인식을 위해 단일 멀티클래스 모델을 사용하며, 시스템 부하를 최적화하기 위한 제어 로직을 포함한다.
*   **세부 기능**:
    *   **단일 멀티클래스 모델**: 한 번의 추론으로 여러 종류의 객체를 동시에 탐지한다.
    *   **트리거 기반 룰 평가 강화**: `Person` 객체가 탐지되거나 위험영역(ROI)에 진입했을 때만 룰 엔진의 평가 강도를 높여 불필요한 연산을 줄인다.
*   **요구사항**:
    *   모델 추론 속도 최적화.
    *   GPU 활용을 통한 병렬 처리 지원.

## 4.4 작업 이벤트/행위 기반 경고 기능

### 4.4.1 이벤트 정의

*   **기능 설명**: AI 객체 인식 결과와 ROI 정보를 기반으로 작업 현장에서 발생할 수 있는 위험 상황을 이벤트로 정의하고 감지한다.
*   **MVP 이벤트**:
    *   **ROI 내 Person 진입**: `ROI_HOTWORK` (화기작업 구역) 내에 `Person`이 진입하고 일정 시간(예: 2초) 이상 체류.
    *   **PPE 미착용**: `Person`이 `ROI_HOTWORK` 내에 존재하지만 `Helmet` 또는 `Mask`가 탐지되지 않음 (누적 판정).
    *   **소화기 미확인**: `Person`이 `ROI_HOTWORK` 내에 존재하지만 작업 반경(ROI 버퍼) 내에서 `FireExtinguisher`가 탐지되지 않음.
    *   **불티방지 가림막 미확인**: `Person`이 `ROI_HOTWORK` 내에 존재하지만 `SparkShield/FireBlanket`가 탐지되지 않음 (확장 기능이나 MVP 포함 고려).
*   **확장 이벤트**:
    *   불꽃/스파크 탐지.
    *   작업자 자세/도구(그라인더) 탐지.
*   **요구사항**:
    *   이벤트 발생 조건의 유연한 설정 및 수정.
    *   오탐 방지를 위한 N초 지속, 쿨다운, 누적 판정 로직 적용.

### 4.4.2 알람 조건 예시 (화기작업)

| 조건 | 설명 |
|:---|:---|
| `ROI_HOTWORK` 내 `Person` 진입 | 화기작업 구역에 작업자가 들어왔을 때 |
| `Person` 존재 상태에서 PPE 미착용 | 작업자가 화기작업 구역에 있으나 안전모 또는 마스크를 착용하지 않았을 때 |
| 작업 반경 내 소화기 미확인 | 작업 반경 내에 소화기가 비치되어 있지 않을 때 |
| 불티방지 가림막 미확인 | 불티방지 가림막이 설치되어 있지 않을 때 |

## 4.5 법령/사내규정 DB 기반 체크리스트 자동 생성 기능

### 4.5.1 체크리스트 생성 및 관리

*   **기능 설명**: 화기작업 감지 시 관련 법령 및 사내규정을 기반으로 체크리스트를 자동으로 생성하고, AI 탐지 결과를 활용하여 일부 항목을 자동 체크한다.
*   **세부 기능**:
    *   **체크리스트 자동 생성**: “화기작업 이벤트 시작” 시, `ChecklistTemplate`에서 화기작업 관련 템플릿을 로드하여 오른쪽 패널에 체크리스트를 자동 생성한다.
    *   **AI 자동 체크**: AI 객체 인식 결과(예: `Person` bbox 안에 `Helmet/Mask` 검출, 주변 ROI/버퍼에서 `FireExtinguisher` 검출)를 기반으로 해당 체크리스트 항목을 자동으로 체크(✅)한다.
    *   **수동 확인 필요 항목**: AI로 확정 불가한 항목(예: 서류 확인, 작업 허가서, 가스 측정 등)은 “수동 확인 필요” 상태로 남긴다.
*   **요구사항**:
    *   규정 DB와의 연동을 통한 최신 규정 반영.
    *   체크리스트 항목별 중요도 설정.
    *   AI 매핑 조건의 유연한 설정.

### 4.5.2 UI 동작 예시

*   “화기작업 이벤트 시작” → 체크리스트 패널 생성/고정.
*   `Person` bbox 안에 `Helmet/Mask` 검출 → PPE 항목 자동 체크.
*   주변 ROI/버퍼에서 `FireExtinguisher` 검출 → 소화기 비치 항목 자동 체크.
*   미확인 항목은 빨간색/노란색 상태로 유지되며 경고 표시.

## 4.6 알림/이력/증빙 저장 기능

### 4.6.1 실시간 알림

*   **기능 설명**: 위험 이벤트 발생 시 사용자에게 즉각적으로 알림을 제공한다.
*   **세부 기능**:
    *   **팝업**: 관제 대시보드 화면에 경고 팝업 표시.
    *   **사운드**: 경고음 재생.
    *   **로그**: 시스템 이벤트 로그에 기록.
    *   **옵션**: Slack, Telegram, Webhook 등 외부 메시징 서비스 연동.
*   **요구사항**:
    *   알림 설정의 사용자 정의 (알림 종류, 수신 채널).
    *   알림 우선순위 설정.

### 4.6.2 이력 저장 및 증빙

*   **기능 설명**: 발생한 이벤트 및 관련 정보를 저장하여 사후 분석, 보고서 작성, 법적 증빙 자료로 활용한다.
*   **세부 기능**:
    *   **이벤트 로그**: 이벤트 발생 시각, 카메라 ID, ROI 정보, 탐지 결과, 체크리스트 상태 등을 포함한 상세 로그 저장.
    *   **스냅샷/클립 저장**: 알람 발생 전후 3~5초간의 영상 스냅샷 또는 클립을 자동으로 저장하여 증빙 자료로 활용.
*   **요구사항**:
    *   저장된 이력 및 증빙 자료의 검색 및 필터링 기능.
    *   데이터 무결성 및 보안 확보.
    *   저장 공간 관리 및 자동 삭제 정책 (선택 사항).

## 4.7 UI/UX (Flutter) 화면 구성

### 4.7.1 메인 관제 화면

*   **구성**: 좌측/중앙에 CCTV 영상 스트림, 우측에 체크리스트 패널, 하단에 이벤트 타임라인(알람 로그)을 배치한다.
*   **세부 요소**:
    *   **CCTV 영상**: 실시간 영상 스트림 또는 재생 중인 저장 영상 표시. ROI 오버레이 및 객체 바운딩 박스(bbox) 표시.
    *   **체크리스트 패널**: 작업 종류(예: 화기작업) 자동 표시. 항목 상태(✅자동체크 / ⚠️미확인 / ❗위험)를 직관적으로 표시. 클릭 시 근거(스냅샷/탐지 결과) 표시.
    *   **이벤트 타임라인**: 발생한 알람 로그를 시간 순서대로 표시. 클릭 시 해당 이벤트 발생 시점의 영상 및 체크리스트 상태로 이동.

### 4.7.2 설정 화면

*   **구성**: 시스템 운영에 필요한 다양한 설정을 관리하는 화면.
*   **세부 요소**:
    *   **카메라 등록**: RTSP URL, 저장 영상 경로 등 카메라 정보를 등록하고 관리.
    *   **ROI 편집**: 다각형/라인 형태의 ROI를 생성, 수정, 삭제.
    *   **규정 템플릿 관리**: 사내규정 항목 추가/수정 등 체크리스트 템플릿을 관리.
    *   **알림 설정**: Slack/Webhook 연동 등 알림 수신 채널 및 조건을 설정.

## 4.8 개발 범위 (MVP)

### 4.8.1 MVP 포함 기능

*   저장 영상 재생 및 실시간(1채널) 입력.
*   ROI 설정/저장.
*   객체 탐지: `Person` + `PPE 2종` (`Helmet`, `Mask`) + `소화기 1종` (`FireExtinguisher`).
*   화기작업 체크리스트 자동 생성 + 자동 체크 (가능 항목만).
*   알람/로그/스냅샷 저장.
*   Flutter 관제 UI (영상 + 체크리스트 + 이벤트 로그).

### 4.8.2 MVP 제외 (확장) 기능

*   행동 인식 (용접/그라인딩 정확 분류).
*   가연물 (말통/캔) 정밀 탐지.
*   다채널 대규모 (10채널 이상) 모니터링.
*   사용자 권한 관리.
*   레포트 자동 생성.

## 4.9 리스크 및 주의사항

*   **법 위반 판정 UI 금지**: 시스템은 직접적으로 “법 위반”을 판정하는 UI를 제공하지 않는다. 대신 “위험요인 미이행 가능성/미확인” 형태로 표시하여 법적 리스크를 줄인다.
*   **오탐 제어**: 오탐(False Positive)을 최소화하기 위해 N초 지속, 쿨다운, 누적 판정 로직을 적용하여 알람 폭주를 방지한다.
*   **제철소 도메인 갭**: 공개 데이터만으로는 현장 환경의 특수성(주간/야간/역광/거리 등)을 반영하기 어려울 수 있으므로, 현장 샘플을 통한 파인튜닝이 필수적이다.

## 4.10 산출물 (Deliverables)

본 프로젝트의 최종 산출물은 다음과 같다.

*   **실행 가능한 데모**: Replay 모드 및 1채널 Live 모드를 지원하는 시스템 데모.
*   **체크리스트 DB 템플릿**: 화기작업 관련 규정 및 체크리스트 항목을 포함하는 데이터베이스 템플릿.
*   **이벤트 로그/스냅샷 저장 기능**: 이벤트 발생 시 로그 기록 및 증빙 자료(스냅샷/클립) 저장 기능.
*   **Flutter UI APK/EXE**: 개발 환경에 따라 Flutter 기반 관제 UI의 실행 파일 (APK 또는 EXE).
*   **기술 문서**: 시스템 아키텍처, API 명세, 모델/데이터 정의, 운영 가이드 등을 포함하는 상세 기술 문서.

---

# 5. 모듈별 구현 방안 및 API 명세

본 문서는 CCTV 기반 화기작업 안전관제 시스템을 구성하는 주요 모듈들의 구현 방안과 모듈 간 통신을 위한 API 명세를 상세히 기술한다. 이는 개발자가 각 모듈을 독립적으로 개발하고 통합하는 데 필요한 지침을 제공한다.

## 5.1 모듈별 구현 방안

### 5.1.1 관제 UI/대시보드 (프론트엔드) - Flutter (Dart)

*   **역할**: 사용자 인터페이스 제공, 실시간 모니터링 화면, 설정 관리, 이벤트 로그 표시.
*   **주요 기능 구현 방안**:
    *   **영상 스트림 표시**: `video_player` 또는 `flutter_vlc_player`와 같은 Flutter 패키지를 활용하여 RTSP/HTTP 스트림 및 로컬 영상 파일을 재생하고 화면에 표시한다. AI 서버로부터 전송되는 객체 탐지 결과(바운딩 박스, 클래스명) 및 ROI 정보를 영상 위에 오버레이하여 시각화한다.
    *   **ROI 설정 UI**: `CustomPainter`를 활용하여 영상 위에 다각형 ROI를 그릴 수 있는 인터페이스를 구현한다. 사용자의 터치/마우스 이벤트를 감지하여 점 추가, 이동, 삭제 기능을 제공한다. 설정된 ROI 정보는 JSON 형태로 AI 서버에 전송하고, AI 서버로부터 카메라별 ROI 프로파일을 요청하여 불러올 수 있도록 한다.
    *   **체크리스트 패널**: AI 서버로부터 실시간으로 전송되는 체크리스트 상태(자동 체크 여부, 미확인/위험 상태)를 표시한다. 각 항목 클릭 시 관련 증빙 자료(스냅샷, 탐지 결과 JSON)를 팝업 형태로 보여준다.
    *   **이벤트 타임라인/로그**: AI 서버로부터 수신되는 이벤트 로그를 시간 순서대로 표시한다. 특정 로그 클릭 시 해당 이벤트 발생 시점의 영상 및 체크리스트 상태를 Replay 모드로 전환하여 보여주는 기능을 구현한다.
    *   **설정 화면**: 카메라 등록(RTSP URL, 저장 경로), ROI 편집, 규정 템플릿 관리, 알림 설정(Slack/Webhook 연동) 등의 UI를 구현하여 사용자가 시스템을 유연하게 설정할 수 있도록 한다.
    *   **통신**: AI 서버와의 실시간 데이터 통신을 위해 WebSocket을 활용하고, 설정 정보 및 제어 명령 전송을 위해 RESTful API를 사용한다.

### 5.1.2 AI/비디오 처리 서버 (백엔드) - Python

*   **역할**: RTSP/HTTP 스트림 디코딩, AI 객체 인식(YOLO), 객체 트래킹, ROI 진입 판단, 룰 엔진(법령/규정 매핑), 이벤트 생성, 알림 처리.
*   **주요 기능 구현 방안**:
    *   **영상 스트림 처리**: `OpenCV` 또는 `FFmpeg` 라이브러리를 활용하여 RTSP/HTTP 스트림을 디코딩하고 프레임 단위로 처리한다. 저장 영상 파일 처리도 동일한 방식으로 수행한다.
    *   **AI 객체 인식**: `PyTorch`, `TensorFlow` 또는 `ONNX Runtime`과 같은 딥러닝 프레임워크를 사용하여 YOLO 기반의 객체 인식 모델을 로드하고 추론을 수행한다. GPU 가속을 통해 실시간 처리 성능을 확보한다. 탐지된 객체의 바운딩 박스, 클래스, 신뢰도 정보를 JSON 형태로 관리한다.
    *   **객체 트래킹**: `DeepSORT` 또는 `ByteTrack`과 같은 트래킹 알고리즘을 적용하여 영상 내 객체들의 ID를 유지하고 이동 경로를 추적한다. 이는 ROI 진입/체류 판단 및 누적 판정에 활용된다.
    *   **ROI 판단 및 룰 엔진**: Flutter UI로부터 전송받은 ROI 정보를 기반으로, 트래킹된 객체들이 ROI에 진입하거나 이탈하는지, 특정 ROI 내에 일정 시간 이상 체류하는지 등을 판단한다. 사전 정의된 안전 규칙(예: PPE 미착용, 소화기 미비치)을 `Rule Engine`에서 평가하여 위반 사항 발생 시 이벤트를 트리거한다. 룰은 파이썬 스크립트 또는 설정 파일 형태로 관리하여 유연하게 변경 가능하도록 한다.
    *   **이벤트 생성 및 알림**: 룰 엔진에서 트리거된 이벤트를 `EventLog` DB에 저장하고, Flutter UI로 WebSocket을 통해 실시간으로 전송한다. Slack, Telegram, Webhook 등 외부 알림 서비스 연동을 위한 API 클라이언트를 구현한다.
    *   **스냅샷/클립 저장**: 이벤트 발생 시점의 영상 프레임을 스냅샷으로 저장하거나, 이벤트 전후 일정 시간의 영상 클립을 추출하여 저장한다.
    *   **API 서버**: `FastAPI` 또는 `Flask`와 같은 웹 프레임워크를 사용하여 Flutter UI와의 통신을 위한 RESTful API 엔드포인트를 구현한다. (예: ROI 프로파일 저장/로드, 설정 정보 업데이트).

### 5.1.3 DB 서버

*   **역할**: 규정, 체크리스트 템플릿, 카메라 프로파일, 이벤트 로그, 체크리스트 인스턴스 등 시스템 데이터 저장.
*   **주요 기능 구현 방안**:
    *   **데이터베이스 선택**: 관계형 데이터베이스(예: PostgreSQL, MySQL) 또는 NoSQL 데이터베이스(예: MongoDB) 중 프로젝트의 규모와 요구사항에 맞춰 선택한다. 초기 MVP 단계에서는 SQLite와 같은 경량 DB를 사용하여 개발 편의성을 높일 수 있다.
    *   **스키마 설계**: `RegulationSource`, `ChecklistTemplate`, `ChecklistItem`, `CameraProfile`, `EventLog`, `ChecklistInstance` 등의 엔티티를 정의하고 테이블 스키마를 설계한다. (상세 스키마는 다음 섹션에서 다룸).
    *   **데이터 접근 계층 (DAL)**: Python AI 서버에서 DB에 접근하기 위한 ORM(Object-Relational Mapping) 라이브러리(예: SQLAlchemy, Peewee)를 활용하여 데이터 CRUD(Create, Read, Update, Delete) 작업을 추상화한다.
    *   **데이터 무결성 및 보안**: 데이터베이스 접근 권한 관리, 데이터 암호화(민감 정보), 백업 및 복구 전략을 수립한다.

## 5.2 API 명세

Flutter UI와 AI/비디오 처리 서버 간의 주요 API 통신은 RESTful API와 WebSocket을 혼합하여 사용한다. RESTful API는 주로 설정 정보 및 제어 명령과 같이 요청-응답 형태의 통신에 사용되며, WebSocket은 실시간 영상 데이터, 객체 탐지 결과, 이벤트 알림, 체크리스트 상태 업데이트 등 지속적인 데이터 스트리밍에 사용된다.

### 5.2.1 RESTful API 명세 (Flutter UI ↔ AI/비디오 처리 서버)

#### 5.2.1.1 카메라 관리

*   **카메라 등록/수정**
    *   **Endpoint**: `POST /api/cameras`, `PUT /api/cameras/{camera_id}`
    *   **Method**: `POST`, `PUT`
    *   **Description**: 새로운 카메라를 등록하거나 기존 카메라 정보를 수정한다.
    *   **Request Body (JSON)**:
        ```json
        {
            "name": "Camera 1",
            "source_type": "RTSP", // "RTSP" or "FILE"
            "source_path": "rtsp://admin:password@192.168.1.100/stream",
            "description": "Main entrance camera"
        }
        ```
    *   **Response (JSON)**:
        ```json
        {
            "camera_id": "cam_001",
            "status": "success",
            "message": "Camera registered successfully"
        }
        ```
*   **카메라 목록 조회**
    *   **Endpoint**: `GET /api/cameras`
    *   **Method**: `GET`
    *   **Description**: 등록된 모든 카메라 목록을 조회한다.
    *   **Response (JSON)**:
        ```json
        [
            {
                "camera_id": "cam_001",
                "name": "Camera 1",
                "source_type": "RTSP",
                "source_path": "rtsp://admin:password@192.168.1.100/stream"
            },
            // ... more cameras
        ]
        ```

#### 5.2.1.2 ROI 관리

*   **ROI 프로파일 저장**
    *   **Endpoint**: `POST /api/cameras/{camera_id}/roi_profile`
    *   **Method**: `POST`
    *   **Description**: 특정 카메라에 대한 ROI 프로파일을 저장한다.
    *   **Request Body (JSON)**:
        ```json
        {
            "profile_name": "Hotwork Zone 1",
            "rois": [
                {
                    "roi_id": "roi_001",
                    "type": "HOTWORK", // "HOTWORK", "NO_ENTRY", "WARNING"
                    "points": [[100, 100], [200, 100], [200, 200], [100, 200]], // Polygon coordinates
                    "buffer_radius": 50 // in pixels
                },
                // ... more ROIs
            ]
        }
        ```
    *   **Response (JSON)**:
        ```json
        {
            "status": "success",
            "message": "ROI profile saved successfully"
        }
        ```
*   **ROI 프로파일 불러오기**
    *   **Endpoint**: `GET /api/cameras/{camera_id}/roi_profile`
    *   **Method**: `GET`
    *   **Description**: 특정 카메라에 저장된 ROI 프로파일을 불러온다.
    *   **Response (JSON)**:
        ```json
        {
            "profile_name": "Hotwork Zone 1",
            "rois": [
                {
                    "roi_id": "roi_001",
                    "type": "HOTWORK",
                    "points": [[100, 100], [200, 100], [200, 200], [100, 200]],
                    "buffer_radius": 50
                }
            ]
        }
        ```

#### 5.2.1.3 알림 설정

*   **알림 설정 업데이트**
    *   **Endpoint**: `PUT /api/settings/notifications`
    *   **Method**: `PUT`
    *   **Description**: 알림 수신 채널 및 조건을 업데이트한다.
    *   **Request Body (JSON)**:
        ```json
        {
            "slack_webhook_url": "https://hooks.slack.com/services/...",
            "telegram_chat_id": "123456789",
            "enable_sound_alert": true
        }
        ```
    *   **Response (JSON)**:
        ```json
        {
            "status": "success",
            "message": "Notification settings updated"
        }
        ```

### 5.2.2 WebSocket 명세 (Flutter UI ↔ AI/비디오 처리 서버)

WebSocket은 실시간으로 영상 프레임 데이터, 객체 탐지 결과, 이벤트 알림, 체크리스트 상태 업데이트 등을 스트리밍하는 데 사용된다.

*   **Endpoint**: `ws://<AI_SERVER_IP>:<PORT>/ws/stream/{camera_id}`
*   **메시지 타입**: JSON

#### 5.2.2.1 영상 프레임 및 탐지 결과 스트리밍

*   **AI 서버 → Flutter UI**
    *   **Description**: AI 서버는 처리된 영상 프레임(또는 인코딩된 이미지)과 해당 프레임에서 탐지된 객체들의 정보를 실시간으로 전송한다.
    *   **Message (JSON)**:
        ```json
        {
            "type": "frame_data",
            "timestamp": "2026-02-03T14:30:00.123Z",
            "camera_id": "cam_001",
            "frame": "base64_encoded_image_data", // 또는 별도 스트림으로 전송
            "detections": [
                {
                    "class": "person",
                    "bbox": [x1, y1, x2, y2], // [left, top, right, bottom]
                    "confidence": 0.95,
                    "track_id": 1
                },
                {
                    "class": "helmet",
                    "bbox": [x1, y1, x2, y2],
                    "confidence": 0.88,
                    "track_id": 1 // Person 1에 속하는 헬멧
                }
            ],
            "rois": [
                {
                    "roi_id": "roi_001",
                    "type": "HOTWORK",
                    "points": [[100, 100], [200, 100], [200, 200], [100, 200]],
                    "status": "active" // ROI 활성화 상태 등
                }
            ]
        }
        ```

#### 5.2.2.2 이벤트 알림 스트리밍

*   **AI 서버 → Flutter UI**
    *   **Description**: AI 서버는 룰 엔진에서 감지된 위험 이벤트 정보를 실시간으로 전송한다.
    *   **Message (JSON)**:
        ```json
        {
            "type": "event_notification",
            "timestamp": "2026-02-03T14:30:05.456Z",
            "camera_id": "cam_001",
            "event_id": "evt_001",
            "event_type": "PPE_MISSING", // 예: "ROI_INTRUSION", "FIRE_EXTINGUISHER_MISSING"
            "severity": "WARNING", // "INFO", "WARNING", "CRITICAL"
            "message": "작업자 안전모 미착용 감지",
            "snapshot_url": "/api/snapshots/evt_001.jpg", // 증빙 스냅샷 URL
            "clip_url": "/api/clips/evt_001.mp4" // 증빙 클립 URL (선택 사항)
        }
        ```

#### 5.2.2.3 체크리스트 상태 업데이트 스트리밍

*   **AI 서버 → Flutter UI**
    *   **Description**: AI 서버는 이벤트 발생 시 생성된 체크리스트의 항목별 자동 체크 상태를 실시간으로 전송한다.
    *   **Message (JSON)**:
        ```json
        {
            "type": "checklist_update",
            "timestamp": "2026-02-03T14:30:06.789Z",
            "camera_id": "cam_001",
            "event_id": "evt_001", // 관련 이벤트 ID
            "checklist_instance_id": "chk_inst_001",
            "items": [
                {
                    "item_id": "item_001",
                    "name": "안전모 착용 여부",
                    "status": "CHECKED", // "CHECKED", "UNCHECKED", "MANUAL_REQUIRED"
                    "ai_reason": "Helmet detected near person bbox"
                },
                {
                    "item_id": "item_002",
                    "name": "소화기 비치 여부",
                    "status": "UNCHECKED",
                    "ai_reason": "FireExtinguisher not detected in ROI buffer"
                }
            ]
        }
        ```

### 5.2.3 API 에러 응답 형식

모든 RESTful API는 에러 발생 시 다음과 같은 표준 JSON 응답 형식을 따른다.

```json
{
    "status": "error",
    "code": 400, // HTTP Status Code
    "message": "Error description",
    "details": "More specific error details if available"
}
```

## 5.3 데이터 흐름 상세

1.  **영상 입력**: Flutter UI에서 사용자가 카메라를 등록하고 Live 모드를 시작하면, AI 서버는 해당 카메라의 `source_path` (RTSP URL 또는 파일 경로)로부터 영상 스트림을 수신한다.
2.  **프레임 처리**: AI 서버는 영상 스트림을 프레임 단위로 디코딩하고, 각 프레임에 대해 AI 객체 인식 모델을 실행하여 `detections` (객체 바운딩 박스, 클래스, 신뢰도)를 생성한다.
3.  **트래킹 및 ROI 판단**: `detections` 결과를 기반으로 객체 트래킹을 수행하고, Flutter UI로부터 수신된 `ROI` 정보와 비교하여 객체의 ROI 진입/이탈, 체류 시간 등을 판단한다.
4.  **룰 엔진 평가**: ROI 판단 결과 및 `detections` 정보를 `Rule Engine`에 입력하여 사전 정의된 안전 규칙을 평가한다. (예: `Person`이 `ROI_HOTWORK`에 2초 이상 체류하고 `Helmet`이 미탐지되면 `PPE_MISSING` 이벤트 트리거).
5.  **이벤트 생성 및 DB 저장**: 룰 엔진에서 이벤트가 트리거되면, `EventLog` 테이블에 이벤트 정보를 저장하고, 해당 이벤트에 대한 `ChecklistInstance`를 생성하여 `ChecklistInstance` 테이블에 저장한다. 이때 `ChecklistTemplate`을 참조하여 항목별 자동 체크 여부를 결정한다.
6.  **실시간 스트리밍**: AI 서버는 처리된 영상 프레임(또는 요약 정보), `detections`, `rois` 정보, `event_notification`, `checklist_update` 정보를 WebSocket을 통해 Flutter UI로 실시간 스트리밍한다.
7.  **UI 갱신**: Flutter UI는 WebSocket을 통해 수신된 데이터를 바탕으로 화면을 갱신한다. 영상 위에 바운딩 박스와 ROI를 오버레이하고, 체크리스트 패널의 상태를 업데이트하며, 이벤트 타임라인에 새로운 알림을 추가한다.
8.  **설정 및 제어**: Flutter UI에서 사용자가 카메라 등록, ROI 설정, 알림 설정 등을 변경하면, RESTful API를 통해 AI 서버로 해당 정보가 전송되고, AI 서버는 이를 DB에 반영하거나 내부 로직에 적용한다.

---

# 6. DB 스키마 및 체크리스트 템플릿 설계

본 문서는 CCTV 기반 화기작업 안전관제 시스템의 데이터베이스 스키마와 핵심 기능인 체크리스트 템플릿의 상세 설계를 다룬다. 이는 시스템의 데이터 저장 및 관리의 기반이 되며, AI 기반 자동 체크 기능의 핵심 로직과 연동된다.

## 6.1 데이터베이스 스키마 설계

시스템은 다양한 정보를 효율적으로 저장하고 관리하기 위해 다음과 같은 주요 엔티티(테이블)를 포함한다. 각 테이블은 관계형 데이터베이스(예: PostgreSQL, MySQL)를 기준으로 설계되었으며, 필요에 따라 NoSQL 데이터베이스로의 전환도 고려할 수 있다.

### 6.1.1 `RegulationSource` 테이블

법령, 사내규정, 작업 표준 등 체크리스트 항목의 출처 정보를 관리한다.

| 컬럼명 | 데이터 타입 | 제약 조건 | 설명 |
|:---|:---|:---|:---|
| `source_id` | `VARCHAR(50)` | `PRIMARY KEY` | 규정 출처의 고유 ID (예: `LAW_SANAN`, `COMPANY_RULE_001`) |
| `name` | `VARCHAR(255)` | `NOT NULL` | 규정 출처명 (예: 산업안전보건법, 사내 화기작업 안전수칙) |
| `description` | `TEXT` | `NULLABLE` | 규정 출처에 대한 상세 설명 |
| `created_at` | `DATETIME` | `NOT NULL` | 레코드 생성 시각 |
| `updated_at` | `DATETIME` | `NOT NULL` | 레코드 최종 수정 시각 |

### 6.1.2 `ChecklistTemplate` 테이블

작업 유형별 체크리스트 템플릿을 관리한다. 예를 들어, 화기작업, 고소작업 등.

| 컬럼명 | 데이터 타입 | 제약 조건 | 설명 |
|:---|:---|:---|:---|
| `template_id` | `VARCHAR(50)` | `PRIMARY KEY` | 체크리스트 템플릿의 고유 ID (예: `HOTWORK_V1`, `HIGH_ALTITUDE_V1`) |
| `name` | `VARCHAR(255)` | `NOT NULL` | 템플릿 이름 (예: 화기작업 안전 체크리스트) |
| `work_type` | `VARCHAR(50)` | `NOT NULL` | 작업 유형 (예: `HOTWORK`, `HIGH_ALTITUDE`) |
| `description` | `TEXT` | `NULLABLE` | 템플릿에 대한 상세 설명 |
| `created_at` | `DATETIME` | `NOT NULL` | 레코드 생성 시각 |
| `updated_at` | `DATETIME` | `NOT NULL` | 레코드 최종 수정 시각 |

### 6.1.3 `ChecklistItem` 테이블

각 체크리스트 템플릿에 포함되는 개별 항목들을 관리한다.

| 컬럼명 | 데이터 타입 | 제약 조건 | 설명 |
|:---|:---|:---|:---|
| `item_id` | `VARCHAR(50)` | `PRIMARY KEY` | 체크리스트 항목의 고유 ID |
| `template_id` | `VARCHAR(50)` | `FOREIGN KEY` | `ChecklistTemplate` 테이블 참조 |
| `item_name` | `VARCHAR(255)` | `NOT NULL` | 항목명 (예: 안전모 착용 여부) |
| `description` | `TEXT` | `NULLABLE` | 항목에 대한 상세 설명 |
| `importance` | `ENUM(\'LOW\', \'MEDIUM\', \'HIGH\')` | `NOT NULL` | 항목의 중요도 |
| `auto_checkable` | `BOOLEAN` | `NOT NULL` | AI에 의한 자동 체크 가능 여부 |
| `ai_mapping_condition` | `TEXT` | `NULLABLE` | AI 자동 체크를 위한 조건 (JSON 또는 특정 포맷) |
| `manual_guidance` | `TEXT` | `NULLABLE` | 수동 확인이 필요한 경우의 가이드 |
| `source_id` | `VARCHAR(50)` | `FOREIGN KEY` | `RegulationSource` 테이블 참조 |
| `order_idx` | `INT` | `NOT NULL` | 템플릿 내 항목 순서 |
| `created_at` | `DATETIME` | `NOT NULL` | 레코드 생성 시각 |
| `updated_at` | `DATETIME` | `NOT NULL` | 레코드 최종 수정 시각 |

### 6.1.4 `CameraProfile` 테이블

각 카메라별 설정 정보 및 ROI 프로파일을 관리한다.

| 컬럼명 | 데이터 타입 | 제약 조건 | 설명 |
|:---|:---|:---|:---|
| `camera_id` | `VARCHAR(50)` | `PRIMARY KEY` | 카메라의 고유 ID |
| `camera_name` | `VARCHAR(255)` | `NOT NULL` | 카메라 이름 |
| `source_type` | `ENUM(\'RTSP\', \'FILE\')` | `NOT NULL` | 영상 소스 타입 |
| `source_path` | `VARCHAR(512)` | `NOT NULL` | 영상 소스 경로 (RTSP URL 또는 파일 경로) |
| `roi_profile_json` | `JSON` | `NULLABLE` | ROI 설정 정보 (JSON 형태) |
| `description` | `TEXT` | `NULLABLE` | 카메라에 대한 상세 설명 |
| `created_at` | `DATETIME` | `NOT NULL` | 레코드 생성 시각 |
| `updated_at` | `DATETIME` | `NOT NULL` | 레코드 최종 수정 시각 |

### 6.1.5 `EventLog` 테이블

시스템에서 감지된 모든 이벤트 기록을 저장한다.

| 컬럼명 | 데이터 타입 | 제약 조건 | 설명 |
|:---|:---|:---|:---|
| `event_id` | `VARCHAR(50)` | `PRIMARY KEY` | 이벤트의 고유 ID |
| `camera_id` | `VARCHAR(50)` | `FOREIGN KEY` | `CameraProfile` 테이블 참조 |
| `timestamp` | `DATETIME` | `NOT NULL` | 이벤트 발생 시각 |
| `event_type` | `VARCHAR(100)` | `NOT NULL` | 이벤트 유형 (예: `PPE_MISSING`, `ROI_INTRUSION`) |
| `severity` | `ENUM(\'INFO\', \'WARNING\', \'CRITICAL\')` | `NOT NULL` | 이벤트 심각도 |
| `message` | `TEXT` | `NOT NULL` | 이벤트 메시지 |
| `snapshot_path` | `VARCHAR(512)` | `NULLABLE` | 증빙 스냅샷 파일 경로 |
| `clip_path` | `VARCHAR(512)` | `NULLABLE` | 증빙 영상 클립 파일 경로 |
| `detection_results_json` | `JSON` | `NULLABLE` | 이벤트 발생 시점의 AI 탐지 결과 (JSON) |
| `roi_status_json` | `JSON` | `NULLABLE` | 이벤트 발생 시점의 ROI 상태 (JSON) |
| `created_at` | `DATETIME` | `NOT NULL` | 레코드 생성 시각 |

### 6.1.6 `ChecklistInstance` 테이블

특정 이벤트 발생 시 생성된 체크리스트의 인스턴스 및 항목별 상태를 관리한다.

| 컬럼명 | 데이터 타입 | 제약 조건 | 설명 |
|:---|:---|:---|:---|
| `instance_id` | `VARCHAR(50)` | `PRIMARY KEY` | 체크리스트 인스턴스의 고유 ID |
| `event_id` | `VARCHAR(50)` | `FOREIGN KEY` | `EventLog` 테이블 참조 |
| `template_id` | `VARCHAR(50)` | `FOREIGN KEY` | `ChecklistTemplate` 테이블 참조 |
| `created_at` | `DATETIME` | `NOT NULL` | 인스턴스 생성 시각 |
| `updated_at` | `DATETIME` | `NOT NULL` | 인스턴스 최종 수정 시각 |
| `item_status_json` | `JSON` | `NOT NULL` | 각 항목의 상태 (JSON 형태) |

## 6.2 체크리스트 템플릿 (화기작업) 설계

화기작업 안전관리를 위한 체크리스트 템플릿은 `ChecklistTemplate` 및 `ChecklistItem` 테이블에 저장될 데이터의 구체적인 예시이다. MVP 단계에서 고려되는 화기작업 체크리스트는 다음과 같다.

### 6.2.1 `ChecklistTemplate` 예시

| `template_id` | `name` | `work_type` | `description` |
|:---|:---|:---|:---|
| `HOTWORK_V1` | 화기작업 안전 체크리스트 | `HOTWORK` | 제철소 화기작업 시 준수해야 할 안전 수칙 |

### 6.2.2 `ChecklistItem` 예시 (화기작업)

| `item_id` | `template_id` | `item_name` | `auto_checkable` | `ai_mapping_condition` | `manual_guidance` | `source_id` | `importance` |
|:---|:---|:---|:---|:---|:---|:---|:---|
| `HW_001` | `HOTWORK_V1` | 안전모 착용 여부 | `TRUE` | `Person in ROI_HOTWORK AND Helmet detected near Person bbox` | `육안으로 안전모 착용 여부 확인` | `LAW_SANAN` | `HIGH` |
| `HW_002` | `HOTWORK_V1` | 마스크 착용 여부 | `TRUE` | `Person in ROI_HOTWORK AND Mask detected near Person bbox` | `육안으로 마스크 착용 여부 확인` | `LAW_SANAN` | `HIGH` |
| `HW_003` | `HOTWORK_V1` | 소화기 비치 여부 | `TRUE` | `FireExtinguisher detected in ROI_BUFFER` | `작업 반경 내 소화기 비치 여부 확인` | `COMPANY_RULE_001` | `HIGH` |
| `HW_004` | `HOTWORK_V1` | 불티방지 가림막 설치 여부 | `TRUE` | `SparkShield/FireBlanket detected in ROI_HOTWORK` | `불티방지 가림막 설치 상태 확인` | `COMPANY_RULE_001` | `MEDIUM` |
| `HW_005` | `HOTWORK_V1` | 작업 허가서 확인 | `FALSE` | `NULL` | `작업 허가서 유효성 및 내용 확인` | `COMPANY_RULE_001` | `HIGH` |
| `HW_006` | `HOTWORK_V1` | 가스 측정 여부 | `FALSE` | `NULL` | `밀폐공간 또는 가스 발생 우려 지역 가스 농도 측정 확인` | `LAW_SANAN` | `HIGH` |

### 6.3 AI 매핑 조건 상세

`ai_mapping_condition` 필드는 AI 서버의 룰 엔진에서 체크리스트 항목의 자동 체크 여부를 판단하는 데 사용되는 조건식을 정의한다. 이는 JSON 또는 특정 도메인 특화 언어(DSL) 형태로 표현될 수 있다. 위 예시에서는 가독성을 위해 자연어에 가까운 형태로 표현되었으나, 실제 구현 시에는 파싱 가능한 형태로 정의되어야 한다.

*   **`Person in ROI_HOTWORK`**: `Person` 객체가 `ROI_HOTWORK` 영역 내에 존재하는지 여부.
*   **`Helmet detected near Person bbox`**: `Person` 객체의 바운딩 박스 근처에서 `Helmet` 객체가 탐지되었는지 여부. (예: `Person` bbox와 `Helmet` bbox의 IoU(Intersection over Union)가 일정 임계치 이상이거나, 중심점 거리가 일정 거리 이내).
*   **`FireExtinguisher detected in ROI_BUFFER`**: `ROI_HOTWORK`의 버퍼 영역 내에서 `FireExtinguisher` 객체가 탐지되었는지 여부.
*   **`SparkShield/FireBlanket detected in ROI_HOTWORK`**: `ROI_HOTWORK` 영역 내에서 `SparkShield` 또는 `FireBlanket` 객체가 탐지되었는지 여부.

이러한 조건식은 룰 엔진에서 실시간으로 평가되어 `ChecklistInstance`의 `item_status_json` 필드를 업데이트하는 데 활용된다. `item_status_json`은 각 `item_id`에 대한 `status` (CHECKED, UNCHECKED, MANUAL_REQUIRED) 및 `ai_reason` (AI가 판단한 근거)를 포함할 수 있다.
