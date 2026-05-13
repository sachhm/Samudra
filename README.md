# Samudra

An iPad app for marking up nautical charts with the Apple Pencil.

Open a chart, draw with the Pencil, drop hazard rings or notes, measure
distance and bearing between two points. Annotations carry real WGS84
coordinates because the bundled charts are georeferenced. Export the
result as a PNG, a PDF briefing, or a JSON file.

54 charts ship with the app — every chart on the [WA Department of
Transport nautical chart catalogue](https://www.transport.wa.gov.au/marine/charts-warnings-current-conditions/coastal-data-charts/nautical-charts),
from Lake Argyle down to Esperance.

## Build

Xcode 16. Target is iPadOS 26 on iPad Pro.

```
open Samudra.xcodeproj
```

Or from the command line:

```
xcodebuild test -scheme Samudra \
    -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)'
```

## Regenerating the chart catalogue

`scripts/fetch_charts.py` queries the WA Transport ArcGIS feature service
and rewrites the sidecar JSON for every chart. Pass `--download` to also
fetch each PDF into `Samudra/Charts/`.

```
python3 scripts/fetch_charts.py --download
```

Stdlib only, needs Python 3.11+.

## Not for navigation

This is a demo. It isn't a SOLAS-compliant chart system. Don't use it for
real passage planning. The bundled charts are advisory recreational
charts; certified marine charts come from the [Australian Hydrographic
Office](https://www.hydro.gov.au/).

## License

Proprietary. See `LICENSE`.
