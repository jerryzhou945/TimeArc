from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(relative_path):
    return (ROOT / relative_path).read_text(encoding="utf-8")


def require(text, needle, label):
    if needle not in text:
        raise AssertionError(f"missing {label}: {needle}")


def require_file(relative_path):
    path = ROOT / relative_path
    if not path.is_file():
        raise AssertionError(f"missing Android launch resource: {relative_path}")
    return path


def main():
    manifest = read("android/AndroidManifest.xml")
    require(manifest, 'android:icon="@mipmap/ic_launcher"',
            "standard launcher icon")
    require(manifest, 'android:roundIcon="@mipmap/ic_launcher_round"',
            "round launcher icon")
    if 'android:theme="@style/TimeArcLaunchTheme"' in manifest:
        raise AssertionError(
            "QtActivity must retain the Qt default theme for compatibility")

    required_resources = (
        "android/res/drawable-nodpi/timearc_icon_artwork.png",
        "android/res/drawable/timearc_icon_foreground.xml",
        "android/res/drawable/timearc_splash_icon.xml",
        "android/res/mipmap-anydpi-v26/ic_launcher.xml",
        "android/res/mipmap-anydpi-v26/ic_launcher_round.xml",
        "android/res/mipmap-mdpi/ic_launcher.png",
        "android/res/mipmap-hdpi/ic_launcher.png",
        "android/res/mipmap-xhdpi/ic_launcher.png",
        "android/res/mipmap-xxhdpi/ic_launcher.png",
        "android/res/mipmap-xxxhdpi/ic_launcher.png",
        "android/res/values/colors.xml",
        "android/res/values/styles.xml",
        "android/res/values-v31/styles.xml",
        "qml/mobile/components/MobileLaunchOverlay.qml",
    )
    for resource in required_resources:
        require_file(resource)

    adaptive = read("android/res/mipmap-anydpi-v26/ic_launcher.xml")
    require(adaptive, '<background android:drawable="@color/timearc_icon_background"',
            "adaptive icon background")
    require(adaptive, '<foreground android:drawable="@drawable/timearc_icon_foreground"',
            "adaptive icon foreground")

    api31_theme = read("android/res/values-v31/styles.xml")
    require(api31_theme, "windowSplashScreenBackground",
            "Android 12 splash background")
    require(api31_theme, "windowSplashScreenAnimatedIcon",
            "Android 12 splash icon")
    require(api31_theme, 'parent="TimeArcAppTheme"',
            "Android 12 post-splash application theme")

    overlay = read("qml/mobile/components/MobileLaunchOverlay.qml")
    require(overlay, "property bool reducedMotion",
            "reduced-motion input")
    require(overlay, "function begin()", "explicit post-preference start")
    require(overlay, "signal finished()", "bounded completion signal")
    require(overlay, "running: root.started && !root.reducedMotion",
            "motion bypass")
    require(overlay, "duration: 960", "sub-1.2-second launch motion")
    if "loops: Animation.Infinite" in overlay:
        raise AssertionError("launch animation must not loop indefinitely")

    shell = read("qml/mobile/MobileAppShell.qml")
    require(shell, "MobileLaunchOverlay", "mobile launch overlay instance")
    require(shell, "reducedMotion: mobileTheme.reducedMotion",
            "saved reduced-motion preference")
    require(shell, "onFinished:", "launch overlay completion handling")
    require(shell, "launchOverlay.begin()",
            "launch start after saved preferences")

    qml_cmake = read("qml/CMakeLists.txt")
    require(qml_cmake, "MobileLaunchOverlay.qml",
            "launch overlay QML registration")

    print("Android launch experience static checks passed")


if __name__ == "__main__":
    main()
