# ARCH-002 — Local mod artwork

Revision: 1. Proposed for independent review; not adopted until the board records
a passing review of this exact hash. Addendum to adopted ARCH-001 revision 2.
Author: primary lead. User requested real pictures for each mod on 2026-09-19.

## Scope and behavior

Display each Workshop addon's shipped logo in its existing list row and selected
item detail. Read the resolved mod copy in place. Do not download artwork, copy
addon files, extract archives to disk, create symlinks, or modify Steam/game files.
Preserve launch and selection behavior. DLC may retain its generic category icon;
this increment does not invent DLC artwork or ownership evidence.

Prefer literal `logo`, then `picture`, then `overviewPicture` from `mod.cpp`, with
`logoOver` as a final fallback. Reuse a bounded literal config-field reader with
comment and quoted-string handling for both names and artwork. No config
evaluation, preprocessing, executable plugin loading or shell commands. Names
and artwork must come from the resolved duplicate copy, not another library.

Initial local evidence: CBA, ACE and ACRE ship loose DXT5 PAA logos; ALiVE references
a virtual path inside a PBO. Support those four observed mods without hardcoding
Workshop IDs or individual logos. Standard PNG/JPEG files are also accepted.
Unsupported or missing artwork keeps a quiet generic fallback, with no effect on
readiness or launch. A fallback is not claimed as actual mod artwork.

## Boundaries and parsing

Foundation Core owns read-only artwork resolution, bounded PBO entry reading and
PAA decoding. Return Sendable data: encoded ordinary image bytes or width, height
and straight RGBA bytes. AppKit/ImageIO conversion stays in the application.
Keep archive parsing, texture decoding and metadata/path resolution in cohesive
files with independently testable contracts; no remote dependency.

Normalize backslashes in Arma references and allow one leading virtual slash for
archive paths. Reject traversal, empty interior segments, control characters,
drive-letter/URL references and relative `.`/`..`. Resolve ordinary file paths
case-insensitively inside the selected mod directory; verify canonical symlink
containment before reading. A virtual PBO prefix never becomes a filesystem root.
Archive files themselves must also resolve inside the selected mod directory.
Only enumerate the mod root and its direct `addons` directory, never recurse
through the installation or inspect executables/extension binaries.

PBO handling reads headers and the requested stored entry only. No general archive
extraction. Match normalized prefix plus entry path case-insensitively, including
prefix metadata and a deterministic basename fallback when no prefix exists.
Reject ambiguous matches rather than selecting arbitrary entries. Support stored
entries (packing method zero) only; unsupported compression returns no artwork.
Bounds: 1 MiB header per archive, 4096 entries, 1024 bytes per string, 8 MiB target
image, 128 archives examined and 8 MiB cumulative header reads per mod. Prioritize
archive basenames matching components of the requested virtual path, then sort
remaining paths. Validate offsets, sizes, EOF and checked arithmetic before seek,
allocation or slicing. Close file handles on every path; poll cancellation.

PAA handling accepts DXT1 and DXT5 only, skips bounded TAGG/palette sections, and
chooses the largest uncompressed mip with dimensions at most 128 by 128. Skip
LZO-marked mips by validated stored length; do not add an LZO decoder. Verify exact
block payload length and safely crop partial 4x4 edge blocks. Decode RGB565 color,
DXT1 transparency and DXT5 alpha correctly. All cursor operations check bounds;
malformed, unsupported or oversized input returns no image rather than trapping.
Source image reads are capped at 8 MiB. Ordinary image decoding uses ImageIO
thumbnail sizing with a 128-pixel maximum and rejects absurd source dimensions
before decompression. No persistent cache is needed in this checkpoint.

## UI and concurrency

Rows display proportionally fitted real artwork in a 36–40-point rounded area,
using a neutral background for transparent/light logos. Preserve comfortable row
spacing, light/dark contrast, checkbox behavior and accessible text labels.
Artwork is decorative when the adjacent name already supplies its accessible name.

Load off the main thread after discovery, bounded to two concurrent reads. A new
scan cancels its previous artwork work and invalidates the snapshot generation.
Only the current generation and same resolved content identity/path may publish
results. Cache at most 128 thumbnails per scan in memory and release stale entries;
do not serialize image bytes into configuration JSON or discovery diagnostics.
Refresh retries missing images and notices replaced logos. MainActor publishes
images; no synchronous disk/archive decoding in SwiftUI body or on the main actor.

## Verification and acceptance

Add independent-value synthetic tests for DXT1/DXT5 colors and alpha, skipped
compressed mips, truncated/oversized headers, invalid dimensions/lengths, PBO
prefix/path lookup, duplicate entry ambiguity, unsupported compression, invalid
offsets, traversal and symlink escape, and commented/literal metadata fields.
Synthetic fixtures only are committed; do not vendor the user's addon artwork.

Read-only diagnostics must report decoded dimensions for the four observed mods.
Native UI verification must visibly show their actual logos, retain existing
selection/preset state, and inspect light and dark appearances. No Photoshop or
generated artwork substitutes for observing the application. Missing actual
logos leave this acceptance incomplete.

Run the complete canonical gate and independent review of the changed candidate
before a local candidate commit. Original ARCH-001 A4 real-game loading and A5
user visual acceptance stay separate; artwork does not prove either. Repair
confirmed original-candidate correctness findings under ARCH-001's existing
contract, retaining the same incident/attempt counters.

The gate must parse board JSON and the current task's adopted architecture
bindings, confirm exact hashes and passing independent review records, validate
local Markdown links in maintained docs, and count physical handwritten lines
including Package.swift and final unterminated lines. It must not match arbitrary
historical revision strings or silently skip required checks. Root owns board and
documentation; the implementer owns only the gate implementation and tests.

## References and non-goals

- [Bohemia PAA format](https://community.bistudio.com/wiki/PAA_File_Format)
- [Bohemia PBO format](https://community.bistudio.com/wiki/PBO)
- [Mod folder metadata](https://community.bistudio.com/wiki/Arma_3%3A_Mod.cpp)

Automatic dependency selection, Workshop dependency fetching and load-order
optimization are not introduced by this artwork increment. The current planner
preserves selected ID order; do not claim it resolves dependencies. Arma engine
`requiredAddons` initialization is distinct from the launcher's mod-folder list.
