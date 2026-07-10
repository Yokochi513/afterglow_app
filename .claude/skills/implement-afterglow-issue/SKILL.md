---
name: implement-afterglow-issue
description: Implement an Afterglow (afterglow_app) GitHub Issue end to end from its acceptance criteria. Use when asked to implement, fix, or complete an Issue in the afterglow_app repository while following the canonical docs, branch and scope rules, local validation, and PR requirements.
---

# Implement an Afterglow Issue

Afterglow is a Flutter + Firebase app (`lib/` Flutter client, `functions/` TypeScript Cloud Functions). GitHub repo: `Yokochi513/afterglow_app`. Default branch: `main`. Integration branch for Issue work: `dev`.

## Workflow

1. Fetch the requested Issue with `gh issue view <number>` and record its acceptance criteria, scope, exclusions, and any referenced spec sections.
2. Read the relevant parts of the canonical specifications under `docs/` — primarily `docs/要件定義.md` (requirements) and `docs/詳細設計.md` (detailed design). Treat them as read-only. `docs/prompts/phase1_roadmap.md` is useful background on product direction but is not a spec.
3. Inspect `git status`. If the working tree is dirty, stop and ask the user to stash or commit unrelated changes before continuing.
4. Create one branch for this Issue off the latest `dev`:
   - `git switch dev && git pull --ff-only origin dev` (skip the pull if it fails), then `git switch -c <branch>`.
   - Branch name: `feat-<issue-number>-<short-english-slug>` for features, `fix-<issue-number>-<slug>` for fixes (kebab-case, matching the repo's existing hyphenated branch style). Use the branch the user requests if given.
5. Map every acceptance criterion to a code change or verification, then implement only that scope. Keep the client/functions split clean: UI in `lib/pages` and `lib/widgets`, data access in `lib/services`, models in `lib/models`.
6. Format and run every validation that applies to the files you touched (see Validation below).
7. Review the final diff for generated artifacts, secrets, spec edits, and unmet criteria.
8. Follow the `1 Issue = 1 branch = 1 PR` rule. Open a PR targeting `dev` whose body lists `Closes #<number>`, a checklist of the satisfied acceptance criteria, and the exact validation commands run with their results. Commit and push only when requested; report the commit hash and PR URL.

## Operating Rules

- Do not edit the canonical documents under `docs/`. If a spec change seems necessary, stop and report it on the Issue instead of implementing it.
- Do not add dependencies beyond the Issue scope. Follow the existing stack: `flutter_map` + `latlong2` for the map, Firebase (`firebase_auth`, `cloud_firestore`, `firebase_storage`) for the backend, and `fake_cloud_firestore` / `firebase_storage_mocks` / `firebase_auth_mocks` for tests.
- Stop and report ambiguity instead of inventing missing product behavior.
- Commit messages and PR titles/bodies are written in **Japanese** (repository convention), using Conventional Commits subjects (e.g. `feat: ...`, `fix: ...`). Follow the user's language if they specify one.
- Never commit secrets or generated outputs: service-account keys, `.env` files, APNs keys, `*.keystore`, new `google-services.json` / `GoogleService-Info.plist`, build outputs (`build/`, `functions/lib/`), or unrelated user changes. Note that `lib/firebase_options.dart` and `.firebaserc` are already tracked — leave them as-is unless the Issue requires a change.

## Validation

Flutter (run whenever `lib/` or Dart/Flutter code changes):

- `flutter pub get`
- `flutter analyze` (keep warnings at zero)
- `dart format .` then `dart format --output=none --set-exit-if-changed .`
- `flutter test` (tests run offline via the Firebase mocks listed above)

Cloud Functions (run only when `functions/` changes):

- `npm --prefix functions ci`
- `npm --prefix functions run build` (TypeScript compile via `tsc`; there is no lint/test script defined)

If Flutter stalls before producing output, inspect the Flutter/Dart processes and the SDK cache lock — the SDK may need permission to write its cache.

Before handoff, report the satisfied acceptance criteria, exact validation results, any intentionally uncommitted files, and the commit hash or PR URL.
