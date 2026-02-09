# PortDeck

[한국어 README](README.ko.md)

PortDeck is a macOS menu bar utility to inspect active TCP listening ports and stop the processes that own them.

## AI-Friendly Project Summary

- Project type: macOS menu bar app (SwiftUI)
- Main use case: find and stop local dev servers by port (for example FastAPI on `8000`)
- Core features: port inspection, process termination, CPU/RAM/disk monitoring
- Stack: Swift 6, SwiftUI, `lsof`, `ps`, `kill`, `launchctl`
- Platform: macOS 13+

## Keywords

`macOS` `menu bar app` `port monitor` `TCP LISTEN` `process killer` `SwiftUI` `FastAPI` `uvicorn` `LaunchAgent`

## Features

- List active TCP listening ports (`lsof` based)
- Show process details per port:
  - PID
  - process name
  - command line
  - current working directory
  - owner/user
- Hide system ports by default (`1-1023`)
- Group and filter by port ranges:
  - `1-1023` (system)
  - `1024-49151` (registered/user)
  - `49152-65535` (dynamic/ephemeral)
- Advanced search syntax:
  - single port: `8000`
  - range: `3000:3999`
  - multi query (OR): `8000,8080` or `3000:3999,uvicorn`
- One-click PID stop (`SIGTERM`, fallback to `SIGKILL`)
- Stop by direct port input
- Live system metrics:
  - CPU usage
  - memory usage
  - disk usage
- Automatic light/dark mode theme adaptation

## Menu Bar Name Visibility

- The menu bar label is configured as text (`PortDeck`).
- On macOS, menu bar text can still collapse when there is not enough menu bar space.
- Even if text is collapsed, functionality is normal.

## Project Structure

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

## Quick Start

### 1) Build and run

```bash
swift build
swift run
```

Then open `PortDeck` from the menu bar.

### 2) Package as `.app`

```bash
./scripts/package_app.sh
```

Output:

- `dist/PortDeck.app`

### 3) Install auto-start (LaunchAgent)

```bash
./scripts/install_launch_agent.sh
```

This will:

- copy app to `~/Applications/PortDeck.app`
- install `~/Library/LaunchAgents/com.baem1n.portdeck.plist`
- start immediately in current session
- auto-start on next login

### 4) One-command deploy

```bash
./scripts/deploy.sh
```

## How Port Detection Works

PortDeck reads listeners from:

- `lsof -nP -iTCP -sTCP:LISTEN -FpcLun`

Then enriches data with:

- command line: `ps -p <pid> -o command=`
- working directory: `lsof -a -p <pid> -d cwd -Fn`

## Safety Notes

- Intended mainly for developer-owned local processes.
- System-owned processes may fail to terminate due to permissions.
- `SIGKILL` is used only when `SIGTERM` fails.

## Troubleshooting

- If no ports appear, click refresh and verify the process is in `LISTEN` state.
- If termination fails, check process ownership/permissions.
- LaunchAgent logs:
  - `/tmp/com.baem1n.portdeck.out.log`
  - `/tmp/com.baem1n.portdeck.err.log`

## License

No license file is configured yet.
