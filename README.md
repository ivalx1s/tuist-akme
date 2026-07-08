# AcmeApp

Multi-platform (iOS/macOS) application template built on [Tuist](https://tuist.io)
with a modular architecture and the composition-root pattern.

## Quick start

```bash
# Clone and generate the project
git clone <repo-url>
cd tuist-akme
make
```

That is all. `make` will:
1. Install Homebrew (if missing)
2. Install Tuist (if missing)
3. Ask for a Team ID and Bundle Suffix (both skippable)
4. Fetch dependencies (`tuist install`)
5. Generate and open the Xcode workspace

## Project structure

```
├── Apps/                          # Host applications
│   ├── iOSApp/                    # iOS app
│   │   └── Extensions/            # App extensions (widgets, etc.)
│   └── macOSApp/                  # macOS app
├── Modules/                       # Modules
│   ├── CompositionRoots/          # Wiring points
│   ├── Features/                  # Features
│   ├── Core/                      # Infrastructure
│   ├── Shared/                    # Shared components
│   └── Utility/                   # Utilities
├── Tuist/                         # Project-specific Tuist helpers
├── TuistPlugins/ProjectInfraPlugin/  # Core DSL (ProjectFactory, Capability, etc.)
├── Scripts/                       # Python automation scripts
├── Docs/                          # Documentation (RFCs)
├── .env.shared                    # Repo-tracked config
└── .env                           # Local config (gitignored)
```

## Commands

| Command | What it does |
|---------|--------------|
| `make` | Generates the workspace (default) |
| `make bootstrap` | Full initialization from scratch |
| `make module layer=feature name=Auth` | Creates a new module |
| `make clean` | Cleans everything |
| `make check-graph` | Validates architecture rules |

## Modules

Every feature module consists of 4 targets:

| Target | Purpose |
|--------|---------|
| `AuthInterface` | Protocols and public types. **No external dependencies!** |
| `Auth` | Implementation |
| `AuthTesting` | Mocks and fakes for other modules' tests |
| `AuthTests` | Unit tests |

### Creating a module

```bash
make module layer=feature name=Payment
```

Creates `Modules/Features/Payment/` with this layout:
```
Payment/
├── Project.swift
├── Interface/
├── Sources/
├── Testing/
└── Tests/
```

### Dependencies between modules

```swift
// In the module's Project.swift
let project = ProjectFactory.makeFeature(
    module: .feature(.payment, scope: .common),
    dependencies: [
        .interface(.feature(.auth)),      // Depend on an interface
        .interface(.core(.networking)),   // Core modules allowed
        .external(dependency: .algorithms), // External (from the allow-list)
    ]
)
```

**Rules:**
- Interface targets must not have external dependencies
- An implementation may depend only on other modules' Interface targets
- External dependencies must be on the allow-list (`Tuist/ProjectDescriptionHelpers/ExternalDependency.swift`)

## Composition roots

The composition root is the only place allowed to link Impl targets directly:

```swift
// Modules/CompositionRoots/AppCompositionRoot/Project.swift
let project = ProjectFactory.makeCompositionRoot(
    module: .app,
    dependencies: [
        .module(.feature(.auth)),    // Links Auth + AuthInterface
        .module(.feature(.payment)),
        .module(.core(.networking)),
    ]
)
```

The application depends only on the composition root:

```swift
// Apps/iOSApp/Project.swift
let project = ProjectFactory.makeHostApp(
    projectName: projectName,
    bundleId: AppIdentifiers.iOSApp.bundleId,
    compositionRoot: .app,  // ← right here
    ...
)
```

## Configuration

### Repo-tracked (`.env.shared`)

```bash
WORKSPACE_NAME=AcmeApp
CORE_ROOT=com.acme.akmeapp           # Bundle ID root
SHARED_ROOT=com.acme.akmeapp.shared  # For cross-platform capabilities
IOS_APP_NAME=AcmeApp
IOS_MIN_VERSION=16.0
```

### Local (`.env`, gitignored)

```bash
DEVELOPMENT_TEAM_ID=XXXXXXXXXX       # Your Apple Team ID
BUNDLE_ID_SUFFIX=.ivan               # Avoids collisions with teammates
```

The bundle suffix is inserted after `com.acme`:
- Before: `com.acme.akmeapp.app.ios`
- After: `com.acme.ivan.akmeapp.app.ios`

This lets the wildcard App ID `com.acme.*` match every developer.

## Capabilities (entitlements)

A DSL for describing capabilities in manifests:

```swift
capabilities: [
    .appGroups(),                              // group.<bundleId>
    .keychainSharing(),                        // Defaults to the host bundle ID
    .iCloudCloudKitContainer(container: .shared), // iOS↔macOS sharing
    .healthKit([.backgroundDelivery]),
    .associatedDomains(["applinks:example.com"]),
]
```

Sharing levels:
- `.default`: derived from the host bundle ID (app + extensions)
- `.shared`: derived from `SHARED_ROOT` (iOS + macOS)
- `.custom(id:)`: an explicit identifier

## External dependencies

Adding a new dependency:

1. Add it to `Package.swift`:
```swift
dependencies: [
    .package(url: "https://github.com/...", from: "1.0.0"),
]
```

2. Add it to the allow-list (`Tuist/ProjectDescriptionHelpers/ExternalDependency.swift`):
```swift
public enum ExternalDependency: String, CaseIterable, Sendable, ExternalDependencyDescriptor {
    case myLib = "MyLib"

    public var allowedLayers: Set<ModuleLayer> {
        switch self {
        case .myLib: return [.feature, .core]  // Where it may be used
        }
    }
}
```

3. Regenerate: `make`

## Testing

```bash
# Run a module's tests
xcodebuild -workspace AcmeApp.xcworkspace \
  -scheme Auth \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  test
```

We use **Swift Testing** (not XCTest).

## Documentation

- `Docs/RFC-0001-Identifiers.md`: bundle ID and capability identifier specification
- `CLAUDE.md`: instructions for AI assistants

## Tools

| Tool | Purpose | Install |
|------|---------|---------|
| [Tuist](https://tuist.io) | Xcode project generation | `curl -Ls https://install.tuist.io \| bash` |
| Python 3 | Automation scripts | Built into macOS |

## The Relux stack

This template is part of the Relux stack: the
[Relux](https://github.com/relux-works/swift-relux) unidirectional data-flow
architecture for Swift 6, a family of modules around it, and agent-ready testing
tools. The stack is how we build MVPs fast on agentic rails and then scale them into
enterprise-grade apps: Tuist workspaces, strict modularization, and a UDF architecture
proven in production for years. Browse the full picture in the
[Relux Works open-source catalog](https://relux.works/en/open-source/).

<!-- relux-ecosystem:start -->

## About Relux Works

This project is part of the open-source ecosystem of
[Relux Works](https://relux.works), an AI-native software development studio.
We build fixed-price MVPs, rescue vibe-coded apps, run local AI inference, and
train teams to work with coding agents. Much of the infrastructure behind that
work is open source.

- Full catalog: [relux.works/en/open-source](https://relux.works/en/open-source/)
- Agentic enablement: [agent harnesses & team training](https://relux.works/en/agentic-enablement/)
- Hire us the agent-native way: point your assistant at `https://api.relux.works/mcp`
- Contact: ivan@relux.works

<!-- relux-ecosystem:end -->
