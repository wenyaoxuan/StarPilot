# Astronomy cross-validation harness

Compares `starpilot-watch/entry/src/main/ets/common/Astro.ets` against the
independent `astronomy-engine` library.

```bash
npm install
npx esbuild ../../starpilot-watch/entry/src/main/ets/common/Astro.ets \
  --loader:.ets=ts --format=esm --outfile=astro.mjs
node verify.mjs
```

The script prints per-case errors and a PASS/FAIL line. Thresholds are in
`verify.mjs`; the rationale is in `S2_TEST_REPORT.md`.
