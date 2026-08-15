# Changelog

## [0.1.0] - 2026-08-15

First release.

### Added

- Compact dispel panel: one box per group member, coloured by debuff type,
  click to cleanse.
- Automatic dispel detection for Paladin, Priest, Druid, Shaman, Monk, Evoker
  and Mage, following your current specialisation. Where a specialisation has a
  second dispel covering other schools, it is bound to right click.
- Stack counts, rendered by the game engine.
- Options panel in **Options → AddOns → Salve**: Layout, Appearance and Dispel.
- Drag handle beside the panel, plus a minimap button.
- LibDataBroker launcher, registered only when another addon has already loaded
  LibStub. Salve embeds no libraries and depends on none.
- `/salve probe` engine diagnostics.
- Experimental affliction alert sound, off by default.
