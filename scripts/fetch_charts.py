#!/usr/bin/env python3
"""
fetch_charts.py — WA Transport chart import pipeline.

Reads scripts/wa_charts.toml, downloads each PDF, writes per-chart
JSON georef sidecar, regenerates aggregate manifest.json.

Run from repo root:
    python3 scripts/fetch_charts.py [--skip-download]

Requires Python 3.11+ (built-in tomllib). No third-party deps.

Optional auto-georef extraction via PyMuPDF is supported if installed;
otherwise sidecar corners come from the TOML manifest entries directly.

Usage:
    --skip-download : reuse existing PDFs in Samudra/Charts/, only
                       regenerate sidecars + manifest.json
    --dry-run       : print actions, write nothing
    --verbose       : noisier logging

Exit codes:
    0  success (all entries processed)
    1  network / file error
    2  validation error
"""

from __future__ import annotations

import argparse
import json
import sys
import tomllib
import urllib.error
import urllib.request
from dataclasses import dataclass
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
TOML_PATH = REPO_ROOT / "scripts" / "wa_charts.toml"
CHARTS_DIR = REPO_ROOT / "Samudra" / "Charts"


@dataclass(frozen=True)
class Defaults:
    projection_type: str
    projection_zone: int
    projection_hemisphere: str
    pixel_corners: tuple[int, int, int, int]  # left, top, right, bottom


@dataclass(frozen=True)
class ChartEntry:
    id: str
    code: str
    display_name: str
    filename: str
    source_url: str
    wgs84: dict[str, list[float]]  # corners
    pixel_corners: tuple[int, int, int, int] | None  # optional override


def load_toml(path: Path) -> tuple[Defaults, list[ChartEntry]]:
    with path.open("rb") as f:
        data = tomllib.load(f)
    d = data.get("defaults", {})
    defaults = Defaults(
        projection_type=d.get("projection_type", "utm"),
        projection_zone=int(d.get("projection_zone", 50)),
        projection_hemisphere=d.get("projection_hemisphere", "south"),
        pixel_corners=tuple(d.get("default_pixel_corners", [120, 80, 3456, 2440])),  # type: ignore
    )
    charts: list[ChartEntry] = []
    for entry in data.get("chart", []):
        charts.append(
            ChartEntry(
                id=entry["id"],
                code=entry["code"],
                display_name=entry["display_name"],
                filename=entry["filename"],
                source_url=entry["source_url"],
                wgs84={
                    "top_left": entry["wgs84_top_left"],
                    "top_right": entry["wgs84_top_right"],
                    "bottom_left": entry["wgs84_bottom_left"],
                    "bottom_right": entry["wgs84_bottom_right"],
                },
                pixel_corners=tuple(entry["pixel_corners"]) if "pixel_corners" in entry else None,  # type: ignore
            )
        )
    return defaults, charts


def download_pdf(url: str, dest: Path, dry_run: bool, verbose: bool) -> bool:
    if dest.exists():
        if verbose:
            print(f"  skip: {dest.name} already exists")
        return True
    if dry_run:
        print(f"  [dry-run] would fetch {url} -> {dest.name}")
        return True
    try:
        if verbose:
            print(f"  fetching {url}")
        req = urllib.request.Request(url, headers={"User-Agent": "Samudra/1.0"})
        with urllib.request.urlopen(req, timeout=30) as resp:
            data = resp.read()
        dest.write_bytes(data)
        print(f"  fetched {dest.name} ({len(data) // 1024} KB)")
        return True
    except (urllib.error.URLError, TimeoutError) as e:
        print(f"  ERROR: failed to fetch {url}: {e}", file=sys.stderr)
        return False


