# Goal

Make `dev` contain the latest `origin/main` history with a normal merge, without rebasing, force-pushing, or touching `main`.

# What Happened

Fetched `origin/main` and `origin/dev`, stashed pre-existing harness working-tree noise, then merged `origin/main` into `dev`. The merge produced a README conflict between the desktop P1 notes on `dev` and the desktop/hot-spring wording on `main`; the resolved README keeps both current desktop P1 storage notes and the `main` desktop Memory Lake description.

# Related Error Reports

- `.harness/journal/errors/20260530-100042-C-merge-main-readme-conflict.md`

# Outcome

The merge is staged locally for validation. It brings in `main`'s mobile-shell removal and Memory Lake hot spring resources while preserving `dev`'s P1 desktop MVP data-loop commit. No push has been performed yet.
