# Mistake Loop plan

## Scope and architecture
Flutter stable, one codebase; create windows/android/ios folders in first issue. Pure Dart mistake/attempt model: subject, source locator, prompt (optional), wrong answer, corrected answer, cause tag, attempt timestamps, resolved/reopened status. SQLite local repository with migration tests; JSON backup with schema version and round-trip tests. No network dependency. `com.infinityball.mistakeloop` throughout Android applicationId, iOS bundle identifier and applicable Windows identity.

UX strategy A (platform-native adaptive): Cupertino on iOS/iPadOS, Material 3 on Android, Fluent-style Windows via a small adaptive-widget layer. No Material on iOS, no Cupertino on Android, no phone UI on Windows. Per-platform navigation/back, dialogs, scrolling, focus, hover, keyboard shortcuts, safe areas, accessible semantics and text scaling. Verify TargetPlatform.iOS/android/windows at phone/tablet/desktop dimensions.

## Milestones and dependencies
1. Flutter skeleton, platform folders, Windows/Android CI, pinned toolchain; Docker local test.
2. Pure Dart lifecycle invariants and unit tests: reopen, resolve, chronology and counts.
3. SQLite storage and versioned migration, durable reopen and backup round trip.
4. Capture and revisit workflow with explicit reveal and self-marking.
5. Adaptive screens plus screenshot/golden/widget accessibility tests.
6. JSON backup/restore, CSV export and privacy disclosure.
7. Generate `AppStore/icon.png` via spark-media image/OpenAI Images; inspect, wire all Windows/Android/iOS icon sets, review `AppStore/description.txt` for actual functionality. Add `.github/workflows/release.yml`: `v*` or manual dispatch, `windows-latest` release zip attached to GitHub release. TestFlight and Play later opt-in (ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_P8, ASC_TEAM_ID names only).

## Testing and distribution
`flutter test`, widget/golden tests under TargetPlatform.iOS/android/windows, Windows `flutter build windows --release`, Linux/Docker Android `flutter build apk --debug`. Keep iPhone/iPad and Android phone/tablet compiling; Apple builds require macOS evidence. Window resize and keyboard-only journeys required. Windows zip is first distributable; optional MSIX only when needed. No test has run at scaffold stage.

## Risks and non-goals
Sensitive answer text in backups: explicit share warning; no telemetry. No automatic grading or copyrighted question bank; users supply permitted content. No claim that cause counts diagnose learning difficulties or guarantee learning. No account/cloud sync, OCR, AI tutor, React Native, Expo, native Swift/Xcode-only app, Kotlin Multiplatform, .NET MAUI or Unity. Apple bundle registration currently blocked by FORBIDDEN_ERROR.PLA_NOT_ACCEPTED; account owner action required.
