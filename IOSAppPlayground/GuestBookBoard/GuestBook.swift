import Foundation
import Observation

/// One submission from the form on the board.
struct VisitorEntry: Identifiable {
    let id = UUID()
    let name: String
    let email: String
    let mood: Mood
    let notes: String
    let date: Date
}

/// How the visitor feels. Shown as a segmented picker on the board.
enum Mood: String, CaseIterable, Identifiable {
    case happy = "Happy"
    case curious = "Curious"
    case tired = "Tired"

    var id: Self { self }

    var symbolName: String {
        switch self {
        case .happy: "face.smiling"
        case .curious: "eyes"
        case .tired: "zzz"
        }
    }
}

/// Shared model that collects every entry submitted on the 3D board.
/// The form inside the RealityKit scene writes to it, and the 2D
/// overlay in `ContentView` reads from it.
@Observable
final class GuestBook {
    private(set) var entries: [VisitorEntry] = []

    func add(name: String, email: String, mood: Mood, notes: String) {
        let entry = VisitorEntry(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            email: email.trimmingCharacters(in: .whitespacesAndNewlines),
            mood: mood,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            date: .now
        )
        entries.insert(entry, at: 0)
    }
}
