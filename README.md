# SECOND EARTH

A single persistent simulated planet, observed through a native macOS application.
MVP 3 includes climate, oceans, geology and a slowly evolving regional biosphere
with inherited lineages, population ecology and extinction. It has no character controls, resources to collect, construction,
civilization or communication system.

## Run on macOS

Requires macOS 14 or later and Apple Command Line Tools (`xcode-select --install`),
or Xcode with Swift 6+. No dependencies need downloading. Apple Silicon is the
primary target; SwiftPM can also build natively on Intel, which has not been tested.

```sh
bash scripts/swift.sh test -c release
bash scripts/build-app.sh
open "build/SECOND EARTH.app"
```

`bash scripts/build-app.sh debug` includes the developer laboratory. The default
release app has no simulation intervention controls. The package can also be opened
in Xcode through `Package.swift`. Launch the packaged `.app`, rather than `swift run`,
for normal use and macOS notification identity.

Grab and drag the globe to rotate it, scroll or pinch to zoom, and click to inspect
a real ecological region. History opens the permanent timeline. Life opens the
lineage tree and species inspector. Settings offers optional major-milestone notifications;
permission is requested only when you enable them. Closing the last window quits.
The clock resumes from the save timestamp on the next launch.

## Architecture

```text
Sources/
  SimulationEngine/  Planet value state, SplitMix64, clock, climate, hydrology,
                     geology, habitability, regions, species, ecology, evolution
                     timescale, return summaries and permanent events
  Persistence/       Versioned JSON, validation, atomic saves, backup and lock
  RealWorldInputs/   Provider protocol, aggregate host CPU / battery / uptime
  Rendering/         SceneKit scene, seeded spherical textures and pure quaternion
                     observation controller / native input adapter
  SecondEarthApp/    Lifecycle, observer, SwiftUI observation/history/debug views
  PlanetProbe/       Isolated simulation, persistence and rendering audit tool
Tests/               Simulation, biosphere, migration, persistence and interaction checks
```

The engine imports Foundation only. It owns the authoritative world state; rendering
receives value snapshots and has a separate random stream. Scene construction does
not depend on the SwiftUI window, so a wallpaper or screen-saver host can reuse it.
The UI never advances history from a render callback.

## Simulation assumptions

This is a coherent toy planetary model, not a calibrated scientific forecast.
Radius, gravity, tilt, day/year duration, atmospheric pressure and volatile inventory
vary within plausible Earth-like ranges. Terrain is seamless spherical fractal noise,
seeded independently; drift represents aggregate continental reorganization.
The renderer uses a height quantile for ocean extent. Pixel area varies by latitude,
so visible coverage is an approximation of the authoritative simulated fraction.

Internal heat decays exponentially. Volcanism releases carbon and transient heat;
weathering draws atmospheric carbon toward an outgassing-dependent floor. Logarithmic
CO₂ warming, internal heat and ice albedo determine a temperature target. Gas cycling
and thermal inertia approach targets exponentially. Mixing fractions preserve the
nitrogen-to-other-inert-gas ratio as carbon and water enter or leave the gas phase.
Water condenses as the world
cools, with cold conditions sequestering surface water as ice. Erosion is represented
by aggregate weathering rather than an explicit terrain transport model. Rotation,
orbit and tilt are physical metadata; rendered rotation is slowed for observation.

Rare eruptions, impacts and continental collisions use `1 - exp(-rate × duration)`
hazard probabilities. They alter physical state; milestones report actual state
transitions. A normalized habitability score combines temperature, liquid oceans,
pressure, composition and geological stability. Hard liquid-water and atmospheric
gates cannot be averaged away. The score is an internal diagnostic, not a player resource.

Abiogenesis remains probabilistic and requires sustained favorable liquid water.
MVP 3 separates physical age from **biological opportunity**: life earns opportunity
at 12% of physical time, weighted by habitability and stability. Normal rates live in
`EvolutionTimescale.swift`. The abiogenesis hazard is twenty times smaller than MVP 2;
major innovation uses a planet-wide budget. Adding more species does not multiply
major breakthrough rates. There are no calendar unlocks or promised stages.

Persisted exponential waiting distances integrate hazard rather than sampling a new
coin on every UI tick. Evolution runs at one-million-opportunity-year boundaries;
population ecology runs at two-million-physical-year boundaries. Photosynthetic
chemical feedback uses a separate metabolic factor of 0.35. Formation/climate still
change during the first hours. Typical biological changes take days and weeks, with
substantial seeded variation and indefinite lifeless or microbial histories possible.
See the measured distribution in `docs/MVP3_IMPLEMENTATION.md`.

The globe has **48 ecological regions** (six latitude bands × eight longitude sectors).
They sample the same spherical terrain field as rendering, with coarse ocean fractions,
area weights, latitude temperatures, liquid-water availability and wet/dry/ice/volcanic
biomes. There is no high-resolution regional weather solver. Region snapshots and
species populations are saved; environmental fields update from global physical state.

