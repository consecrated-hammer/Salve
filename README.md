# Salve

**Decursive-style dispelling, one click per party member.**

_One click to cleanse them all, and in the options bind them._

[![Discord](https://img.shields.io/badge/discord-join-5865F2?style=flat-square&logo=discord&logoColor=white)](https://discord.gg/z3xKxRygDc) [![Retail](https://img.shields.io/badge/retail-supported-4c9a7a?style=flat-square)](https://www.curseforge.com/wow/addons/salve) [![WoW Forever](https://img.shields.io/badge/wow%20forever-supported-4c9a7a?style=flat-square)](https://www.curseforge.com/wow/addons/salve) [![Release](https://img.shields.io/github/v/release/consecrated-hammer/Salve?style=flat-square&color=4c9a7a&label=release)](https://github.com/consecrated-hammer/Salve/releases) [![License](https://img.shields.io/badge/license-GPL--3.0-4c9a7a?style=flat-square)](https://github.com/consecrated-hammer/Salve/blob/main/LICENSE.txt)

Questions, bugs or ideas? Come say hi on the [Consecrated Hammer Discord](https://discord.gg/z3xKxRygDc). Bug reports go in `#bug-reports`, or you can open a [GitHub issue](https://github.com/consecrated-hammer/Salve/issues).

---

Salve gives you one box per group member. When someone picks up a debuff you can remove, their box lights up with that debuff type's colour and icon, and you click it to cleanse them. As a long-time Decursive user, I wanted to keep that simple rhythm: see the colour, click the box, cleanse the party.

## What it does

- **One box per group member**, in a small grid you can size and place anywhere.
- **It lights up straight away.** A box shows the dispel type's colour and icon (Magic, Curse, Poison or Disease) the moment that member catches something _you_ can remove, and dims when they're clean. Stack counts are drawn by the game itself.
- **One click to cleanse.** Left click uses your primary dispel. If your spec has a second dispel covering other schools, it goes on right click automatically. Every detected action can be rebound.
- **Every dispelling class:** Paladin, Priest, Druid, Shaman, Monk, Evoker, Mage and Warlock. Your spells are picked up automatically when you change spec or, for Warlocks, when your demon changes.
- **Movement removal for you.** Enable a spell like Blessing of Freedom on the Actions page and your own box lights gold when Blizzard reports a root or snare on you, with optional on-screen or chat text.
- **Optional sound alerts** for known dispellable debuffs in the current dungeon or raid.

## Getting started

Install, then type `/salve` for settings.

The panel starts in the centre of your screen with a small gold grip above it. Drag the grip to move it (the boxes themselves are buttons, so the panel can't be dragged directly). Use `/salve lock` or right-click the minimap button to hide the grip once you're happy with it.

## Commands

| Command | What it does |
| --- | --- |
| `/salve` | Open settings |
| `/salve toggle` | Show or hide the panel |
| `/salve lock` / `unlock` | Hide or show the drag grip |
| `/salve reset position` | Put the panel back in the centre |
| `/salve forever` | Copy a WoW Forever cure and spellbook report, handy for bug reports |
| `/salve snares` | List the root and snare spell IDs Salve has captured |
| `/salve learned` / `learned clear` | Show or clear the learned spell catalogue |

Every Consecrated Hammer addon also has `help`, `version`, `about`, `debug`, `startup`, `minimap`, `reset settings` and `quiz`.

## Detected actions

The **Actions** page only lists spells your character knows. Movement actions stay off until you turn them on and bind them. "Area movement" is a ground-placed spell, so drop it where the affected players can reach it.

| Class | Dispels | Frees movement (ally) | Area movement | Self only |
| --- | --- | --- | --- | --- |
| Paladin | Cleanse: Magic, Poison, Disease; Cleanse Toxins: Poison, Disease | Blessing of Freedom; Blessing of Protection | None | Divine Shield |
| Priest | Purify: Magic, plus Disease with Improved Purify; Purify Disease: Disease | None | None | None |
| Druid | Nature's Cure: Magic, plus Poison/Curse with Improved Nature's Cure; Remove Corruption: Poison, Curse | None | None | Travel Form; Cat Form |
| Shaman | Purify Spirit: Magic, plus Curse with Improved Purify Spirit; Cleanse Spirit: Curse | None | Wind Rush Totem (Jet Stream only) | Spirit Walk; Ghost Wolf |
| Monk | Detox (Mistweaver): Magic, plus Poison/Disease with Improved Detox; Detox: Poison, Disease | Tiger's Lust | None | None |
| Evoker | Naturalize: Magic, Poison; Expunge: Poison; Cauterizing Flame: Poison, Curse, Disease | None | None | Hover |
| Mage | Remove Curse: Curse | None | None | Blink; Shimmer; Ice Block; barriers with Energized Barriers (snares only) |
| Hunter | None | Master's Call | None | None |
| Death Knight | None | None | None | Wraith Walk; Death's Advance |
| Demon Hunter | None | None | None | Fel Rush; Vengeful Retreat |
| Rogue | None | None | None | Shadowstep; Sprint |
| Warrior | None | None | None | Heroic Leap |
| Warlock | Singe Magic (via your Imp) | None | None | Demonic Circle: Teleport |

Talent-gated actions only show up when you know both the spell and the talent that enables it. Jet Stream and Energized Barriers remove snares, not roots.

On WoW Forever, Salve uses that client's own dispels instead: Paladin Purify and Cleanse, Priest Cure Disease, Abolish Disease and Dispel Magic, Druid Cure Poison, Abolish Poison and Remove Curse, Shaman Cure Poison and Cure Disease, and Mage Remove Curse. If one of yours is missing, `/salve forever` copies a report you can paste into `#bug-reports`.

## Settings worth knowing

The settings pages are **Panel**, **Tooltips**, **Actions**, **Visibility** and **Alerts**, then **Learned Spells**, **Commands**, **Troubleshooting** and **About**.

- **Preview.** The Panel page can show a full-size test panel at the panel's saved position, with controls for group size, clear or dispellable boxes and cooldowns, so you can set it up without waiting for someone to get cursed. It closes with the settings window or when combat starts.
- **Show unit names** is off by default because names don't fit in the default 20 × 20 boxes. Turn it on and widen the boxes to about 95 if you'd like names.
- **Grid flow** lets rows grow from the left or right and columns from the top or bottom. The edge you pick stays anchored as the group changes, which makes it easier to line Salve up with your unit frames.
- **Show units with nothing to dispel** keeps the panel's shape. Turn it off and idle boxes go transparent, but they still take clicks, because the game won't let addons change that on protected frames in combat.
- **Alert sounds** are off by default. When on, Salve only listens for debuffs from its built-in list for the dungeon or raid you're in, and only ones you can remove. Roots and snares on you use a separate sound. The Alerts page has a test button for each.
- **Learned spells.** Salve records the readable dispellable debuffs and reported roots and snares it sees, grouped by location, which helps improve the built-in list. **Copy learned spells** on the Learned Spells page gets it ready to paste, and `/salve learned clear` empties it.

## Limits

These aren't oversights. Midnight made debuff details private to addons, so Salve hands the game a filter for _harmful auras this character can remove_ and the game decides which boxes light up, and with which colour and icon. That keeps Salve working, but it means:

- **It can't prioritise or hide individual debuffs.** That needs debuff details that addons can't use for this any more.
- **Dispel colours and icons can't be changed.** The game owns them, and they follow your colourblind settings. The cooldown sweep colour for each movement action can be set on the Actions page.
- **Sound alerts only cover Salve's built-in list.** They can miss a debuff the box still lights up for, and they can't play for private auras.
- **Movement alerts are for you only.** Roots and snares on other players aren't reported.

## Screenshots

![All clear](https://media.forgecdn.net/attachments/1889/940/screenshot-2026-08-22-151235-png.png)

All clear.

![Time to click](https://media.forgecdn.net/attachments/1889/941/screenshot-2026-08-22-151216-png.png)

You really should be clicking that.

![On cooldown](https://media.forgecdn.net/attachments/1889/939/screenshot-2026-08-22-151247-png.png)

Waiting for that cooldown.

## Licence

GPL v3, see [LICENSE.txt](https://github.com/consecrated-hammer/Salve/blob/main/LICENSE.txt). The alert sound `Sounds/AfflictionAlert.ogg` comes from Decursive by Archarodim and is used under GPL v3.
