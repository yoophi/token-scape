# 구현 프롬프트

Swift로 macOS 데스크탑 앱을 구현하세요. 이 앱은 로컬 로그를 읽어 Claude Code와 Codex의 AI 코딩 어시스턴트 사용량을 나란히 표시해야 합니다.

## 핵심 목표

Swift/AppKit/SwiftUI 기반 macOS 데스크탑 앱을 만듭니다. 앱은 다음 두 제품의 사용량과 남은 사용 정보를 표시합니다.

- Claude Code: `~/.claude/projects/**/*.jsonl` 로컬 로그 기반
- Codex: `~/.codex/sessions/**/*.jsonl` 로컬 세션 로그 기반

앱은 일반 macOS `.app` 번들로 실행 가능해야 하며, 메뉴바 항목도 제공해야 합니다.

## 데이터 요구사항

### Codex

다음 경로 아래의 Codex 세션 JSONL 파일에서 최신 `rate_limits` 이벤트를 읽습니다.

```text
~/.codex/sessions/**/*.jsonl
```

표시해야 할 항목:

- 짧은 기간 사용량. 일반적으로 5시간 창
- 주간 또는 긴 기간 사용량
- 남은 비율
- 사용 비율
- 리셋까지 남은 시간과 리셋 시각
- 플랜 타입. 사용 가능할 경우 표시
- `token_count` payload의 토큰 breakdown
  - input tokens
  - cached input tokens
  - output tokens
  - reasoning output tokens
  - total tokens
  - 최근 응답 token total. 사용 가능할 경우 표시

### Claude Code

다음 경로 아래의 Claude Code JSONL 로그를 읽습니다.

```text
~/.claude/projects/**/*.jsonl
```

assistant 메시지의 usage 필드를 파싱하고 다음 값을 집계합니다.

- input tokens
- output tokens
- cache creation/write tokens
- cache read tokens
- total tokens
- message count

활성 사용량 블록을 계산합니다.

- 5시간 블록
- 7일 주간 블록

블록 계산은 `ccusage`와 유사한 방식으로 처리합니다. 엔트리를 timestamp 기준으로 정렬하고, 첫 엔트리 시각에서 고정 길이 블록을 시작합니다. 기존 블록 경계를 넘는 첫 엔트리는 다음 블록의 시작점이 됩니다.

## UI 요구사항

### 좌우 레이아웃

메인 창은 세로 컬럼 2개를 좌우로 나눠 표시합니다.

- 왼쪽: Claude Code usage
- 오른쪽: Codex usage

두 컬럼은 가능한 한 동일한 시각적 포맷을 사용해야 합니다.

### 공통 표시 포맷

Claude Code와 Codex 사이에서 공통으로 표시할 수 있는 정보를 식별하고 같은 위치에 표시합니다.

- 짧은 창
- 주간 창
- 남은 시간
- 남은 비율
- 진행률 막대
- 리셋 시각과 리셋까지 남은 시간
- 토큰 요약
- 자세히 보기에서 source path와 metadata

서비스별 하이라이트 색상을 사용합니다.

- Claude Code는 Claude 계열의 따뜻한 오렌지 하이라이트 색상을 사용합니다.
- Codex는 OpenAI/Codex 계열의 녹색 하이라이트 색상을 사용합니다.
- 제품명, 아이콘, 배지, 서비스 성격을 나타내는 progress/highlight 요소에는 해당 서비스 색상을 적용합니다.
- 경고 또는 위험 상태를 나타내는 색상은 서비스 색상보다 의미 기반 색상 사용을 우선할 수 있습니다.

남은 시간 포맷은 창 종류에 따라 통일합니다.

- 5시간 창 남은 시간은 항상 `HH:MM:SS` 형식으로 표시합니다.
- 주간 창 남은 시간은 `6d HH:MM:SS`처럼 일수와 `HH:MM:SS`를 함께 표시합니다.

서로 의미가 다른 데이터를 같은 시각적 위치에 넣지 마세요. 특히 다음 위치는 반드시 통일합니다.

- 각 window card의 오른쪽 상단 첫 번째 metric은 항상 `남은 시간`이어야 합니다.
- 각 window card의 오른쪽 상단 두 번째 metric은 항상 `남은 비율`이어야 합니다.
- Codex의 남은 비율은 Codex가 제공하는 rate limit 값을 기준으로 계산합니다.
- Claude의 남은 비율은 활성 usage block의 시간 기준 남은 비율로 계산합니다.

