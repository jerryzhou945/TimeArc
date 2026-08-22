from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
HEADER = ROOT / "src/service/windows/tracker/audio_tracker.h"
SOURCE = ROOT / "src/service/windows/tracker/audio_tracker.c"
PLATFORM = ROOT / "src/service/windows/platform/audio_win.c"


def require(text: str, fragment: str, purpose: str) -> None:
    if fragment not in text:
        raise AssertionError(f"missing {purpose}: {fragment}")


def reject(text: str, fragment: str, purpose: str) -> None:
    if fragment in text:
        raise AssertionError(f"unexpected {purpose}: {fragment}")


def main() -> None:
    header = HEADER.read_text(encoding="utf-8")
    source = SOURCE.read_text(encoding="utf-8")
    platform = PLATFORM.read_text(encoding="utf-8")

    require(
        header,
        "timearc_audio_tracker_has_foreground",
        "foreground media evidence query",
    )
    reject(header, "TIMEARC_AUDIO_SILENCE_GRACE_SEC", "silence grace")
    reject(header, "TIMEARC_AUDIO_FLUSH_INTERVAL_SEC", "periodic split")
    reject(source, "last_seen_sec + 1", "delayed media end")
    require(header, "checkpoint_sec", "bounded persistence checkpoint state")
    require(
        source,
        "persist_audio_session(session, now_sec)",
        "open-session checkpoint persistence",
    )
    reject(platform, "find_added_audio_app", "path-only platform deduplication")
    require(
        source,
        "timearc_app_identity_equal",
        "complete normalized media identity",
    )
    require(
        platform,
        "timearc_app_identity_equal",
        "platform deduplicates only equal observations",
    )
    require(
        source,
        "if (sample_succeeded && !session->seen_this_poll)",
        "immediate absence boundary after a successful sample",
    )

    print("Windows audio tracker static checks passed")


if __name__ == "__main__":
    main()
