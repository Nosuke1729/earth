# MVP 1 implementation plan

Repository inspection: the supplied GitHub repository had no commits or files.
Local host: Apple Silicon, Swift 6.2.3 and the macOS SDK; no full Xcode.

1. Bootstrap a macOS 14+ Swift package with a SwiftUI executable, independent
   simulation library, persistence, safe local inputs, and a reusable SceneKit renderer.
2. Generate Earth-like physical parameters and terrain from a stored UInt64 seed.
   Start lifeless, hot and largely dry. Persist the exact SplitMix64 state.
3. Couple atmosphere, climate, cooling, hydrology and geology in aggregate intervals.
   Draw rare events from hazard probabilities; let abiogenesis depend on habitable
   conditions and sustained stability. Only `none` and `primitive` life stages.
4. Store the complete world and permanent event history in versioned JSON, with
   atomic replacement, a validated previous-save backup and an exclusive process lock.
   Catch up elapsed wall time independently of window visibility or rendering.
5. Present a rotating, draggable 3D world with procedural terrain, oceans, clouds,
   atmosphere, directional sunlight and seeded stars. Show a small set of measurements,
   a history panel and an observation inspector. Debug controls stay out of release builds.
6. Verify seed reproducibility, random reference vectors, live/offline equivalence,
   time remainders, era changes, climate coupling, physical bounds, corruption handling,
   schema rejection and save continuation. Build both configurations; render and launch.

Out of scope: species evolution, civilization, communication, wallpaper hosting,
external data sources, invasive permissions, user construction and rewind controls.
