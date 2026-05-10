#!/usr/bin/env python3
"""
fetch_charts.py — WA Transport chart catalogue pipeline.

Queries the WA Transport ArcGIS feature service for the full 104-chart
catalogue, computes WGS84 corners (via Web Mercator inverse) for each
chart's bounding rectangle, derives UTM zone from centroid longitude,
writes per-chart sidecar JSONs + aggregate manifest.json.

Source feature service:
  https://services6.arcgis.com/67Ks15nDmWoIbK8b/arcgis/rest/services/Map/FeatureServer/0

Run from repo root:
    python3 scripts/fetch_charts.py             # regenerate sidecars + manifest
    python3 scripts/fetch_charts.py --download  # also fetch PDFs to Samudra/Charts/

Requires Python 3.11+ (built-in tomllib for optional overrides).
No third-party deps.

TOML override layer:
  scripts/wa_charts_overrides.toml may contain per-chart corner refinements
  keyed by filename (without extension). Override values supersede ArcGIS-
  derived corners. Useful for charts where manual graticule extraction has
  yielded more precise bounds than the feature service rectangle.

Exit codes:
    0  success
    1  network/file error
    2  validation error
"""

from __future__ import annotations

import argparse
import json
import math
import re
import sys
import urllib.error
import urllib.request
from dataclasses import dataclass
from pathlib import Path
from typing import Any

try:
    import tomllib
except ImportError:
    tomllib = None  # type: ignore

REPO_ROOT = Path(__file__).resolve().parent.parent
CHARTS_DIR = REPO_ROOT / "Samudra" / "Charts"
OVERRIDES_PATH = REPO_ROOT / "scripts" / "wa_charts_overrides.toml"

FEATURE_SERVICE_URL = (
    "https://services6.arcgis.com/67Ks15nDmWoIbK8b/arcgis/rest/services/"
    "Map/FeatureServer/0/query?where=1%3D1&outFields=*&f=json&resultRecordCount=500"
)

# WGS84 sphere radius (Web Mercator uses sphere, not ellipsoid)
WEB_MERCATOR_R = 6378137.0


@dataclass
class Chart:
    object_id: int
    chart_number: str       # e.g. "WA 755"
    chart_name: str         # e.g. "Bouvard"
    chart_type: str         # SIDE A / SIDE B / INSET
    chart_map_name: str     # parent chart name (often duplicate or full title)
    horizontal_datum: str
    link_url: str           # direct PDF URL
    bbox_web_mercator: tuple[float, float, float, float]  # min_x, min_y, max_x, max_y

    @property
    def display_name(self) -> str:
        base = self.chart_name or self.chart_map_name or "(unnamed)"
        # Disambiguate sides + insets
        if self.chart_type and self.chart_type != "SIDE A":
            suffix = {
                "INSET": " (Inset)",
                "SIDE B": " (Side B)",
            }.get(self.chart_type, f" ({self.chart_type.title()})")
            return base + suffix
        return base

    @property
    def filename_stem(self) -> str:
        """Derive unique slug from LINKURL basename (handles 30 chart-number collisions)."""
        last = self.link_url.rsplit("/", 1)[-1]
        last = last.rsplit(".", 1)[0]
        # Strip query strings + sanitize
        last = re.sub(r"[^A-Za-z0-9_-]", "_", last)
        return last or f"chart_{self.object_id}"


def fetch_features() -> list[dict[str, Any]]:
    print(f"querying {FEATURE_SERVICE_URL}")
    req = urllib.request.Request(FEATURE_SERVICE_URL, headers={"User-Agent": "Samudra/1.0"})
    with urllib.request.urlopen(req, timeout=30) as resp:
        data = json.loads(resp.read().decode("utf-8"))
    features = data.get("features", [])
    print(f"  fetched {len(features)} chart features")
    return features


