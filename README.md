# Mistake Loop

Offline study mistake journal: capture wrong answers, tag why they failed, and revisit only unresolved errors across phone, tablet, and Windows.

## Why and for whom
Students preparing for exams often repeat the same error without recording its cause. Mistake Loop keeps a private correction trail rather than another giant flashcard deck. Use it for math exercises, language drills, or self-marked practice; not for official scoring or automated answer checking.

## Intended workflow
1. Create a subject and record a question/source locator, your incorrect answer, correct answer, and error cause. Do not copy copyrighted material without permission.
2. Revisit unresolved entries in a focused queue; write a fresh answer before revealing correction. Mark resolved only after a successful attempt; reopen whenever needed.
3. Review cause counts and export/import a local JSON backup or CSV summary.

MVP: subjects, mistake entries, explicit cause tags, revisit attempts, status history, local persistence, export/import, adaptive accessible UI. Non-goals: AI grading, online course content, social features, accounts, cloud sync, automatic spaced-repetition promises or guaranteed exam performance.

## Platforms and privacy
Flutter stable single codebase for Windows desktop, Android phone/tablet and iOS iPhone/iPad. Windows primary release. Local-only data; no account, ads, analytics, microphone or camera permissions. User chooses backup destination; exports may contain sensitive answer text, so warn before sharing. Touch, keyboard/mouse, screen readers, scalable text, high contrast and full Windows keyboard navigation are required. Identifier: `com.infinityball.mistakeloop` for Android applicationId, iOS bundle ID and applicable Windows package identity.

## Status and quickstart
Flutter 3.47.7 / Dart 3.13.5 app for Windows, Android and iOS; pin in `toolchain.json`. Capture subjects and mistakes, revisit with self-marking, reopen resolved errors, and import/export JSON backups or CSV summaries through native file pickers. Run `flutter pub get --enforce-lockfile`, `dart format --output=none --set-exit-if-changed .`, `flutter analyze`, `flutter test`. CI builds Windows release, Android debug APK and unsigned iOS simulator app. See PLAN.md and AppStore/description.txt.

`AppStore/icon.png` is OpenAI Images (`gpt-image-2.5-flare`) source art generated through `spark-media --project mistake-loop image`; derived launcher icons ship in Windows/Android/iOS projects. Prompt: "analyze the repo and AppStore description to generate an icon that does not have any text or marketing, transparency, borders or corner radius. The image needs to be square, be edge-to-edge graphics and a modern colorful representation of the function provided by the app or game. If a logo or symbol is used, then there should be a gradient background or other abstract background behind the logo." Source output: `~/media/mistake-loop/images/20261109T142412Z_openai_d14ba6.png` (1024×1024, opaque RGB); automated corner/size checks do not replace visual store review.

`.github/workflows/release.yml` builds Windows on `windows-latest` from an existing `vMAJOR.MINOR.PATCH` tag, triggered by tag push or manual dispatch with `tag` input. It uploads a portable zip containing the full runner directory to a GitHub release. Release workflow validates an existing tag before upload; PR CI does not prove a tagged release upload. TestFlight/Play publishing later; ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_P8 and ASC_TEAM_ID are secret names, not repository values.

## Manual setup required
`com.infinityball.mistakeloop` could not be registered: `FAILED bundleId lookup rejected: FORBIDDEN_ERROR.PLA_NOT_ACCEPTED`. Account owner must accept current Apple Program License Agreement; retry registration afterward. GitHub ASC secret names are installed; values never belong in this repository.

MIT licensed. Local Flutter tests and analyzer passed on Linux ARM64; platform build results pending CI.
