# SPDX-License-Identifier: GPL-3.0-or-later

from pathlib import Path
import xml.etree.ElementTree as ET


ROOT = Path(__file__).resolve().parents[1]
RESOURCE_DIR = ROOT / "resources"
PACKS = {
    "backgrounds.qrc": "resources/app/backgrounds/",
    "site-icons.qrc": "resources/app/icons/sites/",
    "monthly-recap.qrc": "resources/features/monthly-recap/",
}


def main():
    aliases = {}
    for manifest_name, expected_prefix in PACKS.items():
        manifest = RESOURCE_DIR / manifest_name
        root = ET.parse(manifest).getroot()
        files = root.findall("./qresource/file")
        if not files:
            raise AssertionError(f"empty resource pack: {manifest_name}")

        for entry in files:
            alias = entry.attrib.get("alias", "")
            if not alias.startswith(expected_prefix):
                raise AssertionError(
                    f"{manifest_name} contains cross-functional alias: {alias}"
                )
            if alias in aliases:
                raise AssertionError(
                    f"duplicate alias in {manifest_name} and {aliases[alias]}: {alias}"
                )
            aliases[alias] = manifest_name

            source = RESOURCE_DIR / (entry.text or "")
            if not source.is_file():
                raise AssertionError(f"missing resource source: {source}")

    if len(aliases) != 40:
        raise AssertionError(f"expected 40 bundled aliases, found {len(aliases)}")
    if any("memory-lake" in alias for alias in aliases):
        raise AssertionError("legacy Memory Lake art entered a functional pack")

    print("resource manifest static checks passed")


if __name__ == "__main__":
    main()