### 보기 모드

두 가지 보기 모드를 제공합니다.

- `간단히 보기`: 기본 모드입니다. 공통 필드를 중심으로 compact summary를 표시합니다.
- `자세히 보기`: 상세 row, token breakdown, source path, metadata를 추가로 표시합니다.

### 창 크기

기본 창 크기는 화면에 표시되는 전체 내용을 충분히 담을 수 있어야 합니다.

보기 모드별로 적절한 창 크기를 사용합니다.

- `간단히 보기`는 compact summary만 표시하므로 자세히 보기보다 더 작은 기본 창 크기를 사용합니다.
- `자세히 보기`는 상세 row와 token breakdown을 표시하므로 더 큰 창 크기를 사용합니다.
- 보기 모드를 전환하면 창 크기와 최소 창 크기도 해당 모드에 맞게 조정합니다.
- 작은 화면에서도 전체 내용을 확인할 수 있도록 스크롤을 제공합니다.
- `간단히 보기`에서 일부 정보가 가려지지 않도록 기본 창 높이와 최소 창 크기를 충분히 확보합니다.
- 사용자가 창을 세로로 크기 조정할 수 있어야 합니다.
- SwiftUI 루트 뷰는 고정 폭/고정 높이에 갇히지 않고 최소 크기를 기준으로 창 크기 확장을 허용해야 합니다.
- 사용자가 조정한 창 크기는 저장하고, 앱을 다시 실행했을 때 복원합니다.
- 창 크기 저장은 `간단히 보기`와 `자세히 보기`를 구분하여 보기 모드별로 유지합니다.

### 자동 새로고침

자동 새로고침 옵션을 제공합니다.

- 자동 새로고침은 별도 체크박스가 아니라 `1분` / `5분` / `안함` 세그먼트 컨트롤 하나로 조작합니다.
- `안함`을 선택하면 자동 새로고침을 끕니다.
- 자동 새로고침이 켜져 있을 때 다음 간격을 지원합니다.
  - 1분
  - 5분
- 현재 자동 새로고침 상태를 UI에 표시합니다.
- 상단 컨트롤에서는 자동 새로고침 아이콘과 `자동 새로고침` 텍스트 옆에 `1분` / `5분` / `안함` 버튼을 배치합니다.
- 하단 오른쪽에는 고정 설명 문구가 아니라 다음 자동 새로고침까지 남은 시간을 표시합니다. 예: `자동 새로고침 1분 · 57초 후 새로고침`
- 자동 새로고침이 꺼져 있으면 `자동 새로고침 꺼짐`처럼 명확히 표시합니다.
- 1초 단위 tick은 로그 새로고침과 독립적으로 유지하되, 이 tick을 이용해 다음 새로고침까지 남은 초를 갱신합니다.

### 항상 위

`항상 위` 옵션을 제공합니다.

- 켜져 있을 때 macOS window level을 조정하여 일반 창보다 위에 표시되게 합니다.
- 꺼져 있을 때 일반 window level로 되돌립니다.
- 항상 위 상태가 켜져 있으면 pin badge 또는 동등한 시각적 indicator를 표시합니다.
- 상단 컨트롤의 `항상 위` 조작은 체크박스가 아니라 pin 아이콘 토글 버튼으로 제공합니다.
- 항상 위 토글 버튼은 켜져 있을 때 채워진 pin 아이콘과 강조 색상으로 상태를 표시합니다.

### 상단 컨트롤 배치

상단 우측에 주요 컨트롤을 한 줄로 배치합니다.

- 보기 모드: `간단히` / `자세히`
- 자동 새로고침: 아이콘과 `자동 새로고침` 텍스트, 그리고 `1분` / `5분` / `안함` 세그먼트 버튼
- 새로고침: 아이콘 버튼
- 항상 위: pin 아이콘 토글 버튼

컨트롤 순서는 다음과 같이 유지합니다.

```text
간단히/자세히 | 자동 새로고침 아이콘 + 1분/5분/안함 | 새로고침 버튼 | 항상 위 토글 버튼
```

### 사용자 설정 저장

앱을 종료했다가 다시 실행해도 사용자가 선택한 UI 설정이 유지되어야 합니다.

