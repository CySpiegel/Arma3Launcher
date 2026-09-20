# UI-004 — appearance transition diagnosis

Astra High `/root/architecture_review`, read-only diagnosis against A4 manifest
`a11226f8eada91a5f29c2911b395f189e6b72050c4ff980d1f7769322611ed1e`.
Native root repro: System(dark OS)→Light works; Light→System leaves light native
chrome/list/editor with black text on dark content panels. Settled screenshots
confirm; explicit Dark restores coherent rendering. No game or user content lost.

Source has sole preferredColorScheme(model.appearance.colorScheme), nil for
System; no other window/application appearance override. Stale SwiftUI
presentation preference is an inference, not proven internals. Apple's API
permits nil. Minimal advised repair: remove preferredColorScheme; use
onChange(of:model.appearance,initial:true) to set NSApplication.shared.appearance
to nil/System, NSAppearance(.aqua)/Light, NSAppearance(.darkAqua)/Dark. Remove
unused colorScheme property. Preserve model/view/window identity and persistence.
No .id reconstruction, fixed text colors, global settings or polling.

Sources: [SwiftUI preference](https://developer.apple.com/documentation/SwiftUI/View/preferredColorScheme%28_%3A%29),
[NSApplication appearance](https://developer.apple.com/documentation/appkit/nsapplication/appearance).
Apple documents nil application appearance as restoring current system appearance.
This is a bounded repair within existing adopted architecture; root adopts advice.

Verify repeated System→Light→System and System→Dark→Light→System, all panels,
preserved selections/arguments/search, persisted appearance after reopen and
full independent gate/review. No claim of an automated native screenshot test.
