# Changelog

All notable changes to Salve are recorded here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and Salve uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

## [1.1.0] — 2026-08-16

### Added

- Expanded alert-sound coverage to all eight Midnight Season 2 Mythic+
  dungeons using current Mythic Dungeon Tools dispel metadata, Blizzard DB2
  spell categories and four live learning captures.
- Added 52 catalogue records, bringing the Season 2 Mythic+ pool to 62
  source-backed spell IDs.

### Changed

- Updated instance 2993 to its live in-game name, Altar of Rezan.

## [1.0.0] — 2026-08-16

First stable release.

### Added

- Load-on-demand Midnight Season 1 and Season 2 sound catalogues. Only data for
  the current dungeon or raid loads, and only spell schools the character can
  remove are registered.
- Blizzard-driven Cleanse cooldown sweeps and countdown text on every cell.
- Scrollable Salve, Visibility, Dispels, Troubleshooting, Commands and About
  pages with short tooltips and per-page reset actions.
- A pinned 1–40 player preview for layout, clear/dispellable state, cooldown,
  names, stack counts, class colours, sizing and text placement.
- Configurable name and cooldown text size/alignment, clear-cell class colours,
  and eight drag-handle anchors.
- Temporary location-scoped aura logging for catalogue diagnostics. It turns
  itself off on zone change, reload and logout.
- Copyable diagnostics, `/salve debug`, optional startup message, CurseForge
  metadata, release screenshots and a complete in-game command reference.

### Changed

- Detection now uses Blizzard's broad harmful-aura candidate filter narrowed to
  the dispel schools the current character can remove. This catches manually
  curable dungeon and legacy effects omitted by the raid-only flag.
- Alert sound defaults off and uses the bundled GPL-compatible Decursive alert.
- Learning mode is opt-in and session-only instead of always listening.
- Clean cells use Blizzard artwork and persistent borders rather than flat,
  merging boxes.
- `/salve probe` remains as a compatibility alias for `/salve debug`.

### Fixed

- Secret or unreadable legacy auras no longer produce learning-mode Lua errors.
- Duplicate automatic click bindings are collapsed and removed visibility
  conditions are cleared from existing profiles.
- Cooldown widgets render outside Blizzard's sealed aura-button subtree.
- Sound and learning modules remain dormant when both features are disabled.
- Options pages stay within the settings frame and refresh reliably after
  changes, resets and specialisation swaps.

## [0.1.0] — 2026-08-15

Beta release.

### Added

**The panel**

- One box per group member, coloured by debuff type, click to cleanse.
- Left click dispels. Where a specialisation has a second dispel covering other
  schools, it is bound to right click automatically.
- Stack counts, rendered by the game engine.
- Drag handle beside the panel, and a minimap button.

**Supported specialisations**

- Paladin, Priest, Druid, Shaman, Monk, Evoker and Mage. The dispel is detected
  from your current specialisation and follows it when you change.

**Options**

- Settings panel in **Options → AddOns → Salve**, across Layout, Appearance and
  Dispel pages.
- Panel size, columns, spacing, scale and position.
- Unit names, stack counts, and how clean members are shown.
- Where the panel appears: solo, party, raid.

**Other**

- LibDataBroker launcher, registered only when another addon has already loaded
  LibStub. Salve embeds no libraries and depends on none.
- `/salve probe` engine diagnostics.
- Optional native aura alert sound, off by default. Load-on-demand Midnight
  Season 1 and Season 2 modules register only the current instance's verified
  IDs and only schools the current character can remove.
- Opt-in, group-scoped `/salve learn` diagnostics for readable catalogue gaps.

[1.1.0]: https://github.com/consecrated-hammer/Salve/releases/tag/v1.1.0
[1.0.0]: https://github.com/consecrated-hammer/Salve/releases/tag/v1.0.0
[0.1.0]: https://github.com/consecrated-hammer/Salve/releases/tag/v0.1.0
