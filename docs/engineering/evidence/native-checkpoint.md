# Native checkpoint verification ledger

This is a verification ledger, not a claim that unfinished checks passed.
Exact source/build identity will be attached after independent gate/review.

## Observed first preview

The user explicitly requested opening the built native application. Native CUA
opened the A1 app at `.build/DerivedData/Build/Products/Debug/Arma3Launcher.app`.
The transcript showed the real dark appearance, discovered Workshop/DLC content,
launch controls and Steam-not-running state. Generic mod symbols were visible.
The user subsequently requested real addon artwork and asked about ordering.
This preview predates an accepted commit and is not user visual sign-off.

On the subsequent inventory, the app process was still running but the old window
was unavailable. The coordinator did not reopen it while source/build repairs ran.
Existing app-only settings were preserved for recovery in ignored
`.build/evidence/pre-artwork-settings.json`; no Steam or addon files were copied.

## Pending verification of repaired candidate

A2 native checks were exercised on 2026-09-19 (local date), after its independent
gate passed. CUA reset plus direct app-path selection recovered automation.
All four actual logos were visible in native light and dark captures in the tool
transcript. A temporary preset with CBA and Windowed enabled survived Cmd-Q and
reopening with its name/selection/option intact. The temporary preset was removed
and the original zero selections, zero presets, Windowed off and System appearance
were restored and verified from a fresh full accessibility state.

Three concrete UI findings are assigned to A3: low logo contrast (ALiVE/CBA in
dark, ACE in light), clipped Steam status/Open Steam at default 1160x720, and
the user's reproducible Advanced-options blank-window defect. Expanding Advanced
left all controls present in accessibility but visually blanked all columns and
footer; collapsing it restored them. The coordinator recovered the current view
without losing settings. A3 must correct finite layout/scrolling and retest this
exact interaction, alongside per-logo background contrast in both appearances.

- Bind source manifest, independent review, full gate result and candidate commit.
- Reopen the resulting app and confirm actual CBA, ACE, ALiVE and ACRE logos.
- Check a row selection, keyboard access, search and refresh, keeping launch
  selection stable. Confirm missing-content explanation through synthetic checks.
- Exercise a clearly temporary preset with content, mode and options; relaunch
  and confirm persistence. Restore the prior current configuration afterward.
- Inspect light and dark using the app's own appearance setting, preserving its
  prior setting afterward. Observe transparency, aspect ratio and readable rows.
- Inspect the advanced note: selected order is retained; dependency checks absent.
- Record transcript screenshots when no native screenshot-file export exists.
- Ask for in-use visual acceptance only after committed, independently verified
  build. Lack of response is not acceptance.

Real-game testing remains distinct: Steam availability, exact chosen process/argv,
positive in-game addon and optional DLC evidence, and each advertised mode must be
recorded before original A4 is complete. No app build or thumbnail check proves it.

## A3 repaired interface, 2026-09-19 local date

Exact source manifest:
`e11c93e239209e8d45ad7a075fc9abc4404392bdb75203acb2ee3803bbc31425`.
The coordinator reopened the final A3 binary (including removal of the redundant
bottom caption), selected Workshop and expanded Advanced. Native screenshot in
the CUA transcript shows all three columns, all four actual logos, argument
editor/preview, Play, Steam status and Open Steam at 1160×720. The entire window
remains visible. Light appearance was then selected through the app settings;
the corresponding capture confirms readable ACE, ACRE, ALiVE and CBA logos.
Entering `-mod=invalid` plus `-window` displayed the managed-option conflict in
the argument preview without blanking or overflowing the interface. Clearing
the temporary arguments restored the normal preview. System appearance was
restored. No selections, presets, game files or Steam files were changed.

Two attempts to resize using the native automation drag API returned
`noWindowsAvailable`; reconnecting directly to the app path recovered immediately
and showed the unchanged window. Minimum-size visual verification is therefore
incomplete, not a pass. Do not retry the Dock or use unsupported UI automation.
The user may verify resizing during the committed test drive. No real game was
started. All screenshots described above are actual tool-transcript captures,
not generated concepts. A4 changes are verification-only unless explicitly noted.

## A5 appearance fix

Source af156183ca5a1426666f857f1af7f38568ac7dc0aabd30583ec4c5185d7f761d,
independent full gate and QA pass60tests. Fresh app restart with Dark persisted,
then Light, then System shows consistent native chrome, controls, text and panels.
Actual CUA screenshot captures Workshop with all4logos and Advanced expanded after
Light→System, fixing the prior mixed-color defect. System restored. Zero configured
content selections; the user's earlier Expeditionary row focus is not enablement.
A6 will be the final combined test-drive candidate for shared DLC artwork/clicks.
