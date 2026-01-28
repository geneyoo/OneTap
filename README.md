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
tap claim --auto --name "ci-$CI_JOB_ID"
tap run --scheme MyApp --configuration Release
tap screenshot ./artifacts/screenshot.png
tap release
```

### Claude Code Integration

Add to your project's `~/.claude/hooks/PreToolCall`:

```bash
#!/bin/bash
# Auto-claim simulator for Claude sessions
if [[ "$1" == "Bash" ]] && [[ "$2" == *"xcodebuild"* ]]; then
    tap claim --auto --name "claude-$$" 2>/dev/null || true
fi
```

## Build System Support

- **Xcode Workspace** (`.xcworkspace`) - Preferred for CocoaPods/SPM projects
- **Xcode Project** (`.xcodeproj`) - Standard Xcode projects
- **Swift Package Manager** - Detects `Package.swift` (iOS app support limited)

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

## License

MIT
