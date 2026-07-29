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
    "设置迁移",
    "从设置文件恢复偏好，或复制一份便于排查的配置摘要。",
    "导入设置",
    "复制配置摘要",
    "数据库备份与恢复",
    "把整个使用数据库导出为单文件备份，或从备份恢复（恢复前请先停止后台采集）。",
    "备份数据库",
    "恢复数据库",
    "服务数据库目录",
    "选择后台服务写入 timearc_service.db 的目录；GUI 只更新位置指针，"
    "不移动数据库文件。完成后请重启采集。",
    "当前位置",
    "设置目录…",
    "还原默认位置",
    "当前数据概览",
    "今天的使用情况和本地记录规模。",
    "今日使用",
    "切换次数",
    "备忘页数",
    "番茄钟",
    "恢复与重置",
    "用于快速恢复视觉默认状态。",
    "恢复视觉默认",
    "清空本地缓存",
)

# Native dialogs are chrome the OS draws, but the strings are still ours.
FILE_DIALOG_STRINGS = (
    "导入设置 JSON",
    "选择数据库备份",
    "选择数据库存放目录",
    "JSON 文件 (*.json)",
    "数据库备份 (*.db)",
    "所有文件 (*)",
)

CJK = re.compile(r"[一-鿿]")
PAIR = re.compile(r'"((?:[^"\\]|\\.)*)":\s*"((?:[^"\\]|\\.)*)"')


def require(text, needle, label):
    if needle not in text:
        raise AssertionError(f"missing {label}: {needle}")


def table(js, name):
    """Parse one `var <name> = { ... }` object into a dict.

    Duplicate keys exist in `en` today; later wins, matching JS semantics.
    """
    match = re.search(r"var %s = \{(.*?)\n\}" % name, js, re.S)
    if match is None:
        raise AssertionError(f"missing table: {name}")
    return dict(PAIR.findall(match.group(1)))


def confirm_literals(profile):
    """Chinese literals handed to askConfirm()/showSavedAt() as dictionary keys.

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
        # Top-level string arguments only: nested sentence()/concatenation
        # fallbacks are Chinese by design and are not dictionary keys.
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
            if re.fullmatch(r'"(?:[^"\\]|\\.)*"', arg) and CJK.search(arg):
                found.add(arg[1:-1])
    for title in re.findall(r'showSavedAt\(\s*"((?:[^"\\]|\\.)*)"', profile):
        found.add(title)
    return found


def main():
    profile = (
        ROOT / "qml/desktop/pages/DesktopProfilePage.qml"
    ).read_text(encoding="utf-8")
    js = (ROOT / "qml/desktop/components/I18n.js").read_text(encoding="utf-8")

    en, ja = table(js, "en"), table(js, "ja")
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
        (EXPORT_TAB_STRINGS, "导入导出 card"),
        (FILE_DIALOG_STRINGS, "file dialog"),
    ):
        for source in group:
            if source not in en:
                raise AssertionError(f"missing en entry for {label}: {source}")
            if source not in ja:
                raise AssertionError(f"missing ja entry for {label}: {source}")

    # 4. Key collisions. The dictionaries are keyed by Chinese source text, so a
    # button reusing a word the navigation already owns inherits that meaning —
    # the "设置" confirm button rendered as "Settings" instead of "Set".
    if en.get("设置") != "Settings":
        raise AssertionError("nav 设置 no longer maps to Settings; recheck collisions")
    for arg in re.findall(r'askConfirm\([^)]*?,\s*"([^"]+)"\s*,\s*(?:true|false)',
                          profile, re.S):
        if arg == "设置":
            raise AssertionError(
                'confirm label "设置" collides with the navigation entry; '
                'use "设置此目录"'
            )

    # 5. Native file dialogs must bind, not hardcode. A raw list literal here is
    # the same class of bug as the confirm card: chrome that never re-renders.
    for hardcoded in ('nameFilters: ["', "nameFilters: ['"):
        if hardcoded in profile:
            raise AssertionError("file dialog nameFilters bypass tr()")

    print("i18n settings dialog static test: OK")
    print(f"  confirm literals: {len(literals)}")
    print(f"  en entries: {len(en)}  ja entries: {len(ja)}")


if __name__ == "__main__":
    main()
