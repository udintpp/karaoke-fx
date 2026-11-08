/// Models for audio effects parameters

class MicFxSettings {
  // Master
  bool isEnabled;
  double inputGain;     // 0.0 - 2.0

  // Echo / Delay
  bool echoEnabled;
  double echoDelay;     // ms: 50 - 800
  double echoFeedback;  // 0.0 - 0.9
  double echoWetMix;    // 0.0 - 1.0

  // Reverb
  bool reverbEnabled;
  double reverbRoom;    // 0.0 - 1.0 (room size)
  double reverbDamping; // 0.0 - 1.0
  double reverbWetMix;  // 0.0 - 1.0

  // Pitch Shift
  bool pitchEnabled;
  double pitchSemitones; // -12 to +12

  // Chorus
  bool chorusEnabled;
  double chorusDepth;   // 0.0 - 1.0
  double chorusRate;    // 0.1 - 5.0 Hz
  double chorusWetMix;  // 0.0 - 1.0

  // Noise Gate
  bool noiseGateEnabled;
  double noiseGateThreshold; // -60 to 0 dB

  // Compressor
  bool compressorEnabled;
  double compressorThreshold; // -40 to 0 dB
  double compressorRatio;     // 1.0 - 20.0

  // EQ (3-band)
  bool eqEnabled;
  double eqBass;    // -12 to +12 dB
  double eqMid;     // -12 to +12 dB
  double eqTreble;  // -12 to +12 dB

  MicFxSettings({
    this.isEnabled = true,
    this.inputGain = 1.5,
    this.echoEnabled = false,
    this.echoDelay = 250,
    this.echoFeedback = 0.3,
    this.echoWetMix = 0.4,
    this.reverbEnabled = false,
    this.reverbRoom = 0.5,
    this.reverbDamping = 0.5,
    this.reverbWetMix = 0.3,
    this.pitchEnabled = false,
    this.pitchSemitones = 0,
    this.chorusEnabled = false,
    this.chorusDepth = 0.3,
    this.chorusRate = 1.5,
    this.chorusWetMix = 0.3,
    this.noiseGateEnabled = false,
    this.noiseGateThreshold = -40,
    this.compressorEnabled = false,
    this.compressorThreshold = -20,
    this.compressorRatio = 4.0,
    this.eqEnabled = false,
    this.eqBass = 0,
    this.eqMid = 0,
    this.eqTreble = 0,
  });

  MicFxSettings copyWith({
    bool? isEnabled,
    double? inputGain,
    bool? echoEnabled,
    double? echoDelay,
    double? echoFeedback,
    double? echoWetMix,
    bool? reverbEnabled,
    double? reverbRoom,
    double? reverbDamping,
    double? reverbWetMix,
    bool? pitchEnabled,
    double? pitchSemitones,
    bool? chorusEnabled,
    double? chorusDepth,
    double? chorusRate,
    double? chorusWetMix,
    bool? noiseGateEnabled,
    double? noiseGateThreshold,
    bool? compressorEnabled,
    double? compressorThreshold,
    double? compressorRatio,
    bool? eqEnabled,
    double? eqBass,
    double? eqMid,
    double? eqTreble,
  }) {
    return MicFxSettings(
      isEnabled: isEnabled ?? this.isEnabled,
      inputGain: inputGain ?? this.inputGain,
      echoEnabled: echoEnabled ?? this.echoEnabled,
      echoDelay: echoDelay ?? this.echoDelay,
      echoFeedback: echoFeedback ?? this.echoFeedback,
      echoWetMix: echoWetMix ?? this.echoWetMix,
      reverbEnabled: reverbEnabled ?? this.reverbEnabled,
      reverbRoom: reverbRoom ?? this.reverbRoom,
      reverbDamping: reverbDamping ?? this.reverbDamping,
      reverbWetMix: reverbWetMix ?? this.reverbWetMix,
      pitchEnabled: pitchEnabled ?? this.pitchEnabled,
      pitchSemitones: pitchSemitones ?? this.pitchSemitones,
      chorusEnabled: chorusEnabled ?? this.chorusEnabled,
      chorusDepth: chorusDepth ?? this.chorusDepth,
      chorusRate: chorusRate ?? this.chorusRate,
      chorusWetMix: chorusWetMix ?? this.chorusWetMix,
      noiseGateEnabled: noiseGateEnabled ?? this.noiseGateEnabled,
      noiseGateThreshold: noiseGateThreshold ?? this.noiseGateThreshold,
      compressorEnabled: compressorEnabled ?? this.compressorEnabled,
      compressorThreshold: compressorThreshold ?? this.compressorThreshold,
      compressorRatio: compressorRatio ?? this.compressorRatio,
      eqEnabled: eqEnabled ?? this.eqEnabled,
      eqBass: eqBass ?? this.eqBass,
      eqMid: eqMid ?? this.eqMid,
      eqTreble: eqTreble ?? this.eqTreble,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'isEnabled': isEnabled,
      'inputGain': inputGain,
      'echoEnabled': echoEnabled,
      'echoDelay': echoDelay,
      'echoFeedback': echoFeedback,
      'echoWetMix': echoWetMix,
      'reverbEnabled': reverbEnabled,
      'reverbRoom': reverbRoom,
      'reverbDamping': reverbDamping,
      'reverbWetMix': reverbWetMix,
      'pitchEnabled': pitchEnabled,
      'pitchSemitones': pitchSemitones,
      'chorusEnabled': chorusEnabled,
      'chorusDepth': chorusDepth,
      'chorusRate': chorusRate,
      'chorusWetMix': chorusWetMix,
      'noiseGateEnabled': noiseGateEnabled,
      'noiseGateThreshold': noiseGateThreshold,
      'compressorEnabled': compressorEnabled,
      'compressorThreshold': compressorThreshold,
      'compressorRatio': compressorRatio,
      'eqEnabled': eqEnabled,
      'eqBass': eqBass,
      'eqMid': eqMid,
      'eqTreble': eqTreble,
    };
  }

