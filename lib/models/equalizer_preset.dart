// 🎚️ iPhone/Apple Music-এ যেসব EQ preset জনপ্রিয়, সেগুলোর একটা কালেকশন।
// প্রতিটা preset-এ ৭টা gain value (dB) থাকে, নিচের ৭টা standard band
// ফ্রিকোয়েন্সির জন্য (bass থেকে treble পর্যন্ত):
// 60Hz, 150Hz, 400Hz, 1kHz, 2.4kHz, 6kHz, 12kHz
//
// Android-এ ডিভাইস সাধারণত কম band (৫টা) সাপোর্ট করে — সেক্ষেত্রে প্রথম
// কয়েকটা gain ব্যবহার হয়। iOS-এ ঠিক এই ৭টা band native ভাবে ব্যবহার হয়।

class EqualizerPreset {
  final String name;
  final List<double> gains; // dB, band index অনুযায়ী (bass -> treble)

  const EqualizerPreset({required this.name, required this.gains});
}

class EqualizerPresets {
  // ব্যবহৃত ফ্রিকোয়েন্সি (Hz) — শুধু reference/label দেখানোর জন্য, iOS native
  // engine (NativeAudioEngine.swift) এ ঠিক এই মানগুলোই সেট করা আছে
  static const List<double> standardFrequencies = [
    60,
    150,
    400,
    1000,
    2400,
    6000,
    12000,
  ];

  static const List<EqualizerPreset> all = [
    EqualizerPreset(name: 'Flat', gains: [0, 0, 0, 0, 0, 0, 0]),
    EqualizerPreset(name: 'Bass Booster', gains: [8, 6, 3, 0, 0, 0, 0]),
    EqualizerPreset(name: 'Bass Reducer', gains: [-6, -5, -2, 0, 0, 0, 0]),
    EqualizerPreset(name: 'Treble Booster', gains: [0, 0, 0, 0, 3, 6, 8]),
    EqualizerPreset(name: 'Treble Reducer', gains: [0, 0, 0, 0, -2, -5, -6]),
    EqualizerPreset(name: 'Vocal Booster', gains: [-3, -1, 3, 6, 4, 1, -1]),
    EqualizerPreset(name: 'Late Night', gains: [4, 3, 1, 0, -1, -3, -4]),
    EqualizerPreset(name: 'Loudness', gains: [7, 5, 1, -2, 1, 5, 7]),
    EqualizerPreset(name: 'Acoustic', gains: [4, 4, 2, 2, 3, 2, 2]),
    EqualizerPreset(name: 'Rock', gains: [6, 4, 1, -2, 2, 4, 5]),
    EqualizerPreset(name: 'Pop', gains: [-1, 2, 4, 4, 2, -1, -1]),
    EqualizerPreset(name: 'Jazz', gains: [4, 3, 1, -1, 1, 3, 4]),
    EqualizerPreset(name: 'Classical', gains: [4, 3, 1, -1, -1, 2, 4]),
    EqualizerPreset(name: 'Dance', gains: [7, 5, 2, 0, 1, 3, 5]),
    EqualizerPreset(name: 'Hip-Hop', gains: [7, 5, 2, 1, 1, 2, 1]),
    EqualizerPreset(name: 'Electronic', gains: [6, 4, 0, 0, 2, 4, 6]),
    EqualizerPreset(name: 'Spoken Word', gains: [-4, -1, 1, 4, 4, 2, -2]),
  ];

  static EqualizerPreset get flat => all.first;
}
