import Foundation

/// The sounds playback can use. All are synthesized; none are samples.
public enum SynthInstrument: String, Codable, Sendable, CaseIterable, Identifiable {
    /// Two slightly detuned sines, like the web app.
    case classic
    /// A bell-like FM electric piano that mellows as it rings.
    case keys
    /// A bright, quickly fading plucked string.
    case pluck
    /// Steady drawbar-style harmonics.
    case organ
    /// A buzzy square-ish retro tone.
    case retro
    /// Shimmering, inharmonic bell partials with a long ring.
    case glass
    /// A slow swell of three detuned voices.
    case pad

    public var id: String { rawValue }

    public var name: String {
        switch self {
        case .classic: return "Classic"
        case .keys: return "Electric Keys"
        case .pluck: return "Pluck"
        case .organ: return "Organ"
        case .retro: return "8-Bit"
        case .glass: return "Glass Bells"
        case .pad: return "Dream Pad"
        }
    }

    /// How a note's loudness moves over time.
    struct Envelope: Sendable {
        var attack: Double
        /// For sustained sounds: time to fall from the peak to `sustain`.
        var decay = 0.1
        var sustain = 0.7
        var release: Double
        /// For struck or plucked sounds: the note dies away exponentially with this time constant
        /// instead of holding a sustain level.
        var ringTime: Double?
        /// Notes last this much longer than asked, for sounds that ring on.
        var lengthScale = 1.0
    }

    var envelope: Envelope {
        switch self {
        case .classic: return Envelope(attack: 0.02, decay: 0.1, sustain: 0.7, release: 0.3)
        case .keys: return Envelope(attack: 0.005, release: 0.25, ringTime: 0.9, lengthScale: 1.3)
        case .pluck: return Envelope(attack: 0.003, release: 0.1, ringTime: 0.35)
        case .organ: return Envelope(attack: 0.01, decay: 0.05, sustain: 0.9, release: 0.08)
        case .retro: return Envelope(attack: 0.005, decay: 0.05, sustain: 0.6, release: 0.05)
        case .glass: return Envelope(attack: 0.002, release: 0.3, ringTime: 0.8, lengthScale: 2)
        case .pad: return Envelope(attack: 0.25, decay: 0.3, sustain: 0.8, release: 0.5, lengthScale: 1.5)
        }
    }

    /// The raw waveform for a note at `frequency`, `time` seconds after it started. Roughly -2...2,
    /// like the classic voice's two sines, so instruments sit at similar loudness.
    func sample(frequency: Double, time t: Double) -> Double {
        let w = 2 * Double.pi * frequency * t
        switch self {
        case .classic:
            return sin(w) + sin(w * SynthMixer.detune)
        case .keys:
            // FM: the modulator's depth fades, so the tine's bite softens into a rounder tone.
            let index = 1.8 * exp(-t * 5) + 0.2
            return 1.4 * sin(w + index * sin(w)) + 0.3 * sin(w * SynthMixer.detune)
        case .pluck:
            // Higher harmonics die away faster than the fundamental.
            var value = 0.0
            for k in 1...6 {
                let harmonic = Double(k)
                value += sin(harmonic * w) * exp(-harmonic * t * 2.5) / harmonic
            }
            return 1.3 * value
        case .organ:
            return 0.85 * (sin(w) + 0.6 * sin(2 * w) + 0.35 * sin(3 * w) + 0.2 * sin(4 * w) + 0.1 * sin(6 * w))
        case .retro:
            // The first few odd harmonics of a square wave: buzzy without harsh aliasing.
            return 1.1 * (sin(w) + sin(3 * w) / 3 + sin(5 * w) / 5 + sin(7 * w) / 7 + sin(9 * w) / 9)
        case .glass:
            return 1.2 * (sin(w)
                + 0.5 * sin(2.76 * w) * exp(-t * 3)
                + 0.25 * sin(5.4 * w) * exp(-t * 6)
                + 0.2 * sin(8.93 * w) * exp(-t * 9))
        case .pad:
            return 0.7 * (sin(w) + sin(w * 1.004) + sin(w * 0.996) + 0.3 * sin(2 * w))
        }
    }
}

/// The sound generator behind the app's audio: a voice per note, shaped by the chosen instrument's
/// waveform and envelope, mixed through a compressor so big chords don't clip.
///
/// This type only does the math; the app owns the audio engine and calls `render` from its callback.
public struct SynthMixer: Sendable {
    struct Voice: Sendable {
        var frequency: Double
        var startFrame: Int64
        var duration: Double
        var volume: Double
        var instrument: SynthInstrument
        var isChordNote: Bool
        /// Set when a newer chord cuts this one off.
        var fadeStartFrame: Int64?
        var fadeStartGain = 0.0
    }

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

