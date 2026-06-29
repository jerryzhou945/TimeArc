from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(rel):
    return (ROOT / rel).read_text(encoding="utf-8")


def require(text, needle, label):
    if needle not in text:
        raise AssertionError(f"missing {label}: {needle}")


def main():
    main_cpp = read("src/main.cpp")

    require(main_cpp, "#if defined(Q_OS_ANDROID)",
            "Android-gated lifecycle sync")
    require(main_cpp, "applicationStateChanged",
            "application foreground lifecycle signal")
    require(main_cpp, "Qt::ApplicationActive",
            "foreground active-state filter")
    require(main_cpp, "mobileUsageService.requestImmediateSync()",
            "foreground resume usage sync request")

    print("Android usage static checks passed")


if __name__ == "__main__":
    main()
