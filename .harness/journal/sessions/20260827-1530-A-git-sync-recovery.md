# Track A — Git sync recovery

## Goal

Restore the missing Git metadata for the migrated C-drive source copy, preserve any local file differences, and synchronize the working directory with the latest remote `dev` branch without changing product behavior.

## Plan

Compare the current tree against a temporary no-checkout clone, identify local-only changes, restore repository metadata, then fast-forward or reconcile safely and verify the resulting status.

## Outcome

In progress.
