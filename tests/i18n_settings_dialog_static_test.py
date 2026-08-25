"""Guards the i18n path of the settings confirm card and the 导入导出 cards.

The bug this pins down: `confirmCard` rendered `titleText`/`msgText` as raw
Chinese while its buttons went through `tr()` via GhostBtn, so English mode
showed "Cancel" next to "打开文件夹" in the same dialog. Three separate holes
had to line up for that — the missing `tr()` at the render site, missing
dictionary entries, and message bodies concatenated in JS (a runtime-built
string can never be a dictionary key). This test covers all three so the next
dialog added here cannot reintroduce any of them.
"""

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]

# Dynamic bodies are composed at runtime, so they go through sentence()
# templates instead of the source-keyed dictionaries.
SENTENCE_KEYS = ("savedToPath", "backupPreview", "relocateSuccess")

# Every user-visible literal in the 导入导出 section (SettingsCard titles and
# descriptions, buttons, metric tiles). These are what the screenshot showed
# half-translated.
EXPORT_TAB_STRINGS = (
    "Settings Migration",
    "Restore preferences from a settings file, or copy a troubleshooting summary.",
    "Import Settings",
    "Copy Config Summary",
    "Database Backup & Restore",
    "Export the usage database as a backup file, or restore from one. Stop collection before restoring.",
    "Back Up Database",
    "Restore Database",
    "Service Database Folder",
    "Choose the folder where the background service writes timearc_service.db. TimeArc only updates the location pointer and never moves the database file. Restart collection when you are done.",
    "Current Location",
    "Set Folder…",
    "Restore Default Location",
    "Current Data Overview",
    "Today's usage and local record size.",
    "Today Usage",
    "Switches",
    "Memo Pages",
    "Pomodoro",
    "Restore & Reset",
    "Quickly restore visual defaults.",
    "Restore Visual Defaults",
    "Clear Local Cache",
)

# Native dialogs are chrome the OS draws, but the strings are still ours.
FILE_DIALOG_STRINGS = (
    "Import Settings JSON",
    "Choose Database Backup",
    "Choose Database Folder",
    "JSON files (*.json)",
    "Database backups (*.db)",
    "All files (*)",
)

CJK = re.compile(r"[一-鿿]")
PAIR = re.compile(r'"((?:[^"\\]|\\.)*)":\s*"((?:[^"\\]|\\.)*)"')


def require(text, needle, label):
    if needle not in text:
        raise AssertionError(f"missing {label}: {needle}")


def table(js, name):
    """Parse one `var <name> = { ... }` object into a dict.

    Collapsing into a dict matches JS semantics (later key wins) but would also
    hide a re-declared key; `i18n_duplicate_keys_static_test.py` guards that.
    """
    match = re.search(r"var %s = \{(.*?)\n\}" % name, js, re.S)
    if match is None:
        raise AssertionError(f"missing table: {name}")
    return dict(PAIR.findall(match.group(1)))


def confirm_literals(profile):
    """Source literals handed to askConfirm()/showSavedAt() as dictionary keys.

    Titles and button labels are static source strings, so they must resolve
    through the dictionaries. Bodies may be sentence() calls; those are checked
    separately and are skipped here.
    """
    found = set()
    for call in re.finditer(r"askConfirm\(", profile):
        depth, i = 0, call.end() - 1
        while i < len(profile):
            if profile[i] == "(":
                depth += 1
            elif profile[i] == ")":
                depth -= 1
                if depth == 0:
                    break
            i += 1
        body = profile[call.end() : i]
        # Top-level string arguments only; nested sentence() calls are keyed
        # by template name and are checked separately.
        args, depth, start = [], 0, 0
        for pos, ch in enumerate(body):
            if ch in "([{":
                depth += 1
            elif ch in ")]}":
                depth -= 1
            elif ch == "," and depth == 0:
                args.append(body[start:pos])
                start = pos + 1
        args.append(body[start:])
        for index in (0, 2):  # title, confirmLabel
            if index >= len(args):
                continue
            arg = args[index].strip()
            if re.fullmatch(r'"(?:[^"\\]|\\.)*"', arg) and len(arg) > 2:
                found.add(arg[1:-1])
    for title in re.findall(r'showSavedAt\(\s*"((?:[^"\\]|\\.)*)"', profile):
        found.add(title)
    return found


def main():
    profile = (
        ROOT / "qml/desktop/pages/DesktopProfilePage.qml"
    ).read_text(encoding="utf-8")
    js = (ROOT / "qml/shared/I18n.js").read_text(encoding="utf-8")

    # English is the source language: tables are keyed by the English string
    # and named for the language they translate into.
    zh, ja = table(js, "zh"), table(js, "ja")
    sentences_en, sentences_ja = table(js, "sentencesEn"), table(js, "sentencesJa")

    # 1. The render site. Without these two the dictionaries are dead weight:
    # the card would draw the Chinese source no matter what language is set.
    require(profile, "text: root.tr(confirmCard.titleText)",
            "tr() on the confirm card title")
    require(profile, "text: root.tr(confirmCard.msgText)",
            "tr() on the confirm card message")

    # 2. Runtime-built bodies route through sentence() in both languages.
    for key in SENTENCE_KEYS:
        require(profile, f'sentence("{key}"', f"sentence() call for {key}")
        if key not in sentences_en:
            raise AssertionError(f"missing sentencesEn entry: {key}")
        if key not in sentences_ja:
            raise AssertionError(f"missing sentencesJa entry: {key}")

    # 3. Static strings resolve in every language. ja falls back to en, but an
    # explicit entry is what keeps Japanese from silently reading as English.
    literals = confirm_literals(profile)
    if len(literals) < 17:
        raise AssertionError(
            f"confirm-dialog literal scan found only {len(literals)}; parser drifted"
        )
    for group, label in (
        (sorted(literals), "confirm dialog"),
        (EXPORT_TAB_STRINGS, "import/export card"),
        (FILE_DIALOG_STRINGS, "file dialog"),
    ):
        for source in group:
            if source not in zh:
                raise AssertionError(f"missing zh entry for {label}: {source}")
            if source not in ja:
                raise AssertionError(f"missing ja entry for {label}: {source}")

    # 4. Key collisions. The dictionaries are keyed by the English source, so a
    # confirm button reusing a word the navigation already owns inherits that
    # meaning. Same bug as before, mirrored by the inversion: the collision is
    # now between English sources rather than Chinese ones.
    if zh.get("Settings") != "设置":
        raise AssertionError("nav Settings no longer maps to 设置; recheck collisions")
    for arg in re.findall(r'askConfirm\([^)]*?,\s*"([^"]+)"\s*,\s*(?:true|false)',
                          profile, re.S):
        if arg == "Settings":
            raise AssertionError(
                'confirm label "Settings" collides with the navigation entry; '
                'use a distinct source string'
            )

    # 5. Native file dialogs must bind, not hardcode. A raw list literal here is
    # the same class of bug as the confirm card: chrome that never re-renders.
    for hardcoded in ('nameFilters: ["', "nameFilters: ['"):
        if hardcoded in profile:
            raise AssertionError("file dialog nameFilters bypass tr()")

    print("i18n settings dialog static test: OK")
    print(f"  confirm literals: {len(literals)}")
    print(f"  zh entries: {len(zh)}  ja entries: {len(ja)}")


if __name__ == "__main__":
    main()
