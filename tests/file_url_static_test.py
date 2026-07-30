"""Guards local-file URL construction in the desktop QML.

The bug this pins down: `_folderUrlOf` prefixed `file:///` unconditionally.
That is right for a Windows drive path (`C:/…`, no leading slash) and wrong
everywhere else — a Unix absolute path already starts with `/`, so the result
was `file:////Users/…`. Qt reads the extra slash as an empty authority plus a
`//Users/…` path, which is not a local file: `Qt.openUrlExternally` returns
false and the desktop shows nothing. "Open Folder" failed silently on macOS
and Linux for that one missing conditional.

Two other sites in the tree already had the cross-platform idiom, so this test
also keeps them from drifting back.
"""

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]

PROFILE = "qml/desktop/pages/DesktopProfilePage.qml"
MENU_BAR = "qml/desktop/MacMenuBar.qml"
MOBILE_ICON = "qml/mobile/components/MobileAppIcon.qml"


def read(rel):
    return (ROOT / rel).read_text(encoding="utf-8")


def require(text, needle, label):
    if needle not in text:
        raise AssertionError(f"missing {label}: {needle}")


def main():
    profile = read(PROFILE)

    match = re.search(r"function _folderUrlOf\(p\) \{(.*?)\n    \}", profile, re.S)
    if match is None:
        raise AssertionError(f"_folderUrlOf not found in {PROFILE}")
    body = match.group(1)

    # The whole fix is that the prefix is chosen, not fixed. A bare
    # `"file:///" + dir` is the regression.
    if re.search(r'return\s+"file:///"\s*\+', body):
        raise AssertionError(
            "_folderUrlOf hardcodes file:/// — Unix paths get four slashes and "
            "openUrlExternally returns false"
        )
    require(body, 'dir.charAt(0) === "/" ? "file://" : "file:///"',
            "conditional slash count in _folderUrlOf")

    # Spaces are not hypothetical: the default service directory is
    # ~/Library/Application Support/TimeArc/service.
    require(body, "encodeURI(dir)", "percent-encoding in _folderUrlOf")

    # A file sitting directly at the Unix root has lastIndexOf("/") === 0, so
    # the old `i > 0` guard handed back the file itself as its own directory.
    require(body, 'i === 0 ? "/"', "root-level file handled in _folderUrlOf")

    # openUrlExternally reports failure only through its return value; ignoring
    # it is what let this bug sit unnoticed.
    require(profile, "if (!Qt.openUrlExternally(root._folderUrlOf(p)))",
            "return value checked at the Open Folder call site")
    for lang_table, entry in (("en", "Could not open the folder"),
                              ("ja", "フォルダを開けませんでした")):
        js = read("qml/desktop/components/I18n.js")
        if f'"无法打开文件夹": "{entry}"' not in js:
            raise AssertionError(f"missing {lang_table} entry for the failure toast")

    # The two sites that were already correct.
    require(read(MENU_BAR), 'Qt.openUrlExternally("file://" + encodeURI(dir))',
            "cross-platform file URL in MacMenuBar")
    require(read(MOBILE_ICON),
            'value.charAt(0) === "/" ? "file://" + value : "file:///" + value',
            "cross-platform file URL in MobileAppIcon")

    print("file url static test: OK")


if __name__ == "__main__":
    main()
