# MVP 2 implementation notes

## Inspection and plan

The existing Swift package separates Foundation simulation state, persistence,
local host inputs, SceneKit rendering and SwiftUI observation. Its baseline has
19 simulation/persistence tests. All existing sources are untracked in the empty
remote's local `main` branch, so this iteration is reviewed against a pre-edit
file snapshot rather than pretending there is an MVP 1 Git commit.

The interaction defect comes from two competing motions: SceneKit's built-in
turntable controller orbits the camera, while an independent repeating action
rotates the globe. Built-in inertia, vertical-angle limits and unbounded camera
zoom do not share a state machine with the automatic spin.

Phase A: isolate quaternion trackball math in the Rendering module, add a native
SCNView input adapter, unify drag/inertia/rest/idle motion, interpolate bounded
camera distance, and verify stability with mathematical tests before simulation edits.
Preserve the fixed physical axial lean, lighting, procedural assets and renderer host boundary.

Phase B: extend Biosphere with early stages and Codable defaults, derive a bounded
habitability score, gate seeded hazards by environment and accumulated biological
time, apply gradual microbial/photosynthetic atmosphere feedback, allow stress,
regression and loss, and log only major transitions. Extend existing procedural
coloration, observation details and debug-only controls. Migrate version-1 saves
without losing seed, RNG, pending time, age or timeline. Test determinism, offline
continuation, hostile states, feedback, migration and bounds; build and review scope.

No species, organisms, food webs, intelligence, civilization, communication, cities
or wallpaper integration are part of this iteration.

Phase A gate: before modifying simulation sources, the native app and renderer
compiled and all 27 tests passed, including eight new interaction tests. These
check re-grabbing, pointer direction, extreme rim motion, quaternion normalization,
north constraints, coasting/rest/idle behavior, zoom bounds and 30/60 FPS equivalence.
The native adapter freezes projected geometry for each drag to avoid resize/zoom jumps.

Vertical safety projects the rotated north vector onto an upright cone and rebuilds
the quaternion from vector arcs. No Euler-angle clamp is used. Idle rotation and
drag now share one controller; the old competing camera/globe motions are removed.

## Implemented model

`Biosphere` retains its original fields and adds biodiversity, biological/stage age,
resilience, stress, a persisted evolution remainder and a once-only oxygen milestone.
Habitability combines temperature, liquid oceans, pressure, composition and stability.
Abiogenesis and subsequent stages use the saved SplitMix64 stream, environment and
accumulated favorable conditions rather than a planet-age schedule. Evolution checks
run every ten million accumulated biological years inside the existing aggregate
simulation kernel. The live/offline clock, local input provider and climate/hydrology
modules are preserved.

Microbial carbon cycling and gradual photosynthetic CO₂ uptake/O₂ production feed
back into climate. Biomass and complexity respond to environmental stress; severe
hostility permits regression, extinction and later independent origins. Surface
pigments depend on stage, biomass, temperature, ice, latitude and proximity to water.
The main view keeps the globe central, with biological indices in the scrollable
inspector. New interventions exist only in DEBUG builds.

Version-1 saves retain world identity and history. `primitive` maps to microbial,
new indices default conservatively and biological age derives from the prior origin.
The first legacy file is archived byte-for-byte as `planet.mvp1-original.json` when
saving version 2, including recovery from a backup with a missing primary. The
normal rolling backup, validation, corrupt-file preservation and writer lock remain.

## Changed files

| Area | Files |
| --- | --- |
| Interaction | New `Rendering/GlobeRotationController.swift`, `Rendering/InteractivePlanetView.swift`; adapted `Rendering/PlanetView.swift` and `Rendering/PlanetScene.swift` |
| Biosphere | New `SimulationEngine/Biosphere.swift`, `SimulationEngine/HabitabilityModel.swift`; extended `BiosphereSystem.swift`, `Planet.swift`, `GeologySystem.swift`, `SimulationEngine.swift` |
| Rendering and UI | `Rendering/PlanetTextures.swift`, `SecondEarthApp/UI/ObservationView.swift`, `HistoryPanel.swift`, `DebugPanel.swift`, `SecondEarthApp.swift` |
| Compatibility | `Persistence/SaveStore.swift`; new `PersistenceTests/MigrationTests.swift` and two genuine MVP 1 JSON fixtures |
| Verification | New `RenderingTests/GlobeInteractionTests.swift`, `SimulationEngineTests/BiosphereTests.swift`; adjusted one existing simulation assertion; extended `PlanetProbe/PlanetProbe.swift` |
| Build and documentation | `Package.swift`, `scripts/build-app.sh`, `README.md`, these notes and native renders under `docs/media/mvp2/` |

Source and test paths above are relative to `Sources/` and `Tests/`, respectively.
Review against the pre-edit snapshot found no unrelated source changes. Observer
lifecycle, climate, hydrology, seeded RNG and local input implementations are unchanged.

## Final verification

- Debug build and full suite: **45 tests passed in five suites**, approximately 0.30 s.
  The existing 19 tests remain; 26 additions cover nine interaction cases, twelve
  biosphere cases and five migration cases.
- Interaction checks cover pointer directions at different grab locations, precise
  motion, re-grabbing, 500 rapid rim motions, normalized/upright orientation,
  antipodal projection, inertia/rest/idle transitions, bounded smooth zoom and
  equivalent 30/60 FPS integration.
- Biology checks cover hostile/favorable worlds, stability before abiogenesis,
  oxygen-dependent complexity, gradual gas feedback and mixing, stress/regression,
  extinction/re-origin, seeded history, long offline bounds, and exact equality
  between offline and fragmented live progression across photosynthesis/oxygenation.
- Genuine MVP 1 fixtures preserve seed, RNG, age, biomass and history, continue
  identically after reopening, and retain the original archive through later saves.
- Release **0.2.0** builds on Apple Silicon/macOS 14+, with the developer laboratory
  compiled out. The `.app` passes strict local code-signature and plist verification.
- The release application launched with an isolated legacy save, caught up elapsed
  time, migrated to schema 2 and autosaved. Its seed and byte-exact original archive
  were verified; the disposable process was then stopped. The normal user save was
  never opened by verification.
- Native SceneKit render audit: seed 42 naturally reached protocellular, microbial
  and photosynthetic stages. A seven-day run had seven permanent events, CO₂ 0.145%,
  O₂ 15.7%, and remained photosynthetic. Seven-hour aggregate catch-up plus atomic
  save/load took approximately 1.6 ms on this Mac (one measurement, not a benchmark).
  Actual rendered stages and their history are retained in `docs/media/mvp2/`.

## Known limitations

Computer Use permissions were unavailable, so direct mouse/trackpad testing and a
full SwiftUI window screenshot could not be completed. Pure interaction mathematics,
native rendering, release launch and runtime saves were verified; subjective gesture
feel still needs a manual pass on a Mac with input access.

Habitability, biological indices and global chemical feedback are simplified models;
they do not resolve regions, species, organisms or food webs. Offline work still scales
with real minutes absent, using the existing fixed aggregate boundaries to preserve
determinism. Intel builds and public Developer ID signing/notarization are unverified.
New format-2 saves are not readable by the old MVP 1 binary; the migration archive is
retained for recovery. Stages may stall or regress and multicellularity is not guaranteed.
