# Development builds

Before testing an unreleased Salve change through `Copy-AddonToWoW.ps1`, set
the main addon's `## Version:` in `Salve.toc` to the next clearly labelled
development suffix, for example `1.5.2-dev1`, then `1.5.2-dev2`. The current
redesign test build is `1.5.2-dev60`.

Increment the `devN` suffix for every new debug copy so the version shown in
the AddOns list and `/salve version` confirms which build the game loaded.
Do not change release metadata, generated data-module versions or the
changelog for these local debug builds. At release time, replace the suffix
with the final release version and follow the normal release checklist.
