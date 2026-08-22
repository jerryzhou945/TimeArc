# C — Browser media title fragmentation

Goal: restore accurate browser-video time attribution on Windows without weakening the existing media-session boundaries.

Reproduction: while Chrome kept an audible Bilibili session alive, switching the foreground tab caused the service journal to close the Bilibili row after three seconds and assign subsequent audio checkpoints to unrelated Chrome page titles.

Working hypothesis: `timearc_win_preferred_observed_media_title()` uses the foreground browser title ahead of the Windows system media-session title. Because the tracker correctly treats normalized title changes as identity boundaries, that unstable sampler value fragments one playback session.

Expected files: `src/service/windows/platform/audio_win.c`, `src/service/windows/platform/audio_win.h`, `tests/windows_audio_title_policy_test.c`, plus this session and the linked error report. No schema or journal-contract change is intended.

Linked error: `.harness/journal/errors/20260822-045559-C-browser-media-fragmentation.md`

Progress:

- [x] Attempt the raw Windows media-session probe; no media session was active, so retained the earlier live journal evidence.
- [x] Add a failing browser-title regression test.
- [x] Apply the smallest sampler policy correction.
- [x] Verify focused tests, harness build, runtime, and harness checks.

Outcome: browser playback now uses its GSMTC media title as the stable key, enriches it with a correlated Bilibili/browser site title, and retains that identity for continuous audible samples while unrelated tabs take focus. The focused regression first failed under the old policy and passed after the bounded cache was added; all six CTest targets passed. Harness build `20260822-130858-build.log` succeeded. The rebuilt UI and service started from the expected build paths and remained responsive, and the final Qt scan found no log. A pre-existing first-frame radius binding in the new aggregate statistics summary surfaced during runtime QA and was corrected with a focused static regression check. Live Bilibili playback was not active during the final automated run, so device playback remains the final manual acceptance check rather than an automated claim.
