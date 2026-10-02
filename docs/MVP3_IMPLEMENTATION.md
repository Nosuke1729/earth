# MVP 3 implementation plan and audit

Baseline inspection: native MVP 2 launched with an isolated save; all 45 tests pass.
The Swift package has independent simulation, persistence, input, renderer and UI
modules. Existing quaternion observation remains independent of world state.

Pacing cause: 100,000 geological years per real second and 10,000 biological-era
years per second combine with hazards per million physical years. Biological stage
checks every ten million years sample the same plentiful physical time; chemical
feedback also uses that clock. More lineages must not multiply innovation chances.

Implementation sequence:

1. Centralize biological rates and opportunity accrual separately from physical age.
   Retain fixed real-minute integration and saved remainders. Use accumulated hazard
   thresholds and a bounded planet-wide innovation budget rather than one clock per species.
2. Add a 6 × 8 coarse ecological grid using the existing spherical terrain field.
   Derive temperature, water, productivity and biomes from physical state.
3. Add persistent, trait-defined lineages with inherited mutations and regional biomass.
   Preserve extinct records and ancestry; cap active populations and lineage storage.
4. Implement stable aggregate energy flows, competition, predation, decomposition,
   adjacent habitat-aware migration, selection and extinction with niche recovery.
5. Make rare innovations branch from viable parents with environmental prerequisites.
   Derive high-level life descriptors and atmospheric feedback from living populations.
6. Filter significant history, add actual species/tree/region observation and a return
   summary, and drive subtle coloration from regional populations. Retain existing UI.
7. Migrate formats 1 and 2, preserving original files, seed, age and old history.
8. Add deterministic pacing/evolution/ecology/compatibility tests, multi-seed normal
   and long-run audits, timing diagnostics, native renders and a release app package.

No intelligence, civilization, technology, communication or wallpaper integration.

## Implemented model

Physical age and the existing 60-real-second deterministic kernel are preserved.
`EvolutionTimescale` supplies normal biological policy: opportunity accrues at 12%
of physical time, weighted by habitability and stress; chemistry uses a separate
0.35 metabolic multiplier. Abiogenesis is twenty times rarer than MVP 2.
Persisted exponential hazard distances prevent UI polling from multiplying event
chances. Population updates run every 2 Myr of physical time; branching and global
innovation hazards run every 1 Myr of accumulated opportunity. No calendar unlocks.

The shared spherical terrain field supplies 48 area-weighted regions. Latitude,
climate, liquid water, terrain and atmosphere determine biome, fitness and available
chemical/solar energy. Species store seeded IDs, parent IDs, origin/extinction ages,
eleven inherited traits, habitat, ecological role and regional normalized biomass.
Small mutations dominate; rare large mutations are not biased toward the environment.
Fitness and competition determine which descendants succeed afterward.

Producer, consumer, predator, decomposer and mixed strategies share bounded energy
pools. Migration conserves biomass across compatible neighbors. Absolute fitness
limits capacity even without competitors; absent populations never grow without
founding, branching or migration. Temperature tolerance, water dependence, oxygen,
efficiency, reproduction, structure, mobility, size and defense all have consequences.
Steady mortality supplies detritus independently of replacement growth. Mobility
improves foraging, and structure improves thermal tolerance, with energetic costs.

Innovations create child lineages rather than upgrading the whole biosphere.
Environmental and parental prerequisites constrain photosynthesis, multicellularity,
consumer metabolism, recycling, predation, protection and land adaptation. Land
colonization requires an existing coastal population and suitable atmosphere.
High-level `LifeStage` derives from established living traits and can regress.
Biological atmospheric feedback derives from actual biomass and metabolism.

Extinction removes active populations while retaining ancestry. Low-population
background turnover, competition and habitat/climate loss act independently of
catastrophes. Geological events change environment; species survival depends on
traits rather than deleting a fixed percentage. Empty niches increase opportunity.
Ordinary branching stops at 168 living lineages, reserving 24 of the 192 slots for
innovations. The 4,096-record archive ceiling pauses branching without deleting history.

The Life panel shows living/extinct ancestry and a species inspector. Globe clicks
map actual sphere UV coordinates to regions; details show real environment, energy,
diversity, biomass and dominance. Ocean pigments require aquatic-capable producers;
land pigments require land-capable producers. Color is spatially interpolated and
subtle. Filtered history records first innovations, representative radiation,
diversity milestones, dominance and collapse. A dismissible return summary compares
actual saved and caught-up worlds, appearing only for meaningful changes.

