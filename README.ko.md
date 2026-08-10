# Codex Meter

[简体中文](README.md) · [繁體中文](README.zh-Hant.md) · [English](README.en.md) · [日本語](README.ja.md) · 한국어 · [Español](README.es.md)

Codex Meter는 ChatGPT/Codex 계정의 할당량 창과 token 활동을 빠르게 확인할 수 있는 macOS 네이티브 메뉴 막 유틸리티입니다. 로컬 Codex CLI의 `app-server` JSON-RPC 인터페이스에서 데이터를 읽고 기존 로그인 상태를 재사용하며, 액세스 토큰을 읽거나 저장하지 않습니다.

> Codex Meter는 독립적인 오픈 소스 프로젝트입니다. OpenAI의 공식 제품이 아니며 OpenAI의 지원이나 추천을 의미하지 않습니다.

## 스크린샷

| 간체 중국어 · 라이트 | English · Dark |
| --- | --- |
| ![간체 중국어 라이트 화면](docs/images/overview-zh-Hans-light.png) | ![영어 다크 화면](docs/images/overview-en-dark.png) |

> 스크린샷은 모두 합성 데모 데이터를 사용하며 실제 계정 정보를 포함하지 않습니다.

## 주요 기능

- 메뉴 막에 Codex 주간 남은 할당량을 항상 표시
- 모든 할당량 창, 남은 비율, 재설정 카운트다운 표시
- 오늘, 최근 7일, 누적 token 활동과 90일 히트맵
- 오늘 데이터가 없으면 어제 데이터로 자동 대체
- 수동 새로고침, 기본 간격, 1~1,440분 사용자 지정 간격
- 시스템, 라이트, 다크 모드
- 실행 시와 이후 6시간마다 Cloudflare를 통해 GitHub Release를 확인하고 새 버전 다운로드 안내
- 계정 이메일을 기본으로 마스크 처리하고 명시적으로 누를 때만 표시
- 새로고침이 실패해도 마지막 성공 데이터 유지

## 인터페이스 언어

기본 언어는 간체 중국어입니다. 현재 지원 언어:

- 간체 중국어 (`zh-Hans`)
- 번체 중국어 (`zh-Hant`)
- English (`en`)
- 일본어 (`ja`)
- 한국어 (`ko`)
- Español (`es`)

## 다운로드

