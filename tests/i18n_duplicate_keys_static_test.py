"""Guards against duplicate keys reappearing in the I18n.js translation tables.

The bug this pins down: a table had grown to 608 entries of which 84 keys were
declared twice — a whole block of settings-page strings pasted a second time,
plus a second copy of the stats-card labels. A JS object literal keeps the
*last* value, so every earlier copy was dead code, and 15 of those pairs had
drifted apart: someone edited the first copy and the string on screen never
changed.

Duplicates are invisible in review (each table is one long alphabet-free list),
so this test counts keys per table and fails on any repeat.

Since the English-first inversion the tables are keyed by the English source
string and named for their *target* language (zh, ja), not the source.
"""

import collections
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]

TABLE = re.compile(r"^var (\w+) = \{$")
ENTRY = re.compile(r'^\s*"((?:[^"\\]|\\.)*)":\s*"((?:[^"\\]|\\.)*)",?$')

# Every table keyed by an English source string, plus the language it targets.
SOURCE_KEYED = ("zh", "ja", "menuZh", "menuJa")
# Templates keyed by name rather than by source text.
TEMPLATE_KEYED = ("sentencesEn", "sentencesZh", "sentencesJa")


def tables(js):
    """Parse every `var <name> = { ... }` object into a list of (key, line).

    Deliberately keeps duplicates instead of collapsing into a dict — spotting
    them is the whole point.
    """
    found = collections.OrderedDict()
    name = None
    for lineno, line in enumerate(js.split("\n"), 1):
        match = TABLE.match(line)
        if match:
            name = match.group(1)
            found[name] = []
            continue
        if name is None:
            continue
        if line.startswith("}"):
            name = None
            continue
        entry = ENTRY.match(line)
        if entry:
            found[name].append((entry.group(1), lineno))
        elif line.strip() and not line.strip().startswith("//"):
            # A multi-line or single-quoted entry would slip past the counter
            # and hide a duplicate, so treat anything unparsed as a failure.
            raise AssertionError(f"unparsed line {lineno} in {name}: {line}")
    if not found:
        raise AssertionError("no translation tables found")
    return found


def main():
    js = (ROOT / "qml/shared/I18n.js").read_text(encoding="utf-8")
    parsed = tables(js)

    for expected in SOURCE_KEYED + TEMPLATE_KEYED:
        if expected not in parsed:
            raise AssertionError(f"missing table: {expected}")

    for name, entries in parsed.items():
        counts = collections.Counter(key for key, _ in entries)
        dupes = sorted(key for key, count in counts.items() if count > 1)
        if dupes:
            detail = "; ".join(
                "%r at lines %s" % (key, [ln for k, ln in entries if k == key])
                for key in dupes[:5]
            )
            raise AssertionError(
                f"{name} declares {len(dupes)} duplicated key(s); the later "
                f"value silently wins and the earlier one is dead: {detail}"
            )

    # Every Japanese template must correspond to a real English one, or it is
    # keyed to a name sentence() will never ask for.
    en_keys = {key for key, _ in parsed["sentencesEn"]}
    for name in ("sentencesZh", "sentencesJa"):
        orphans = sorted({key for key, _ in parsed[name]} - en_keys)
        if orphans:
            raise AssertionError(
                f"{name} has {len(orphans)} template(s) with no sentencesEn "
                f"counterpart, so they are unreachable: {orphans[:5]}"
            )

    print(
        "i18n tables OK — "
        + ", ".join(f"{n} {len(parsed[n])}" for n in SOURCE_KEYED + TEMPLATE_KEYED)
    )


if __name__ == "__main__":
    main()
