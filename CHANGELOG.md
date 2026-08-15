# Changelog

All notable changes to Salve are recorded here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and Salve uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [0.1.0] — 2026-08-15

First release.

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
- Experimental affliction alert sound, off by default.

[0.1.0]: https://github.com/consecrated-hammer/Salve/releases/tag/v0.1.0
