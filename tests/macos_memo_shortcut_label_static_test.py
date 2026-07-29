from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def require(text, needle, label):
    if needle not in text:
        raise AssertionError(f"missing {label}: {needle}")


def main():
    memo = (
        ROOT / "qml/desktop/memorylake/MemoOverlay.qml"
    ).read_text(encoding="utf-8")

    require(memo, 'Qt.platform.os === "osx"',
            "macOS shortcut-label platform gate")
    require(memo, 'translated.split("Ctrl+").join("⌘")',
            "macOS Command shortcut labels")
    require(memo, "memo.shortcutDisplayText(memo.toolHints",
            "tool hint platform shortcut labels")
    require(memo, 'memo.shortcutDisplayText("仅清当前页手绘',
            "clear confirmation platform shortcut labels")

    print("macOS memo shortcut label static checks passed")


if __name__ == "__main__":
    main()
