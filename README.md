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
Planning scaffold only: no Flutter app, platform folders, icon, CI, or executable exists yet. Issue #1 creates `flutter create --platforms=windows,android,ios .` and runs `flutter test`, `flutter build windows --release`, and `flutter build apk --debug`; Linux host verification uses a pinned Flutter Docker image. See PLAN.md and AppStore/description.txt. `AppStore/icon.png` must be generated using spark-media image (OpenAI Images), inspected and wired to Windows/Android/iOS icon sets; no placeholder accepted. `.github/workflows/release.yml` must build Windows on `windows-latest` for `v*` tags or manual dispatch and attach portable zip to GitHub release. TestFlight/Play publishing later, using secret names ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_P8, ASC_TEAM_ID only.

## Manual setup required
`com.infinityball.mistakeloop` could not be registered: `FAILED bundleId lookup rejected: FORBIDDEN_ERROR.PLA_NOT_ACCEPTED`. Account owner must accept current Apple Program License Agreement; retry registration afterward. GitHub ASC secret names are installed; values never belong in this repository.

MIT licensed. No application build/test claims yet.
