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
