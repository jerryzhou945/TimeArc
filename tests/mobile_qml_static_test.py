from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(relative_path):
    return (ROOT / relative_path).read_text(encoding="utf-8")


def require(text, needle, label):
    if needle not in text:
        raise AssertionError(f"missing {label}: {needle}")


def main():
    settings = read("qml/mobile/pages/MobileSettingsPage.qml")
    actions = read("qml/mobile/components/MobileShareActionBar.qml")
    qml_cmake = read("qml/CMakeLists.txt")
    resources_cmake = read("resources/CMakeLists.txt")
    single_share = read("qml/mobile/components/MobileShareOverlay.qml")
    ranking_share = read("qml/mobile/components/MobileRankingShareOverlay.qml")
    monthly_story = read("qml/mobile/components/MobileMonthlyStory.qml")
    monthly_share = read(
        "qml/mobile/components/monthly/MonthlySharePage.qml")

    require(settings, "MobileSymbolIcon {", "settings SVG icon renderer")
    require(actions, "icon: \"download\"", "gallery SVG action")
    require(actions, "icon: \"group\"", "Moments SVG action")
    require(actions, "icon: \"star\"", "Qzone SVG action")
    require(actions, "icon: \"more\"", "system share SVG action")
    if "mark:" in actions:
        raise AssertionError("share actions must not use text marks as icons")

    require(qml_cmake, "MobileSymbolIcon.qml", "symbol QML registration")
    require(resources_cmake, "resources/app/icons/mobile/download.svg",
            "mobile icon resource registration")
    require(resources_cmake, "material-symbols-apache-2.0.txt",
            "Material Symbols offline license")

    for source, label in ((single_share, "single share"),
                          (ranking_share, "ranking share"),
                          (monthly_story, "monthly story")):
        require(source, "parent: root.Window.window",
                f"{label} full-window parenting")
    require(single_share, "maximumLineCount: 2",
            "two-line single-app name")
    require(single_share, 'name: "close"', "single-share SVG close button")
    require(ranking_share, 'name: "close"', "ranking SVG close button")
    require(monthly_story, 'name: "close"', "monthly SVG close button")
    require(monthly_share, "monthlyShareSheet.height",
            "responsive monthly poster height")
    require(monthly_share, "SafeArea.margins.bottom + 12",
            "monthly share gesture-safe action inset")
    require(monthly_share, "id: monthlyShareSheet\n        anchors.fill: parent",
            "full-window monthly share surface")
    require(monthly_share, "radius: 0", "square full-window monthly surface")
    if 'color: "#46FFFFFF"' in monthly_share:
        raise AssertionError("monthly poster must not use the nested glass fact card")

    print("Mobile QML static checks passed")


if __name__ == "__main__":
    main()
