import argparse
import struct
from pathlib import Path


RT_ICON = 3
RT_GROUP_ICON = 14


def resource_type_ids(executable: Path) -> set[int]:
    image = executable.read_bytes()
    if image[:2] != b"MZ":
        raise AssertionError(f"not a Windows PE executable: {executable}")

    pe_offset = struct.unpack_from("<I", image, 0x3C)[0]
    if image[pe_offset : pe_offset + 4] != b"PE\0\0":
        raise AssertionError(f"missing PE signature: {executable}")

    coff_offset = pe_offset + 4
    section_count = struct.unpack_from("<H", image, coff_offset + 2)[0]
    optional_size = struct.unpack_from("<H", image, coff_offset + 16)[0]
    section_offset = coff_offset + 20 + optional_size

    resource_offset = None
    for index in range(section_count):
        header_offset = section_offset + index * 40
        name = image[header_offset : header_offset + 8].rstrip(b"\0")
        if name == b".rsrc":
            resource_offset = struct.unpack_from("<I", image, header_offset + 20)[0]
            break

    if resource_offset is None:
        return set()

    named_count, id_count = struct.unpack_from("<HH", image, resource_offset + 12)
    entry_count = named_count + id_count
    type_ids: set[int] = set()
    for index in range(entry_count):
        name_or_id = struct.unpack_from(
            "<I", image, resource_offset + 16 + index * 8
        )[0]
        if name_or_id & 0x80000000 == 0:
            type_ids.add(name_or_id & 0xFFFF)
    return type_ids


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--exe",
        type=Path,
        default=Path(__file__).resolve().parents[1] / "build" / "TimeArc.exe",
    )
    args = parser.parse_args()

    type_ids = resource_type_ids(args.exe)
    assert RT_ICON in type_ids, f"{args.exe} has no native RT_ICON resource"
    assert RT_GROUP_ICON in type_ids, (
        f"{args.exe} has no native RT_GROUP_ICON resource"
    )
    print("windows_executable_icon_test: OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
