# Forever personal dispels

Shatter Curse (`1299026`) is a separate optional personal action for Orcs
who know it on Forever build 70425 or later. Bind it under Personal dispels
on Actions. It is never selected as an automatic primary or secondary dispel,
and it does not add schools to class dispels, learning or group sounds.

Only the player's cell is armed, including a raid unit token that represents
the player. That token is normalised to literal `player` before the cell is
armed, so combat roster changes cannot turn it into an ally's cell. The secure
action explicitly targets `player`. When there is no
ordinary class cure, binding this action enables a single player cell.

## Cue and cooldown

A small `R` badge uses a dedicated player AuraContainer with `HARMFUL` and
native `includeDispelTypes = { Curse = true }`. Lua never reads the aura.
An addon-owned wrapper suppresses the badge while unbound, on another unit,
on cooldown, or when cooldown readiness is unavailable or secret. The racial
cooldown does not change the normal class-dispel sweep or secure attributes.
There is no personal-dispel sound registration.

The ordinary class-dispel visual keeps its existing native by-me filter.
Acceptance of a native slot does not prove the filter's live behaviour.
Neither this change nor its tests establish that Banes are exposed as Curse.
Diagnostics include the personal spell, readiness and binding failure.

## Sources and client checks

Blizzard's [October 15 notes](https://us.forums.blizzard.com/en/wow/t/2360696)
confirm the switch from immunity to dispelling Curses and Banes. The
[client spell record](https://foreverdb.net/spell/1299026) identifies Shatter
Curse as 1299026. The [70425 diff](https://needbeforegreed.com/forever/builds/70425)
places the new beta data after 70374. Checked 2026-10-16. Readiness uses the
current client cooldown, with no hardcoded three-minute timer.

Before release, use an Orc with no class Curse cure, then an Orc with one:

1. Verify default-unbound, bind, unbind and reload behaviour.
2. Apply a Curse to yourself and an ally. Confirm the R badge and racial
   action are restricted to yourself, and class dispels still work on allies.
3. Cast Shatter Curse. Confirm the R badge stays suppressed during cooldown
   and recovers if a Curse remains when the cooldown ends.
4. Repeat with a Bane, recording readable dispel classification outside
   combat. Do not claim Bane coverage before this check.
5. Check native cue rendering and secure casts during combat, player raid
   aliases, roster changes and an older non-Orc or Retail character.

Host tests cover discovery, binding scope, alias handling, cooldown secrecy,
unbinding, native setup arguments and combat construction deferral. Actual
Forever rendering, classification and action success remain client checks.
