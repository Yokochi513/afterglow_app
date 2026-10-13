---
name: implement-afterglow-issue
description: Implement an Afterglow (afterglow_app) GitHub Issue end to end. Use when asked to implement, fix, or complete an Issue in the afterglow_app repository. Claude fetches the Issue, branches off dev, implements the change itself, runs validation, auto-iterates on failures, and opens the PR — the only human checkpoint is the final PR review.
---

# Implement an Afterglow Issue

Afterglow is a Flutter + Firebase app (`lib/` Flutter client, `functions/` TypeScript Cloud Functions). GitHub repo: `Yokochi513/afterglow_app`. Default branch: `main`. Integration branch for Issue work: `dev`.

**Claude implements directly.** Do not delegate coding to the Codex CLI (`codex exec`) or any other external agent — Codex runs have repeatedly stalled silently (e.g. hanging inside its sandboxed command layer for 15+ minutes, or hanging for hours after its first edit), and it can keep writing to the working tree after its task is stopped. All intermediate steps run automatically without asking the user; the human's checkpoint is reviewing the final PR.

## Workflow

### 1. Prepare

1. Fetch the requested Issue with `gh issue view <number> --json number,title,body,labels,comments` (plain `gh issue view` can fail on the deprecated Projects classic API). Record its acceptance criteria, scope, exclusions, and any referenced spec sections. Feedback Issues often carry a `feedback-refinement-bot` comment — use it as context, but verify its hypotheses against the code.
2. If the user says several Issues are duplicates, implement once on one branch and close all of them from the PR (`Closes #a`, `Closes #b`).
3. Read the relevant parts of the canonical specifications under `docs/` — primarily `docs/要件定義.md` and `docs/詳細設計.md`. Treat them as read-only. `docs/prompts/phase1_roadmap.md` is background, not a spec.
4. Inspect `git status`. If the working tree is dirty, stop and ask the user to stash or commit unrelated changes before continuing (this is the one pre-flight condition that may interrupt).
5. Create one branch for this Issue off the latest `dev`:
   - `git switch dev && git pull --ff-only origin dev` (skip the pull if it fails), then `git switch -c <branch>`.
   - Branch name: `feat-<issue-number>-<short-english-slug>` for features, `fix-<issue-number>-<slug>` for fixes (kebab-case). Use the branch the user requests if given.
6. Run `flutter pub get` (and `npm --prefix functions ci` if the Issue touches `functions/`).

### 2. Implement

7. Implement the change following the repo rules:
   - Layer split: UI in `lib/pages`/`lib/widgets`, data access in `lib/services`, models in `lib/models`; widgets never touch Firestore/Storage directly.
   - DI-style services (`PostService({FirebaseFirestore? firestore})` with `.instance` defaults), immutable models (`const` constructor + `factory fromSnapshot`, defaults for missing fields), collection names as `static const`.
   - Japanese comments, matching the surrounding code's comment density, naming, and idioms. `flutter_lints` clean.
   - Do **not** edit `docs/`, do **not** add dependencies beyond the Issue scope, do **not** touch secrets or generated outputs.
8. Add or update tests under `test/` mirroring `models`/`services`/`widgets`/`pages`. Existing test mocks: `fake_cloud_firestore` / `firebase_storage_mocks` / `firebase_auth_mocks`.

### 3. Validate and auto-iterate

9. Run every validation that applies to the touched files (see Validation below). Do not ask the user between rounds.
10. If validation fails or acceptance criteria are unmet, fix and re-validate. If still failing after **3 fix rounds**, stop, keep the branch, and report the remaining failures to the user instead of opening a PR.
11. Review the final diff yourself: no `docs/` edits, no secrets or generated artifacts (`build/`, `functions/lib/`, keys, `.env`), no unrelated changes, every acceptance criterion mapped to a change or verification.

### 4. Ship (automatic)

12. Commit, push, and open the PR **without asking for confirmation** — the PR is the human review gate:
    - Commit message and PR title/body in **Japanese**, Conventional Commits subject (`feat: ...`, `fix: ...`).
    - PR targets `dev`, body lists `Closes #<number>`, a checklist of satisfied acceptance criteria, and the exact validation commands with results.
    - Follow the `1 Issue = 1 branch = 1 PR` rule (duplicate Issues share one PR).
13. Report to the user: PR URL, commit hash, validation results, and anything intentionally left out.

## Operating Rules

- Do not edit the canonical documents under `docs/`. If a spec change seems necessary, stop and report it on the Issue instead of implementing it.
- Do not add dependencies beyond the Issue scope. Existing stack: `flutter_map` + `latlong2` (map), Firebase (`firebase_auth`, `cloud_firestore`, `firebase_storage`), test mocks listed above.
- Stop and report genuine product ambiguity instead of inventing behavior; everything else proceeds automatically.
- Never commit secrets or generated outputs: service-account keys, `.env`, APNs keys, `*.keystore`, new `google-services.json` / `GoogleService-Info.plist`, `build/`, `functions/lib/`, or unrelated user changes. `lib/firebase_options.dart` and `.firebaserc` are already tracked — leave them as-is unless the Issue requires a change.

## Validation

Flutter (run whenever `lib/` or Dart/Flutter code changes):

- `flutter analyze` (keep warnings at zero)
- `dart format .` then `dart format --output=none --set-exit-if-changed .`
- `flutter test` (tests run offline via the Firebase mocks)

Cloud Functions (run only when `functions/` changes):

- `npm --prefix functions run build` (TypeScript compile via `tsc`; no lint/test script defined)

Firestore rules (run only when `firestore.rules` changes):

- `npm --prefix test/rules test`

If Flutter stalls before producing output, inspect the Flutter/Dart processes and the SDK cache lock — the SDK may need permission to write its cache.