    /// Seconds rendered so far: the time `play(_:mode:at:)` measures from.
    public var currentTime: Double { Double(renderedFrames) / sampleRate }

    /// Default time between arpeggio notes.
    public static let arpeggioStep = 0.4

    // MARK: - Scheduling

    public mutating func playNote(_ note: Note, duration: Double = 0.8, instrument: SynthInstrument = .classic) {
        schedule([note], offsets: [0], at: nil, duration: duration, volume: 0.25, instrument: instrument, isChord: false)
    }

    /// Plays all notes together, quickly fading out the previous chord so repeats don't pile up.
    /// `time` (on the `currentTime` clock) schedules it ahead; nil plays it now.
    public mutating func playChord(_ notes: [Note], at time: Double? = nil, duration: Double = 1.2, instrument: SynthInstrument = .classic) {
        guard !notes.isEmpty else { return }
        let volume = min(0.25, 0.6 / Double(notes.count))
        schedule(notes, offsets: Array(repeating: 0, count: notes.count), at: time, duration: duration, volume: volume, instrument: instrument, isChord: true)
    }

    /// Plays the notes one after another, `step` seconds apart. Each note rings a little past the
    /// next one's start (0.5s at the default step).
    public mutating func playArpeggio(_ notes: [Note], at time: Double? = nil, step: Double = arpeggioStep, instrument: SynthInstrument = .classic) {
        guard !notes.isEmpty else { return }
        let noteDuration = min(max(step * 1.25, 0.3), 0.8)
        schedule(notes, offsets: notes.indices.map { Double($0) * step }, at: time, duration: noteDuration, volume: 0.25, instrument: instrument, isChord: false)
    }

    public mutating func play(
        _ notes: [Note], mode: PlayMode, at time: Double? = nil, arpeggioStep: Double = arpeggioStep, instrument: SynthInstrument = .classic
    ) {
        switch mode {
        case .chord: playChord(notes, at: time, instrument: instrument)
        case .arpeggio: playArpeggio(notes, at: time, step: arpeggioStep, instrument: instrument)
        }
    }

    private mutating func schedule(
        _ notes: [Note], offsets: [Double], at time: Double?, duration: Double, volume: Double, instrument: SynthInstrument, isChord: Bool
    ) {
        // A time in the past (or none) means now.
        let start = max(renderedFrames, time.map { Int64(($0 * sampleRate).rounded()) } ?? 0)
        if isChord {
            // The previous chord fades as this one starts.
            for index in voices.indices where voices[index].isChordNote && voices[index].fadeStartFrame == nil && voices[index].startFrame < start {
                let voice = voices[index]
                let elapsed = Double(start - voice.startFrame) / sampleRate
                voices[index].fadeStartGain = Self.envelope(at: elapsed, duration: voice.duration, volume: voice.volume, instrument: voice.instrument)
                voices[index].fadeStartFrame = start
            }
        }
        for (note, offset) in zip(notes, offsets) {
            voices.append(Voice(
                frequency: note.frequency,
                startFrame: start + Int64(offset * sampleRate),
                duration: duration * instrument.envelope.lengthScale,
                volume: volume,
                instrument: instrument,
                isChordNote: isChord
            ))
        }
    }

    // MARK: - Rendering

    static func envelope(at time: Double, duration: Double, volume: Double, instrument: SynthInstrument = .classic) -> Double {
        guard time >= 0, time < duration else { return 0 }
        let shape = instrument.envelope
        if time < shape.attack { return volume * time / shape.attack }
        let level: Double
        let settled: Double
        if let ringTime = shape.ringTime {
            level = volume * exp(-(time - shape.attack) / ringTime)
            settled = shape.attack
        } else {
            let sustain = volume * shape.sustain
            settled = shape.attack + shape.decay
            if time < settled { return volume + (sustain - volume) * (time - shape.attack) / shape.decay }
            level = sustain
        }
        // Fade to silence over the release, ending exactly at `duration`.
        let releaseStart = max(duration - shape.release, settled)
        if time < releaseStart { return level }
        return level * (1 - (time - releaseStart) / (duration - releaseStart))
    }

    /// Fills `output` with the next `frameCount` mono samples and advances the clock.
    public mutating func render(into output: UnsafeMutablePointer<Float>, frameCount: Int) {
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
                var gain = Self.envelope(at: elapsed, duration: voice.duration, volume: voice.volume, instrument: voice.instrument)
                if let fadeStart = voice.fadeStartFrame, now >= fadeStart {
                    let progress = Double(now - fadeStart) / fadeFrames
                    gain = min(gain, voice.fadeStartGain * max(0, 1 - progress))
                }
                guard gain > 0 else { continue }
                sample += gain * voice.instrument.sample(frequency: voice.frequency, time: elapsed)
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
