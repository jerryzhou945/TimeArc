#!/usr/bin/env python3
"""Generate the native Windows ICO from the geometry in TimeArc.svg."""

from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "resources" / "bundle" / "windows" / "TimeArc.ico"
CANVAS = 1024
SCALE = CANVAS / 64
SIZES = tuple((size, size) for size in (16, 24, 32, 48, 64, 128, 256))


def scaled(value: float) -> int:
    return round(value * SCALE)


def gradient() -> Image.Image:
    start = (159, 231, 238, 255)  # #9FE7EE
    end = (155, 139, 255, 255)  # #9B8BFF
    image = Image.new("RGBA", (CANVAS, CANVAS))
    pixels = image.load()
    low = scaled(6.25)
    span = scaled(51.5) * 2
    for y in range(CANVAS):
        for x in range(CANVAS):
            ratio = max(0.0, min(1.0, ((x - low) + (y - low)) / span))
            pixels[x, y] = tuple(
                round(start[channel] * (1 - ratio) + end[channel] * ratio)
                for channel in range(4)
            )
    return image


def render_master() -> Image.Image:
    image = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    base_mask = Image.new("L", image.size, 0)
    ImageDraw.Draw(base_mask).rounded_rectangle(
        (scaled(6.25), scaled(6.25), scaled(57.75), scaled(57.75)),
        radius=scaled(11.56),
        fill=255,
    )
    image.alpha_composite(Image.composite(gradient(), image, base_mask))

    draw = ImageDraw.Draw(image, "RGBA")
    draw.rounded_rectangle(
        (scaled(7), scaled(7), scaled(57), scaled(57)),
        radius=scaled(10.81),
        outline=(255, 255, 255, 89),
        width=scaled(1.5),
    )
    glyph = (14, 21, 48, 255)  # #0E1530
    draw.rounded_rectangle(
        (scaled(18.5), scaled(18.5), scaled(45.5), scaled(25.5)),
        radius=scaled(2.2),
        fill=glyph,
    )
    draw.rounded_rectangle(
        (scaled(28.5), scaled(18.5), scaled(35.5), scaled(45.5)),
        radius=scaled(2.2),
        fill=glyph,
    )
    return image


def main() -> int:
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    render_master().save(OUTPUT, format="ICO", sizes=SIZES)
    print(f"generate-windows-icon: OK -> {OUTPUT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