Species have seeded scientific identifiers, parent IDs, origin/extinction times,
regional biomass and inherited traits. Size, mobility, reproduction, temperature
preference/tolerance, water dependence, oxygen demand, photosynthesis, efficiency,
defense and structural complexity each affect energy costs, fitness, growth, migration
or predation. Mutations are small, occasionally large, and never choose a better trait
by looking at the environment. Selection acts through population success afterward.

Producers capture chemical/solar energy; consumers and predators receive bounded
fractions from existing lower-level biomass; decomposers use regional detritus,
including steady mortality even when replacement growth hides net losses. Foraging
mobility improves resource capture; complexity improves tolerance, both with costs.
Competition shares finite pools. Absolute fitness also limits carrying capacity, so
an unsuitable organism cannot claim all energy merely by having no competitor.
Migration conserves biomass and crosses compatible neighboring regions; land life
cannot cross open-ocean cells, and aquatic life cannot grow on dry continents.
Populations begin only where founded, branched or migrated, not spontaneously everywhere.

Speciation branches an existing population with mutated inherited traits. Innovations
include cellular organization, photosynthesis, multicellularity, mobility, consumer
metabolism, recycling, predation, protection and water management. Prerequisites derive
from parent traits and surroundings: multicellularity needs oxygen; land adaptation
needs coastal populations and suitable atmosphere/tolerance. Strategies need not arise
in Earth's order. Extinct lineages retain ancestry and traits; their active populations
are removed. Background turnover favors small vulnerable populations. Catastrophes
change environment, with trait-dependent survival, rather than deleting a percentage
of species. Empty niches raise opportunity for surviving lineages.

`LifeStage` is now a summary of established living traits. Biomass, diversity, complexity,
productivity and dominance derive from the actual populations. Microbial carbon cycling
and photosynthetic CO₂ uptake/O₂ production feed back into climate. Ocean pigments
require aquatic photosynthetic populations; land coloration requires land-capable life.
Spatial interpolation smooths the coarse regional boundaries without inventing biomass.

Small mutations, ordinary migration and individual branching are silent. The timeline
records representative radiation thresholds, biodiversity doublings, major innovations,
land persistence, dominance changes and substantial collapse. Ancestry is always stored
regardless of event filtering. A dismissible return summary appears only for meaningful
new lineages, loss, range expansion, oxygen change or major events; it is never a modal.

Population values are **normalized biomass indices**, not counted organisms. Living
populations are capped at 192 lineages. Ordinary branching stops at 168, reserving
capacity for rare innovations; vulnerable-lineage turnover can reopen niches.
There are at most 4,096 historical lineage records.
At the archive ceiling, branching pauses while existing ecology continues; old ancestry
is not silently deleted. A future archival/aggregation policy should extend this bound.
No intelligence, civilization or communication module exists.

## Globe interaction

`GlobeRotationController` is pure quaternion/SIMD mathematics independent of Planet
and its random stream. The native adapter maps the cursor onto the globe's projected
sphere, with a continuous hyperbolic rim, and freezes projection geometry per drag.
Subdivided motion and normalized quaternions prevent fast-drag flips and re-grab jumps.
Geometric north/heading projection constrains tilt to 70° while preserving axial lean;
Euler angles are not accumulated. The camera remains stationary except for zoom.

Dragging stops idle spin; release applies subtle angular inertia with analytic
exponential damping. After coasting comes a short rest, then idle spin blends back in.
Scroll/pinch smoothly interpolates camera distance between 3 and 6 planet radii;
the globe's scale is never changed. Sensitivity, damping, inertia, idle speed/delay
and zoom response are centralized in `GlobeInteractionTuning`.
Visibility pauses animation timers and cloud actions without pausing simulation time.

## Time and reproducibility

Geological era: **100,000 years / real second**. Biological eras: **10,000 years /
real second**. Life emergence changes the rate at the next aggregate boundary.
The observer checks wall time every two seconds; the physical model processes fixed
**60-real-second intervals**, each covering 6 million or 600,000 simulated years.
Biological transitions run on accumulated opportunity; ecological populations use a
separate slower scheduler. Neither runs on rendering frames.
Measurements therefore change at minute boundaries. Unfinished seconds stay in the
save. An eight-hour absence is 480 aggregate calculations, not millions of frames.

Catch-up runs off the main actor on launch. It consumes all elapsed time without a
silent cap. Live batches have a work budget and retain any unfinished catch-up in
`pendingRealSeconds`. Work is linear in real minutes absent, so extremely long
absences can take longer; a future multiscale model should preserve deterministic
boundaries before coarsening this further. Backwards clock changes never rewind or
double-count time; forward changes are treated as elapsed time.

Seed, random state, physical state, pending interval and identical input sequences
reproduce the same trajectory on the same implementation. Tests check exact equality
across live/offline and save/reload boundaries. Floating-point differences across
architectures or future model versions are not promised to be bit-identical.

