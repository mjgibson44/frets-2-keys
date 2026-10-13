import Foundation
import Frets2KeysCore
import os

/// Keeps chord sets in sync across the user's devices through iCloud key-value storage.
///
/// The whole library is stored under one key. Every read merges the iCloud copy with the local one
/// (see `ChordLibrary.merge`), so edits made on two devices before they sync are both kept, set by set.
@MainActor
final class ChordLibrarySync {
    private static let key = "chordLibrary.v1"
    /// iCloud allows 1 MB per key; stay well under it.
    private static let maxBytes = 900_000

    private let store: NSUbiquitousKeyValueStore
    private let logger = Logger(subsystem: "com.mjgibson44.frets2keys", category: "sync")
    private let readLocal: () -> ChordLibrary
    private let applyMerged: (ChordLibrary) -> Void
    private var pushTask: Task<Void, Never>?
    private var observer: NSObjectProtocol?

    /// - Parameters:
    ///   - readLocal: The current local library.
    ///   - applyMerged: Adopts a merged library locally (without triggering another push).
    init(
        store: NSUbiquitousKeyValueStore = .default,
        readLocal: @escaping () -> ChordLibrary,
        applyMerged: @escaping (ChordLibrary) -> Void
    ) {
        self.store = store
        self.readLocal = readLocal
        self.applyMerged = applyMerged
    }

    /// Starts listening for changes from other devices and does an initial merge.
    func start() {
        observer = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: store,
            queue: .main
        ) { [weak self] notification in
            let reason = notification.userInfo?[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int
            MainActor.assumeIsolated {
                self?.handleExternalChange(reason: reason)
            }
        }
        store.synchronize()
        mergeWithCloud()
    }

    /// Call after local chord sets change; pushes shortly after edits settle.
    func localLibraryChanged() {
        pushTask?.cancel()
        pushTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            self?.mergeWithCloud()
        }
    }

    private func handleExternalChange(reason: Int?) {
        if reason == NSUbiquitousKeyValueStoreQuotaViolationChange {
            logger.error("iCloud key-value storage quota exceeded; chord sets may not sync")
            return
        }
        mergeWithCloud()
    }

    /// Merges the iCloud copy into the local library, then writes the result back if iCloud is behind.
    private func mergeWithCloud() {
        let local = readLocal()
        let remote = readCloud()
        let merged = remote.map { ChordLibrary.mergeIncoming(local: local, remote: $0) } ?? local
        if merged != local {
            applyMerged(merged)
        }
        // A brand-new install's empty starter set isn't worth syncing; waiting also avoids racing
        // the first download of the user's real sets.
        if merged != remote && !merged.isUntouchedStarter {
            write(merged)
        }
    }

    private func readCloud() -> ChordLibrary? {
        guard let data = store.data(forKey: Self.key) else { return nil }
        do {
            return try JSONDecoder().decode(ChordLibrary.self, from: data)
        } catch {
            logger.error("Couldn't read chord sets from iCloud: \(error.localizedDescription)")
            return nil
        }
    }

    private func write(_ library: ChordLibrary) {
        guard let data = try? JSONEncoder().encode(library) else { return }
        guard data.count <= Self.maxBytes else {
            logger.error("Chord sets are too large to sync (\(data.count) bytes)")
            return
        }
        store.set(data, forKey: Self.key)
        store.synchronize()
    }
}