def parse_charts(features: list[dict[str, Any]]) -> list[Chart]:
    """
    104 ArcGIS features dedupe to 54 unique PDFs. Each unique PDF (LINKURL)
    may have SIDE A, SIDE B, and multiple INSET rows describing different
    sub-regions printed on the same physical chart. We pick SIDE A's geometry
    as canonical (the main chart area); fall back to first row if no SIDE A
    in group. Display name retains the chart type so SIDE-B-only PDFs are
    still labeled accurately.
    """
    groups: dict[str, list[dict[str, Any]]] = {}
    for f in features:
        url = str(f.get("attributes", {}).get("LINKURL", "")).strip()
        if not url:
            continue
        groups.setdefault(url, []).append(f)

    out: list[Chart] = []
    for url, group in groups.items():
        # Prefer SIDE A row; fall back to first.
        primary = next(
            (f for f in group if f.get("attributes", {}).get("CHARTTYPE", "").upper() == "SIDE A"),
            group[0],
        )
        attrs = primary.get("attributes", {})
        geom = primary.get("geometry", {})
        rings = geom.get("rings", [])
        if not rings:
            continue
        xs = [pt[0] for ring in rings for pt in ring]
        ys = [pt[1] for ring in rings for pt in ring]
        bbox = (min(xs), min(ys), max(xs), max(ys))

        # Decide display type label
        chart_type = str(attrs.get("CHARTTYPE", "")).strip().upper()
        # If this PDF has no SIDE A, surface its actual type for honesty.
        has_side_a = any(
            f.get("attributes", {}).get("CHARTTYPE", "").upper() == "SIDE A" for f in group
        )
        if not has_side_a:
            chart_type = str(attrs.get("CHARTTYPE", "")).strip().upper()
        else:
            chart_type = "SIDE A"

        out.append(
            Chart(
                object_id=int(attrs.get("OBJECTID", 0)),
                chart_number=str(attrs.get("CHARTNUMBER", "")).strip(),
                chart_name=str(attrs.get("CHARTNAME", "")).strip(),
                chart_type=chart_type,
                chart_map_name=str(attrs.get("CHARTMAPNAME", "")).strip(),
                horizontal_datum=str(attrs.get("HORIZONTALDATUM", "GDA94")).strip(),
                link_url=url,
                bbox_web_mercator=bbox,
            )
        )
    return out


def web_mercator_to_wgs84(x: float, y: float) -> tuple[float, float]:
    """Spherical Web Mercator (EPSG:3857) inverse → (lat, lon) WGS84 degrees."""
    lon = math.degrees(x / WEB_MERCATOR_R)
    lat = math.degrees(2 * math.atan(math.exp(y / WEB_MERCATOR_R)) - math.pi / 2)
    return (lat, lon)


