# Salve

A compact dispel panel for World of Warcraft. One click removes Curse, Disease,
Poison or Magic from anyone in your group.

## What it does

- One small box per group member, laid out in a grid you can size and place.
- A box lights up in the debuff's colour the moment that member catches
  something **you** can remove, and dims when they are clean.
- Left click dispels. Where your specialisation has a second dispel covering
  other schools, it goes on right click automatically.
- Stack counts, drawn by the game itself.
- Works for every dispelling specialisation: Paladin, Priest, Druid, Shaman,
  Monk, Evoker and Mage. Salve detects your dispels automatically and needs no
  configuring when you change spec.

## How it works

Salve never reads your debuffs. It hands the game a filter — harmful auras this
character can remove — along with the artwork for each box, and the game decides
what matches, when a box is visible, what colour it is and what the stack count
says.

This keeps the addon small and quiet: there is no aura event handler, and none
of Salve's own code runs during a fight. It also means the dispel colours come
from the game's palette rather than Salve's, so colourblind settings are
respected automatically and the colours always match the rest of your UI.

## Usage

| Command | Does |
|---|---|
| `/salve` | Open the options panel |
| `/salve unlock` | Show the drag handle |
| `/salve lock` | Hide the drag handle |
| `/salve reset` | Put the panel back in the centre |
| `/salve probe` | Print engine diagnostics |

Move the panel with the small grip beside it rather than by dragging the panel
itself — the boxes are buttons and cover every pixel of it. Right-click the grip
to hide it again, or use the minimap button.

Options live in **Game Menu → Options → AddOns → Salve**, under three pages:
Layout, Appearance and Dispel.

## Settings worth knowing

- **Show unit names** is off by default, because the default 20×20 boxes are too
  small for names to fit. Turn names on and raise the box width to around 58 if
  you would rather have them.
- **Keep clean units visible** holds the panel's shape so boxes never move
  mid-fight. Turning it off empties the panel until something lands. Note that a
  fully transparent box is still clickable — mouse input cannot be disabled on a
  protected frame during combat.
- **Alert sound** is experimental and off by default. Run `/salve probe` to see
  whether it has actually fired on your client.

## Limitations

- **No priority ordering between debuff schools, and no per-spell filtering.**
  Both would require inspecting aura data, which addons are no longer permitted
  to do. These are not missing features; they are outside what the game allows.
- **Dispel colours cannot be customised,** for the same reason — the game owns
  them.

## Licence

Salve is licensed **GPL v3**.

`Sounds/AfflictionAlert.ogg` is taken from Decursive by Archarodim and used
under GPL v3.
