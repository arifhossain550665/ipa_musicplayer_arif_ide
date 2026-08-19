// 🎚️ Android (just_audio AndroidEqualizer) আর iOS (AVAudioUnitEQ) দুটোরই
// band তথ্য একই generic আকারে UI-তে দেখানোর জন্য এই ক্লাস — যাতে
// equalizer_screen.dart কোনো platform-specific টাইপের উপর নির্ভর না করে।
class EqBandInfo {
  final double frequencyHz;
  final double minDb;
  final double maxDb;
  final double currentGain;

  const EqBandInfo({
    required this.frequencyHz,
    required this.minDb,
    required this.maxDb,
    required this.currentGain,
  });
}
