# Contributing to Walkable

Thanks for your interest in contributing!

## Setup

1. Clone the repo
2. Install XcodeGen: `brew install xcodegen`
3. Generate Xcode project: `make generate`
4. Open: `make open`

## Development

- All changes go through PRs against `main`
- Branch naming: `feat/`, `fix/`, `chore/`, `docs/`
- Commits: title only, no body. Follow existing style (`git log --oneline -10`)
- Run tests before pushing: `make test`

## Architecture

- **WalkableKit** — Shared Swift package (models, services, formatters)
- **WalkableApp** — iOS app (views, view models)
- **WalkableWatch** — watchOS app
- **WalkableWidgets** — Dynamic Island + Lock Screen

## Testing

```bash
make test        # Unit tests (48)
make test-ui     # UI tests (17)
make test-all    # Everything
make maestro     # Visual Maestro tests
```

## Code Style

- SwiftUI + MVVM
- Liquid glass (`.glassEffect`) for floating controls
- SF Symbols for icons
- Shared formatters in `WalkableKit/Extensions/FormatUtils.swift`
- Haptics: light (tap), medium (action), heavy (destructive), success (complete)
