from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
HEADER = ROOT / "src/service/windows/tracker/audio_tracker.h"
SOURCE = ROOT / "src/service/windows/tracker/audio_tracker.c"


def require(text: str, fragment: str, purpose: str) -> None:
    if fragment not in text:
        raise AssertionError(f"missing {purpose}: {fragment}")


def reject(text: str, fragment: str, purpose: str) -> None:
    if fragment in text:
        raise AssertionError(f"unexpected {purpose}: {fragment}")


def main() -> None:
    header = HEADER.read_text(encoding="utf-8")
    source = SOURCE.read_text(encoding="utf-8")

    require(
        header,
        "timearc_audio_tracker_has_foreground",
        "foreground media evidence query",
    )
    reject(header, "TIMEARC_AUDIO_SILENCE_GRACE_SEC", "silence grace")
    reject(header, "TIMEARC_AUDIO_FLUSH_INTERVAL_SEC", "periodic split")
    reject(source, "last_seen_sec + 1", "delayed media end")
    reject(source, "start_sec >= TIMEARC_AUDIO", "periodic checkpoint")
    require(
        source,
        "if (sample_succeeded && !session->seen_this_poll)",
        "immediate absence boundary after a successful sample",
    )

    print("Windows audio tracker static checks passed")


if __name__ == "__main__":
    main()
