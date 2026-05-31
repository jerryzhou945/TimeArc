# Session - services-snake-case

## Track

B Feature

## Motivation

Unify `src/services` file names after the desktop MVP data loop work. The
existing directory mixed PascalCase files with lowercase-concatenated manager
files, which made CMake source lists and include paths harder to audit.

## Frozen File Touch

`src/CMakeLists.txt` is frozen and must change because the service/repository
file names changed. The edit is mechanical: update source paths only, without
changing targets, dependencies, build options, or platform boundaries.

## Data Safety

No storage contract files are changed. SQLite schema, QSettings migration,
project archive behavior, and foreground/media sampling paths stay unchanged.
