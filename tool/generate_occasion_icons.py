#!/usr/bin/env python3
"""Generates occasion app-icon variants for the "occasion-driven home-screen
app icon" feature (see the migration plan / QuickMandi_Branding_* docs).

Two modes:

1. No arguments — (re)generates the placeholder variants in `VARIANTS`
   below (the existing `app_logo.png` composited onto a colored
   rounded-square background). Used to prove the mechanism end-to-end
   before real artwork exists.

       python3 tool/generate_occasion_icons.py

2. `--name <Key> --source <path-to-1024x1024-image>` — wires in a *real*
   icon (e.g. one an Admin uploaded via QuickyAdmin's Occasion form,
   `appIconImageUrl`) as-is, resized to every platform size, no
   compositing. `<Key>` must match the `appIconKey` value stored on the
   Occasion doc exactly (it's what QuickyAdmin writes to
   `app_config/current_theme.appIconKey` on activation, and what the two
   native handlers below key off of).

       python3 tool/generate_occasion_icons.py --name Dasara --source ~/Downloads/dasara_icon.png

Either way, after running this you still need to (once per *new* key):
  - Add the key to `ios/Runner/Info.plist`'s `CFBundleAlternateIcons`.
  - Add an `<activity-alias>` for it in
    `android/app/src/main/AndroidManifest.xml`.
  - Add it to the `aliases` map in
    `android/.../MainActivity.kt`'s `setLauncherIcon`.
  - Add it to `kBundledAppIcons` in QuickyAdmin's `occasion.dart` (so its
    picker shows the "✓ live" quick-pick chip instead of free text).
Then reinstall the user app once — after that, activating that key from
QuickyAdmin switches the icon live with no further release needed.

Requires Pillow (`pip3 install pillow`).
"""

import argparse
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
LOGO_PATH = ROOT / "assets/images/app_logo.png"

# key -> (PascalCase name used in iOS/Android file+identifier naming, background hex)
# Only used by the no-argument placeholder mode.
VARIANTS = {
    "festive_gold": ("FestiveGold", "#F5A623"),
    "festive_red": ("FestiveRed", "#C62828"),
}

MASTER_SIZE = 1024
LOGO_SCALE = 0.66  # logo occupies ~66% of the canvas, matching typical adaptive-icon safe-zone padding

ANDROID_DENSITIES = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}

# Adaptive-icon canvas per density (108dp x the density multiplier) — same
# sizing the project's own default icon uses (verified against
# mipmap-xxxhdpi/ic_launcher_adaptive_back.png: 432px). Used for the
# `<adaptive-icon>` background layer below, so Android draws these at full
# resolution instead of upscaling the small legacy-density PNGs above.
ANDROID_ADAPTIVE_DENSITIES = {
    "mipmap-mdpi": 108,
    "mipmap-hdpi": 162,
    "mipmap-xhdpi": 216,
    "mipmap-xxhdpi": 324,
    "mipmap-xxxhdpi": 432,
}

TRANSPARENT_FOREGROUND_DRAWABLE = "ic_launcher_transparent"

# How much of the adaptive-icon canvas the artwork fills before Android's own
# mask (circle/squircle/rounded-square, launcher-dependent) is applied on
# top. 1.0 (full bleed) let the mask crop noticeably into the design; 0.9
# leaves a thin margin so the mask only trims the very edge.
ADAPTIVE_FILL = 0.7

IOS_SIZES = {"@2x": 120, "@3x": 180}


