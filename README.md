# Arma3Launcher

A native macOS application with a complete graphical interface for configuring
and launching the Mac release of Arma 3: game launch methods, purchased DLC, and
downloaded Steam Workshop addons.

## Product brief

The intended users are Arma 3 players on macOS, starting with the project owner.
The current pain is finding downloaded addons and manually assembling content
selections, mod paths, and launch options. The application should make this a
repeatable configuration and launch workflow.

Confirmed scope:

- A well-constructed native macOS GUI for configuring the game.
- Player-facing controls for supported Mac game launch methods.
- Include purchased DLC and its applicable launch configuration.
- Discover mods already downloaded through Steam Workshop.
- Let the player select mods and launch Arma 3 with them.
- Support the Mac release of the game only for the first version. Windows
  versions running through CrossOver or similar tools are outside that scope.

## Authorized first increment

The user authorized construction using the graph team on 2026-09-19. Coding
remains subject to the independent review/adoption of
[ARCH-001](docs/specs/ARCH-001.md):

1. Locate the Steam game and Workshop content, with a folder-selection fallback.
2. Present supported launch methods and relevant options as ordinary GUI
   controls, with one clear Play action.
3. Show DLC and downloaded Workshop addons in distinct, searchable views, with
   recognizable names where available and enable/disable controls where the
   content supports optional loading.
4. Refresh discovery to reflect changes in installed content, and distinguish
   content availability from its selection for the next launch.
5. Launch the installed Mac game with the selected configuration and
   understandable feedback when the installation or selected content is
   unavailable.

Use Workshop content in its existing location so Steam can continue updating it.
Saved configurations are included in the initial checkpoint: a preset remembers the
launch method, DLC selection, Workshop addons, and applicable launch options.
See the [design brief](docs/specs/design-brief.md) for the proposed GUI structure.

## Platform evidence and questions

[Bohemia's Play on Mac guide](https://community.bistudio.com/wiki/Arma_3%3A_Play_on_Mac)
describes loading mods with launch arguments, warns that moving Workshop folders
stops their updates, and distinguishes the default Mac game launch mode from the
experimental Apple silicon native mode. These are game modes, separate from the
requirement that this launcher itself be a native macOS application.

Before choosing an implementation, verify the actual installed game layout,
available Mac launch modes, argument handling (including spaces in paths), and
how to distinguish usable addons from other Workshop content or incomplete
downloads. Automatic discovery should account for non-default Steam libraries.
The guide is a starting reference, not evidence that either launch mode has been
tested by this project.

DLC needs its own discovery and loading model. The Mac guide lists optional
content such as Contact and Creator DLC with launch parameters; do not assume
every purchased DLC is an optional mod. The design must distinguish ownership,
installed files, and enabled content. A folder's presence alone is not proof of
purchase, and missing ownership evidence should be shown as unknown.

## Recommended development tools

A macOS app project in Xcode, using Swift and SwiftUI, is the recommended starting
point adopted in ARCH-001 after independent review. Apple's [SwiftUI overview](https://developer.apple.com/documentation/technologyoverviews/swiftui)
and [Xcode project guide](https://developer.apple.com/documentation/Xcode/creating-an-xcode-project-for-an-app)
describe this native app workflow. Open `Arma3Launcher.xcodeproj` and select the
Arma3Launcher scheme to build and run the current prototype.

Local tooling checked on 2026-09-19: `xcode-select -p` resolves to
`/Applications/Xcode.app/Contents/Developer`; `xcodebuild -version` succeeds with
Xcode 27.0, build 27A266a. This is a tool-availability check, not a product build.

## Test build

Download the macOS app from [GitHub Releases](https://github.com/CySpiegel/Arma3Launcher/releases).
The first release, **v0.1.0-beta.1**, is a test build for macOS14 or later.
It includes Apple silicon and Intel binaries. Unzip the download and move
`Arma3Launcher.app` to Applications. Steam and the Mac version of Arma3 must
already be installed. Workshop addons stay in their original Steam folders.

The app is ad-hoc signed and not Apple-notarized. macOS may require approval
under System Settings → Privacy & Security on first launch; see
[Apple’s app-opening guidance](https://support.apple.com/en-us/102445). No paid signing
identity, installer or privileged helper is included.

## Project state

The native test build has searchable Workshop and DLC lists, presets, launch
options and a shared artwork interface. Local checks decode four Workshop logos
and15cached DLC/platform images; missing artwork keeps a fallback. Artwork boxes
follow their pictures' proportions. Advanced-panel and appearance issues are
repaired, and the user has confirmed the selection delay is fixed.

Independent review and `bash scripts/gate.sh` pass with72tests across10suites,
strict formatting and an Xcode Debug warnings-as-errors build. The user confirmed
that both ACE and CBA now appear in the game when launched with their preset
in Standard (Rosetta) mode. Quoted mod values preserve Steam paths with spaces.
Experimental Apple silicon game mode, optional DLC combinations and older/Intel
macOS runtime coverage remain to be tested separately. A universal build does
not establish runtime testing on both architectures.

Automatic dependency selection and load ordering are not implemented; the saved
selection order is retained. DLC installation does not establish account ownership.

Source candidate branch: [issue/m0/001-foundation](https://github.com/CySpiegel/Arma3Launcher/tree/issue/m0/001-foundation).
This beta is published from the reviewed candidate; milestone acceptance remains
open. Stack:Swift6,SwiftUI,Foundation Core. See [HANDOFF](docs/HANDOFF.md),
[workflow](docs/engineering/WORKFLOW.md) and the [board](docs/engineering/board.json)
for exact evidence and remaining acceptance.

## Local development

Open `Arma3Launcher.xcodeproj`, select the shared `Arma3Launcher` scheme and run
on My Mac. The project links the `LauncherCore` Swift package from this folder.
It needs no generated project or downloaded package dependencies.

Run the complete verification gate from the repository root:

```sh
bash scripts/gate.sh
```

The Debug application is produced at
`.build/DerivedData/Build/Products/Debug/Arma3Launcher.app`. Build evidence remains
under ignored `.build/evidence/`. Read-only diagnostics use the same Core logic
as the app; they never start Steam or the game.

Workshop addon files stay in Steam's original directories. App configuration is
stored separately in the app's own Application Support directory. Local
artwork support is described in [ARCH-002](docs/specs/ARCH-002.md) and the shared
DLC interface in [ARCH-003](docs/specs/ARCH-003.md); no online
artwork service or persistent copy of addon assets is required.