Local CPU activity changes geological hazard by at most 2%; uptime adds at most 0.5%.
The current live sample is used at an aggregate boundary. Offline/sleep intervals use
neutral inputs because past host activity is unknown. The provider exposes a charging
modifier for future aurora probabilities; MVP 1 does not model auroras. macOS wall
time drives elapsed progression and visual ambience is provided by rotation. No
messages, browser history, files, microphone, camera or location are inspected.

## Saves and failure handling

Default location: `~/Library/Application Support/SECOND EARTH/`.

`planet.json` is a version-3 envelope with seed, physical parameters, atmosphere,
climate, hydrology, geology, biosphere, species/ancestry, regional populations,
ecosystems, opportunity/hazard remainders, age, persistent events, RNG state,
pending real seconds and the last accounted wall timestamp. `planet.backup.json`
contains the previous validated save. Saves use atomic file replacement at launch,
every 30 seconds, on deactivation, and on orderly quit. Abrupt termination can lose
at most the unsaved live interval; reopening advances it again from the prior
timestamp. This is not a continuously running background daemon.

An OS advisory lock prevents concurrent writers. Corrupt primary saves recover from
a validated backup and are moved to a uniquely named `planet.corrupt-*.json` for
inspection. With no usable backup, opening stops and preserves files. Future schema
versions are rejected without fallback or replacement. The app never silently creates
a new planet over an invalid save.

Version-1 and version-2 saves are read and validated. Legacy `primitive` becomes
microbial; additional indices default conservatively. A living aggregate biosphere
becomes one representative founder lineage carrying its stage, origin and biomass;
no ancient species tree is fabricated. Seed, age, RNG, unfinished real time, timestamps
and old events remain. New opportunity clocks start at zero. Original data is retained
byte-for-byte in `planet.mvp1-original.json` or `planet.mvp2-original.json`, separately
from the rolling backup. Migration works during backup recovery as well. Saving writes
format 3; older binaries cannot read it. Unknown stages and future formats are rejected.

For isolated checks, set `SECOND_EARTH_SAVE_DIR` to a disposable directory. This is
a developer environment override; the normal UI offers neither save slots nor rewind.

## Performance and extensions

Normal rendering uses 30 FPS; the view pauses when inactive or occluded. The timer
keeps accounting for time, and macOS suspension is caught up on resume. No evolution
work runs per rendered frame. Textures refresh only when quantized visual state changes.
The starfield, clouds and terrain come from local procedural data, with no network.

Future ecological systems should extend Codable/Sendable trait or regional state,
add bounded deterministic integration, and supply explicit migration defaults. Keep
lineage history immutable and leave rendering/UI as snapshot consumers. Extend
`RealWorldInputProvider` through bounded, documented influences without private
monitoring. Add advanced eras through an explicit clock policy rather than UI timers.

The packaged app is locally ad-hoc signed. Public distribution requires a Developer
ID signature and notarization; neither is part of this build. SceneKit is used for
MVP portability and can later be replaced by Metal behind the rendering boundary.

## Verification tools

```sh
bash scripts/swift.sh test -c release
bash scripts/swift.sh run -c release PlanetProbe /tmp/second-earth-audit --ecology --days 90 --seeds 42,43,7,99
bash scripts/swift.sh run -c release PlanetProbe /tmp/second-earth-render --ecology --days 30 --seeds 43 --render
bash scripts/swift.sh run -c release PlanetProbe /tmp/second-earth-image --render-save /tmp/second-earth-audit/seed-43
bash scripts/swift.sh run -c release PlanetProbe /tmp/second-earth-cost --benchmark-save /tmp/second-earth-audit/seed-43
# Include the DEBUG-only laboratory test with optimized simulation code:
bash scripts/swift.sh test -Xswiftc -O
```

The ecology probe runs multiple seeded normal-speed histories, validates every
checkpoint, verifies save/reload equality, records milestones/regions/species, and
measures minute-step median/p95 time and encoded state size. `--render` exports actual
SceneKit results. Its isolated output directories never use the normal save.
The original `--biosphere` audit remains available. See `docs/MVP3_IMPLEMENTATION.md`
for current validation and the retained MVP 1/2 notes for their historical baselines.

The debug laboratory offers ×1/10/100/1,000/1,000,000 observational acceleration,
Myr advances, branching, climate/stress/extinction tests and vacant niches. Acceleration
is a per-session observer setting with a bounded batch; queued debug seconds are not
saved and are discarded when returning to ×1. Only explicitly processed debug time
alters the test planet; normal timing constants never change.

The Swift wrapper keeps build caches inside `.build` and locates the bundled Swift
Testing framework on Command Line Tools installations. On full Xcode, `swift test
--disable-xctest` also runs the same tests. All dependencies are local; the wrapper
disables SwiftPM's nested manifest sandbox to work inside managed build environments.