def build_placeholder_master(bg_hex: str) -> Image.Image:
    canvas = Image.new("RGBA", (MASTER_SIZE, MASTER_SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)
    radius = int(MASTER_SIZE * 0.22)  # rounded-square, similar curvature to the platforms' own masks
    draw.rounded_rectangle([0, 0, MASTER_SIZE, MASTER_SIZE], radius=radius, fill=bg_hex)

    logo = Image.open(LOGO_PATH).convert("RGBA")
    logo_size = int(MASTER_SIZE * LOGO_SCALE)
    logo = logo.resize((logo_size, logo_size), Image.LANCZOS)
    offset = ((MASTER_SIZE - logo_size) // 2, (MASTER_SIZE - logo_size) // 2)
    canvas.alpha_composite(logo, offset)
    return canvas


def ensure_transparent_foreground_drawable():
    """A single shared fully-transparent adaptive-icon foreground layer,
    reused by every occasion variant below — the actual artwork lives
    entirely in each variant's own background layer, since the source icons
    are already complete circular badge designs, not a logo-on-a-mat that
    needs separate front/back layers."""
    drawable_dir = ROOT / "android/app/src/main/res/drawable"
    drawable_dir.mkdir(parents=True, exist_ok=True)
    path = drawable_dir / f"{TRANSPARENT_FOREGROUND_DRAWABLE}.xml"
    if path.exists():
        return
    path.write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<shape xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <solid android:color="#00000000"/>\n'
        "</shape>\n"
    )


def pad_to_fill(img: Image.Image, fill: float, bg_hex: str) -> Image.Image:
    """Returns a same-size canvas with `img` shrunk to `fill` fraction of it
    and centered, padded with `bg_hex` — used for the adaptive background
    layer so Android's own icon mask doesn't crop into the artwork."""
    size = img.size[0]
    canvas = Image.new("RGBA", (size, size), bg_hex)
    inner = int(size * fill)
    resized = img.resize((inner, inner), Image.LANCZOS)
    offset = ((size - inner) // 2, (size - inner) // 2)
    canvas.alpha_composite(resized, offset)
    return canvas


def emit_variant(key: str, pascal_name: str, master: Image.Image, fallback_bg_hex: str):
    """Resizes `master` (any size — upscaled if smaller than a target,
    downscaled if larger) to every platform size and writes it under `key`.
    `fallback_bg_hex` fills the transparent-pixel matte for iOS's
    must-be-opaque requirement — a real uploaded icon usually has no
    transparency at all, but this makes the script safe either way.

    `key` is used verbatim for the iOS/Dart/Firestore identifier (it must
    match `appIconKey` exactly, which may be mixed-case, e.g. "Dasara").
    Android resource *file* names are stricter — lowercase a-z/0-9/underscore
    only — so the mipmap filename is always the lowercased key, independent
    of what's stored as the activation key.

    Also emits a proper `<adaptive-icon>` (API 26+) for Android: without one,
    Android auto-wraps a plain legacy PNG launcher icon by shrinking it to
    ~66% and padding/shadowing it into a synthetic safe zone — which is what
    made the first cut of these icons look small with a lot of surrounding
    white space. The adaptive background layer here is the artwork at
    `ADAPTIVE_FILL` (90%) of the canvas with a fully transparent foreground
    layer, so Android's own mask (e.g. a circle) only trims the thin margin
    left around it instead of cropping into the design."""
    master = master.convert("RGBA")
    android_key = key.lower()

    for folder, size in ANDROID_DENSITIES.items():
        out_dir = ROOT / "android/app/src/main/res" / folder
        out_dir.mkdir(parents=True, exist_ok=True)
        master.resize((size, size), Image.LANCZOS).save(out_dir / f"ic_launcher_{android_key}.png")

    ensure_transparent_foreground_drawable()
    for folder, size in ANDROID_ADAPTIVE_DENSITIES.items():
        out_dir = ROOT / "android/app/src/main/res" / folder
        out_dir.mkdir(parents=True, exist_ok=True)
        padded = pad_to_fill(master.resize((size, size), Image.LANCZOS), ADAPTIVE_FILL, fallback_bg_hex)
        padded.save(out_dir / f"ic_launcher_{android_key}_background.png")
    anydpi_dir = ROOT / "android/app/src/main/res/mipmap-anydpi-v26"
    anydpi_dir.mkdir(parents=True, exist_ok=True)
    (anydpi_dir / f"ic_launcher_{android_key}.xml").write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        f'  <background android:drawable="@mipmap/ic_launcher_{android_key}_background"/>\n'
        f'  <foreground android:drawable="@drawable/{TRANSPARENT_FOREGROUND_DRAWABLE}"/>\n'
        "</adaptive-icon>\n"
    )

    ios_dir = ROOT / "ios/Runner"
    ios_dir.mkdir(parents=True, exist_ok=True)
    for suffix, size in IOS_SIZES.items():
        resized = master.resize((size, size), Image.LANCZOS)
        opaque = Image.new("RGB", resized.size, fallback_bg_hex)
        opaque.paste(resized, mask=resized.split()[3])
        opaque.save(ios_dir / f"AppIcon-{pascal_name}{suffix}.png")

    print(f"Generated {key} -> Android 5 densities + iOS @2x/@3x (AppIcon-{pascal_name})")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--name", help="Icon key (must match the Occasion's appIconKey exactly)")
    parser.add_argument("--source", help="Path to the real 1024x1024 (or similar) source icon image")
    args = parser.parse_args()

    if args.name or args.source:
        if not (args.name and args.source):
            raise SystemExit("--name and --source must be given together")
        source_path = Path(args.source).expanduser()
        if not source_path.exists():
            raise SystemExit(f"Source image not found: {source_path}")
        master = Image.open(source_path)
        emit_variant(args.name, args.name, master, "#FFFFFF")
        return

    if not LOGO_PATH.exists():
        raise SystemExit(f"Base logo not found: {LOGO_PATH}")
    for key, (pascal_name, bg_hex) in VARIANTS.items():
        emit_variant(key.replace("_", "").replace("-", "") and key, pascal_name, build_placeholder_master(bg_hex), bg_hex)
        # (key stays as-is for these two — see the original Android/iOS filenames already shipped)


if __name__ == "__main__":
    main()
