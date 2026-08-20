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
import 'equalizer_storage_service.dart';

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
  final EqualizerStorageService _eqStorage = EqualizerStorageService();

  List<SongModel> _currentSongs = [];
  int? _currentIndex;
  final _currentIndexController = StreamController<int?>.broadcast();
  final _playingController = StreamController<bool>.broadcast();

  List<String> lastMissingFileNames = [];

  // 🔴 EQ-এর বর্তমান অবস্থা মেমোরিতে cache করা থাকে — UI (equalizer_screen)
  // এখান থেকেই শুরুর মান পড়বে, প্রতিবার backend query করা লাগবে না।
  bool _eqEnabled = false;
  String _eqPresetName = 'Flat';
  List<double> _eqGains =
      List.filled(EqualizerPresets.standardFrequencies.length, 0.0);
  bool _eqRestored = false;
  Future<void>? _eqRestoreFuture;

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

  // 🔴 UI-এর জন্য cached getters — এখান থেকে শুরুর অবস্থা পড়া হয়
  bool get equalizerEnabledCached => _eqEnabled;
  String get activePresetName => _eqPresetName;
  List<double> get currentGains => List.unmodifiable(_eqGains);

  // 🔴 App চালু হওয়ার পর একবার কল করা হয় (home_screen initState-এ) —
  // আগে সেভ করা EQ অবস্থা (on/off, preset, gain) থাকলে সেটা backend-এ
  // আবার apply করে দেয়। বারবার কল করলেও একবারই আসল কাজ হয় (idempotent)।
  Future<void> restoreEqualizerSettings() {
    if (_eqRestored) return _eqRestoreFuture ?? Future.value();
    _eqRestored = true;
    _eqRestoreFuture = _doRestoreEqualizerSettings();
    return _eqRestoreFuture!;
  }

  Future<void> _doRestoreEqualizerSettings() async {
    try {
      final enabled = await _eqStorage.loadEnabled();
      final saved = await _eqStorage.loadState();

      if (saved != null && saved.gains.isNotEmpty) {
        _eqGains = saved.gains;
        _eqPresetName = saved.presetName;
      }
      _eqEnabled = enabled;

      // backend-এ আসল audio filtering আবার চালু করা (persist না করে, কারণ
      // এটা তো storage থেকেই পড়া ডেটা — আবার সেভ করার দরকার নেই)
      await _applyEnabledToBackend(enabled);
      for (int i = 0; i < _eqGains.length; i++) {
        await _applyBandGainToBackend(i, _eqGains[i]);
      }
    } catch (_) {
      // প্রথমবার app চালু হলে কোনো saved data থাকবে না — সেটা স্বাভাবিক
    }
  }

  Future<void> _applyEnabledToBackend(bool enabled) async {
    if (_useNativeIOSEngine) {
      await _ios.setEqualizerEnabled(enabled);
    } else {
      await _android.setEqualizerEnabled(enabled);
    }
  }

  Future<void> _applyBandGainToBackend(int index, double gain) async {
    if (_useNativeIOSEngine) {
      await _ios.setBandGain(index, gain);
    } else {
      await _android.setBandGain(index, gain);
    }
  }

  Future<void> setEqualizerEnabled(bool enabled) async {
    _eqEnabled = enabled;
    await _applyEnabledToBackend(enabled);
    await _eqStorage.saveEnabled(enabled); // 🔴 সেভ হচ্ছে
  }

  Future<void> setBandGain(int index, double gain) async {
    if (index >= 0 && index < _eqGains.length) {
      _eqGains[index] = gain;
    }
    _eqPresetName = 'Custom';
    await _applyBandGainToBackend(index, gain);
    await _eqStorage.saveState(_eqPresetName, _eqGains); // 🔴 সেভ হচ্ছে
  }

  Future<void> applyPreset(EqualizerPreset preset) async {
    _eqPresetName = preset.name;
    for (int i = 0; i < _eqGains.length && i < preset.gains.length; i++) {
      _eqGains[i] = preset.gains[i];
    }

    if (_useNativeIOSEngine) {
      await _ios.applyPreset(preset);
    } else {
      await _android.applyPreset(preset);
    }

    await _eqStorage.saveState(_eqPresetName, _eqGains); // 🔴 সেভ হচ্ছে
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
          currentGain: i < _eqGains.length ? _eqGains[i] : 0,
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