[⬇️ Codex Meter v1.0.1 다운로드(macOS Universal 2)](https://github.com/JTXYH/codex-meter/releases/download/v1.0.1/CodexMeter-1.0.1-macOS.zip)

Apple Silicon과 Intel Mac을 모두 지원합니다. ZIP을 풀고 `CodexMeter.app`을 응용 프로그램 폴더로 옮기세요. [v1.0.1 릴리스 노트](https://github.com/JTXYH/codex-meter/releases/tag/v1.0.1).

### 첫 실행 시 macOS가 앱을 차단하는 경우

현재 빌드는 ad-hoc 서명을 사용하며 Apple 공증을 받지 않았습니다. 첫 실행 시 “Apple에서 앱에 악성 소프트웨어가 있는지 확인할 수 없습니다” 또는 “앱 개발자를 확인할 수 없습니다”라는 경고가 표시되면 먼저 이 저장소의 [GitHub Releases](https://github.com/JTXYH/codex-meter/releases)에서 다운로드한 앱인지 확인한 다음 아래 방법 중 하나를 사용하세요.

**방법 1: Finder에서 열기**

1. Finder에서 응용 프로그램 폴더를 열고 `CodexMeter.app`을 찾습니다.
2. Control 키를 누른 채 앱을 클릭하거나 오른쪽 클릭한 다음 **열기**를 선택합니다.
3. 확인 창에서 **열기**를 한 번 더 클릭합니다. 한 번 허용하면 다음부터는 이중 클릭하여 정상적으로 실행할 수 있습니다.

**방법 2: 시스템 설정에서 허용하기**

1. `CodexMeter.app`을 한 번 이중 클릭한 다음 macOS 경고를 닫습니다.
2. Apple 메뉴 ** → 시스템 설정 → 개인정보 보호 및 보안**을 엽니다.
3. 아래로 스크롤하여 보안 섹션에서 Codex Meter에 대한 메시지를 찾고 **그래도 열기**를 클릭합니다.
4. 요청대로 본인 인증을 완료한 다음 **열기**를 클릭합니다. **그래도 열기** 버튼은 보통 앱 실행을 시도한 후 약 1시간 동안만 표시됩니다.

자세한 내용은 [Apple 지원: Mac에서 앱 안전하게 열기](https://support.apple.com/ko-kr/102445)를 참고하세요. macOS가 앱이 “컴퓨터를 손상시킬 것”이라고 명확히 알리거나 악성 소프트웨어를 감지하면 경고를 우회하지 마세요. 현재 파일을 삭제하고 공식 Release에서 다시 다운로드하세요.

## 시스템 요구 사항

- macOS 14 Sonoma 이상
- [Codex CLI](https://github.com/openai/codex) 설치 및 ChatGPT 계정 로그인
- Swift 6 / Xcode 16 이상(소스에서 빌드할 때만 필요)

Codex Meter는 `PATH`, `~/.local/bin/codex`, `~/.npm-global/bin/codex`, 일반적인 Homebrew 경로, Codex/ChatGPT App 내부에서 `codex` 실행 파일을 순서대로 찾습니다.

## 설치

저장소를 클론하거나 다운로드한 다음 실행하세요.

```bash
cd codex-meter
chmod +x scripts/build-app.sh
./scripts/build-app.sh
```

`dist/CodexMeter.app`에 앱이 생성됩니다. 바로 실행하거나 응용 프로그램 폴더로 옮기세요.

개발 중에는 다음과 같이 실행할 수 있습니다.

```bash
swift run CodexMeter
```

## 사용 가이드

1. Codex CLI를 시작하고 ChatGPT 계정으로 로그인되어 있는지 확인합니다.
2. Codex Meter를 실행하면 메뉴 막에 아이콘과 주간 남은 할당량이 표시됩니다.
3. 메뉴 막 항목을 클릭해 할당량, token 활동, 히트맵, 사용량 개요를 확인합니다.
4. 오른쪽 위 새로고침 버튼으로 데이터를 즉시 업데이트합니다.
5. 마스크된 이메일을 클릭하면 전체 주소가 잠시 표시됩니다. 패널을 닫으면 다시 마스크 처리됩니다.
6. 왼쪽 아래 톱니바퀴 버튼에서 모드, 언어, 자동 새로고침 간격을 변경합니다.
7. 오른쪽 아래 전원 버튼으로 앱을 종료합니다.

## 데이터와 개인정보

- 계정 요약은 `account/read`에서 가져옵니다.
- 할당량 창은 `account/rateLimits/read`에서 가져오며 비율은 각 창의 사용된 부분을 나타냅니다.
- Token 활동과 히트맵은 `account/usage/read`에서 가져오며 할당량 상한과는 다른 활동 통계입니다.
- 앱은 `auth.json`에 접근하지 않고, 액세스 토큰을 저장하지 않으며, 전체 서버 응답을 기록하거나 추가 데이터를 업로드하지 않습니다.
- API Key 또는 Amazon Bedrock 로그인은 ChatGPT 할당량이나 활동 데이터를 반환하지 않을 수 있습니다. 이 지표가 필요하면 ChatGPT 로그인을 사용하세요.

## 개발 및 테스트

```bash
swift test
swift build -c release
```

프로젝트는 Swift Package Manager를 사용하며 현재 제3자 패키지 의존성이 없습니다. 변경 사항을 제출하기 전에 테스트와 release 빌드가 통과하는지 확인하세요.

## 보안

공개 Issue에 액세스 토큰, `auth.json`, 전체 이메일 주소, 원본 App Server 응답을 올리지 마세요. GitHub Private Vulnerability Reporting이 활성화되어 있다면 **Security → Advisories → Report a vulnerability**에서 비공개로 제보하세요.

## 자주 묻는 질문(FAQ)

### Claude Code를 지원하지 않는 이유는 무엇인가요?

![Anthropic이 Claude Code 계정 복구를 거부한 안내](docs/images/why-claude-code-is-not-supported.png)

## 라이선스

Codex Meter는 [Apache License 2.0](LICENSE)으로 배포됩니다.
