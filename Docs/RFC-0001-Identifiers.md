# RFC-0001: Identifier Nomenclature (Bundle IDs + Capability Identifiers)

- Status: **Draft**
- Date: **2026-01-21**

## Summary

This RFC defines a deterministic, cross-platform, reverse-DNS identifier scheme for:

- host applications (iOS, macOS, Android, Linux, Windows…)
- Apple app extensions (which must start with the host app bundle identifier)
- internal module targets (Interface/Impl/Testing/Tests)
- “capability identifiers” derived from bundle IDs (App Groups, iCloud containers, keychain access groups, etc.)

It introduces:

- a single repo-wide **core root** (the only stable base)
- an explicit **shared identifier root** for cross-platform sharing (opt-in)
- a portability **scope** segment for module IDs (`common|darwin|ios|macos|android|linux|windows`)
- strict **lowercase** normalization for all segments we control (with explicit Apple exceptions like `iCloud.` and `$(TeamIdentifierPrefix)`)

## Motivation

We need identifier conventions that:

1. Scale beyond Apple (Android/Linux/Windows).
2. Remain valid reverse-DNS identifiers.
3. Satisfy Apple constraints (app extensions must prefix-match the host bundle ID).
4. Encode module portability (fully portable vs Darwin-only vs platform-specific).
5. Make entitlement-derived identifiers predictable and shareable **when explicitly desired**.
6. Continue supporting a local-only “bundle ID suffix” to avoid signing collisions.

## Goals

- **Single source of truth** for base naming: one repo-wide `coreRoot`.
- **Deterministic derivation** for all identifiers from `coreRoot`.
- **Lowercase** identifiers for segments we control (portable across Apple/Android and future tooling).
- **Apple extension safety**: every extension bundle ID MUST start with the host app bundle ID.
- **Module portability encoding** via a dedicated scope segment.
- **Opt-in cross-platform sharing** of capability identifiers via a dedicated `sharedRoot`.
- **Local namespacing** via `TUIST_BUNDLE_ID_SUFFIX` remains supported.

## Non-goals

- Defining app display names / marketing names.
- Fully modeling all Apple portal constraints (membership requirements, approvals).
- Enforcing a particular Android packaging strategy beyond “valid reverse-DNS”.
- Solving runtime sharing behavior for keychain/iCloud (this RFC covers identifiers only).

## Terminology

- **Identifier**: a dot-separated reverse-DNS string (e.g. `com.acme.akmeapp.app.ios`).
- **Segment**: a single dot-separated component.
- **Bundle ID**: `CFBundleIdentifier` on Apple; `applicationId` on Android; conceptually similar elsewhere.
- **Capability identifier**: an identifier used by signing/entitlements (App Groups, iCloud containers, etc.).
- **coreRoot**: repo-wide base root for all identifiers.
- **sharedRoot**: repo-wide root used for capability identifiers shared across platforms (opt-in).
- **hostBundleId**: the bundle identifier of an app (iOS/macOS/etc).
- **scope**: portability classification for modules (`common|darwin|ios|macos|android|linux|windows`).
- **layer**: architecture layer (`core|feature|shared|utility|compositionroot|app`).
- **kind**: target kind (`interface|impl|testing|tests`).

## Platform constraints & precedence

When requirements conflict, we optimize for Apple platforms first (highest constraints), then Android, then Windows. Other platforms follow the same reverse-DNS style but typically impose fewer hard rules.

### Apple (iOS / iPadOS / macOS / watchOS / tvOS / visionOS)

Bundle IDs (`CFBundleIdentifier`):

- Uniquely identify an app throughout the system.
- Allowed characters: alphanumerics, hyphen (`-`), and period (`.`).
- Apple documents bundle IDs as case-insensitive, but in practice some tooling and deployment systems can behave as if they’re case-sensitive; we treat bundle IDs as case-sensitive for safety and enforce lowercase for the parts we control.
- The bundle ID in the app must match the bundle ID you enter in App Store Connect; after you upload a build to App Store Connect, you can’t change the bundle ID **or delete the associated explicit App ID** in your developer account.

Prefix-coupled targets:

- **App extensions**: if an app contains an app extension, the extension’s bundle identifier must be prefixed by the containing app’s bundle identifier.
- **watchOS companion apps**: for watchOS apps with a companion iOS app, the WatchKit app and WatchKit extension must share the iOS app’s bundle ID prefix, and use the suffix formats:
  - WatchKit app: `[Bundle ID].watchkitapp`
  - WatchKit extension: `[Bundle ID].watchkitextension`
- **App Clips**: the App Clip app identifier uses the full app’s app identifier as its prefix, followed by a string (Xcode defaults to `Clip`).

Related capability identifiers:

