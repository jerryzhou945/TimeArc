"""Every translatable English source string must exist in the zh table.

The bug this pins down: under the old Chinese-keyed layout, a string reached
`tr()` with no entry in the `en` table and English mode rendered raw Chinese.
38 strings shipped that way, and the journal carries two separate incidents
(i18n-residual-chinese-copy, i18n-confirm-dialog). Nothing checked the call
sites against the tables, so each one was found by eye, on screen.

After the English-first inversion English can no longer be wrong — `t()`
returns the source unchanged — but Chinese and Japanese can silently fall back
to English. This test walks every `tr(...)` / `I18n.t(...)` call site and fails
when its source string is missing from `zh`.

It also fails on any Chinese literal left in QML outside the tables, which is
what "English-first" means mechanically: source text is English, translations
live in I18n.js and nowhere else.
"""

import json
import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
I18N = ROOT / "qml/shared/I18n.js"

CJK = re.compile(r"[一-鿿]")
TABLE = re.compile(r"^var (\w+) = \{$")
ENTRY = re.compile(r'^\s*"((?:[^"\\]|\\.)*)":\s*"((?:[^"\\]|\\.)*)",?$')

# Call sites whose first string argument is a translatable source string.
CALL = re.compile(
    r'(?:\btr|\bi18nMenu|I18n\.(?:t|tag|category|categoryList|menu))'
    r'\(\s*(?:[\w.]+\s*,\s*)?"((?:[^"\\]|\\.)*)"'
)

# Chinese is still the right answer inside these: the zh/ja translation tables
# themselves, and the per-language weekday arrays that cannot share a key.
ALLOW_CJK_VARS = ("zh", "ja", "menuZh", "menuJa", "sentencesZh", "sentencesJa",
                  "weekdayNarrowZh", "weekdayNarrowJa")

# A language picker lists every language in its own script, so that a user who
# cannot read the current UI language can still find their own.
ALLOW_LITERALS = {"简体中文", "日本語"}


def parse_tables(js):
    found, name = {}, None
    for line in js.split("\n"):
        m = TABLE.match(line)
        if m:
            name = m.group(1)
            found[name] = {}
            continue
        if name is None:
            continue
        if line.startswith("}"):
            name = None
            continue
        e = ENTRY.match(line)
        if e:
            found[name][e.group(1)] = e.group(2)
    return found


# Chinese is still correct inside these, for reasons that are not about UI copy:
#
#   macos_status_bar_icon.cpp  carries its own zh/en/ja table (QCocoa builds the
#                              status item natively, so it cannot use I18n.js);
#                              the Chinese column is the translation.
#   AppVisual.js               matches needles against real app names as the OS
#                              reports them - WeChat's Windows name IS 微信.
#                              Translating these would stop them matching.
ALLOW_CJK_FILES = {
    "src/services/macos/macos_status_bar_icon.cpp",
    "qml/desktop/components/AppVisual.js",
    "qml/shared/I18n.js",
}


def source_files():
    """Every file that can put text on screen.

    Scoped to *.qml only at first, which is how two regressions reached the
    screen: TagPalette.js kept matching on Chinese tag names after every caller
    had moved to English, and daily_card_service.cpp asked the rule table for
    the "zh" label. Neither is a .qml file, and neither is caught by the
    compiler, so nothing failed until it was rendered.
    """
    for pattern in ("qml/**/*.qml", "qml/**/*.js",
                    "src/**/*.cpp", "src/**/*.h", "src/**/*.mm"):
        for p in sorted(ROOT.glob(pattern)):
            if p.relative_to(ROOT).as_posix() in ALLOW_CJK_FILES:
                continue
            yield p


def qml_files():
    for p in sorted((ROOT / "qml").rglob("*.qml")):
        yield p


