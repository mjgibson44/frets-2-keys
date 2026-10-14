import AVFoundation
import Frets2KeysCore
import os

/// Plays notes through AVAudioEngine, rendering samples with `SynthMixer`.
final class SynthEngine: @unchecked Sendable {
    static let shared = SynthEngine()

    private let engine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?
    private var mixer: OSAllocatedUnfairLock<SynthMixer>?
    /// The latest render: the audio time (seconds) of its first sample, and the host time at which
    /// that sample reaches the output.
    private let lastRender = OSAllocatedUnfairLock<(audioTime: Double, hostTime: UInt64)?>(initialState: nil)
    private var sampleRate = 44_100.0

    private init() {
        NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main
        ) { [weak self] _ in
            self?.handleConfigurationChange()
        }
    }

    func playNote(_ note: Note, instrument: SynthInstrument) {
        withMixer { $0.playNote(note, instrument: instrument) }
    }

    /// Plays notes now, or at `time` on the `currentTime` clock so they start exactly on time
    /// however late the caller runs.
    func play(_ notes: [Note], mode: PlayMode, at time: Double? = nil, arpeggioStep: Double, instrument: SynthInstrument) {
        withMixer { $0.play(notes, mode: mode, at: time, arpeggioStep: arpeggioStep, instrument: instrument) }
    }

    /// Seconds of audio rendered so far; starts the engine if needed. Resets if the output device
    /// changes.
    var currentTime: Double {
        startIfNeeded()
        return mixer?.withLock { $0.currentTime } ?? 0
    }

    /// Seconds from now until the sample at `audioTime` (on the `currentTime` clock) is actually
    /// heard: rendering runs ahead of the speakers by the output buffer and device latency.
    func secondsUntilHeard(_ audioTime: Double) -> Double {
        startIfNeeded()
        guard let render = lastRender.withLock({ $0 }) else { return audioTime - currentTime }
        let latency = engine.outputNode.presentationLatency
        let heardAt = Self.seconds(fromHostTime: render.hostTime) + (audioTime - render.audioTime) + latency
        return heardAt - Self.seconds(fromHostTime: mach_absolute_time())
    }

    private static let timebase: mach_timebase_info_data_t = {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return info
    }()

    private static func seconds(fromHostTime hostTime: UInt64) -> Double {
        Double(hostTime) * Double(timebase.numer) / Double(timebase.denom) / 1_000_000_000
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

            self.sampleRate = sampleRate
            let mixer = OSAllocatedUnfairLock(initialState: SynthMixer(sampleRate: sampleRate))
            let lastRender = self.lastRender
            lastRender.withLock { $0 = nil }
            let node = AVAudioSourceNode(format: format) { _, timestamp, frameCount, bufferList in
                let buffers = UnsafeMutableAudioBufferListPointer(bufferList)
                let hostTime = timestamp.pointee.mFlags.contains(.hostTimeValid) ? timestamp.pointee.mHostTime : nil
                for buffer in buffers {
                    guard let data = buffer.mData?.assumingMemoryBound(to: Float.self) else { continue }
                    nonisolated(unsafe) let output = data
                    let start = mixer.withLock { mixer -> Double in
                        let start = mixer.currentTime
                        mixer.render(into: output, frameCount: Int(frameCount))
                        return start
                    }
                    if let hostTime { lastRender.withLock { $0 = (start, hostTime) } }
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