- **App Groups**: `group.<group name>` (on macOS, `<team identifier>.<group name>` is also supported for creating/using app groups without registering them).
- **iCloud containers**: container IDs begin with `iCloud.`; container identifier strings must not contain wildcard (`*`) characters.
- **Keychain access groups**: apps always have a private access group; enabling Keychain Sharing adds additional access groups (Xcode prefixes access groups with the team identifier / app identifier prefix).

### Android

- The `applicationId` must have at least two segments, each segment must start with a letter, and all characters must be alphanumeric or underscore (`[a-zA-Z0-9_]`).

### Windows (MSIX / AppxManifest Identity)

- The package identity `Name` is case-sensitive.
- Allowed characters: alphanumeric, period (`.`), dash (`-`).
- Length: 3–50 characters.
- Certain reserved device names (like `CON`, `PRN`, `AUX`, `NUL`, `COM1`… `LPT9`) are not allowed as the identity name.

## Canonical roots

### 1) Core root

The repository defines a single core root:

- `coreRoot = com.acme.akmeapp`

Rules:

- MUST be lowercase.
- SHOULD be stable over time.
- MUST be reverse-DNS (at least 3 segments recommended).

### 2) Shared identifier root (explicit / opt-in)

The repository defines a shared identifier root:

- `sharedRoot = com.acme.akmeapp.shared`

Rules:

- MUST be lowercase.
- MUST be derived from (or at least subordinate to) `coreRoot`.
- Used only when cross-platform sharing is explicitly required/desired.

## Segment rules (portability)

To maximize portability across Apple/Android tooling and future platforms:

- All bundle IDs and identifier segments we control MUST be lowercase.
- Do not force-lowercase Apple-required prefixes/macros (e.g. `iCloud.`, `$(TeamIdentifierPrefix)`, `$(AppIdentifierPrefix)`).
- Each segment SHOULD match: `^[a-z][a-z0-9]*$`
  - (letters first; digits allowed after the first character)
- Dots (`.`) separate segments; no empty segments allowed.
- Avoid underscores and hyphens in new identifiers.

### Normalization

When a human name must become an identifier segment (module folder names like `Auth`, `URLSession`):

- Normalize by:
  1. stripping non-alphanumeric characters
  2. lowercasing the result
  3. ensuring the first character is a letter (prefix with `x` if needed)

Examples:

- `Auth` → `auth`
- `URLSession` → `urlsession`

## Bundle ID formats

### Host applications

Host application bundle identifiers are derived from `coreRoot` using a reserved `.app` namespace:

- iOS: `com.acme.akmeapp.app.ios`
- macOS: `com.acme.akmeapp.app.macos`
- Android: `com.acme.akmeapp.app.android`
- Linux: `com.acme.akmeapp.app.linux`
- Windows: `com.acme.akmeapp.app.windows`

Notes:

- This is “Option A” (platform appended as a suffix under `.app`).
- Subplatforms can be appended later when needed (e.g. `...app.windows.uwp`) without changing the core scheme.

### Apple app extensions (appex)

Apple requires extension bundle IDs to share the prefix of the host app bundle ID.
To guarantee this, all extension IDs MUST be derived from the host bundle ID:

- `<hostBundleId>.appex.<type>[.<name>]`

Examples (iOS host `com.acme.akmeapp.app.ios`):

- Widget: `com.acme.akmeapp.app.ios.appex.widget`
- Share: `com.acme.akmeapp.app.ios.appex.share`
- Notification service: `com.acme.akmeapp.app.ios.appex.notifications.service`

Examples (macOS host `com.acme.akmeapp.app.macos`):

- Share: `com.acme.akmeapp.app.macos.appex.share`

Rules:

- `.appex` is reserved for app extensions.
- `<type>` and `<name>` MUST be lowercase segments.

### watchOS companion targets (WatchKit app / WatchKit extension)

When a watchOS app has a companion iOS app, Apple requires the embedded WatchKit app and WatchKit extension targets to share the iOS app’s bundle ID prefix, and use fixed suffix formats.

To satisfy this while keeping Option A for host apps, derive them from the iOS host bundle ID:

- WatchKit app: `<iosHostBundleId>.watchkitapp`
- WatchKit extension: `<iosHostBundleId>.watchkitextension`

Example (iOS host `com.acme.akmeapp.app.ios`):

- WatchKit app: `com.acme.akmeapp.app.ios.watchkitapp`
- WatchKit extension: `com.acme.akmeapp.app.ios.watchkitextension`

### App Clips

Apple requires an App Clip app identifier to use the full iOS app identifier as a prefix, followed by a suffix string (Xcode defaults this suffix to `Clip`).

To stay consistent with our lowercase scheme:

- App Clip: `<iosHostBundleId>.clip`

