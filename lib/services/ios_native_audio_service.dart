import 'dart:async';
import 'package:flutter/services.dart';
import '../models/position_data.dart';
import '../models/equalizer_preset.dart';

// 🎚️ iOS-এর জন্য real audio engine (AVAudioEngine + AVAudioUnitEQ) — Swift
// কোড ios/Runner/NativeAudioEngine.swift এবং ios/Runner/AppDelegate.swift এ।
// এখানে শুধু MethodChannel/EventChannel দিয়ে সেই native engine-কে কল করা হয়।
class IOSNativeAudioService {
  static final IOSNativeAudioService _instance =
      IOSNativeAudioService._internal();
  factory IOSNativeAudioService() => _instance;

  static const MethodChannel _method =
      MethodChannel('com.ah.audio.player/native_engine');
  static const EventChannel _positionChannel =
      EventChannel('com.ah.audio.player/position_stream');
  static const EventChannel _stateChannel =
      EventChannel('com.ah.audio.player/state_stream');
  static const EventChannel _indexChannel =
      EventChannel('com.ah.audio.player/index_stream');

  late final Stream<PositionData> positionDataStream;
  late final Stream<bool> playingStream;
  late final Stream<int> currentIndexStream;

  IOSNativeAudioService._internal() {
    positionDataStream = _positionChannel.receiveBroadcastStream().map((event) {
      final map = Map<String, dynamic>.from(event as Map);
      final posSec = (map['position'] as num?)?.toDouble() ?? 0.0;
      final durSec = (map['duration'] as num?)?.toDouble() ?? 0.0;
      return PositionData(
        Duration(milliseconds: (posSec * 1000).round()),
        Duration.zero,
        Duration(milliseconds: (durSec * 1000).round()),
      );
    }).asBroadcastStream();

    playingStream = _stateChannel
        .receiveBroadcastStream()
        .map((event) => event as bool)
        .asBroadcastStream();

    currentIndexStream = _indexChannel
        .receiveBroadcastStream()
        .map((event) => event as int)
        .asBroadcastStream();
  }

  // 🎵 প্লেলিস্ট সেট করা — এখানে সরাসরি absolute path পাঠাতে হয় (missing
  // ফাইল filter করা home_screen.dart-এই হয়ে থাকে facade এর মাধ্যমে)
  Future<void> setPlaylist(List<String> absolutePaths) async {
    await _method.invokeMethod('setPlaylist', {'paths': absolutePaths});
  }

  Future<void> playAtIndex(int index) async {
    await _method.invokeMethod('playAtIndex', {'index': index});
  }

  Future<void> play() async => await _method.invokeMethod('play');
  Future<void> pause() async => await _method.invokeMethod('pause');
  Future<void> seekToNext() async => await _method.invokeMethod('seekToNext');
  Future<void> seekToPrevious() async =>
      await _method.invokeMethod('seekToPrevious');

  Future<void> seek(Duration position) async => await _method.invokeMethod(
      'seek', {'seconds': position.inMilliseconds / 1000.0});

  Future<void> removeAtIndex(int index) async =>
      await _method.invokeMethod('removeAtIndex', {'index': index});

  // 🎚️ Equalizer
  Future<void> setEqualizerEnabled(bool enabled) async =>
      await _method.invokeMethod('setEqualizerEnabled', {'enabled': enabled});

  Future<void> setBandGain(int index, double gain) async =>
      await _method.invokeMethod('setBandGain', {'index': index, 'gain': gain});

  Future<void> applyPreset(EqualizerPreset preset) async =>
      await _method.invokeMethod('applyPreset', {'gains': preset.gains});

  Future<List<double>> getBandFrequencies() async {
    final result = await _method.invokeMethod('getBandFrequencies');
    return (result as List).map((e) => (e as num).toDouble()).toList();
  }
}
