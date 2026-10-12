import Foundation

/// The chord sets that sync between devices, plus a record of deleted sets so a deletion on one
/// device isn't undone by an older copy from another.
public struct ChordLibrary: Codable, Equatable, Sendable {
    public var sets: [ChordSet]
    /// When each deleted set was deleted.
    public var deletedSetIDs: [UUID: Date]

    public init(sets: [ChordSet], deletedSetIDs: [UUID: Date] = [:]) {
        self.sets = sets
        self.deletedSetIDs = deletedSetIDs
    }

    /// How long deletions are remembered. Devices offline for longer could bring a deleted set back.
    public static let deletionMemory: TimeInterval = 180 * 24 * 60 * 60

    /// True for a brand-new install: one empty set that's never been edited, and nothing deleted.
    /// Syncing replaces this starter set rather than adding it next to the user's real sets.
    public var isUntouchedStarter: Bool {
        guard deletedSetIDs.isEmpty, sets.count == 1, let set = sets.first else { return false }
        return set.chords.isEmpty && set.name == AppState.defaultSetName(number: 1) && set.modifiedAt == set.createdAt
    }

    /// Merges an iCloud copy into the local library. An untouched starter set on either side is
    /// left out when the other side has sets, so a new device doesn't add a stray empty "Set 1".
    public static func mergeIncoming(local: ChordLibrary, remote: ChordLibrary, now: Date = Date()) -> ChordLibrary {
        if remote.isUntouchedStarter && !local.sets.isEmpty {
            return merge(local, ChordLibrary(sets: []), now: now)
        }
        if local.isUntouchedStarter && !remote.sets.isEmpty {
            return merge(ChordLibrary(sets: []), remote, now: now)
        }
        return merge(local, remote, now: now)
    }

    /// Combines two copies of the library, set by set: the most recently edited version of each set
    /// wins, and a set deleted after its last edit stays deleted. Sets are ordered by creation date.
    public static func merge(_ local: ChordLibrary, _ remote: ChordLibrary, now: Date = Date()) -> ChordLibrary {
        var deleted = local.deletedSetIDs
        for (id, date) in remote.deletedSetIDs {
            deleted[id] = max(deleted[id] ?? date, date)
        }
        deleted = deleted.filter { now.timeIntervalSince($0.value) < deletionMemory }

        var newest: [UUID: ChordSet] = [:]
        for set in local.sets + remote.sets {
            if let existing = newest[set.id], existing.modifiedAt >= set.modifiedAt { continue }
            newest[set.id] = set
        }
        let sets = newest.values
            .filter { set in
                guard let deletedAt = deleted[set.id] else { return true }
                return set.modifiedAt > deletedAt
            }
            .sorted { ($0.createdAt, $0.id.uuidString) < ($1.createdAt, $1.id.uuidString) }

        return ChordLibrary(sets: sets, deletedSetIDs: deleted)
    }
}

extension AppState {
    /// The synced part of the state.
    public var chordLibrary: ChordLibrary {
        ChordLibrary(sets: chordSets, deletedSetIDs: deletedSetIDs)
    }

    /// Adopts a merged library. If every set was deleted elsewhere, starts a fresh empty set.
    public mutating func apply(_ library: ChordLibrary) {
        deletedSetIDs = library.deletedSetIDs
        if library.sets.isEmpty {
            let set = ChordSet(name: Self.defaultSetName(number: 1))
            replaceChordSets([set])
        } else {
            replaceChordSets(library.sets)
        }
    }
}