Example (iOS host `com.acme.akmeapp.app.ios`):

- App Clip: `com.acme.akmeapp.app.ios.clip`

## Module bundle ID formats

Module targets MUST encode portability via a `scope` segment:

- `<coreRoot>.mod.<scope>.<layer>.<module>.<kind>`

Where:

- `scope ∈ common|darwin|ios|macos|android|linux|windows`
- `layer ∈ core|feature|shared|utility|compositionroot|app`
- `module` is a normalized module name segment
- `kind ∈ interface|impl|testing|tests`

Examples:

- Cross-platform Auth module (feature):
  - Interface: `com.acme.akmeapp.mod.common.feature.auth.interface`
  - Impl: `com.acme.akmeapp.mod.common.feature.auth.impl`
  - Tests: `com.acme.akmeapp.mod.common.feature.auth.tests`

- Darwin-only Keychain module (core):
  - Impl: `com.acme.akmeapp.mod.darwin.core.keychain.impl`

- iOS-only Paywall module (feature):
  - Impl: `com.acme.akmeapp.mod.ios.feature.paywall.impl`

## Local bundle ID suffix (developer namespacing)

The project supports a local-only namespacing suffix:

- `TUIST_BUNDLE_ID_SUFFIX` (example: `.ivan`)

Semantics:

- The suffix is treated as one or more additional reverse-DNS segments.
- It MUST be inserted after the first two segments of the identifier.

Example:

- Base: `com.acme.akmeapp.app.ios`
- Suffix: `.ivan`
- Result: `com.acme.ivan.akmeapp.app.ios`

This allows wildcard App IDs like `com.acme.*` to continue matching.

This suffix MUST apply consistently to:

- host bundle IDs
- extension bundle IDs (because they are derived from host IDs)
- module bundle IDs
- capability identifiers derived from host bundle IDs (Level B)

This suffix MUST NOT apply implicitly to:

- shared capability identifiers derived from `sharedRoot` (Level C)

Rationale:

- `sharedRoot`-derived identifiers are repo-tracked and must remain stable across developers and CI.
- Per-developer namespacing for shared capability identifiers is still possible via `.custom(..., namespacing: .environmentSuffix)` when explicitly needed.

## Capability identifiers (App Groups, iCloud, Keychain…)

This RFC defines **three** identifier sharing levels:

### Level A: Target-only (no explicit sharing)

If no capability is enabled, the target uses platform defaults.

Example: “app-only keychain”

- Do **not** enable Keychain Sharing.
- The app uses its private keychain access group (not intended for sharing).

### Level B: App-suite sharing (default for `.default`)

When a capability identifier is derived “by default”, it MUST be derived from the **host bundle ID**
of the app that owns the entitlement:

- host app and its extensions can share
- iOS and macOS do **not** share by default (because host bundle IDs differ)

This is the default behavior (and the selected strategy for this repo).

### Level C: Product-shared (explicit / opt-in)

Some capabilities must be shared between iOS and macOS (and their extensions).
For this, identifiers MUST be derived from `sharedRoot`:

- iOS host app uses `sharedRoot`-derived identifiers
- macOS host app uses the same identifiers
- extensions share by inheriting the host app’s entitlements

This must be explicitly requested in manifests.

### Derived identifier formats

When using **Level B (host bundle ID)**:

- App Groups: `group.<hostBundleId>`
- iCloud container: `iCloud.<hostBundleId>`
- Apple Pay merchant ID: `merchant.<hostBundleId>`
- Wallet pass type ID: `pass.<hostBundleId>`
- Keychain access group: `$(AppIdentifierPrefix)<hostBundleId>`
- iCloud KVS identifier: `$(TeamIdentifierPrefix)<hostBundleId>`

When using **Level C (sharedRoot)**:

- App Groups: `group.<sharedRoot>`
- iCloud container: `iCloud.<sharedRoot>`
- Apple Pay merchant ID: `merchant.<sharedRoot>`
- Wallet pass type ID: `pass.<sharedRoot>`
- Keychain access group: `$(AppIdentifierPrefix)<sharedRoot>`
- iCloud KVS identifier: `$(TeamIdentifierPrefix)<sharedRoot>`

Notes:

- iCloud has multiple entitlements with different identifier “shapes”; don’t conflate container identifiers with the key-value store identifier (see below).
- iCloud container identifiers must not contain wildcard (`*`) characters.
- `$(AppIdentifierPrefix)` / `$(TeamIdentifierPrefix)` are Xcode build setting macros and are not subject to our lowercase normalization rules.
- During signing, the entitlements embedded into the app must be compatible with (and typically a subset of) the entitlements granted by the provisioning profile. Mismatches (for example, requesting an iCloud container identifier not enabled for the App ID/profile) will fail at install/build time.

