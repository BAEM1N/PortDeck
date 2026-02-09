# PortDeck

[한국어 문서 보기](README.ko.md)

PortDeck is a small macOS menu bar app I built to make local port cleanup less annoying.
When a dev server is stuck on a port, you can find it quickly and stop it without jumping back to Terminal every time.

## What You Can Do

- See active TCP `LISTEN` ports in real time
- Check details for each process:
  - PID
  - process name
  - full command
  - current working directory
  - owner
- Stop by PID (tries `SIGTERM`, then `SIGKILL` only if needed)
- Stop directly by port number (for example `8000`)
- Hide system ports (`1-1023`) by default
- Filter by common port ranges (`1-1023`, `1024-49151`, `49152-65535`)
- Monitor CPU, memory, and disk usage in the same panel
- Hover or click CPU/Memory/Disk cards to view Top N heavy users
- Follow macOS light/dark mode automatically

## What's New in v0.0.2

- Added Top N insight panel from system metric cards
- Supports both hover and click interactions on CPU/Memory/Disk cards
- Added process-based Top N for CPU and memory
- Added home-directory-based Top N for disk usage
- Updated docs for new interaction model

## Search Syntax

The search box supports simple mixed queries:

- Single port: `8000`
- Port range: `3000:3999`
- Multiple conditions (OR): `8000,8080`
- Mixed query: `3000:3999,uvicorn`

## Run Locally

```bash
swift build
swift run
```

After launch, open `PortDeck` from the menu bar.

## Build an App Bundle

```bash
./scripts/package_app.sh
```

Output:

- `dist/PortDeck.app`

## Enable Auto-Start on Login

```bash
./scripts/install_launch_agent.sh
```

This installs:

- app: `~/Applications/PortDeck.app`
- launch agent: `~/Library/LaunchAgents/com.baem1n.portdeck.plist`

## Deploy in One Command

```bash
./scripts/deploy.sh
```

## Notes on Menu Bar Label

`PortDeck` is configured as a text label in the menu bar.
On macOS, labels can still collapse when menu bar space is tight. This is expected behavior.

## Troubleshooting

- No ports shown:
  - Click refresh and make sure your process is actually in `LISTEN` state.
- Kill failed:
  - Check owner/permissions for that process.
- LaunchAgent logs:
  - `/tmp/com.baem1n.portdeck.out.log`
  - `/tmp/com.baem1n.portdeck.err.log`

## Project Layout

```text
Sources/PortDeck/
  AppBrand.swift
  ContentView.swift
  SystemInsights.swift
  PortManager.swift
  PortDeckApp.swift
  SystemMonitor.swift
scripts/
  package_app.sh
  install_launch_agent.sh
  deploy.sh
```
