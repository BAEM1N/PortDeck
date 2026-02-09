# PortDeck

[English README](README.md)

PortDeck은 "포트 누가 잡고 있는지 확인하고 바로 내리는" 데 초점을 둔 macOS 메뉴바 앱입니다.
로컬 개발 중에 서버가 포트를 점유한 채 남아 있을 때, 터미널을 오가며 명령어 치는 과정을 줄여줍니다.

## 주요 기능

- 현재 TCP `LISTEN` 포트 실시간 조회
- 각 포트의 프로세스 정보 확인:
  - PID
  - 프로세스 이름
  - 전체 명령어
  - 작업 디렉터리(cwd)
  - 소유 사용자
- PID 기준 종료 (`SIGTERM` 우선, 실패 시에만 `SIGKILL`)
- 포트 번호로 바로 종료 (예: `8000`)
- 시스템 포트(`1-1023`) 기본 숨김
- 포트 대역별 필터 (`1-1023`, `1024-49151`, `49152-65535`)
- 같은 패널에서 CPU/메모리/디스크 사용량 확인
- macOS 라이트/다크 모드 자동 대응

## 검색 문법

검색창에서 아래 형태를 지원합니다.

- 단일 포트: `8000`
- 포트 구간: `3000:3999`
- 다중 조건(OR): `8000,8080`
- 혼합 검색: `3000:3999,uvicorn`

## 로컬 실행

```bash
swift build
swift run
```

실행 후 메뉴바에서 `PortDeck`을 열어 사용하면 됩니다.

## 앱 번들 생성

```bash
./scripts/package_app.sh
```

생성 결과:

- `dist/PortDeck.app`

## 로그인 자동 실행 설정

```bash
./scripts/install_launch_agent.sh
```

설치 항목:

- 앱: `~/Applications/PortDeck.app`
- LaunchAgent: `~/Library/LaunchAgents/com.baem1n.portdeck.plist`

## 한 번에 배포

```bash
./scripts/deploy.sh
```

## 메뉴바 이름 표시 관련

메뉴바 라벨은 텍스트 `PortDeck`으로 설정되어 있습니다.
다만 macOS는 메뉴바 공간이 부족하면 텍스트를 접거나 숨길 수 있습니다. 이 경우도 동작은 정상입니다.

## 트러블슈팅

- 포트가 안 보일 때:
  - 새로고침 후 대상 프로세스가 `LISTEN` 상태인지 확인
- 종료 실패 시:
  - 프로세스 소유자/권한 확인
- LaunchAgent 로그:
  - `/tmp/com.baem1n.portdeck.out.log`
  - `/tmp/com.baem1n.portdeck.err.log`

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