### iCloud identifiers by entitlement key (clarification)

Apple uses multiple iCloud entitlements that look similar but are *not* interchangeable:

- **iCloud container identifiers** (container IDs):
  - Used by:
    - `com.apple.developer.ubiquity-container-identifiers` (iCloud Documents)
    - `com.apple.developer.icloud-container-identifiers` (CloudKit)
  - Value shape: `iCloud.<reverse-dns>`
  - Notes:
    - The first container ID in the list is treated as the app’s “primary” container.
    - These values must not include wildcard (`*`) characters.

- **iCloud key-value store identifier** (KVS identifier):
  - Used by:
    - `com.apple.developer.ubiquity-kvstore-identifier` (Key-Value Storage)
  - Value shape: `$(TeamIdentifierPrefix)<reverse-dns>`

### Keychain access groups (gotchas)

Apple forms the effective keychain access group list as a concatenation of:

1. `keychain-access-groups` (if present)
2. the (auto-added) `application-identifier` / `com.apple.application-identifier` entitlement
3. application group names from `com.apple.security.application-groups`

Practical implications:

- An app always has a private access group via its application identifier, even if you don’t enable Keychain Sharing.
- You can use App Group names as keychain access group names **without** adding them to `keychain-access-groups`.

## Implementation notes (Tuist DSL)

### Configuration inputs (repo tracked vs local)

Repo-tracked:

- `coreRoot`
- `sharedRoot`
- app project names / target names
- min OS versions

Local-only (not committed):

- `DEVELOPMENT_TEAM_ID`
- `BUNDLE_ID_SUFFIX`

These values are passed into Tuist via `TUIST_*` environment variables so manifests can read them via `Environment.*`.

### Capability DSL requirement

The capability DSL MUST support choosing between:

- default identifiers derived from `hostBundleId` (Level B)
- shared identifiers derived from `sharedRoot` (Level C)

Default MUST remain Level B, and “shared” MUST be explicitly selected at the call site.

## Migration plan (high level)

1. Introduce `coreRoot` + `sharedRoot` repo-tracked configuration (and `TUIST_*` env plumbing).
2. Update app bundle ID derivation:
   - `...app.ios` / `...app.macos`
3. Update extension bundle ID derivation:
   - `...<host>.appex.<type>[.<name>]`
4. Update module bundle ID derivation:
   - `...mod.<scope>.<layer>.<module>.<kind>` with lowercase normalization
5. Extend the capability DSL to opt into Level C (`sharedRoot`) per capability.
6. Update any tooling that parses bundle IDs (graph checks, reports) if needed.

## Alternatives considered

- Using `darwin.<subplatform>` for apps (Option B). Rejected for now in favor of shorter Option A; Option A can still grow via subplatform suffixes.
- Encoding platform sets in module IDs (e.g. `ios+macos`). Rejected: use a single `scope` and rely on build settings/tags for exact sets.

## Open questions

- Should we add additional scopes (e.g. `watchos`, `tvos`, `visionos`) later, or treat them as `darwin` until needed?
- Should we enforce normalization via build-time checks (Tuist manifest validation) or via a lint script?

## References

Apple:

- `CFBundleIdentifier` rules (allowed characters, case-insensitive; WatchKit suffix requirements; App Store Connect immutability): https://developer.apple.com/tutorials/data/documentation/bundleresources/information_property_list/cfbundleidentifier.json
- App extension prefix rule (Apple DTS): https://developer.apple.com/forums/thread/101754
- App Clips App ID prefix rule: https://developer.apple.com/help/account/identifiers/register-an-app-id-for-app-clips/
- App Groups entitlement format: https://developer.apple.com/tutorials/data/documentation/bundleresources/entitlements/com.apple.security.application-groups.json
- Keychain sharing (access group prefixing behavior): https://developer.apple.com/tutorials/data/documentation/security/sharing-access-to-keychain-items-among-a-collection-of-apps.json
- Entitlements troubleshooting (profile vs app entitlements mismatch): https://developer.apple.com/library/archive/technotes/tn2415/_index.html
- iCloud container IDs begin with `iCloud.`: https://developer.apple.com/library/archive/documentation/DataManagement/Conceptual/CloudKitWebServicesReference/SettingUpWebServices.html
- iCloud container IDs must not contain wildcard `*`: https://developer.apple.com/library/archive/documentation/General/Conceptual/iCloudDesignGuide/Chapters/iCloudFundametals.html
- iCloud KVS entitlement default value reference: https://developer.apple.com/forums/thread/22867

Android:

- `applicationId` naming rules: https://developer.android.com/build/configure-app-module

Windows:

- AppxManifest `Identity` name constraints: https://learn.microsoft.com/en-us/uwp/schemas/appxpackage/uapmanifestschema/element-identity
