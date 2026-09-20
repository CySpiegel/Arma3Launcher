# User acceptance and remaining work

Live execution belongs to `engineering/board.json`.

- UX-001 — Required test-drive feedback on the committed build: single-click row
  selection and checkbox response, Advanced options, resizing and light/dark UI.
  The user confirmed the selection delay is fixed on build575c546.
  Picture-shaped artwork backgrounds are implemented in shared component A7;
  user visual feedback on that adjustment remains pending.
  CUA coordinate actions could not verify
  minimum-size resizing or checkbox clicks; do not record those as passed.
- GAME-001 — User reports selected mods absent on A7. A8 quoting correction
  and model/planner tests pass independent review/full gate. Actual in-game
  ACE/CBA loading remains to be verified on the new committed build; optional
  DLC and both game modes require separate positive evidence.
- ORDER-001 — Automatic dependency selection and load ordering are not implemented;
  current launch order is the selection/preset order. Previously disclosed to user.
- PUB-001 — Source remains local; GitHub repository creation did not authorize push
  or remote integration. Current local-only work has no remote backup.
- DIST-001 — Distribution, paid signing and notarization remain release decisions.

DLC-ART-001 is implemented under ARCH-003r2:shared source, reader and view show
15existing local DLC/platform pictures and4Workshop logos. MissingCSLA has no
cached image and keeps an honest fallback; no network fetch or EBO extraction.
No other parked architecture decisions are awaiting ratification.
