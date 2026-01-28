# OneTap

**IDE-less iOS development. One tap to build, install, and run.**

OneTap is a CLI for iOS simulator development with session-based ownership, enabling parallel Claude Code workflows without simulator conflicts.

## Installation

### From Source

```bash
git clone https://github.com/geneyoo/onetap.git
cd onetap
swift build -c release
cp .build/release/tap /usr/local/bin/
```

### Homebrew (coming soon)

```bash
brew install geneyoo/tap/onetap
```

## Quick Start

```bash
# Claim a simulator for your terminal session
tap claim --auto --name "feature-x"

# Build, install, and run your app
tap run --scheme MyApp

# Check your claim status
tap status

# Release when done
tap release
```

## Commands

| Command | Description |
|---------|-------------|
| `tap claim` | Claim a simulator for this terminal session |
| `tap release` | Release claimed simulator |
| `tap status` | Show all active claims |
| `tap run` | Build, install, launch (the main command) |
| `tap build` | Build only |
| `tap install` | Install .app to claimed sim |
| `tap launch` | Launch app by bundle ID |
| `tap logs` | Stream simulator logs (filtered by app) |
| `tap screenshot` | Capture screenshot |
| `tap gc` | Garbage collect stale claims |

## Session Management

OneTap uses TTY-based claims to give each terminal session exclusive ownership of a simulator. This enables multiple Claude Code instances to work in parallel without conflicts.

```bash
# Terminal 1
tap claim --name "auth-feature"
tap run --scheme MyApp

# Terminal 2 (different simulator automatically)
tap claim --name "ui-tests"
tap run --scheme MyAppUITests
```

### Environment Variable Override

For scripts and automation (where TTY isn't available), use the `ONETAP_SESSION` environment variable:

```bash
export ONETAP_SESSION="my-session"
tap claim --auto
tap run --scheme MyApp
tap release
```

### Minimum Runtime Requirement

When your project requires a specific iOS version:

```bash
# Claim a simulator with iOS 26.2 or later
tap claim --auto --min-runtime 26.2

# Formats accepted: "26.2", "iOS 26.2", "iOS-26-2"
```

### Stale Claim Detection

If a terminal closes without releasing its claim, OneTap detects the dead process:

```bash
tap status
# Shows 🔴 for stale claims

tap gc
# Removes all stale claims
```

## Examples

### Full Workflow

```bash
# Start a session
tap claim --auto --boot --name "dev"

# Iterate on code
tap run --scheme MyApp

# Check logs
tap logs

# Take screenshots for documentation
tap screenshot ./screenshot.png

# Clean up
tap release --shutdown
```

### CI/CD Usage

```bash
# Non-interactive mode for automation
export ONETAP_SESSION="ci-$CI_JOB_ID"
tap claim --auto --name "ci-$CI_JOB_ID" --min-runtime 26.0
tap run --scheme MyApp --configuration Release
tap screenshot ./artifacts/screenshot.png
tap release
```

### Claude Code Integration

Add to your shell profile or Claude Code hooks:

```bash
# Auto-claim for Claude sessions
export ONETAP_SESSION="claude-$(date +%H%M)"
```

Or create a custom `/run` skill that wraps `tap run`.

## Build System Support

- **Xcode Workspace** (`.xcworkspace`) - Preferred for CocoaPods/SPM projects
- **Xcode Project** (`.xcodeproj`) - Standard Xcode projects
- **Swift Package Manager** - Detects `Package.swift` (iOS app support limited)

OneTap auto-detects your project type. Use `--project` to specify explicitly:

```bash
tap run --project MyApp.xcworkspace --scheme MyApp
```

## Command Reference

### `tap claim`

```
USAGE: tap claim [--name <name>] [--udid <udid>] [--auto] [--boot] [--min-runtime <version>]

OPTIONS:
  -n, --name <name>       Name for this session (e.g., 'auth-feature')
  --udid <udid>           Specific simulator UDID to claim
  --auto                  Auto-select an available simulator (non-interactive)
  --boot                  Boot the simulator if not already running
  --min-runtime <version> Minimum iOS version (e.g., '26.2')
```

### `tap run`

```
USAGE: tap run [--scheme <scheme>] [--configuration <config>] [--project <path>] [--restart/--no-restart] [--show]

OPTIONS:
  -s, --scheme <scheme>   Scheme to build
  -c, --configuration     Build configuration (Debug/Release, default: Debug)
  --project <path>        Path to project or workspace
  --restart/--no-restart  Terminate existing app before launching (default: --restart)
  --show                  Open Simulator.app and bring to front
```

### `tap logs`

```
USAGE: tap logs [--bundle-id <id>] [--all]

OPTIONS:
  -b, --bundle-id <id>    Bundle ID to filter logs (uses last installed if omitted)
  -a, --all               Show all logs (don't filter by app)
```

## State Storage

OneTap stores state in `~/.onetap/`:

```
~/.onetap/
├── state.json    # Active claims
└── state.lock    # File lock for concurrent access
```

## Requirements

- macOS 13+
- Xcode 15+ (for simulator tools)
- Swift 5.9+

## Troubleshooting

### "No simulator claimed for this session"

Each terminal needs to claim a simulator before running commands. Use `tap claim --auto` to claim one.

### "Unable to find a destination matching the provided destination specifier"

Your project requires a newer iOS version than the claimed simulator. Use `--min-runtime`:

```bash
tap release
tap claim --auto --min-runtime 26.2
```

### Simulator not booting

Make sure Xcode is installed and the simulator runtime is available:

```bash
xcrun simctl list devices available
```

## License

MIT
