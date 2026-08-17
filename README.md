# Salve

**A compact dispel panel for World of Warcraft.** One click removes Curse,
Disease, Poison or Magic from anyone in your group.

[![CurseForge](https://img.shields.io/curseforge/v/1653368?style=flat-square&color=4c9a7a&label=curseforge)](https://www.curseforge.com/wow/addons/salve)
[![Downloads](https://img.shields.io/curseforge/dt/1653368?style=flat-square&color=4c9a7a&label=downloads)](https://www.curseforge.com/wow/addons/salve)
[![License](https://img.shields.io/badge/license-GPL--3.0-4c9a7a?style=flat-square)](LICENSE.txt)
[![Client](https://img.shields.io/badge/client-retail-4c9a7a?style=flat-square)](https://worldofwarcraft.blizzard.com/)

---

## Why Salve exists

WoW: Midnight made aura details private to addons. Older dispel addons were
built around reading those details, so they became unreliable or stopped
working.

Salve is built for the new rules. Blizzard decides which cells light up and
what dispel colour they use; Salve supplies the clickable panel. It can show
and remove debuffs your character can dispel. It cannot inspect them to rank
individual spells, and optional sound alerts can only cover spell IDs in the
current dungeon or raid catalogue.

## What it does

**One box per group member**, in a small grid you can size and place anywhere.

**It lights up instantly.** A box takes the debuff's colour the moment that
member catches something *you* can remove, and dims when they are clean.

**One click to cleanse.** Left click dispels. Where your specialisation has a
second dispel covering other schools, it goes on right click automatically.

**Stack counts**, drawn by the game itself, so they follow its own rules.

**Every dispelling specialisation** — Paladin, Priest, Druid, Shaman, Monk,
Evoker and Mage. Detected automatically, with nothing to reconfigure when you
change spec.

## Screenshots

| Clear cells | Dispellable cells | Unit names |
| :--: | :--: | :--: |
| ![Compact clear cells](docs/screenshots/panel-clear-cells.png) | ![Cells lit by dispel type](docs/screenshots/panel-dispellable-cells.png) | ![Wide cells with unit names](docs/screenshots/panel-unit-names.png) |

![Pinned preview and layout options](docs/screenshots/options-preview-and-layout.png)

More settings: [cell appearance](docs/screenshots/options-cell-size-and-alignment.png),
[visibility](docs/screenshots/options-visibility.png), and
[dispels and alerts](docs/screenshots/options-dispels-and-alerts.png).

## How it works

Salve never reads your debuffs.

It hands the game a filter — *harmful auras this character can remove* — along
with the artwork for each box, and the game decides what matches, when a box is
visible, what colour it is and what the stack count says.

This keeps the addon small and quiet. Normal operation has no aura event
handler, and none of Salve's own detection code runs during a fight. The
opt-in learning diagnostic is the sole exception. It also means the dispel
colours come from the game's palette rather than Salve's, so colourblind
settings are respected automatically.

## Getting started

Install, then type **`/salve`**.

The panel starts in the centre of your screen with a small gold grip above it.
Drag the grip to place it — not the panel itself, whose boxes are buttons and
cover every pixel of it. Use `/salve lock` or right-click the minimap button to
hide the grip once you are happy.

### Commands

| Command | Does |
| :-- | :-- |
| `/salve` or `/salve options` | Open the options panel |
| `/salve unlock` | Show the drag handle |
| `/salve lock` | Hide the drag handle |
| `/salve reset` | Put the panel back in the centre |
| `/salve debug` | Print a diagnostic report (`probe` remains an alias) |
| `/salve learn on` / `off` / `status` | Control persistent, opt-in aura learning |
| `/salve snares` | List auto-captured root and snare spell IDs for sharing |
| `/salve learned` / `learned clear` | Inspect or clear learned spell IDs |
| `/salve help` | Print the command list in chat |

Options also live in **Game Menu → Options → AddOns → Salve**, across six
pages: **Salve** (layout and live preview), **Visibility**, **Dispels**,
**Troubleshooting**, **Commands** and **About**.

## Settings worth knowing

**Show unit names** is off by default. The default 20 × 20 boxes are too small
for names to fit — turn names on and raise the box width to around 58 if you
would rather have them.

**Keep their cells on screen** holds the panel's shape. Turning it off makes
cells with nothing to dispel transparent. Their click areas stay in place:
mouse input cannot be changed on a protected frame during combat.

**Alert sound** is optional and off by default. When enabled, Salve loads
only the bundled data module covering the current instance, then registers only
that instance's debuff schools your character can remove. Season 1, Season 2
and future catalogues can coexist without loading or activating one another.
Run `/salve debug` to see the active module, spell ID count and native
sound registrations.

Diagnostic learning is deliberately opt-in and stays enabled until you turn it
off. Outdoor discoveries are keyed to the current map; dungeon and raid
discoveries are keyed to their instance. While it is enabled, Salve listens for
group aura changes and stores readable dispellable aura names, IDs and schools
in the separate `SalveLearnedDB` block in its saved data; private auras cannot be learned. It also automatically
captures Blizzard-reported roots and snares for group members through the
loss-of-control feed, so there is no need to type a command during a pull. It
starts off only so you explicitly choose whether to record group data; once
enabled, leave it on to improve coverage.

## Limitations

These are worth stating plainly, because they are not oversights:

- **The visual panel has no priority ordering or per-spell filtering.**
  Both would require inspecting aura data, which addons are no longer permitted
  to do. They are outside what the game allows, not features left undone.
- **Sound coverage is source-backed but not guaranteed complete.** Encounter
  Journal data covers boss abilities, not every trash debuff. Opt-in learning
  can collect readable omissions; private auras still require curated data.
- **Dispel colours cannot be customised,** for the same reason. The game owns
  them.

## Licence

Salve is licensed **GPL v3**. See [LICENSE.txt](LICENSE.txt).