  factory MicFxSettings.fromMap(Map<String, dynamic> map) {
    return MicFxSettings(
      isEnabled: map['isEnabled'] as bool? ?? true,
      inputGain: (map['inputGain'] as num?)?.toDouble() ?? 1.0,
      echoEnabled: map['echoEnabled'] as bool? ?? false,
      echoDelay: (map['echoDelay'] as num?)?.toDouble() ?? 250.0,
      echoFeedback: (map['echoFeedback'] as num?)?.toDouble() ?? 0.3,
      echoWetMix: (map['echoWetMix'] as num?)?.toDouble() ?? 0.4,
      reverbEnabled: map['reverbEnabled'] as bool? ?? false,
      reverbRoom: (map['reverbRoom'] as num?)?.toDouble() ?? 0.5,
      reverbDamping: (map['reverbDamping'] as num?)?.toDouble() ?? 0.5,
      reverbWetMix: (map['reverbWetMix'] as num?)?.toDouble() ?? 0.3,
      pitchEnabled: map['pitchEnabled'] as bool? ?? false,
      pitchSemitones: (map['pitchSemitones'] as num?)?.toDouble() ?? 0.0,
      chorusEnabled: map['chorusEnabled'] as bool? ?? false,
      chorusDepth: (map['chorusDepth'] as num?)?.toDouble() ?? 0.3,
      chorusRate: (map['chorusRate'] as num?)?.toDouble() ?? 1.5,
      chorusWetMix: (map['chorusWetMix'] as num?)?.toDouble() ?? 0.3,
      noiseGateEnabled: map['noiseGateEnabled'] as bool? ?? false,
      noiseGateThreshold: (map['noiseGateThreshold'] as num?)?.toDouble() ?? -40.0,
      compressorEnabled: map['compressorEnabled'] as bool? ?? false,
      compressorThreshold: (map['compressorThreshold'] as num?)?.toDouble() ?? -20.0,
      compressorRatio: (map['compressorRatio'] as num?)?.toDouble() ?? 4.0,
      eqEnabled: map['eqEnabled'] as bool? ?? false,
      eqBass: (map['eqBass'] as num?)?.toDouble() ?? 0.0,
      eqMid: (map['eqMid'] as num?)?.toDouble() ?? 0.0,
      eqTreble: (map['eqTreble'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class MediaFxSettings {
  bool isEnabled;
  double volume;      // 0.0 - 1.0
  double speed;       // 0.5 - 2.0
  double pitch;       // 0.5 - 2.0 (pitch of media)

  // EQ (5-band)
  bool eqEnabled;
  double eq60Hz;    // -12 to +12 dB (bass)
  double eq250Hz;   // -12 to +12 dB (low-mid)
  double eq1kHz;    // -12 to +12 dB (mid)
  double eq4kHz;    // -12 to +12 dB (high-mid)
  double eq12kHz;   // -12 to +12 dB (treble)

  // Spatial / Stereo
  bool stereoWidenEnabled;
  double stereoWidth; // 0.0 - 2.0

  // Bass Boost
  bool bassBoostEnabled;
  double bassBoostStrength; // 0 - 100

  // Reverb (subtle room ambience)
  bool reverbEnabled;
  double reverbWetMix; // 0.0 - 1.0

  MediaFxSettings({
    this.isEnabled = true,
    this.volume = 0.8,
    this.speed = 1.0,
    this.pitch = 1.0,
    this.eqEnabled = false,
    this.eq60Hz = 0,
    this.eq250Hz = 0,
    this.eq1kHz = 0,
    this.eq4kHz = 0,
    this.eq12kHz = 0,
    this.stereoWidenEnabled = false,
    this.stereoWidth = 1.0,
    this.bassBoostEnabled = false,
    this.bassBoostStrength = 50,
    this.reverbEnabled = false,
    this.reverbWetMix = 0.2,
  });

  MediaFxSettings copyWith({
    bool? isEnabled,
    double? volume,
    double? speed,
    double? pitch,
    bool? eqEnabled,
    double? eq60Hz,
    double? eq250Hz,
    double? eq1kHz,
    double? eq4kHz,
    double? eq12kHz,
    bool? stereoWidenEnabled,
    double? stereoWidth,
    bool? bassBoostEnabled,
    double? bassBoostStrength,
    bool? reverbEnabled,
    double? reverbWetMix,
  }) {
    return MediaFxSettings(
      isEnabled: isEnabled ?? this.isEnabled,
      volume: volume ?? this.volume,
      speed: speed ?? this.speed,
      pitch: pitch ?? this.pitch,
      eqEnabled: eqEnabled ?? this.eqEnabled,
      eq60Hz: eq60Hz ?? this.eq60Hz,
      eq250Hz: eq250Hz ?? this.eq250Hz,
      eq1kHz: eq1kHz ?? this.eq1kHz,
      eq4kHz: eq4kHz ?? this.eq4kHz,
      eq12kHz: eq12kHz ?? this.eq12kHz,
      stereoWidenEnabled: stereoWidenEnabled ?? this.stereoWidenEnabled,
      stereoWidth: stereoWidth ?? this.stereoWidth,
      bassBoostEnabled: bassBoostEnabled ?? this.bassBoostEnabled,
      bassBoostStrength: bassBoostStrength ?? this.bassBoostStrength,
      reverbEnabled: reverbEnabled ?? this.reverbEnabled,
      reverbWetMix: reverbWetMix ?? this.reverbWetMix,
    );
  }
}