Debug acceleration is an ephemeral observer setting, with bounded work batches.
Queued debug time is not saved and is discarded at ×1; normal policy is immutable.
The laboratory also offers branching, vacant niches, warming/cooling and stress.

## Long-run issues found and corrected

The first audit exposed carrying capacity that depended only on relative fitness:
the sole inhabitant of an unsuitable niche could claim its entire resource pool.
Absolute fitness now also limits target population. Solar capture also depends on
the organism's photosynthetic ability, rather than granting a weak photosynthesizer
all available light merely because it has no competitor.

A later audit found innovation stagnation at the active-species cap and decomposers
starving because replacement growth hid steady mortality. Reserved innovation slots,
relative vulnerability in background turnover, and separate mortality accounting
corrected those problems. Foraging and thermal benefits make mobility/complexity
useful in appropriate niches rather than always imposing costs. Focused regression
tests cover all these corrections; the six-month audit was rerun afterward.

## Normal-speed pacing audit

Generated worlds use neutral real-world modifiers. These are samples, not promised
milestone dates. Every checkpoint validates state and exact save/load equality.

| Elapsed real time | Lifeless | Protocellular | Microbial | Photosynthetic | Multicellular |
| --- | ---: | ---: | ---: | ---: | ---: |
| 8 hours, seeds 0–31 | 27 | 4 | 1 | 0 | 0 |
| 1 day, seeds 0–31 | 19 | 8 | 5 | 0 | 0 |
| 3 days, seeds 0–31 | 4 | 14 | 14 | 0 | 0 |
| 7 days, seeds 0–15 | 0 | 4 | 12 | 0 | 0 |
| 14 days, seeds 0–15 | 0 | 2 | 13 | 1 | 0 |
| 21 days, seeds 0–15 | 0 | 1 | 12 | 3 | 0 |

No sampled overnight world reached photosynthesis or complex life. An existing
microbial-world overnight test also checks that it does not jump to complex life.
Major metabolic development is currently conservative: multicellularity did not
establish within three weeks in this 16-seed sample. Some worlds can remain microbial
for months. This is deliberately probabilistic; rates remain easy to tune.

## Six-month audit and performance

Four fresh worlds ran through 180 real days of normal-speed elapsed time, accelerated
only by feeding elapsed time to the same kernel. Each passed all checkpoint validity
and round-trip checks. Additional final audits check regional capacity and ancestry.

| Seed | Stage at day 90 | Living at day 180 | Extinct at day 180 | Occupied regions | O₂ at day 180 |
| --- | --- | ---: | ---: | ---: | ---: |
| 42 | Microbial | 116 | 1,579 | 46 | 12.67% |
| 43 | Multicellular | 168 | 1,022 | 37 | 11.54% |
| 7 | Photosynthetic | 168 | 1,199 | 32 | 10.43% |
| 99 | Photosynthetic | 172 | 1,068 | 37 | 6.46% |

At six months all four have established complex lineages, but ancestry, innovation
order, turnover and habitats differ. Seed 43 remains 166/168 aquatic lineages;
seed 42 has 107 amphibious and one terrestrial lineage. Seed 42's photosynthetic
breakthrough came much later than seed 43's. Their actual native renders are in
`media/mvp3/seed-42/planet.png` and `media/mvp3/seed-43/planet.png`.
Living producers, consumers, mixed strategies and decomposers occur in all four;
predation is supported and tested, but did not arise in this four-seed sample.
Regional biomes and occupancy differ, including persistent frozen refuges/boundaries.
Final physical ages span approximately 173–189 billion toy-model years; this model
does not yet age the star or model stellar death.

Measurements on Apple Silicon, macOS 26.2, release build; 240 minute steps per mature
world, without rendering. Each benchmark advances an in-memory copy and leaves the
saved audit planet unchanged. Peak RSS includes probe/runtime/JSON overhead, not UI/GPU.

| Seed | Median step | p95 step | Maximum observed | Peak probe RSS | Encoded world |
| --- | ---: | ---: | ---: | ---: | ---: |
| 42 | 0.048 ms | 1.049 ms | 23.197 ms | 21.4 MiB | 1.12 MB |
| 43 | 0.058 ms | 1.547 ms | 2.096 ms | 17.5 MiB | 0.89 MB |
| 7 | 0.060 ms | 1.401 ms | 2.019 ms | 17.7 MiB | 0.99 MB |
| 99 | 0.059 ms | 1.462 ms | 2.125 ms | 17.4 MiB | 0.95 MB |

