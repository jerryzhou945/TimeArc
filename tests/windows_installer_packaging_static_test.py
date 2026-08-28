from pathlib import Path


REPO = Path(__file__).resolve().parents[1]
PACKAGER = REPO / "tools" / "package-installer.ps1"


def main() -> int:
    text = PACKAGER.read_text(encoding="utf-8")

    assert "lzma/bin/7zSD.sfx" in text, (
        "installer must use the configurable 7zSD.sfx module; "
        "7zS2.sfx ignores Installer Config and opens install.ps1 as text"
    )
    assert 'Directory=""' in text, (
        "system powershell.exe lookup requires an empty RunProgram directory prefix"
    )
    assert 'RunProgram="powershell.exe -NoProfile -ExecutionPolicy Bypass -File install.ps1"' in text

    print("windows_installer_packaging_static_test: OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
