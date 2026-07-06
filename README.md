# Paper

SwiftUI와 AppKit으로 만든 네이티브 macOS 일반 텍스트 편집기입니다. 빠르고
집중하기 쉬운 사용감을 목표로 하며, 사이드바, 창 안 탭, 줄 번호가 있는 편집기,
상태 표시줄, 찾기/바꾸기, `Command-K` 명령 팔레트, `Command-P` 빠른 열기,
여러 테마와 사용자 지정 강조색을 제공합니다.

## 요구 사항

- macOS 14 이상
- 전체 Xcode 또는 Command Line Tools
  - Swift Package Manager로 터미널에서 빌드할 수 있으므로 Xcode IDE가 꼭 필요하지는 않습니다.

## 빌드 및 실행

```bash
./build.sh release run     # 릴리즈 빌드, Paper.app 생성, 코드 서명, 실행
./build.sh release         # 실행 없이 릴리즈 앱 번들만 생성
./build.sh debug           # 빠른 디버그 빌드
```

앱 번들은 `build/Paper.app`에 생성됩니다.

```bash
open build/Paper.app
```

Xcode가 설치되어 있다면 다음 명령으로 프로젝트를 열 수 있습니다.

```bash
open Package.swift
```

### 엔진 셀프 테스트

UI 없이 핵심 엔진 동작을 검증할 수 있습니다. 인코딩 감지, EUC-KR 왕복 변환,
줄 끝 처리, 줄 인덱싱, 퍼지 매칭을 확인합니다.

```bash
swift build -c release && ./.build/release/Paper --selftest
```

### 미리보기 렌더링

개발 중에는 각 화면과 테마를 PNG로 오프스크린 렌더링할 수 있습니다.

```bash
./.build/release/Paper --render <dir>
```

이 기능은 `ImageRenderer`와 AppKit 편집기의 `cacheDisplay`를 사용하며,
디스플레이 없이 UI 상태를 확인하는 데 사용합니다. 구현은
`Sources/Paper/Support/RenderHarness.swift`에 있습니다.

## 주요 기능

- **일반 텍스트 전용:** 리치 텍스트, 스마트 따옴표/대시, 텍스트 자동 치환을 비활성화해 입력한 내용이 그대로 저장됩니다.
- **네이티브 편집 성능:** SwiftUI 안에서 AppKit `NSTextView`(TextKit 1)를 사용하고, `NSRulerView` 기반 줄 번호 거터를 제공합니다.
- **탭 편집:** 각 탭은 독립적인 편집기를 유지해 실행 취소 기록, 스크롤 위치, 선택 영역을 보존합니다.
- **사이드바:** 접을 수 있는 사이드바에서 검색, 최근 파일, 폴더 바로가기를 확인할 수 있습니다.
- **찾기/바꾸기:** 일치 개수, 대소문자 구분, 정규식을 지원합니다.
- **명령 팔레트와 빠른 열기:** `Command-K` 명령 팔레트와 `Command-P` 빠른 열기는 퍼지 검색과 키보드 조작을 지원합니다.
- **테마:** 웜 페이퍼, 쿨 시스템, 다크 그레파이트, 시스템 자동 테마를 제공합니다.
- **사용자 지정 강조색:** 스와치 또는 색상 선택기로 강조색을 바꾸면 커서, 선택 영역, 활성 탭, 하이라이트에 반영됩니다.
- **인코딩 및 줄 끝:** UTF-8/BOM, UTF-16, EUC-KR을 자동 감지하고, 문서별 인코딩과 LF/CRLF/CR 줄 끝을 상태 표시줄에서 바꿀 수 있습니다.
- **자동 저장:** 설정한 간격에 따라 문서를 자동 저장합니다.

## 키보드 단축키

| 동작 | 단축키 | 동작 | 단축키 |
|---|---|---|---|
| 새 문서 | `Command-N` | 명령 팔레트 | `Command-K` |
| 열기 | `Command-O` | 빠른 열기 | `Command-P` |
| 저장 | `Command-S` | 파일 안에서 찾기 | `Command-F` |
| 다른 이름으로 저장 | `Shift-Command-S` | 사이드바 토글 | `Control-Command-S` |
| 모든 탭 저장 | `Option-Command-S` | 다음/이전 탭 | `Shift-Command-]` / `Shift-Command-[` |
| 탭 닫기 | `Command-W` | 설정 | `Command-,` |

## 프로젝트 구조

```text
Sources/Paper/
├── PaperApp.swift          @main 진입점, 메뉴 명령, Settings scene
├── Model/                  TextDocument, TextEncoding, LineEnding, AppState, RecentFile
├── Theme/                  PaperColor, Theme (3개 프리셋과 사용자 지정 강조색)
├── Settings/               AppSettings (영구 저장), SettingsView
├── Editor/                 EditorController, PaperTextView, LineNumberRulerView,
│                           LineIndex, PaperEditor (NSViewRepresentable)
├── Views/                  ContentView, TopBar, SidebarView, StatusBarView,
│                           FindBarView, CommandPaletteView, QuickOpenView, ViewSupport
└── Support/                AppearanceObserver, PaperUtil, SelfTest
```

## 배포

개발 초기 배포는 GitHub Releases의 DMG 파일로 제공합니다. 현재 알파 빌드는
ad-hoc 서명만 되어 있고 notarization은 적용되어 있지 않으므로, macOS Gatekeeper
경고가 표시될 수 있습니다.

릴리즈용 DMG에는 `Paper.app`과 `/Applications` 바로가기가 들어갑니다.

## 참고

- 앱 아이콘은 `Packaging/AppIcon.icns`를 사용하며, `build.sh`가 앱 번들에 포함합니다.
- 최근 파일과 폴더 목록은 실제 사용자 데이터로 저장됩니다.
- 첫 실행 시에는 최근 항목이 비어 있고, 초기 문서는 샘플 텍스트가 들어간 새 문서로 시작합니다.