def main():
    tables = parse_tables(I18N.read_text(encoding="utf-8"))
    zh, ja = tables["zh"], tables["ja"]

    missing_zh, cjk_left = [], []

    # tr() means the I18n wrapper in QML, but QObject::tr() in C++ — a different
    # function with its own catalogs. Only QML call sites are checked against the
    # zh table; C++ is swept for stray Chinese literals alone.
    for path in qml_files():
        rel = path.relative_to(ROOT)
        for lineno, line in enumerate(path.read_text(encoding="utf-8").split("\n"), 1):
            code = re.sub(r"//.*$", "", line)
            for src in CALL.findall(code):
                if src and src not in zh and not CJK.search(src):
                    missing_zh.append((rel, lineno, src))

    for path in source_files():
        rel = path.relative_to(ROOT)
        for lineno, line in enumerate(path.read_text(encoding="utf-8", errors="replace").split("\n"), 1):
            code = re.sub(r"//.*$", "", line)
            for lit in re.findall(r'"((?:[^"\\]|\\.)*)"', code):
                if CJK.search(lit) and lit not in ALLOW_LITERALS:
                    cjk_left.append((rel, lineno, lit))

    problems = []
    if cjk_left:
        detail = "; ".join(f"{p}:{n} {s!r}" for p, n, s in cjk_left[:6])
        problems.append(
            f"{len(cjk_left)} Chinese literal(s) remain in source. Source "
            f"text must be English; translations belong in I18n.js: {detail}"
        )
    if missing_zh:
        detail = "; ".join(f"{p}:{n} {s!r}" for p, n, s in missing_zh[:6])
        problems.append(
            f"{len(missing_zh)} source string(s) reach tr() with no zh entry, "
            f"so Chinese mode shows English: {detail}"
        )

    if problems:
        raise AssertionError("\n\n".join(problems))

    # A template with {placeholders} must be called with a params object.
    # Stripping the dead `fallback` argument during the inversion silently ate
    # the `params` argument at ten call sites, which would have rendered raw
    # "{count}" on screen.
    placeholder_keys = {k for k, v in tables["sentencesEn"].items() if "{" in v}
    bad_calls = []
    for path in qml_files():
        text = path.read_text(encoding="utf-8")
        for m in re.finditer(r'\bsentence\(\s*(?:[\w.]+\s*,\s*)?"(\w+)"\s*([,)])', text):
            key, nxt = m.group(1), m.group(2)
            if key in placeholder_keys and nxt == ")":
                line = text[: m.start()].count("\n") + 1
                bad_calls.append((path.relative_to(ROOT), line, key))
    if bad_calls:
        detail = "; ".join(f"{p}:{n} {k!r}" for p, n, k in bad_calls[:6])
        raise AssertionError(
            f"{len(bad_calls)} sentence() call(s) pass no params for a template "
            f"that has placeholders, so {{...}} renders literally: {detail}"
        )

    # zh and ja must cover the same keys. Call sites that pass a variable —
    # tr(modelData.subtitle) — cannot be resolved statically, so a key reachable
    # only that way is invisible to the check above; "Dashboard" had Japanese
    # and no Chinese for exactly that reason. Symmetry catches it without having
    # to resolve the argument.
    only_zh = sorted(set(zh) - set(ja))
    only_ja = sorted(set(ja) - set(zh))
    if only_zh or only_ja:
        raise AssertionError(
            f"{len(only_zh)} key(s) have Chinese but no Japanese "
            f"({only_zh[:4]}) and {len(only_ja)} have Japanese but no Chinese "
            f"({only_ja[:4]}); one language would silently fall back to English"
        )

    # Japanese gaps are reported, not fatal: t() falls back to the English
    # source, which is a legible result rather than a wrong-language one.
    gaps = sorted(set(zh) - set(ja))
    print(f"i18n coverage OK — {len(zh)} zh entries, {len(ja)} ja entries")
    if gaps:
        print(f"note: {len(gaps)} key(s) have no Japanese yet (fall back to English)")


if __name__ == "__main__":
    main()