The day-90-to-day-180 increments took 31–56 seconds, processing every fixed real-minute
boundary rather than rendered frames or individual years. Whole six-month catch-up
is slower than those incremental measurements. Large absences still take meaningful
time; calculation occurs off the main actor during launch. Live work is budgeted.
The initial outer `time -l` wrapper could not read sandboxed kernel counters after
the complete audit; portable in-process `getrusage` benchmarks above supply RSS.

Reproduction tools:

```sh
bash scripts/swift.sh test -c release
bash scripts/swift.sh test -Xswiftc -O
bash scripts/swift.sh run -c release PlanetProbe /tmp/earth-mvp3 --ecology --days 180 --seeds 42,43,7,99
bash scripts/swift.sh run -c release PlanetProbe /tmp/earth-cost --benchmark-save /tmp/earth-mvp3/seed-43
bash scripts/swift.sh run -c release PlanetProbe /tmp/earth-image --render-save /tmp/earth-mvp3/seed-43
```

Machine-readable pacing/checkpoint reports, complete generated histories, benchmark
data and test logs are retained under `audits/mvp3/`.

## Verification and compatibility

- 74 release tests pass; 75 optimized DEBUG tests pass, including developer behavior.
  The prior 45-test suite is retained, with pacing/stress expectations updated for
  the intentional new model. Added coverage checks integrated hazard partitioning,
  overnight pacing, inheritance, bounded mutation, seed biomass conservation,
  selection under cooling, competition, predation/defense, stable recycling,
  migration connectivity/conservation, recolonization, background extinction,
  archive/cap behavior, regional pigment restrictions and meaningful summaries.
- Format 3 saves retain regions, populations, ancestry, clocks and hazard remainders.
  Genuine formats 1/2 load; legacy aggregate life becomes one inferred founder,
  with no fabricated old branches. Original legacy files are archived byte-for-byte.
  Tests cover malformed traits/populations/ancestry and exact lineage round trips.
- The release `.app` builds and passes strict signature/plist validation. A native
  launch with an isolated genuine MVP 2 fixture completed eight-hour catch-up,
  migration and autosaving; its original archive exactly matches the fixture.
- Two native SceneKit exports were visually inspected. Globe quaternion math,
  climate, hydrology, seeded RNG, safe local inputs and existing interaction tests
  remain byte-for-byte identical to MVP 2. No user save was accessed.
- Reviewed the changes against the captured MVP 2 baseline, since this checkout
  has no Git commits and its source files are untracked. No commit or push was made.

## File groups changed

- `SimulationEngine`: new `EvolutionTimescale`, `TerrainField`, `EcologyState`,
  `RegionSystem`, `Species`, `EcologySystem`, `EvolutionSystem`, `EcologyHistory`
  and `ReturnSummary`; extended biosphere state/descriptors/events and geological
  shock handling, with the existing physical integration preserved.
- `Persistence/SaveStore.swift`: format 3, legacy defaults/archive and validation.
- `Rendering`: shared terrain, actual regional pigments and clicked-region callback;
  the existing arcball/inertia/zoom controller is preserved.
- `SecondEarthApp`: Life/region inspectors, significant history, return summary,
  observer work budget and separate DEBUG acceleration/laboratory.
- `Tests`: ecology suite, updated biological pacing tests, save migration tests and
  a genuine MVP 2 fixture. `PlanetProbe` adds multi-seed ecology and saved-world audits.
- Build metadata is 0.3.0; README, implementation notes and generated validation
  reports describe the model and its limits.

## Remaining limitations

This is aggregate ecology over a coarse grid, with normalized biomass instead of
organism counts and simplified energy flows rather than a calibrated food-web model.
Ancestry is genuine, but the species abstraction does not yet model reproductive
isolation. The tree uses a simple indented list, limiting displayed indentation.
Long-lived worlds need a future historical archive strategy beyond 4,096 lineages.
Offline cost remains linear in real minutes, and neutral inputs substitute for
unobserved host activity. Debug acceleration may fall behind its requested multiplier
when the work budget is reached. Rates are conservative and based on a finite sample.

Native launch and renders were verified; pointer/panel interactions were not manually
exercised in this run. The app is locally ad-hoc signed, not Developer ID notarized.
No MVP 4 systems were introduced.
