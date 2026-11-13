# Third-party notices

StarPilot application code is licensed under the MIT License (see `LICENSE`).
The following data, code and services keep their own licenses/terms.

## Catalog data

- **OpenNGC** — Mattia Verga, CC BY-SA 4.0.
  https://github.com/mattiaverga/OpenNGC
  Used for Messier/NGC/IC coordinates, magnitudes, sizes, aliases and derived
  catalog rows.
- **Caldwell metadata** — Paul Spinelli / Astro-Catalogue-Viewer, MIT.
  https://github.com/thebioguy/Astro-Catalogue-Viewer
  Used for Caldwell number/name/coordinate metadata.
- **HYG Database v3.5** — David Nash / Astronexus, CC BY-SA 4.0.
  https://github.com/astronexus/HYG-Database
  Used for bright-star coordinates, magnitudes and identifiers; derived star
  tables are distributed under CC BY-SA 4.0.
- **Stellarium Modern / Chinese skyculture** — Stellarium team; Chinese names
  contributed by Karrie Berglund and Sun Shuwei, CC BY-SA 4.0.
  https://github.com/Stellarium/stellarium
  Used for constellation line segments and Chinese star names, matched by HIP
  and deduplicated; derived data is distributed under CC BY-SA 4.0.
- **International Meteor Organization (IMO)** — meteor shower calendar data,
  used with attribution. https://www.imo.net

The catalog is a transformed/derived database. CC BY-SA 4.0 requires
attribution and share-alike for the derived data; the application source code
remains under MIT where separable.

## Code

- **satellite.js 6.0.1** — Shashwat Kandadai / UCSC Jack Baskin School of
  Engineering, MIT. Near-Earth SGP4 was ported to ArkTS; see
  `starpilot-watch/entry/src/main/resources/rawfile/satellite-js-license.txt`.
- **astronomy-engine 2.1.19** — Don Cross, MIT. Used only by the Node
  cross-check harness, not shipped in the watch HAP.
- **esbuild** — MIT, test/build tooling.
- HarmonyOS SDK / DevEco Studio components are used under Huawei's SDK terms;
  they are not redistributed in this repository.

## Network services

- **Open-Meteo** — weather data; free/non-commercial API terms may apply.
  https://open-meteo.com/en/terms
- **7Timer** — ASTRO forecast API. https://www.7timer.info/doc.php?lang=en
- Weather requests send the selected city's latitude/longitude. The app's
  privacy page documents this; commercial distribution must re-check the API
  terms.

## Fonts, icons and brands

The app icon/splash artwork in `brand/` was generated for StarPilot. No
third-party commercial fonts are bundled. "HUAWEI", "HarmonyOS" and other
marks belong to their owners; this project is not affiliated with Huawei.
