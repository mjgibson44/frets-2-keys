import Foundation

/// The sound generator behind the app's audio, mirroring the web app's Web Audio voice: two slightly
/// detuned sine waves with an ADSR envelope, mixed through a compressor so big chords don't clip.
///
/// This type only does the math; the app owns the audio engine and calls `render` from its callback.
public struct SynthMixer: Sendable {
    struct Voice: Sendable {
        var frequency: Double
        var startFrame: Int64
        var duration: Double
        var volume: Double
        var phase1 = 0.0
        var phase2 = 0.0
        var isChordNote: Bool
        /// Set when a newer chord cuts this one off.
        var fadeStartFrame: Int64?
        var fadeStartGain = 0.0
    }

    // Envelope, in seconds.
    static let attack = 0.02
    static let decay = 0.1
    static let release = 0.3
    static let sustainRatio = 0.7
    static let cutoffFade = 0.05
    static let detune = 1.002
    static let masterGain = 0.8

    // Compressor: threshold -6 dB, ratio 12:1, 3 ms attack, 100 ms release.
    static let threshold = 0.5
    static let ratio = 12.0

    public let sampleRate: Double
    private(set) var voices: [Voice] = []
    /// Frames rendered so far: the mixer's clock.
    public private(set) var renderedFrames: Int64 = 0
    private var compressorEnvelope = 0.0

    public init(sampleRate: Double) {
        self.sampleRate = sampleRate
    }

    public var activeVoiceCount: Int { voices.count }

    // MARK: - Scheduling

    public mutating func playNote(_ note: Note, duration: Double = 0.8) {
        schedule([note], offsets: [0], duration: duration, volume: 0.25, isChord: false)
    }

    /// Plays all notes together, quickly fading out the previous chord so repeats don't pile up.
    public mutating func playChord(_ notes: [Note], duration: Double = 1.2) {
        guard !notes.isEmpty else { return }
        let volume = min(0.25, 0.6 / Double(notes.count))
        schedule(notes, offsets: Array(repeating: 0, count: notes.count), duration: duration, volume: volume, isChord: true)
    }

    /// Plays the notes one after another, 0.4 seconds apart by default.
    public mutating func playArpeggio(_ notes: [Note], noteDuration: Double = 0.5, gap: Double = 0.1) {
        guard !notes.isEmpty else { return }
        let step = noteDuration * 0.6 + gap
        schedule(notes, offsets: notes.indices.map { Double($0) * step }, duration: noteDuration, volume: 0.25, isChord: false)
    }

    public mutating func play(_ notes: [Note], mode: PlayMode) {
        switch mode {
        case .chord: playChord(notes)
        case .arpeggio: playArpeggio(notes)
        }
    }

    private mutating func schedule(_ notes: [Note], offsets: [Double], duration: Double, volume: Double, isChord: Bool) {
        let now = renderedFrames
        if isChord {
            for index in voices.indices where voices[index].isChordNote && voices[index].fadeStartFrame == nil {
                let voice = voices[index]
                let elapsed = Double(now - voice.startFrame) / sampleRate
                voices[index].fadeStartGain = Self.envelope(at: elapsed, duration: voice.duration, volume: voice.volume)
                voices[index].fadeStartFrame = now
            }
        }
        for (note, offset) in zip(notes, offsets) {
            voices.append(Voice(
                frequency: note.frequency,
                startFrame: now + Int64(offset * sampleRate),
                duration: duration,
                volume: volume,
                isChordNote: isChord
            ))
        }
    }

    // MARK: - Rendering

    static func envelope(at time: Double, duration: Double, volume: Double) -> Double {
        guard time >= 0, time < duration else { return 0 }
        let sustain = volume * sustainRatio
        if time < attack { return volume * time / attack }
        if time < attack + decay { return volume + (sustain - volume) * (time - attack) / decay }
        let releaseStart = max(duration - release, attack + decay)
        if time < releaseStart { return sustain }
        return sustain * (1 - (time - releaseStart) / (duration - releaseStart))
    }

    /// Fills `output` with the next `frameCount` mono samples and advances the clock.
    public mutating func render(into output: UnsafeMutablePointer<Float>, frameCount: Int) {
        let twoPi = 2 * Double.pi
        let attackCoefficient = 1 - exp(-1 / (0.003 * sampleRate))
        let releaseCoefficient = 1 - exp(-1 / (0.1 * sampleRate))
        let fadeFrames = Self.cutoffFade * sampleRate

        for frame in 0..<frameCount {
            let now = renderedFrames + Int64(frame)
            var sample = 0.0
            for index in voices.indices {
                let voice = voices[index]
                guard now >= voice.startFrame else { continue }
                let elapsed = Double(now - voice.startFrame) / sampleRate
                var gain = Self.envelope(at: elapsed, duration: voice.duration, volume: voice.volume)
                if let fadeStart = voice.fadeStartFrame {
                    let progress = Double(now - fadeStart) / fadeFrames
                    gain = min(gain, voice.fadeStartGain * max(0, 1 - progress))
                }
                sample += gain * (sin(voice.phase1) + sin(voice.phase2))
                voices[index].phase1 = (voice.phase1 + twoPi * voice.frequency / sampleRate).truncatingRemainder(dividingBy: twoPi)
                voices[index].phase2 = (voice.phase2 + twoPi * voice.frequency * Self.detune / sampleRate).truncatingRemainder(dividingBy: twoPi)
            }
            sample *= Self.masterGain

            // Feed-forward peak compressor.
            let level = abs(sample)
            compressorEnvelope += (level - compressorEnvelope) * (level > compressorEnvelope ? attackCoefficient : releaseCoefficient)
            if compressorEnvelope > Self.threshold {
                let target = Self.threshold * pow(compressorEnvelope / Self.threshold, 1 / Self.ratio)
                sample *= target / compressorEnvelope
            }
            output[frame] = Float(max(-1, min(1, sample)))
        }

        renderedFrames += Int64(frameCount)
        let now = renderedFrames
        voices.removeAll { voice in
            let finished = now > voice.startFrame + Int64((voice.duration + 0.1) * sampleRate)
            let faded = voice.fadeStartFrame.map { Double(now - $0) > fadeFrames } ?? false
            return finished || faded
        }
    }

    /// Convenience for tests: renders `seconds` of audio into an array.
    public mutating func render(seconds: Double) -> [Float] {
        let count = Int(seconds * sampleRate)
        var buffer = [Float](repeating: 0, count: count)
        buffer.withUnsafeMutableBufferPointer { pointer in
            guard let base = pointer.baseAddress else { return }
            render(into: base, frameCount: count)
        }
        return buffer
    }
}
