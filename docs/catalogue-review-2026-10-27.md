# Catalogue review, 2026-10-27

This refresh adds 12 ordinary dispel records to the built-in sound catalogue.
The CSV `verified` flag means the aura ID and school were checked against the
named source. It does not mean Salve playback has been observed in game.

## Sources

Reviewed installed BigWigs v427.8, LittleWigs v12.1.22, DBM 12.1.17 and
ExBoss v26.10.27.1315 source. Each CSV row names its versioned source file.
BigWigs and LittleWigs use `SetAuraData` for the current aura IDs and explicit
`dispel` fields for schools. Historical cast or damage IDs were not substituted
for those aura IDs.

| Instance | Effect | Aura ID | School | Author source |
|---|---|---|---|---|
| Ruby Life Pools, 2521 | Living Bomb | 373693 | Magic | LittleWigs_Dragonflight/RubyLifePools/Trash.lua; Blizzard tuning |
| The Venomous Abyss, 3004 | Venomfang | 1306906 | Poison | BigWigs_TheVenomousAbyss/CoiledAltar.lua |
| The Venomous Abyss, 3004 | Icebound Flames | 1286922 | Magic | BigWigs_TheVenomousAbyss/Explorers.lua |
| The Venomous Abyss, 3004 | Essence Rend | 1287434 | Magic | BigWigs_TheVenomousAbyss/Nekzali.lua |
| The Venomous Abyss, 3004 | Tempest | 1287083 | Poison | BigWigs_TheVenomousAbyss/Sszorak.lua |
| The Venomous Abyss, 3004 | Congealing Bolt | 1305833 | Magic | BigWigs_TheVenomousAbyss/Vashnik.lua |
| Windrunner Spire, 2805 | Curse of Darkness, preliminary effect | 1253834 | Curse | LittleWigs/Midnight/WindrunnerSpire/DerelictDuo.lua |
| Windrunner Spire, 2805 | Curse of Darkness, main effect | 1215803 | Curse | Same file; distinct aura row |
| Algeth'ar Academy, 2526 | Energy Bomb | 374350 | Magic | LittleWigs_Dragonflight/AlgetharAcademy/EchoOfDoragosa.lua |
| Torment's Rise, 2966 | Devouring Essence | 1256358 | Magic | LittleWigs/Midnight/Delves/TormentsRise/Nullaeus.lua |
| Torment's Rise, 2966 | Curse of Hesitation | 1256526 | Curse | Same file |
| Venomfall Deeps, 3079 | Void Toxin | 1293824 | Magic | LittleWigs/Midnight/Delves/VenomfallDeeps/Aztarec.lua |

BigWigs raid loading explicitly assigns instance 3004. The two added delve
IDs appear in LittleWigs' `X-BigWigs-LoadOn-InstanceId`, BigWigs' loader map and
the corresponding DBM delve modules' `SetZone` calls. Torment's Rise remains
in the Season 1 catalogue; Venomfall Deeps belongs to Season 2.

Living Bomb's change is confirmed in
[Blizzard's 12.1.5 tuning](https://eu.forums.blizzard.com/en/wow/t/dungeon-and-raid-tuning-%E2%80%93-14-october/635185)
and [Wowhead's tuning report](https://www.wowhead.com/news/ruby-life-pools-nerfs-on-patch-12-1-5-ptr-mythic-dungeon-tuning-383357),
which links aura 373693. Local logs confirmed successful removal; no raw player
logs or identities are included here.

## Behaviour and client checks

These entries use the existing instance and cure-school sound selection. They
do not change visual filtering, protected clicks, defaults or movement alerts.
Sound registration is an aura warning, not a recommendation about the safest
moment to dispel. Essence Rend's tooltip says removal spawns a Latent Cultist;
other effects can also have removal or expiration consequences.

The automated check exercises native sound registration for every added ID,
school exclusion and absence outside the recorded instance. Confirm actual
sound playback in each relevant instance on a character with the matching
cure and dispel alerts enabled. The two Curse of Darkness stages are separate
aura IDs in both LittleWigs and DBM; each stage intentionally has its own
registration and can sound when applied. Do not merge records by display name.
Verify the new delve scopes through client diagnostics. A successful
registration is not playback proof.

Root/snare candidates were not promoted without evidence that a supported
movement ability removes them. Enemy purges, enrage removal and ordinary
bleeds were excluded from this friendly-dispel update.
