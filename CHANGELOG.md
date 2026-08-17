# Changelog

All notable changes to Salve are recorded here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and Salve uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.3.2] - 2026-08-17

### Added

- Promoted five live captures from Vaults of Atal'Utek into the Season 2
  catalogue: four dispellable effects and the Snared movement impairment.

### Fixed

- `/salve version` reports the installed version and revision instead of
  opening Options. Removed the remaining spell-cast cooldown refresh path so
  non-dispel global cooldowns cannot sweep Salve cells.

## [1.3.1] - 2026-08-17

### Fixed

- Aura logging now clearly states that it remains enabled until turned off,
  rather than incorrectly describing the old session-only behaviour. The
  settings UI, slash-command feedback and documentation explain that it records
  readable group aura metadata, cannot learn private auras, and is optional to
  keep normal operation free of aura-event listeners.
- With learning enabled, roots and snares reported by Blizzard's
  loss-of-control feed are captured automatically for group members. The manual
  `/salve snared` command has been removed; it was not usable while healing a
  Mythic+ pull.

## [1.3.0] - 2026-08-17

### Added

- **Roots and snares (alpha).** These carry no dispel school, so Salve's normal
  filter never saw them. A second engine-driven overlay now outlines a cell when
  a captured movement-impairing effect is on it, drawn as a border so a cell
  that is also dispellable still shows its dispel colour underneath.
- Per-class escape list on the Dispels page. Nothing is enabled until you tick
  it: several candidates are mobility rather than a true removal, and some are
  talent-gated, so which ones count is your call rather than Salve's.
- Party-wide escapes (Blessing of Freedom, Tiger's Lust, Master's Call) light
  anyone's cell. Personal ones (Blink, Wraith Walk, shapeshift and the rest)
  light only your own, because you cannot Blink someone else out of a root.
- `/salve snared` captures whatever is impairing you right now, and
  `/salve snares` lists what has been captured.

### Changed

- Learning no longer switches itself off on zone change, reload or logout. It
  re-scopes instead. Traffic is light in practice, and for movement-impairing
  effects learning is the primary data source rather than a diagnostic.

### Known limitations

- The curated movement list is nearly empty by design. Blizzard's journal
  describes only boss abilities, and dungeon roots and snares come almost
  entirely from trash, so a database join across the whole Season 1 and
  Season 2 pool yields three spells. `/salve snared` is how this fills in.

## [1.2.0] - 2026-08-17

### Added

- Hover tooltip on every cell, naming the unit and listing what each bound
  mouse button will cast on them. Built from your live bindings, so it follows
  custom assignments and specialisation changes. On by default, with a toggle
  on the Salve page.

### Changed

- The cooldown swipe now shows only the dispel's own cooldown. It previously
  refreshed on `SPELL_UPDATE_COOLDOWN`, which fires on every global cooldown,
  so cells swept for a second and a half whatever you cast and the swipe
  carried no information.

### Fixed

- Release notes now conform to Keep a Changelog, so CurseForge sections each
  release instead of rendering the whole history as one block. Only the
  released version's notes are published.

## [1.1.0] - 2026-08-16

### Added

- Expanded alert-sound coverage to all eight Midnight Season 2 Mythic+
  dungeons using current Mythic Dungeon Tools dispel metadata, Blizzard DB2
  spell categories and four live learning captures.
- Added 52 catalogue records, bringing the Season 2 Mythic+ pool to 62
  source-backed spell IDs.

### Changed

- Updated instance 2993 to its live in-game name, Altar of Rezan.

## [1.0.0] - 2026-08-16

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

## [0.1.0] - 2026-08-15

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

[1.3.0]: https://github.com/consecrated-hammer/Salve/releases/tag/v1.3.0
[1.3.1]: https://github.com/consecrated-hammer/Salve/releases/tag/v1.3.1
[1.2.0]: https://github.com/consecrated-hammer/Salve/releases/tag/v1.2.0
[1.1.0]: https://github.com/consecrated-hammer/Salve/releases/tag/v1.1.0
[1.0.0]: https://github.com/consecrated-hammer/Salve/releases/tag/v1.0.0
[0.1.0]: https://github.com/consecrated-hammer/Salve/releases/tag/v0.1.0
