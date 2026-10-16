# Codex Meter 2.0

[简体中文](README.md) · [繁體中文](README.zh-Hant.md) · [English](README.en.md) · [日本語](README.ja.md) · 한국어 · [Español](README.es.md)

<img src="Resources/AppIcon.png" alt="Codex Meter 아이콘" width="96">

Codex 계정의 남은 한도, 기기 간 사용 기록, 이 Mac의 실시간 Token 수를 확인하는 네이티브 macOS 메뉴 막대 앱입니다. 메뉴 막대 항목을 클릭하면 패널이 열립니다.

Codex Meter는 OpenAI와 제휴하지 않은 독립 오픈 소스 프로젝트입니다.

[v2.0.0 다운로드](https://github.com/JTXYH/codex-meter/releases/download/v2.0.0/CodexMeter-2.0.0-macOS.zip) · [릴리스 노트](https://github.com/JTXYH/codex-meter/releases/tag/v2.0.0) · [문제 신고](https://github.com/JTXYH/codex-meter/issues)

## 화면

스크린샷에는 데모 데이터를 사용했습니다.

| A · 간결한 패널 | B · 데이터 패널 |
| --- | --- |
| ![간결한 패널](docs/images/panel-light.png) | ![데이터 패널](docs/images/panel-data.png) |

![통합 설정 화면](docs/images/settings.png)

## 기능

- **두 가지 테마:** 보라색 원형 게이지의 간결한 패널과 초록색 가로 게이지의 데이터 패널. 설정의 강조색도 테마를 따르며, 시스템 설정·라이트·다크 모드를 지원합니다.
- **한도와 초기화 시간:** 메뉴 막대는 5시간 한도를 우선 표시하고, 주간 한도만 있으면 이를 표시합니다. 패널에는 계정에서 받은 한도 구간과 초기화 시간이 나타납니다. 사용 가능, 한도 부족, 초기화 대기 상태의 문구를 직접 설정할 수 있습니다.
- **오늘의 상세 정보:** 본 기기의 Token 카운터를 5초마다 증분으로 읽어 입력, 출력, 캐시 입력, 모델별 내역을 보여 줍니다.
- **계정 사용 기록:** 공식 계정 API의 일·주·월·연간 Token 합계로, 다른 기기와 클라우드 작업을 포함합니다. 모델명, Fast 표시, 응답 데이터가 지원하는 사용 비율을 보여 줍니다.
- **활동:** 어제, 최근 7일, 이번 달 사용량과 120일 히트맵, 계정에서 제공하는 누적 Token·연속 사용 일수·최장 단일 작업.
- **초기화 카드:** 공식 API의 사용 가능 수량과 각 카드의 만료 날짜·시간을 만료 순서대로 표시합니다. 조회 전용이며 카드 사용이나 한도 초기화를 실행하지 않습니다.
- **Credits 잔액:** 추가 사용 잔액을 표시합니다. 환산 기준은 아래 표를 참고하세요.
- **통합 설정:** 카드 표시와 드래그 정렬, 메뉴 막대 원형 아이콘 크기, 전체 또는 카드별 글자 크기, 새로 고침 간격, 시작 방식, 언어, 로컬 데이터 정리.
- **업데이트와 개인정보:** Sparkle을 통한 앱 내 업데이트. 이메일은 기본적으로 가려지며 클릭하면 잠시 표시되고, 패널을 닫으면 다시 숨겨집니다.

중국어 간체·번체, 영어, 일본어, 한국어, 스페인어를 지원합니다. 처음 실행할 때 시스템의 선호 언어를 따르며, 일치하는 언어가 없으면 영어를 사용합니다.

## 설치와 사용

macOS 14 Sonoma 이상이 필요합니다. Universal 빌드는 Apple Silicon과 Intel Mac을 지원합니다. 먼저 [Codex 데스크톱 앱 또는 CLI](https://github.com/openai/codex)를 설치하고 ChatGPT 계정으로 로그인하세요.

1. [GitHub Releases](https://github.com/JTXYH/codex-meter/releases/latest)에서 ZIP을 다운로드해 압축을 푼 뒤 `CodexMeter.app`을 응용 프로그램 폴더로 옮깁니다.
2. Codex Meter를 실행하고 메뉴 막대의 한도 링을 클릭합니다.
3. 오른쪽 위 버튼으로 새로 고침, 왼쪽 아래 톱니바퀴로 설정 열기, 오른쪽 아래 전원 버튼으로 종료할 수 있습니다.
4. 설정에서 수동 시작, 로그인 시 시작, Codex와 함께 시작·종료를 선택합니다. 마지막 두 방식은 동시에 켤 수 없습니다. Codex 연동에는 패키징된 앱이 필요하며, macOS의 로그인 항목 및 확장 프로그램에서 백그라운드 도우미를 허용해야 할 수 있습니다.

빌드 스크립트는 기본적으로 ad-hoc 서명을 사용하며, Apple 공증을 의미하지 않습니다. 처음 실행할 때 macOS가 차단하면 배포 출처와 Release의 SHA-256 체크섬을 확인한 뒤 시스템 설정 → 개인정보 보호 및 보안의 허용 옵션을 사용하세요.

릴리스 빌드는 정보 및 업데이트에서 업데이트를 확인할 수 있고, 6시간마다 자동으로 확인합니다. Sparkle이 업데이트 패키지를 검증한 후 설치합니다. 개발 빌드는 자동 확인을 하지 않습니다.

## 데이터 출처와 집계 기준

| 데이터 | 출처와 의미 |
| --- | --- |
| 계정, 한도, 초기화 시간 | 본 기기 Codex CLI의 공식 `app-server`: `account/read`, `account/rateLimits/read`. |
| Token 기록, 히트맵, 계정 요약 | `account/usage/read`가 제공하는 계정 통계. 누락된 날짜를 로컬 기록으로 채우지 않습니다. |
| 과거 모델과 사용 비율 | 공식 계정의 `daily-token-usage-breakdown`. 같은 응답 안에서 각 모델의 `credits` 가중치 합을 전체 가중치 합으로 나눕니다. Token 비율이나 달러 비용이 아닙니다. 가중치가 불완전하면 모델명만 표시합니다. |
| 오늘의 Token과 모델 내역 | 본 기기 Codex 세션·보관 로그의 당일 카운터 이벤트. 이 Mac만 포함합니다. |
| 초기화 카드 | `account/rateLimits/read`의 `rateLimitResetCredits`. 수량은 `availableCount`, 만료 시간은 사용 가능한 카드의 상세 정보에서 가져옵니다. 상세 정보가 없으면 공식 수량을 유지하고 안내를 표시합니다. |
| Credits 잔액 | 공식 Credits 잔액을 고정 비율 `1 Credit = US$0.04`로 환산해 표시합니다. Token 기반 API 비용과는 별개입니다. |

오늘과 과거 통계는 **UTC 날짜 경계**를 사용해 로컬의 ‘오늘’과 계정의 ‘어제’가 겹치지 않도록 합니다. 주간 통계는 UTC 기준 월요일부터 일요일까지입니다. 한도 초기화와 카드 만료 시간은 Mac의 현재 시간대로 표시합니다. 과거 통계에 포함되는 오늘의 값도 계정 응답만 사용하며 로컬 실시간 수치를 더하지 않습니다.

API 비용 계산과 관련 설정은 제거했습니다. API 키나 Amazon Bedrock으로 로그인하면 ChatGPT 계정 한도, 모델 기록, 초기화 카드를 제공받지 못할 수 있습니다. API 응답이 늦거나 일부 필드가 없을 수도 있습니다. 새로 고침에 실패하면 마지막 성공 데이터를 유지하고, 최초 로딩 실패 시 재시도를 안내합니다.

## 로컬 저장과 개인정보

설정, 로컬 카운터, 로그 읽기 위치는 다음 경로에 저장합니다.

```text
~/Library/Application Support/CodexMeter/meter.sqlite
```

SQLite는 WAL과 트랜잭션을 사용합니다. 계정 한도, 기록, 모델 결과는 메모리에만 캐시합니다. 로그에서 사용량 카운터만 추출하며 대화 본문은 저장하거나 업로드하지 않습니다.

모델 기록 요청은 `$CODEX_HOME/auth.json`(기본값 `~/.codex/auth.json`)의 기존 ChatGPT 로그인 정보를 사용합니다. 계정을 확인한 뒤 `chatgpt.com`으로 요청하며, 액세스 토큰을 앱 데이터베이스나 로그에 기록하지 않습니다.

설정의 로컬 데이터 화면에서 보관 기간에 따라 통계를 삭제하거나 모두 비울 수 있습니다. 원본 Codex 로그, 계정 통계, 설정은 보존됩니다. 정리 기준을 저장하므로 재시작해도 과거 이벤트를 다시 가져오지 않습니다.

공개 Issue에 액세스 토큰, `auth.json`, 전체 이메일 주소, 원본 계정 응답을 첨부하지 마세요.

## 소스에서 빌드

Swift 6 도구 모음(Xcode 16 이상)이 필요합니다.

```bash
git clone https://github.com/JTXYH/codex-meter.git
cd codex-meter
./scripts/build-app.sh release
```

결과물은 `dist/CodexMeter.app`입니다. 빌드할 때마다 프로젝트 `dist/`의 이전 결과물을 먼저 삭제합니다. 직접 지정한 CLI가 우선이며, 자동 탐색은 Codex/ChatGPT 데스크톱 앱에 포함된 CLI를 먼저 확인한 다음 일반 설치 경로를 찾습니다.

```bash
swift run CodexMeter
swift test
```

패키징과 서명 절차는 [릴리스 가이드](docs/releasing.md)를 참고하세요. `master`에는 2.0 코드가 있으며, 이번 배포 전의 온라인 `master`는 [V1.0 브랜치](https://github.com/JTXYH/codex-meter/tree/V1.0)에 보존되어 있습니다.

## 라이선스

[MIT License](LICENSE)
