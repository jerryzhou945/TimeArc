# English service comments

Goal: Replace Chinese comments in non-frozen `src/service/` sources and `src/main.cpp` with concise English without changing code.

## Progress

- [x] Inventory eligible comments and establish a clean baseline build.
- [x] Replace only comment text; leave frozen files and executable code untouched.
- [x] Verify comment coverage, code equivalence, and the final build.

Expected touch points are Windows service entry/tracker/platform sources, macOS service sources, and `src/main.cpp`; frozen shared headers/path files, CMake files, schemas, and application behavior are explicitly out of scope. Expected diff size is under 300 changed lines.

Outcome: Replaced Chinese comments in `src/main.cpp` and all eligible Windows service files. The diff changes comments only, baseline and final sanctioned builds pass, and `git diff --check` is clean. Frozen `src/service/shared/app_info.h` and `app_env.h` remain unchanged under Track A.
