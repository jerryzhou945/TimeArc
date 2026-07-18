from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(rel):
    return (ROOT / rel).read_text(encoding="utf-8")


def require(text, needle, label):
    if needle not in text:
        raise AssertionError(f"missing {label}: {needle}")


def main():
    main_cpp = read("src/main.cpp")
    ui_header = read("src/services/mobile/mobile_ui_service.h")
    android_bridge = read(
        "android/src/main/java/com/timearc/mobile/ui/MobileUiBridge.java"
    )
    shell = read("qml/mobile/MobileAppShell.qml")
    stats = read("qml/mobile/pages/MobileStatsPage.qml")
    app_icon = read("qml/mobile/components/MobileAppIcon.qml")
    share = read("qml/mobile/components/MobileShareOverlay.qml")

    require(main_cpp, '"mobileUiService"', "QML mobile UI service")
    require(ui_header, "Q_PROPERTY(QString wallpaperUrl",
            "wallpaper property")
    require(ui_header, "Q_INVOKABLE bool importWallpaper",
            "wallpaper import")
    require(ui_header, "Q_INVOKABLE bool shareImage", "share handoff")
    require(android_bridge, "FileProvider.getUriForFile",
            "Android FileProvider share")
    require(android_bridge, "Intent.ACTION_SEND", "Android share intent")
    require(shell, "Image.PreserveAspectCrop",
            "single shell wallpaper crop")
    require(shell, "wallpaperActive", "global wallpaper state")
    require(shell, "wallpaperUrl.toString().length > 0",
            "QUrl-safe wallpaper state")
    require(stats, '["week", "month", "year", "all"]',
            "four statistics ranges")
    require(app_icon, "appIconPath", "real app icon")
    require(share, "grabToImage", "shared preview/export component")
    require(share, "anonymous", "anonymous share mode")
    require(share, "function storyForShare()",
            "anonymous-safe share story")
    require(share, "text: root.storyForShare()",
            "share poster uses privacy-filtered story")
    story_block = share.split("function storyForShare()", 1)[1].split(
        "function exportAndShare()", 1
    )[0]
    if "displayName" in story_block:
        raise AssertionError(
            "anonymous-safe share story must not read the application name"
        )

    print("Mobile UI static checks passed")


if __name__ == "__main__":
    main()
