# TokenScope

Claude Code와 Codex의 로컬 사용량을 한 화면에서 나란히 보여주는 macOS 데스크탑 앱입니다.

- 왼쪽 컬럼: Claude Code usage
- 오른쪽 컬럼: Codex usage

앱은 로컬 로그만 읽으며, 네트워크 요청을 보내지 않습니다.

## 데이터 소스

Claude Code는 다음 경로의 JSONL 로그를 읽습니다.

```text
~/.claude/projects/**/*.jsonl
```

Codex는 다음 경로의 세션 JSONL에서 최신 `rate_limits` 이벤트와 `token_count` 정보를 읽습니다.

```text
~/.codex/sessions/**/*.jsonl
```

## 표시 정보

두 제품은 가능한 한 같은 포맷으로 표시됩니다.

- 5시간 또는 짧은 창
- 주간 창
- 남은 시간
- 남은 비율
- 진행률 막대
- 리셋 시각과 리셋까지 남은 시간
- 토큰 요약
- 자세히 보기의 source path와 metadata

남은 시간 포맷:

- 5시간 창: `HH:MM:SS`
- 주간 창: `6d HH:MM:SS`처럼 일수와 시각을 함께 표시

카드의 오른쪽 상단 위치는 양쪽 제품 모두 동일합니다.

- 첫 번째 metric: `남은 시간`
- 두 번째 metric: `남은 비율`

Codex의 남은 비율은 Codex가 기록한 rate limit 값을 기준으로 합니다. Claude Code의 남은 비율은 활성 usage block에서 남은 시간을 기준으로 계산합니다.

## 화면 옵션

- `간단히`: 기본 보기입니다. Claude Code와 Codex의 공통 필드를 compact summary로 표시합니다.
- `자세히`: token breakdown, source path, 상세 row를 추가로 표시합니다.
- 보기 모드에 따라 창 크기와 여백이 조정됩니다. 간단히 보기는 더 작은 창과 compact spacing을 사용하고, 자세히 보기는 더 큰 창과 상세 정보에 맞는 여백을 사용합니다.
- 자동 새로고침: 켜거나 끌 수 있으며, `1분` 또는 `5분` 간격을 선택할 수 있습니다.
- 다음 새로고침 표시: 하단 오른쪽에 `N초 후 새로고침` 형태로 다음 자동 새로고침까지 남은 시간이 표시됩니다. 수동 새로고침 후에도 다음 예정 시간이 다시 계산됩니다.
- 항상 위: 켜면 앱 창을 일반 창보다 위에 유지하고, 헤더에 pin badge를 표시합니다.
- 사용자 설정 저장: 보기 모드, 자동 새로고침 켜짐/꺼짐, 새로고침 간격, 항상 위 상태는 앱 재실행 후에도 유지됩니다.

## 메뉴바

앱은 메뉴바 항목을 제공합니다.

- Codex 남은 비율이 있으면 메뉴바에 표시합니다.
- 메뉴에서 창 열기, 새로고침, 종료를 실행할 수 있습니다.

## 요구사항

- macOS 14 이상
- Swift 6 toolchain 또는 Xcode Command Line Tools
- Codex 세션 로그: `~/.codex/sessions`
- Claude Code 프로젝트 로그: `~/.claude/projects`

## 실행

```sh
make run
```

## macOS 앱 번들 생성

```sh
make app
open .build/release/TokenScope.app
```

## 테스트

```sh
make test
```

현재 Command Line Tools-only 환경에서는 `make test`가 compile check로 동작합니다. XCTest 기반 테스트가 필요하면 Xcode test target을 추가할 수 있습니다.

## 아키텍처

프로젝트는 작은 hexagonal architecture로 구성되어 있습니다.

- `CodexUsageCore/Domain`: usage snapshot과 dashboard state
- `CodexUsageCore/Ports`: `CodexUsageReading`, `ClaudeUsageReading`, `DateProviding`
- `CodexUsageCore/UseCases`: 앱 동작. 현재 `LoadUsageDashboardUseCase`
- `CodexUsageCore/Adapters/LocalLogs`: 로컬 Codex/Claude JSONL 로그를 읽는 outbound adapter
- `TokenScope`: inbound adapter. SwiftUI/AppKit UI, 메뉴바 통합, timer, formatting

SwiftUI 앱은 로그 파일을 직접 파싱하지 않습니다. UI는 use case를 호출하고, use case는 concrete file reader가 아니라 port에 의존합니다. 로컬 JSONL reader는 교체 가능한 outbound adapter입니다.

## 검증 명령

변경 후 다음 명령으로 앱을 검증합니다.

```sh
make test
make app
plutil -lint .build/release/TokenScope.app/Contents/Info.plist
open .build/release/TokenScope.app
```