저장해야 할 설정:

- `간단히 보기` / `자세히 보기`
- 자동 새로고침 켜짐 / 꺼짐
- 자동 새로고침 간격: 1분 / 5분
- 항상 위 켜짐 / 꺼짐
- 보기 모드별 창 크기

설정 저장은 macOS 앱에 적합한 방식으로 처리합니다. 예를 들어 `UserDefaults`를 사용할 수 있습니다.

### 메뉴바

메뉴바 항목을 제공합니다.

- 가능한 경우 Codex 남은 비율을 메뉴바에 표시합니다.
- 메뉴 액션을 제공합니다.
  - 창 열기
  - 새로고침
  - 종료

## 아키텍처 요구사항

작은 규모의 hexagonal architecture를 사용합니다.

### Core 모듈

Core 로직은 다음 구조로 구성합니다.

- `Domain`: usage snapshot과 dashboard state
- `Ports`: 프로토콜
  - `CodexUsageReading`
  - `ClaudeUsageReading`
  - `DateProviding`
- `UseCases`: 앱 동작. 특히 combined dashboard를 로드하는 use case
- `Adapters/LocalLogs`: 로컬 Codex/Claude JSONL 파일을 읽는 outbound adapter

use case는 concrete file reader에 직접 의존하지 않고 port에 의존해야 합니다.

### Viewer 모듈

SwiftUI/AppKit 앱은 inbound adapter로 취급합니다.

- `UsageStore`: observable state, timer, refresh 설정, always-on-top 설정
- `UsageLoader`: use case 호출
- `ContentView`: 메인 레이아웃과 컨트롤
- 재사용 가능한 카드 컴포넌트: usage window, metadata, error, token chip
- 날짜, duration, percentage, token count를 위한 공통 formatting helper
- 사용자 UI 설정 저장소. 예: `UserPreferencesStore`

SwiftUI view는 로그 파일을 직접 파싱하면 안 됩니다.

## 엔지니어링 요구사항

- Swift Package Manager를 사용합니다.
- `Makefile`을 제공합니다. 최소한 다음 명령을 포함해야 합니다.
  - `make run`
  - `make test`
  - `make app`
  - `make clean`
- `make app`은 `.build/release/TokenScope.app` 위치에 `.app` 번들을 생성해야 합니다.
- build artifact를 제외하기 위한 `.gitignore`를 추가합니다.
- 코드는 읽기 쉽고 유지보수하기 쉬워야 합니다.
- 하나의 큰 `main.swift`에 모든 코드를 몰아넣지 말고, 책임별로 파일을 분리합니다.
- Swift 6 command line tools에서 컴파일되어야 합니다.
- Command Line Tools-only 환경에서 XCTest를 사용할 수 없다면, `make test`는 compile check로 동작해도 됩니다.

## 검증

구현 또는 리팩토링 후 다음 명령을 실행합니다.

```sh
make test
make app
plutil -lint .build/release/TokenScope.app/Contents/Info.plist
open .build/release/TokenScope.app
```

다음을 확인합니다.

- Claude Code가 왼쪽에 표시됩니다.
- Codex가 오른쪽에 표시됩니다.
- 양쪽 제품의 카드에서 `남은 시간`과 `남은 비율`이 같은 위치에 표시됩니다.
- 기본 화면은 `간단히 보기`입니다.
- `자세히 보기`를 선택할 수 있습니다.
- 자동 새로고침을 켜거나 끌 수 있고, 1분/5분 간격을 선택할 수 있습니다.
- 자동 새로고침 상단 UI는 체크박스 없이 `1분` / `5분` / `안함` 세그먼트로 동작합니다.
- 하단 오른쪽에 다음 자동 새로고침까지 남은 초가 표시되고 매초 갱신됩니다.
- 항상 위 모드는 window level을 변경하며, 활성 상태를 시각적으로 표시합니다.
- 항상 위 조작은 체크박스가 아니라 pin 아이콘 토글 버튼으로 동작합니다.
- 간단히 보기에서도 주요 정보가 가려지지 않습니다.
- 창은 세로 크기 조정이 가능하고, 조정한 창 크기는 보기 모드별로 저장됩니다.
- 앱을 종료 후 다시 실행해도 보기 모드, 자동 새로고침 설정, 새로고침 간격, 항상 위 설정, 창 크기가 유지됩니다.
