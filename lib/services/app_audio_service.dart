import 'dart:io';
import 'dart:async';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:rxdart/rxdart.dart';

import '../models/song_model.dart';
import '../models/position_data.dart';
import '../models/equalizer_preset.dart';
import '../models/eq_band_info.dart';
import 'audio_player_service.dart';
import 'ios_native_audio_service.dart';

// 🎯 এই ক্লাসটাই একমাত্র জায়গা যেটা UI (home_screen.dart,
// equalizer_screen.dart) ব্যবহার করবে। ভিতরে ভিতরে platform অনুযায়ী
// Android-এ just_audio (AudioPlayerService) আর iOS-এ native AVAudioEngine
// (IOSNativeAudioService) বেছে নেওয়া হয় — UI কোডে কোনো Platform.isIOS
// চেক লাগবে না, সব এখানেই সামলানো হচ্ছে।
class AppAudioService {
  static final AppAudioService _instance = AppAudioService._internal();
  factory AppAudioService() => _instance;

  final bool _useNativeIOSEngine = Platform.isIOS;

  final AudioPlayerService _android = AudioPlayerService();
  final IOSNativeAudioService _ios = IOSNativeAudioService();

  List<SongModel> _currentSongs = [];
  int? _currentIndex;
  final _currentIndexController = StreamController<int?>.broadcast();
  final _playingController = StreamController<bool>.broadcast();

  List<String> lastMissingFileNames = [];

  AppAudioService._internal() {
    if (_useNativeIOSEngine) {
      _ios.currentIndexStream.listen((index) {
        _currentIndex = index;
        _currentIndexController.add(index);
      });
      _ios.playingStream.listen((playing) {
        _playingController.add(playing);
      });
    } else {
      _android.player.currentIndexStream.listen((index) {
        _currentIndex = index;
        _currentIndexController.add(index);
      });
      _android.player.playerStateStream.listen((state) {
        _playingController.add(state.playing);
      });
    }
  }

  Stream<int?> get currentIndexStream => _currentIndexController.stream;
  Stream<bool> get playingStream => _playingController.stream;
  int? get currentIndex => _currentIndex;

  Stream<PositionData> get positionDataStream {
    if (_useNativeIOSEngine) {
      return _ios.positionDataStream;
    }
    return Rx.combineLatest3<Duration, Duration, Duration?, PositionData>(
      _android.player.positionStream,
      _android.player.bufferedPositionStream,
      _android.player.durationStream,
      (position, bufferedPosition, duration) =>
          PositionData(position, bufferedPosition, duration ?? Duration.zero),
    );
  }

  // 🎵 প্লেলিস্ট সেট করা
  Future<void> setPlaylist(List<SongModel> songs) async {
    _currentSongs = songs;

    if (_useNativeIOSEngine) {
      lastMissingFileNames = [];
      final appDir = await getApplicationDocumentsDirectory();
      final List<String> validPaths = [];

      for (final song in songs) {
        if (song.fileName.isEmpty) {
          lastMissingFileNames.add(song.title);
          continue;
        }
        final absPath = p.join(appDir.path, song.fileName);
        if (await File(absPath).exists()) {
          validPaths.add(absPath);
        } else {
          lastMissingFileNames.add(song.title);
        }
      }

      await _ios.setPlaylist(validPaths);
    } else {
      await _android.setPlaylist(songs);
      lastMissingFileNames = _android.lastMissingFileNames;
    }
  }

  // ⏯️ প্লেব্যাক কন্ট্রোল
  Future<void> play() async {
    if (_useNativeIOSEngine) {
      await _ios.play();
    } else {
      await _android.play();
    }
  }

  Future<void> pause() async {
    if (_useNativeIOSEngine) {
      await _ios.pause();
    } else {
      await _android.pause();
    }
  }

  Future<void> seek(Duration position) async {
    if (_useNativeIOSEngine) {
      await _ios.seek(position);
    } else {
      await _android.seek(position);
    }
  }

  Future<void> seekToNext() async {
    if (_useNativeIOSEngine) {
      await _ios.seekToNext();
    } else {
      await _android.seekToNext();
    }
  }

  Future<void> seekToPrevious() async {
    if (_useNativeIOSEngine) {
      await _ios.seekToPrevious();
    } else {
      await _android.seekToPrevious();
    }
  }

  Future<void> playSongAtIndex(int index) async {
    if (_useNativeIOSEngine) {
      await _ios.playAtIndex(index);
    } else {
      await _android.playSongAtIndex(index);
    }
  }

  Future<void> removeAudioSourceAt(int index) async {
    if (_useNativeIOSEngine) {
      await _ios.removeAtIndex(index);
    } else {
      await _android.removeAudioSourceAt(index);
    }
  }

  // 🎚️ ---------- Equalizer (এখন Android আর iOS দুটোতেই real কাজ করে) ----------

  bool get isEqualizerSupported => true;

  Future<void> setEqualizerEnabled(bool enabled) async {
    if (_useNativeIOSEngine) {
      await _ios.setEqualizerEnabled(enabled);
    } else {
      await _android.setEqualizerEnabled(enabled);
    }
  }

  Future<void> setBandGain(int index, double gain) async {
    if (_useNativeIOSEngine) {
      await _ios.setBandGain(index, gain);
    } else {
      await _android.setBandGain(index, gain);
    }
  }

  Future<void> applyPreset(EqualizerPreset preset) async {
    if (_useNativeIOSEngine) {
      await _ios.applyPreset(preset);
    } else {
      await _android.applyPreset(preset);
    }
  }

  // iOS-এ fixed ৭-band (min/max দেখানোর জন্য Apple Music-স্টাইল -12..+12 dB
  // রেঞ্জ ব্যবহার করা হচ্ছে), Android-এ ডিভাইস যা রিপোর্ট করে সেটাই আসল।
  Future<List<EqBandInfo>> getBandInfos() async {
    if (_useNativeIOSEngine) {
      return List.generate(EqualizerPresets.standardFrequencies.length, (i) {
        return EqBandInfo(
          frequencyHz: EqualizerPresets.standardFrequencies[i],
          minDb: -12,
          maxDb: 12,
          currentGain: 0, // iOS engine নিজে থেকে current gain query করা যায় না;
          // preset/manual change করার সময় UI নিজেই local state রাখে
        );
      });
    }
    return await _android.getBandInfos();
  }

  void dispose() {
    if (!_useNativeIOSEngine) {
      _android.dispose();
    }
    _currentIndexController.close();
    _playingController.close();
  }
}
