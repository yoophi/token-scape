# TokenScope

TokenScope는 Claude Code와 Codex의 로컬 사용량을 한 화면에서 확인하는 macOS 데스크탑 앱입니다.

Claude Code와 Codex를 함께 사용하다 보면 각 도구의 사용량, 남은 시간, 주간 한도, 토큰 사용량을 따로 확인해야 합니다. TokenScope는 두 서비스의 로컬 로그를 읽어 공통 포맷으로 정리하고, 왼쪽에는 Claude Code, 오른쪽에는 Codex 정보를 나란히 보여줍니다.

![TokenScope 스크린샷](docs/screenshot.png)

## 주요 기능

- Claude Code와 Codex 사용량을 좌우 2컬럼으로 표시
- 5시간 창과 주간 창의 남은 시간, 남은 비율, 진행률 표시
- Claude Code와 Codex의 토큰 사용량 요약
- `간단히` / `자세히` 보기 모드
- 자동 새로고침 `1분` / `5분` / `안함` 선택
- 다음 자동 새로고침까지 남은 초 표시
- 항상 위 토글
- 메뉴바 항목 제공
- 보기 모드, 자동 새로고침 설정, 항상 위 상태, 창 크기 저장

## 데이터 소스

TokenScope는 네트워크 요청 없이 로컬 로그만 읽습니다.

Claude Code:

```text
~/.claude/projects/**/*.jsonl
```

Codex:

```text
~/.codex/sessions/**/*.jsonl
```

Codex는 세션 로그의 최신 `rate_limits` 이벤트와 `token_count` 정보를 읽습니다. Claude Code는 assistant 메시지의 `usage` 필드를 집계하고, 5시간/7일 사용 블록을 계산합니다.

## 화면 구성

왼쪽 컬럼은 Claude Code, 오른쪽 컬럼은 Codex입니다. 두 컬럼은 가능한 한 같은 위치에 같은 의미의 정보를 표시합니다.

- 카드 오른쪽 상단 첫 번째 값: `남은 시간`
- 카드 오른쪽 상단 두 번째 값: `남은 비율`
- 5시간 창 남은 시간: `HH:MM:SS`
- 주간 창 남은 시간: `6d HH:MM:SS`

서비스별 하이라이트 색상도 분리했습니다.

- Claude Code: Claude 계열의 따뜻한 오렌지
- Codex: OpenAI/Codex 계열의 녹색

## 설치 및 실행

요구사항:

- macOS 14 이상
- Swift 6 toolchain 또는 Xcode Command Line Tools

실행:

```sh
make run
```

앱 번들 생성:

```sh
make app
open .build/release/TokenScope.app
```

테스트 또는 컴파일 확인:

```sh
make test
```

`make test`는 XCTest 없이 동작하는 `UsageTests` executable test runner를 실행합니다.

## 메뉴바

앱은 메뉴바 항목을 제공합니다.

- Codex 남은 비율 표시
- 창 열기
- 새로고침
- 종료

## 아키텍처

프로젝트는 작은 hexagonal architecture 기반으로 구성되어 있습니다.

- `Sources/CodexUsageCore/Domain`: 사용량 snapshot과 dashboard state
- `Sources/CodexUsageCore/Ports`: `CodexUsageReading`, `ClaudeUsageReading`, `DateProviding`
- `Sources/CodexUsageCore/UseCases`: 사용량 dashboard 로드 use case
- `Sources/CodexUsageCore/Adapters/LocalLogs`: 로컬 JSONL 로그 reader
- `Sources/TokenScope`: SwiftUI/AppKit UI, 메뉴바, timer, formatting, 사용자 설정 저장

SwiftUI 화면은 로그 파일을 직접 파싱하지 않습니다. UI는 use case를 호출하고, use case는 port에 의존하며, 로컬 로그 reader는 교체 가능한 outbound adapter로 분리되어 있습니다.

## 검증 명령

변경 후 다음 명령으로 앱을 확인합니다.

```sh
make test
make app
plutil -lint .build/release/TokenScope.app/Contents/Info.plist
open .build/release/TokenScope.app
```