def utm_zone_for_longitude(lon: float) -> int:
    """Standard UTM zone formula: zone n covers longitudes (6n-186) to (6n-180)."""
    return int((lon + 180) // 6) + 1


def load_overrides() -> dict[str, dict[str, Any]]:
    if not OVERRIDES_PATH.exists() or tomllib is None:
        return {}
    with OVERRIDES_PATH.open("rb") as f:
        data = tomllib.load(f)
    out: dict[str, dict[str, Any]] = {}
    for entry in data.get("override", []):
        key = entry.get("filename")
        if key:
            out[key] = entry
    return out


def build_sidecar(chart: Chart, overrides: dict[str, dict[str, Any]]) -> tuple[dict[str, Any], dict[str, Any]]:
    """Return (sidecar_json, manifest_entry)."""
    min_x, min_y, max_x, max_y = chart.bbox_web_mercator
    # Top is max_y (Web Mercator y grows north). Bottom is min_y.
    tl_lat, tl_lon = web_mercator_to_wgs84(min_x, max_y)
    tr_lat, tr_lon = web_mercator_to_wgs84(max_x, max_y)
    bl_lat, bl_lon = web_mercator_to_wgs84(min_x, min_y)
    br_lat, br_lon = web_mercator_to_wgs84(max_x, min_y)

    centroid_lon = (tl_lon + tr_lon) / 2
    zone = utm_zone_for_longitude(centroid_lon)

    # Default pixel corners — rasterized image bounds at 1.5× scale, conservative margins.
    pixel_corners = {
        "top_left": [120, 80],
        "top_right": [3456, 80],
        "bottom_left": [120, 2440],
        "bottom_right": [3456, 2440],
    }

    wgs84_corners = {
        "top_left":     {"lat": tl_lat, "lon": tl_lon},
        "top_right":    {"lat": tr_lat, "lon": tr_lon},
        "bottom_left":  {"lat": bl_lat, "lon": bl_lon},
        "bottom_right": {"lat": br_lat, "lon": br_lon},
    }

    # Apply override if present.
    override = overrides.get(chart.filename_stem)
    if override:
        if "wgs84_top_left" in override:
            wgs84_corners["top_left"] = {"lat": override["wgs84_top_left"][0], "lon": override["wgs84_top_left"][1]}
            wgs84_corners["top_right"] = {"lat": override["wgs84_top_right"][0], "lon": override["wgs84_top_right"][1]}
            wgs84_corners["bottom_left"] = {"lat": override["wgs84_bottom_left"][0], "lon": override["wgs84_bottom_left"][1]}
            wgs84_corners["bottom_right"] = {"lat": override["wgs84_bottom_right"][0], "lon": override["wgs84_bottom_right"][1]}
        if "pixel_corners" in override:
            left, top, right, bottom = override["pixel_corners"]
            pixel_corners = {
                "top_left": [left, top],
                "top_right": [right, top],
                "bottom_left": [left, bottom],
                "bottom_right": [right, bottom],
            }

    sidecar = {
        "projection": {
            "type": "utm",
            "zone": int(override.get("projection_zone", zone)) if override else zone,
            "hemisphere": "south",
        },
        "wgs84_corners": wgs84_corners,
        "pixel_corners": pixel_corners,
        "datum": chart.horizontal_datum,
    }

    manifest_entry = {
        "id": chart.filename_stem,
        "code": chart.chart_number,
        "displayName": chart.display_name,
        "pdf": f"{chart.filename_stem}.pdf",
        "georef": f"{chart.filename_stem}.json",
    }

    return sidecar, manifest_entry


def download_pdf(chart: Chart, dest: Path, verbose: bool) -> bool:
    if dest.exists():
        if verbose:
            print(f"  skip: {dest.name} already exists")
        return True
    try:
        req = urllib.request.Request(chart.link_url, headers={"User-Agent": "Samudra/1.0"})
        with urllib.request.urlopen(req, timeout=60) as resp:
            data = resp.read()
        dest.write_bytes(data)
        print(f"  fetched {dest.name} ({len(data) // 1024} KB)")
        return True
    except (urllib.error.URLError, TimeoutError) as e:
        print(f"  ERROR: {chart.filename_stem}: {e}", file=sys.stderr)
        return False


def write_atomic(path: Path, payload: Any) -> None:
    text = json.dumps(payload, indent=2) + "\n"
    path.write_text(text)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--download", action="store_true",
                    help="fetch every chart PDF from ArcGIS LINKURL")
    ap.add_argument("--verbose", action="store_true")
    ap.add_argument("--limit", type=int, default=0,
                    help="process only first N charts (debug)")
    args = ap.parse_args()

    try:
        features = fetch_features()
    except urllib.error.URLError as e:
        print(f"ERROR: failed to reach feature service: {e}", file=sys.stderr)
        return 1

    charts = parse_charts(features)
    if args.limit:
        charts = charts[:args.limit]
    if not charts:
        print("ERROR: no chart features parsed", file=sys.stderr)
        return 2

    overrides = load_overrides()
    if overrides:
        print(f"loaded {len(overrides)} override entries from {OVERRIDES_PATH.name}")

    CHARTS_DIR.mkdir(parents=True, exist_ok=True)

    manifest_entries: list[dict[str, Any]] = []
    any_download_fail = False

    for chart in charts:
        print(f"[{chart.filename_stem}] {chart.display_name}")
        sidecar, manifest_entry = build_sidecar(chart, overrides)
        sidecar_path = CHARTS_DIR / f"{chart.filename_stem}.json"
        write_atomic(sidecar_path, sidecar)
        manifest_entries.append(manifest_entry)

        if args.download:
            pdf_path = CHARTS_DIR / f"{chart.filename_stem}.pdf"
            ok = download_pdf(chart, pdf_path, args.verbose)
            if not ok:
                any_download_fail = True

    # Deterministic order: by id ascending.
    manifest_entries.sort(key=lambda e: e["id"])
    manifest = {"version": 1, "charts": manifest_entries}
    write_atomic(CHARTS_DIR / "manifest.json", manifest)
    print(f"wrote manifest.json ({len(manifest_entries)} charts)")

    return 1 if any_download_fail else 0


if __name__ == "__main__":
    sys.exit(main())
