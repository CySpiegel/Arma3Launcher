# Arma3Launcher design brief

Date: 2026-09-19. Status: initial product/design intake; no visual or architecture
approval, implementation, or working-screen verification yet.

## Required experience

The player should be able to configure and launch the Mac game from a
well-constructed native GUI. Launch methods, purchased DLC, and Workshop addons
are first-class parts of that workflow. Players should not need to compose
paths or command lines for the ordinary launch flow.

The first version targets the Mac release only. The launcher being a native Mac
app does not mean the game's experimental Apple silicon mode is the only game
mode to consider; supported modes must be established from the installed game.
The user explicitly confirmed addons must remain in Steam's download folder;
read them in place and pass their original paths, with no copying or staging.

## First visual concept

The user requested a visual preview on 2026-09-19. The
[main-window concept](design-brief/concepts/main-window-v1.png) shows the proposed
single-window layout in both appearances. Generated with the built-in imagegen
tool; [exact prompt](design-brief/concepts/main-window-v1-prompt.txt) retained.
It is a design image with illustrative selections, not a screenshot of a working
app or accepted proof that launch/content detection works. In-use approval is
still required after the real committed candidate passes its checks.

## Anchor and references

Proposed anchor: Apple/Arc, adapted to a native macOS utility. This draws on the
user's existing cross-project taste record; it is not approval of a particular
Arma3Launcher layout. Use the host's light/dark appearance, restrained emphasis,
comfortable row spacing, and clear primary actions.

- Finder: a reference for familiar native navigation and searchable content
  lists; not a request to duplicate its complete interface.
- System Settings: a reference for discoverable, grouped configuration controls.
- The [Mac game guide](https://community.bistudio.com/wiki/Arma_3%3A_Play_on_Mac):
  a behavior reference for launch modes and content loading, not a visual style.

These named app references are design proposals. There is no existing product
UI to preserve or critique, and no Arma-specific palette or artwork is approved.
Do not transfer the tournament website's branding into this native application.

## Proposed information structure

| Area | Player's task |
| --- | --- |
| Play | Choose an available Mac launch method, review selected content, and launch. |
| DLC | Inspect purchased/installed content and configure optional loading where supported. |
| Workshop addons | Search discovered addons, enable or disable them, and refresh the list. |
| Presets | Proposed: save and recall a named game configuration. |
| Settings | Locate the game and Steam libraries, correct detection, and adjust application preferences. |

Keep the selected configuration and Play action easy to find while navigating.
Use readable rows for content libraries, with details available on selection.
Separate the launch-method selector from the content selection controls.
Place advanced launch arguments behind a clearly named advanced area; the
ordinary workflow should use understandable controls.

## States the design must account for

- First use: game/library detection in progress, found, or requiring a folder.
- Workshop: no addons, discovered addons, unavailable metadata, and content
  removed or changed after selection. Distinguish addons from other Workshop
  content and incomplete downloads using verified evidence.
- DLC: owned, installed, and enabled are different facts. Do not infer purchase
  from a folder or compatibility pack; show unknown ownership honestly. Only
  offer loading switches where the game's content model supports them.
- Launch: ready, preparing, handed off, or failed with an actionable explanation.
  Do not claim the game is running merely because a launch request was sent.
- Missing selected content: identify the item before launch; do not silently
  discard it from a saved configuration.

## First working checkpoint

After the first increment is authorized and its architecture independently
reviewed, implement one representative configuration-to-launch screen first.
Verify working controls and error states, keyboard navigation, window resizing,
and both system appearances. Commit and pass the established native-app gate
before asking the user to inspect it. Obtain the user's in-use visual verdict
before expanding the design to further screens. A picture is not evidence of
working controls or successful game integration.

Native app verification must use the macOS application, not substitute a browser
preview for the actual GUI. The gate, review record, and implementation task are
not established by this design brief.

## Open design inputs

Minimum supported macOS version, precise available game launch methods, and the
reliable source of DLC ownership remain to be resolved during architecture.
Presets and the proposed navigation remain proposals rather than confirmed
individual feature or layout approvals.

## Rejection log

No Arma3Launcher design has been presented or rejected.
