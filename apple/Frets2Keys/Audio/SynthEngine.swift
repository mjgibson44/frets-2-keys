import AVFoundation
import Frets2KeysCore
import os

/// Plays notes through AVAudioEngine, rendering samples with `SynthMixer`.
final class SynthEngine: @unchecked Sendable {
    static let shared = SynthEngine()

    private let engine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?
    private var mixer: OSAllocatedUnfairLock<SynthMixer>?

    private init() {
        NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main
        ) { [weak self] _ in
            self?.handleConfigurationChange()
        }
    }

    func playNote(_ note: Note) {
        withMixer { $0.playNote(note) }
    }

    func play(_ notes: [Note], mode: PlayMode) {
        withMixer { $0.play(notes, mode: mode) }
    }

    private func withMixer(_ change: @Sendable (inout SynthMixer) -> Void) {
        startIfNeeded()
        mixer?.withLock { change(&$0) }
    }

    /// The output device changed (e.g. headphones unplugged): rebuild the source node so the mixer
    /// renders at the new sample rate, then restart.
    private func handleConfigurationChange() {
        if let sourceNode {
            engine.detach(sourceNode)
            self.sourceNode = nil
            mixer = nil
        }
        startIfNeeded()
    }

    private func startIfNeeded() {
        if sourceNode == nil {
            #if os(iOS)
            let session = AVAudioSession.sharedInstance()
            try? session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try? session.setActive(true)
            #endif
            let outputRate = engine.outputNode.outputFormat(forBus: 0).sampleRate
            let sampleRate = outputRate > 0 ? outputRate : 44_100
            guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else { return }

            let mixer = OSAllocatedUnfairLock(initialState: SynthMixer(sampleRate: sampleRate))
            let node = AVAudioSourceNode(format: format) { _, _, frameCount, bufferList in
                let buffers = UnsafeMutableAudioBufferListPointer(bufferList)
                for buffer in buffers {
                    guard let data = buffer.mData?.assumingMemoryBound(to: Float.self) else { continue }
                    nonisolated(unsafe) let output = data
                    mixer.withLock { $0.render(into: output, frameCount: Int(frameCount)) }
                    break
                }
                // Mono source: copy into any extra channels.
                if let first = buffers.first?.mData {
                    for buffer in buffers.dropFirst() {
                        guard let data = buffer.mData else { continue }
                        memcpy(data, first, Int(frameCount) * MemoryLayout<Float>.size)
                    }
                }
                return noErr
            }
            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: format)
            sourceNode = node
            self.mixer = mixer
        }
        if !engine.isRunning {
            engine.prepare()
            do {
                try engine.start()
            } catch {
                print("Frets 2 Keys: couldn't start audio: \(error)")
            }
        }
    }
}
