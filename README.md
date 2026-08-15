<div align="center">

# Salve

**A compact dispel panel for World of Warcraft.**
One click removes Curse, Disease, Poison or Magic from anyone in your group.

[![License](https://img.shields.io/badge/license-GPL--3.0-4c9a7a?style=flat-square)](LICENSE.txt)
[![Release](https://img.shields.io/github/v/release/consecrated-hammer/Salve?style=flat-square&color=4c9a7a&label=release)](https://github.com/consecrated-hammer/Salve/releases)
[![Client](https://img.shields.io/badge/client-retail-4c9a7a?style=flat-square)](https://worldofwarcraft.blizzard.com/)

</div>

<!--
  SCREENSHOT: drop a PNG at media/panel.png and uncomment the block below.
  A 5-box party strip with two or three boxes lit reads best -- crop tight,
  and include a little of the surrounding UI so the scale is obvious.

<div align="center">
  <img src="media/panel.png" alt="The Salve panel in a five-player group" width="420">
</div>
-->

---

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

## How it works

Salve never reads your debuffs.

It hands the game a filter — *harmful auras this character can remove* — along
with the artwork for each box, and the game decides what matches, when a box is
visible, what colour it is and what the stack count says.

This keeps the addon small and quiet. There is no aura event handler, and none
of Salve's own code runs during a fight. It also means the dispel colours come
from the game's palette rather than Salve's, so colourblind settings are
respected automatically and the colours always match the rest of your UI.

## Getting started

Install, then type **`/salve`**.

The panel starts in the centre of your screen with a small gold grip beside it.
Drag the grip to place it — not the panel itself, whose boxes are buttons and
cover every pixel of it. Right-click the grip to hide it once you are happy.

### Commands

| Command | Does |
| :-- | :-- |
| `/salve` | Open the options panel |
| `/salve unlock` | Show the drag handle |
| `/salve lock` | Hide the drag handle |
| `/salve reset` | Put the panel back in the centre |
| `/salve probe` | Print engine diagnostics |

Options also live in **Game Menu → Options → AddOns → Salve**, under three
pages: Layout, Appearance and Dispel.

## Settings worth knowing

**Show unit names** is off by default. The default 20 × 20 boxes are too small
for names to fit — turn names on and raise the box width to around 58 if you
would rather have them.

**Keep clean units visible** holds the panel's shape so boxes never move
mid-fight. Turning it off empties the panel until something lands. Note that a
fully transparent box is still clickable: mouse input cannot be disabled on a
protected frame during combat.

**Alert sound** is experimental and off by default. Run `/salve probe` to see
whether it has actually fired on your client.

## Limitations

These are worth stating plainly, because they are not oversights:

- **No priority ordering between debuff schools, and no per-spell filtering.**
  Both would require inspecting aura data, which addons are no longer permitted
  to do. They are outside what the game allows, not features left undone.
- **Dispel colours cannot be customised,** for the same reason. The game owns
  them.

## Licence

Salve is licensed **GPL v3**. See [LICENSE.txt](LICENSE.txt).

`Sounds/AfflictionAlert.ogg` is taken from Decursive by Archarodim and used
under GPL v3.
