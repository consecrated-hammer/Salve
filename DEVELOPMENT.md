# Development workflow

Develop only from this Git clone. Do not edit the Syncthing copy under
`MyAddons`: it is a deployment handoff, never a Git worktree.

Run the repository tests first. Then make a runtime-only staging folder, using
the one TOC intended for that client:

```sh
python3 tools/stage_addon.py --toc Salve.toc --addon-name Salve --output /mnt/backup/syncthing/kevin/myaddons/_staging
```

For the provisional Camelot preview, substitute `Salve_Camelot.toc`. The stage
contains only one `Salve.toc`, so Retail and preview definitions cannot load
together. Syncthing delivers `_staging/Salve` to the Windows PC; from there,
use the explicit installer/copy step for the intended WoW client and `/reload`.
Confirm the loaded version in-game. Do not tag, push, or publish local builds.

## Combined dispel retirement

The combined grid and mouseover actions are withdrawn. In a live Forever
Druid test, the combined cell click did not remove a curse while a manual
Remove Curse did. Each cure now has its own binding; no macro-order workaround
or automatic choice of cure is offered.

On load, legacy `BOTH` grid entries are removed before chord deduplication,
leaving unrelated custom bindings intact. An emptied custom list stays empty.
The exact `CLICK SalveMouseoverBoth:LeftButton` command is cleared from every
key in the active game binding set, out of combat. Other sets are checked when
activated through `UPDATE_BINDINGS`; the addon never switches binding sets.
Login and combat-end routing retry deferred cleanup. The old button is not
created; if it already exists, cleanup makes it inert out of combat. Blizzard's Key Bindings and Settings panels defer key writes and saves while
an edit transaction is open. One close hook retries on the next frame, after
Cancel or Discard restores the final binding set. Failed engine calls release
the reentrancy guard; failed saves retain per-set retry intent. Distinct errors
are surfaced once through the game error handler.

Actual retirement produces one notice per session telling the player to bind
each cure separately. A minimal `combinedDispelNoticePending` flag survives
reloads until that notice is delivered, then is removed. Clean users gain no
notice flag. Deprecated `bothDispelsOrder` values are retained but unused.

Restoring addon files does not restore deleted SavedVariables entries or game
bindings. Restoring those choices needs a separate user-data backup; otherwise
bind individual dispels explicitly. The existing released What's new entry
and CurseForge description remain historical publication records. Before the
next release, remove the combined-action claim from the pasteable CurseForge
description and record that the owner needs to paste it.
