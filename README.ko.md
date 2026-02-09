# PortDeck

[English README](README.md)

PortDeck은 macOS 메뉴바에서 현재 TCP LISTEN 포트를 확인하고, 해당 포트를 점유한 프로세스를 종료할 수 있는 개발자용 유틸리티입니다.

## AI 친화 요약

- 프로젝트 유형: macOS 메뉴바 앱 (SwiftUI)
- 주요 목적: 로컬 개발 서버 포트 확인/종료 (예: FastAPI `8000`)
- 핵심 기능: 포트 조회, 프로세스 종료, CPU/RAM/디스크 모니터링
- 기술 스택: Swift 6, SwiftUI, `lsof`, `ps`, `kill`, `launchctl`
- 실행 환경: macOS 13+

## 키워드

`macOS` `메뉴바 앱` `포트 모니터` `TCP LISTEN` `프로세스 종료` `SwiftUI` `FastAPI` `uvicorn` `LaunchAgent`

## 기능

- LISTEN 상태 TCP 포트 목록 조회 (`lsof` 기반)
- 포트별 프로세스 정보 표시:
  - PID
  - 프로세스 이름
  - 명령어 전체
  - 작업 디렉터리(cwd)
  - 소유 사용자
- 시스템 포트(`1-1023`) 기본 숨김
- 포트 대역별 구분/필터:
  - `1-1023` (시스템)
  - `1024-49151` (일반/등록)
  - `49152-65535` (동적)
- 고급 검색 문법:
  - 단일 포트: `8000`
  - 구간 검색: `3000:3999`
  - 다중 조건(OR): `8000,8080`, `3000:3999,uvicorn`
- PID 즉시 종료 (`SIGTERM`, 실패 시 `SIGKILL`)
- 포트 번호 직접 입력 종료
- 실시간 시스템 지표:
  - CPU 사용률
  - 메모리 사용량
  - 디스크 사용량
- macOS 다크/라이트 모드 자동 대응

## 메뉴바 이름 표시 안내

- 메뉴바 라벨은 텍스트 `PortDeck`으로 설정되어 있습니다.
- macOS 특성상 메뉴바 공간이 부족하면 텍스트가 축약/숨김될 수 있습니다.
- 텍스트가 안 보여도 앱 동작은 정상입니다.

## 프로젝트 구조

```text
Sources/PortDeck/
  AppBrand.swift
  ContentView.swift
  PortManager.swift
  PortDeckApp.swift
  SystemMonitor.swift
scripts/
  package_app.sh
  install_launch_agent.sh
  deploy.sh
```

## 빠른 시작

### 1) 빌드 및 실행

```bash
swift build
swift run
```

메뉴바에서 `PortDeck`을 열어 사용합니다.

### 2) `.app` 패키징

```bash
./scripts/package_app.sh
```

생성 결과:

- `dist/PortDeck.app`

### 3) 로그인 자동 실행(LaunchAgent)

```bash
./scripts/install_launch_agent.sh
```

동작:

- `~/Applications/PortDeck.app`으로 앱 복사
- `~/Library/LaunchAgents/com.baem1n.portdeck.plist` 등록
- 현재 세션 즉시 실행
- 다음 로그인부터 자동 실행

### 4) 한 번에 배포

```bash
./scripts/deploy.sh
```

## 포트 조회 방식

PortDeck은 아래 명령으로 LISTEN 포트를 수집합니다.

- `lsof -nP -iTCP -sTCP:LISTEN -FpcLun`

추가 정보 보강:

- 명령어: `ps -p <pid> -o command=`
- 작업 디렉터리: `lsof -a -p <pid> -d cwd -Fn`

## 안전/권한 안내

- 주로 개발자가 실행한 로컬 프로세스 제어를 목적으로 합니다.
- 시스템 프로세스는 권한 문제로 종료 실패할 수 있습니다.
- `SIGKILL`은 `SIGTERM` 실패 시에만 사용됩니다.

## 트러블슈팅

- 포트가 안 보이면 새로고침 후 프로세스가 `LISTEN` 상태인지 확인하세요.
- 종료가 실패하면 프로세스 소유자/권한을 확인하세요.
- LaunchAgent 로그:
  - `/tmp/com.baem1n.portdeck.out.log`
  - `/tmp/com.baem1n.portdeck.err.log`

## 라이선스

현재 라이선스 파일은 없습니다.
