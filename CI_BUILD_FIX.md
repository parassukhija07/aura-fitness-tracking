# CI Build Failure — Root Cause & Fix

Run: `fix/c1-merge-corruption`, 2026-07-18 11:00 UTC. Exit code 65, "BUILD FAILED".

## What broke it

Two independent bugs, both now fixed in this repo:

### 1. `LogDayModel.swift` / `ResumeBanner.swift` shared the same UUID in `project.pbxproj`

Pre-existing corruption from commit `499d6d1` (before this session) — both files were
registered under the identical `PBXBuildFile`/`PBXFileReference` ID
(`AAEE0003.../ABEE0003000000000000003B`). Xcode can only keep one file's group/Sources
membership when two files collide on the same ID, so it silently dropped one and printed:

```
warning: The file reference for "LogDayModel.swift" is a member of multiple groups
("DesignSystem" and "Models"); this indicates a malformed project.
...
Skipping duplicate build file in Compile Sources build phase: .../LogDayModel.swift
```

**Fixed**: gave `LogDayModel.swift` its own canonical 24-hex UUID
(`AAF182697FEFC84D54BF50A0` / `ABF182697FEFC84D54BF50A0`), updated all 4 references
(BuildFile, FileReference, `Models` group child, Sources build phase). Verified no
other ID collisions exist anywhere in the file.

### 2. Xcode 15.4's compiler can't build `xctest-dynamic-overlay` (a transitive dependency)

The real build failure. `supabase-swift` pulls in `xctest-dynamic-overlay` (resolved to
1.10.1), which uses Swift syntax Xcode 15.4's toolchain doesn't support:

```
❌ .../Unimplemented.swift:4:17: duplicate attribute
    @concurrent @Sendable (repeat each Argument) async -> Result
❌ .../IssueReporting/IssueReporters/DefaultReporter.swift:1:1: Access level on imports
   require '-enable-experimental-feature AccessLevelOnImport'
   public import Foundation
❌ .../Internal/AppHostWarning.swift:1:8: ambiguous implicit access level for import
   of 'Foundation'; it is imported as 'public' elsewhere
```

This is not app code — it's the package's own source, compiled fresh every CI run (no
`Package.resolved` is checked in, so SPM re-resolves versions each time). Xcode 15.4's
Swift 5.10 compiler predates the `@concurrent` attribute and the access-level-on-imports
feature this package version now uses.

**Fixed**: bumped `.github/workflows/ci.yml` to use `macos-15` + Xcode `~16.2` instead
of `macos-14` + Xcode `~15.4`. Xcode 16's compiler supports this syntax.

## What's committed

- `AuraFitness.xcodeproj/project.pbxproj` — UUID collision fixed
- `.github/workflows/ci.yml` — runner/Xcode version bumped

## What you still need to do

### 1. Push and re-run CI (no local action needed beyond that)
The two fixes above are code/config changes only — once pushed, the next CI run should
get past both the pbxproj warning and the compile failure. Nothing manual required here.

### 2. HealthKit capability (carried over from the earlier audit-fix session, still open)
`AuraFitness/AuraFitness.entitlements` was added in the prior commit, but this repo's CI
config **does not require it to build** (`CODE_SIGNING_ALLOWED=NO` in `ci.yml` skips
entitlement validation entirely for CI). This only matters for running on a real device
or through App Store Connect, not for CI going green. When you're ready to test on
device:

1. Open the project in Xcode.
2. Select the `AuraFitness` target → **Signing & Capabilities** tab.
3. Click **+ Capability** → add **HealthKit**.
4. Xcode will either link the existing `AuraFitness.entitlements` file or generate its
   own — if it creates a second one, delete mine and keep Xcode's (they're functionally
   identical, just avoid two `.entitlements` files fighting over the same build setting).
5. Confirm your Apple Developer account / App ID has HealthKit enabled — Xcode usually
   offers to fix this automatically when the capability is added.

Without this step, `HealthKitService.requestAuthorization` will fail at runtime (not at
build time) — the toggle in Connected Apps just won't turn on.

### 3. Nothing else is currently known to block CI
If the next run still fails, it's most likely a **different** transitive-dependency/Xcode
16 incompatibility (the SPM graph pulls in 6 other packages besides `xctest-dynamic-overlay`
— `swift-clocks`, `swift-crypto`, `swift-asn1`, `swift-concurrency-extras`,
`swift-http-types`, plus `supabase-swift` itself). If a new error shows up mentioning one
of those packages, paste the log and I'll dig into that one the same way.