def write_sidecar(
    entry: ChartEntry,
    defaults: Defaults,
    dest: Path,
    dry_run: bool,
) -> None:
    pc = entry.pixel_corners or defaults.pixel_corners
    left, top, right, bottom = pc
    payload = {
        "projection": {
            "type": defaults.projection_type,
            "zone": defaults.projection_zone,
            "hemisphere": defaults.projection_hemisphere,
        },
        "wgs84_corners": {
            "top_left": {"lat": entry.wgs84["top_left"][0], "lon": entry.wgs84["top_left"][1]},
            "top_right": {"lat": entry.wgs84["top_right"][0], "lon": entry.wgs84["top_right"][1]},
            "bottom_left": {"lat": entry.wgs84["bottom_left"][0], "lon": entry.wgs84["bottom_left"][1]},
            "bottom_right": {"lat": entry.wgs84["bottom_right"][0], "lon": entry.wgs84["bottom_right"][1]},
        },
        "pixel_corners": {
            "top_left": [left, top],
            "top_right": [right, top],
            "bottom_left": [left, bottom],
            "bottom_right": [right, bottom],
        },
    }
    text = json.dumps(payload, indent=2) + "\n"
    if dry_run:
        print(f"  [dry-run] would write sidecar {dest.name} ({len(text)} bytes)")
        return
    dest.write_text(text)
    print(f"  wrote {dest.name}")


def write_manifest(charts: list[ChartEntry], dest: Path, dry_run: bool) -> None:
    payload = {
        "version": 1,
        "charts": [
            {
                "id": c.id,
                "code": c.code,
                "displayName": c.display_name,
                "pdf": f"{c.filename}.pdf",
                "georef": f"{c.filename}.json",
            }
            for c in sorted(charts, key=lambda x: x.id)
        ],
    }
    text = json.dumps(payload, indent=2) + "\n"
    if dry_run:
        print(f"[dry-run] would write {dest.name} ({len(text)} bytes)")
        return
    dest.write_text(text)
    print(f"wrote {dest.name}")


def validate(entry: ChartEntry) -> list[str]:
    errs: list[str] = []
    for key, latlon in entry.wgs84.items():
        if len(latlon) != 2:
            errs.append(f"{entry.id}: {key} expects [lat, lon], got {latlon}")
            continue
        lat, lon = latlon
        if not (-90 <= lat <= 90):
            errs.append(f"{entry.id}: {key} lat out of range: {lat}")
        if not (-180 <= lon <= 180):
            errs.append(f"{entry.id}: {key} lon out of range: {lon}")
    return errs


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--skip-download", action="store_true",
                    help="reuse existing PDFs; just regenerate sidecars + manifest")
    ap.add_argument("--dry-run", action="store_true",
                    help="print actions, write nothing")
    ap.add_argument("--verbose", action="store_true")
    args = ap.parse_args()

    if not TOML_PATH.exists():
        print(f"ERROR: {TOML_PATH} not found", file=sys.stderr)
        return 1

    defaults, charts = load_toml(TOML_PATH)
    if not charts:
        print("ERROR: no [[chart]] entries in TOML", file=sys.stderr)
        return 2

    # Validate before any I/O.
    all_errs: list[str] = []
    for c in charts:
        all_errs.extend(validate(c))
    if all_errs:
        for e in all_errs:
            print(f"VALIDATION: {e}", file=sys.stderr)
        return 2

    if not args.dry_run:
        CHARTS_DIR.mkdir(parents=True, exist_ok=True)

    any_fail = False
    for c in charts:
        print(f"[{c.id}] {c.display_name}")
        pdf_path = CHARTS_DIR / f"{c.filename}.pdf"
        if not args.skip_download:
            ok = download_pdf(c.source_url, pdf_path, args.dry_run, args.verbose)
            if not ok:
                any_fail = True
        elif args.verbose:
            print(f"  skip-download: not fetching")
        sidecar_path = CHARTS_DIR / f"{c.filename}.json"
        write_sidecar(c, defaults, sidecar_path, args.dry_run)

    write_manifest(charts, CHARTS_DIR / "manifest.json", args.dry_run)

    return 1 if any_fail else 0


if __name__ == "__main__":
    sys.exit(main())
