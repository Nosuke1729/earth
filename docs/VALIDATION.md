# MVP 1 validation

Performed on an Apple Silicon Mac on 2026-10-01, with Swift 6.2.3 and the macOS
Command Line Tools SDK. Deployment target: macOS 14. Full Xcode was not installed.

## Automated checks

`bash scripts/swift.sh test -j 4` passed **19 tests in two suites**. The final run
took approximately 0.102 seconds after compilation. Both debug and release
executables compiled successfully, including the native SwiftUI / SceneKit app.

The tests cover:

- Seed reproducibility and variation, and SplitMix64 reference outputs.
- Exact eight-hour live/offline equality, including life and adaptive-rate transition.
- Fractional real seconds, repeated timestamps and backwards-clock behavior.
- Catch-up work budgets retaining every unprocessed second.
- Hostile abiogenesis conditions and diverse stochastic origin ages across 40 seeds.
- Seven-day aggregate progression across 20 seeds with finite bounded physical state.
- CO₂ warming, ice albedo and conservation of the inert-gas mixing ratio.
- Exact save/reload continuation, backup recovery and preserved corrupt files.
- Refusal to replace unrecoverable saves or future-schema saves.
- Invalid physical/timeline rejection and exclusive writer locking.

## Native execution and rendering

The ad-hoc signed `.app` launched with an isolated save directory. It generated a
planet, progressed while inactive, and wrote its primary and previous-save files.
One sample after about six minutes showed **0.1% CPU** and **128,624 KiB resident
memory**. This is an inactive-process spot check, not a full performance benchmark.

The isolated test process was stopped and its saved timestamp moved back eight
hours. Reopening retained seed `12670746535005086756`, advanced the world to over
1.12 billion years and saved a primitive biosphere with formation, stable-ocean,
continental-collision and life events. No normal user save was used or changed.

`PlanetProbe` exported actual offscreen SceneKit renders for three states:
formation, one-hour ocean development, and eight-hour primitive life. Inspection
revealed and corrected an atmosphere blending defect and cloud alpha handling.
The final images show procedural land/oceans, evolving volcanic emission, clouds,
atmosphere and directional day/night shading. See `media/` for the rendered images.

The seed-42 fixture at eight hours reached 2.0592 billion years, 13.575 °C and
60.799% liquid ocean coverage. Life originated at 1.968 billion years. Seven-hour
catch-up plus atomic save/reload took approximately 1.3 milliseconds. These ages
are outcomes of this seed and model, not scripted milestones or promised outcomes.

`codesign --verify --deep --strict` and `plutil -lint` passed for the packaged app.
The release configuration excludes all developer intervention controls.

## Remaining verification limits

- Computer Use permissions were unavailable. Manual camera dragging, zooming,
  planet clicking, history scrolling, panel layout, settings and graceful window
  closing were not interactively verified. The app was launched and its autosave
  and reopen behavior were inspected; the UI should not be described as fully tested.
- Notification permission/delivery was not exercised. Notifications remain off
  by default; the app requests authorization only through the user-enabled setting.
- Intel, macOS 14 hardware, active-window GPU consumption, multi-day runtime,
  external distribution, Developer ID signing and notarization were not tested.
- Catch-up is bounded in work per real minute, not constant-time for arbitrarily
  long absences. Very long periods may take longer to restore.

The `.app` is locally ad-hoc signed for this implementation host. It is not a
notarized public distribution. Civilization, detailed evolution, communication,
wallpaper mode and invasive real-world integrations were intentionally not built.
