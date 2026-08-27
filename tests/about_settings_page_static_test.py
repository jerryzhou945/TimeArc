from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PROFILE = ROOT / "qml/desktop/pages/DesktopProfilePage.qml"


def require(text, needle, label):
    if needle not in text:
        raise AssertionError(f"missing {label}: {needle}")


def reject(text, needle, label):
    if needle in text:
        raise AssertionError(f"unexpected {label}: {needle}")


def main():
    profile = PROFILE.read_text(encoding="utf-8")

    require(
        profile,
        '{ key: "about",    glyph: "©", label: "About & Licenses" }',
        "dedicated About & Licenses settings tab",
    )
    require(
        profile,
        'case "about":    return aboutSec.implicitHeight',
        "About & Licenses section height routing",
    )
    require(
        profile,
        'id: aboutSec\n                            tabKey: "about"',
        "dedicated About & Licenses settings section",
    )

    export_start = profile.index("id: exportSec")
    about_start = profile.index("id: aboutSec")
    if not export_start < about_start:
        raise AssertionError("About & Licenses section must follow Import & Export")
    if 'cardTitle: "About & Licenses"' in profile[export_start:about_start]:
        raise AssertionError("About & Licenses card remains inside Import & Export")

    about_section = profile[about_start:profile.index("id: settingsToast")]
    for content in (
        "readonly property var licenseComponents",
        'name: "TimeArc"',
        "delegate: SettingsCard {",
        'comp.name === "TimeArc"',
        "function showLicenseText(",
        "id: licenseViewer",
    ):
        require(profile, content, "existing About & Licenses content")

    component_positions = [
        profile.index(f'name: "{name}"')
        for name in ("TimeArc", "Qt 6", "SQLite", "Parson")
    ]
    if component_positions != sorted(component_positions):
        raise AssertionError("license cards are not ordered TimeArc, Qt 6, SQLite, Parson")

    reject(about_section, 'cardTitle: "About & Licenses"',
           "single wrapper card duplicating the page title")
    reject(profile, "全文文件位于 resources/licenses/",
           "bundled-license location statement")

    print("about settings page static test: OK")


if __name__ == "__main__":
    main()
