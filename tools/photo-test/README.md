# Photography math harness

Compares `starpilot-watch/entry/src/main/ets/common/Photo.ets` against known
optical values (FOV, pixel scale, NPF/500/pixel-drag, stack rounding).

```bash
npm install
npx esbuild ../../starpilot-watch/entry/src/main/ets/common/Photo.ets \
  --loader:.ets=ts --format=esm --outfile=photo.mjs
node verify.mjs
```

The script prints PASS/FAIL per case. Rationale and tolerances are in
`S5_TEST_REPORT.md`.
