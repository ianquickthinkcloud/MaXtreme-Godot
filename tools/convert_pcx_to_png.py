#!/usr/bin/env python3
"""
PCX to PNG Converter for MaXtreme
==================================
Recursively converts all PCX files under a data directory to PNG format.

M.A.X.R. uses 8-bit indexed PCX files with palette index 0 as the
transparent color. This script converts them to RGBA PNGs with proper
alpha transparency.

Usage:
    python3 tools/convert_pcx_to_png.py                       # Convert data/ (default)
    python3 tools/convert_pcx_to_png.py --data-dir data/      # Explicit path
    python3 tools/convert_pcx_to_png.py --force               # Re-convert all
    python3 tools/convert_pcx_to_png.py --no-transparency     # Skip transparency
    python3 tools/convert_pcx_to_png.py --dry-run             # Preview only
"""

import argparse
import os
import sys
import time
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    print("ERROR: Pillow is required. Install with: pip3 install Pillow")
    sys.exit(1)


def convert_pcx_to_png(pcx_path: Path, png_path: Path, apply_transparency: bool) -> bool:
    """
    Convert a single PCX file to PNG.

    Args:
        pcx_path: Path to the source PCX file.
        png_path: Path to the output PNG file.
        apply_transparency: If True, treat palette index 0 as transparent.

    Returns:
        True if conversion succeeded, False otherwise.
    """
    img = Image.open(pcx_path)

    if apply_transparency and img.mode == "P":
        # Convert palette image to RGBA with index 0 as transparent.
        # Get the raw pixel data as indices.
        pixel_data = img.load()
        width, height = img.size

        # Convert to RGBA first
        rgba = img.convert("RGBA")
        rgba_data = rgba.load()

        # Set pixels with palette index 0 to fully transparent
        for y in range(height):
            for x in range(width):
                if pixel_data[x, y] == 0:
                    r, g, b, _ = rgba_data[x, y]
                    rgba_data[x, y] = (r, g, b, 0)

        rgba.save(png_path, "PNG", optimize=True)
    elif img.mode == "P":
        # Palette mode but no transparency -- convert to RGB
        img.convert("RGB").save(png_path, "PNG", optimize=True)
    else:
        # Already RGB/RGBA or other mode -- save directly
        img.save(png_path, "PNG", optimize=True)

    return True


def should_convert(pcx_path: Path, png_path: Path, force: bool) -> bool:
    """Check if conversion is needed based on file existence and modification times."""
    if force:
        return True
    if not png_path.exists():
        return True
    # Re-convert if PCX is newer than PNG
    return pcx_path.stat().st_mtime > png_path.stat().st_mtime


def find_pcx_files(data_dir: Path) -> list[Path]:
    """Recursively find all PCX files under the data directory."""
    pcx_files = sorted(data_dir.rglob("*.pcx"))
    # Also catch uppercase .PCX extension
    pcx_files += sorted(data_dir.rglob("*.PCX"))
    # Deduplicate (in case filesystem is case-insensitive)
    seen = set()
    unique = []
    for p in pcx_files:
        resolved = p.resolve()
        if resolved not in seen:
            seen.add(resolved)
            unique.append(p)
    return unique


def main():
    parser = argparse.ArgumentParser(
        description="Convert PCX files to PNG for MaXtreme.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    parser.add_argument(
        "--data-dir",
        type=Path,
        default=Path("data"),
        help="Root directory to scan for PCX files (default: data/)",
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Re-convert even if PNG already exists and is newer",
    )
    parser.add_argument(
        "--no-transparency",
        action="store_true",
        help="Skip palette index 0 transparency conversion",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="List files that would be converted without writing",
    )
    args = parser.parse_args()

    data_dir = args.data_dir.resolve()
    if not data_dir.is_dir():
        print(f"ERROR: Data directory not found: {data_dir}")
        sys.exit(1)

    apply_transparency = not args.no_transparency

    print(f"PCX to PNG Converter for MaXtreme")
    print(f"==================================")
    print(f"Data directory: {data_dir}")
    print(f"Transparency:   {'index 0 -> alpha' if apply_transparency else 'disabled'}")
    print(f"Force:          {args.force}")
    print(f"Dry run:        {args.dry_run}")
    print()

    # Find all PCX files
    pcx_files = find_pcx_files(data_dir)
    total = len(pcx_files)
    print(f"Found {total} PCX files")
    print()

    if total == 0:
        print("Nothing to convert.")
        return

    converted = 0
    skipped = 0
    failed = 0
    start_time = time.time()

    for i, pcx_path in enumerate(pcx_files, 1):
        png_path = pcx_path.with_suffix(".png")
        relative = pcx_path.relative_to(data_dir)

        if not should_convert(pcx_path, png_path, args.force):
            skipped += 1
            continue

        if args.dry_run:
            print(f"  [{i}/{total}] Would convert: {relative}")
            converted += 1
            continue

        try:
            convert_pcx_to_png(pcx_path, png_path, apply_transparency)
            converted += 1
            # Print progress every 50 files or for the last file
            if converted % 50 == 0 or i == total:
                print(f"  [{i}/{total}] Converted: {relative}")
        except Exception as e:
            failed += 1
            print(f"  [{i}/{total}] FAILED: {relative} -- {e}")

    elapsed = time.time() - start_time

    print()
    print(f"Done in {elapsed:.1f}s")
    print(f"  Converted: {converted}")
    print(f"  Skipped:   {skipped}")
    print(f"  Failed:    {failed}")
    print(f"  Total:     {total}")

    if failed > 0:
        sys.exit(1)


if __name__ == "__main__":
    main()
