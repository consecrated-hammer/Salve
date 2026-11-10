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
- **Movement removal for you.** Bind a spell like Blessing of Freedom on the Key Bindings page and your own box shows that spell's icon as a small badge when Blizzard reports a root or snare on you, with optional on-screen or chat text. These movement alerts are in beta and live on the **Movement (beta)** page.
- **Optional sound alerts** for known dispellable debuffs in the current dungeon or raid.

## Getting started

Install, then type `/salve` for settings.

The panel starts in the centre of your screen with a small gold grip above it. Drag the grip to move it (the boxes themselves are buttons, so the panel can't be dragged directly). Use `/salve lock`, or right-click the minimap button and pick **Hide drag handle**, to hide the grip once you're happy with it.

## Commands

| Command | What it does |
| --- | --- |
| `/salve` | Open settings |
| `/salve toggle` | Show or hide the panel |
| `/salve lock` / `unlock` | Hide or show the drag grip |
| `/salve reset position` | Put the panel back in the centre |
| `/salve profile` / `profile <name>` | List layout profiles, or switch to one |
| `/salve forever` | Copy a WoW Forever cure and spellbook report, handy for bug reports |
| `/salve whatsnew` | Show what's new in recent releases |
| `/salve whatsnew reset` | Bring back the What's new popup and "!" (for testing) |
| `/salve cooldowns` | Show how the cooldown icons read each spell; works in combat |
| `/salve snares` | List the root and snare spell IDs Salve has captured |
| `/salve learned` / `learned clear` | Show or clear the learned spell catalogue |

Every Consecrated Hammer addon also has `help`, `version`, `about`, `debug`, `startup`, `minimap`, `reset settings` and `quiz`.

## Detected actions

The **Key Bindings** page only lists spells your character knows. Click a spell on the right, then the mouse button you want, and it joins the bound list on the left; the x beside it removes it. Movement actions stay off until you bind them. "Area movement" is a ground-placed spell, so drop it where the affected players can reach it.

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

Orcs on WoW Forever can also bind **Shatter Curse** under
**Personal dispels**. It starts unbound and works only on your own cell.
A small **R** cue marks a Curse while the racial is ready; it stays hidden
when readiness is unavailable. Ordinary class dispels keep their bindings.
This action adds no sound alerts. Its Forever cue and Bane coverage still need
an in-game check; see the [personal-dispel checks](https://github.com/consecrated-hammer/Salve/blob/main/docs/forever-personal-dispels.md).

## Settings worth knowing

The settings pages are **Panel** (with Layout, Cells and Text tabs), **Sorting**, **Attach**, **Cooldowns**, **Tooltips**, **Key Bindings**, **Visibility**, **Alerts** and **Movement (beta)**, then **Learned Spells**, **What's new**, **Commands**, **Troubleshooting** and **About**.

- **Preview.** The Panel page can show a full-size test panel at the panel's saved position, with controls for group size, clear or dispellable boxes and cooldowns, so you can set it up without waiting for someone to get cursed. It closes with the settings window or when combat starts.
- **Panel controls.** **Fill** picks rows or columns and **Start corner** picks where the first cell goes. Names and cooldown numbers each have one position selector. Name, icon and idle-background details appear when enabled; switching backgrounds off remembers their opacity. Tooltips have their own page and reset. Lit cells also show Blizzard's own debuff tooltip, since addons can't read debuffs in combat; **Show Blizzard debuff tooltip** turns it off.
- **Out of range fading.** Cells fade for group members out of your dispel's range. **Out of range opacity** on the Cells tab sets how faded, and 100% turns it off. Your own cell never fades.
- **Live preview.** **Show live preview** at the top of Panel, Sorting, Cooldowns, Visibility and Movement opens the panel in its own window, at actual size, with the cooldown bar and drag handle. Drag it anywhere; it stays open while you change pages and closes with settings (or turn on **Open with settings** in the window). **Keep in front**, on by default, keeps it above the settings window; turn it off and whichever you click comes to the front. It only shrinks if your layout wouldn't fit on screen, and says so. **At panel position** also shows the test panel where Salve sits, which is the one to use when attached Left or Right to another addon's frames. Under **Show**, sample states mix freely: **Dispellable debuff** (colour, type icon at its size and position, two stacks), **Dispel on cooldown**, **Movement sweep**, **Rooted** (the badge on your own cell) and **Lockout** (on a cell, the bar or both, per Show on). The dispel starts ready so the debuff reads clearly. If a ticked state can't show, for example lockouts are off or nothing bound causes one, the note under the controls says why.
- **Right-click menus.** Right-clicking the minimap button opens a small menu: **Salve settings**, **Profiles**, **Hide drag handle** (or **Show drag handle**), then your profiles with the active one ticked. **Minimap right-click** on Visibility switches it to opening settings instead. **Handle right-click** gives the drag handle the same menu, or settings.
- **Hide on flights**, on Visibility and on by default, hides the panel, its handle and cooldown bar, and the on-screen movement text while you're on a flight path, and brings them back when you land. Land in the middle of a fight and the panel comes back as soon as combat ends, because the game won't let addons show it mid-fight.
- **Show unit names** is off by default because names don't fit in the default 20 × 20 boxes. Turn it on and widen the boxes to about 95 if you'd like names.
- **Start corner** grows the grid from any corner, for rows or columns. That corner stays put as the group changes, so **Bottom left** adds new rows above the first one rather than down into your action bars, and lining Salve up with your unit frames stays easy.
- **Profiles** keeps separate layouts for different group sizes. You start with Party, Raid 20 and Raid 40, each holding its own position and grid (cells per row, spacing, cell size, scale and start corner). You can tick unit names, sorting, the cooldown bar, visibility or attach into profiles too, and add, copy, rename or delete profiles on the **Profiles** page. Switch from the Profile dropdown at the top of the Panel page, right-clicking the minimap button or the drag handle, or `/salve profile <name>`. **Auto-switch** is off until you pick **Switch automatically** or **Ask first**. It then follows rules you can edit (group type, size, instance type), checking when you join or leave a group, enter an instance or the group size changes. A switch always waits until combat ends.
- **Sorting** has its own page. It keeps the game's group order by default. You can sort by role, in any tank, healer and DPS order, or by name, pin your own box first or last, and reverse the rest. Sorting only happens out of combat, because the game won't let addons move protected boxes during a fight. If the group changes mid-fight, names update but the order waits until combat ends, so a box can briefly be in the "wrong" place. Members with no role, or whose name the game keeps private, go last in their group order.
- **Attach** lines Salve up with DandersFrames or EllesmereUI group frames. Left or Right puts each cell beside its member's frame, at the same spacing and in the host's order, with raid groups kept apart. Top or Bottom keeps Salve's grid together above or below the host's frames. Salve moves when those frames move, even mid-fight. Re-aligning after a mid-fight reshuffle waits until combat ends, and Salve uses its saved position whenever the host's frames aren't on screen. The drag handle is hidden while attached.
- **Cooldowns** holds the cooldown display. **Sweep style: Icon** moves the cooldown sweep off the whole cell onto a small spell icon that only shows while the spell is on cooldown. **Auto**, the default, does that only when names are on, and keeps the whole-cell sweep when they're off. The **cooldown bar** puts icons for the spells bound on Key Bindings beside the grid, showing each one while it's on cooldown, or dimmed when ready if you turn on **Show when ready**. Salve still never reads cooldown times; it asks the game whether a spell is on cooldown, and where the game won't say mid-fight, it lets the game fade the icon itself. If neither works, the icon stays visible rather than hide a cooldown you need to know about. **Show lockout debuffs** shows Forbearance on the cooldown bar, with the name of whoever you just cast Blessing of Protection (or similar) on, or on their cell if you prefer. The game won't let addons read that debuff on other players, so Salve times it from your own casts and can't see another paladin's.
- **Show box borders** controls the outlines around all boxes, including the preview. For a quieter panel, turn it off along with **Show idle backgrounds**, keep unit names off and use `/salve lock` to hide the grip. Dispel alerts and cooldowns still draw, and invisible boxes still take clicks because the game won't let addons change that on protected frames in combat.
- **Alert sounds** are off by default. When on, Salve only listens for debuffs from its built-in list for the dungeon or raid you're in, and only ones you can remove. Roots and snares on you use a separate sound, switched on the Movement page. Both pages have a test button. Under **Learning messages**, switch off scope-change or newly learned-spell chat messages separately; Salve keeps recording spells.
- **Movement (beta)** holds the automatic root and snare alerts. Turn off **Enable movement alerts (beta)** to stop all movement text, sounds and the movement badge while keeping your movement-spell bindings and dispel alerts. **Include inferred slows (beta)** is off by default. When it's on, a sharp drop in your run speed also shows movement text and the movement badge, pointing at the mouse button you bound for Freedom or similar. Salve can't tell whether an inferred slow is removable, so it may not work correctly, and it never plays a sound. Bindings stay on the Key Bindings page; each bound movement spell's sweep colour and **Show sweep** switch are under **Movement sweeps** here.
- **Learned spells.** Salve records the readable dispellable debuffs and reported roots and snares it sees, grouped by location, which helps improve the built-in list. **Copy learned spells** on the Learned Spells page gets it ready to paste, and `/salve learned clear` empties it.

## Limits

These aren't oversights. Midnight made debuff details private to addons, so Salve hands the game a filter for _harmful auras this character can remove_ and the game decides which boxes light up, and with which colour and icon. That keeps Salve working, but it means:

- **It can't prioritise or hide individual debuffs.** That needs debuff details that addons can't use for this any more.
- **Dispel colours and icons can't be changed.** The game owns them, and they follow your colourblind settings. The cooldown sweep colour for each movement action can be set on the Movement page.
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
