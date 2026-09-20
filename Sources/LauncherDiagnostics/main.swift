import Foundation
import LauncherCore

let snapshot = SteamDiscovery.scan(.standard())
let installation = snapshot.installation
print("Arma 3 diagnostics (read-only)")
print("Libraries: \(installation.libraryRoots.count)")
print("Game candidates: \(installation.candidates.count)")
if let game = installation.selectedGame {
    print(
        "Selected game: \(game.readiness.rawValue), modes: \(game.bundles.map(\.mode.rawValue).joined(separator: ", "))"
    )
} else {
    print("Selected game: none")
}
let workshop = snapshot.content.filter { $0.source == .workshop }
let dlc = snapshot.content.filter { $0.source == .optionalDLC && $0.availability != .missing }
print("Workshop items: \(workshop.count) (ready: \(workshop.filter { $0.availability == .ready }.count))")
for item in workshop {
    var artwork = "no supported artwork"
    if let source = item.artworkSource, let payload = try? ArtworkLoader.load(from: source) {
        if let dimensions = payload.dimensions {
            artwork = "artwork \(dimensions.0)x\(dimensions.1)"
        } else {
            artwork = "ordinary encoded artwork"
        }
    }
    print("  - \(item.displayName): \(item.availability.rawValue), \(artwork)")
}
print("Installed optional DLC folders: \(dlc.count)")
for item in dlc { print("  - \(item.displayName): \(item.availability.rawValue), ownership unverified") }
var artworkCount = 0
for item in snapshot.content {
    if let source = item.artworkSource, (try? ArtworkLoader.load(from: source)) != nil {
        artworkCount += 1
        if item.source != .workshop { print("  - cached artwork: \(item.displayName)") }
    } else if item.displayName == "CSLA Iron Curtain" {
        print("  - cached artwork fallback: CSLA Iron Curtain")
    }
}
print("Local artwork images: \(artworkCount)")
for warning in snapshot.warnings { print("Warning: \(warning)") }
for error in snapshot.errors { print("Error: \(error)") }
