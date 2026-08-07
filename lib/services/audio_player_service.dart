import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import '../models/song_model.dart';

class AudioPlayerService {
  // Singleton pattern to ensure single AudioPlayer instance
  static final AudioPlayerService _instance = AudioPlayerService._internal();
  factory AudioPlayerService() => _instance;
  AudioPlayerService._internal();

  final AudioPlayer player = AudioPlayer();

  // 🎵 প্লেলিস্ট সেট করা (LateInitializationError Fix)
  Future<void> setPlaylist(List<SongModel> songs) async {
    try {
      if (songs.isEmpty) {
        await player.stop();
        return;
      }

      final playlist = ConcatenatingAudioSource(
        useLazyPreparation: true,
        children: songs.map((song) {
          // File path verification
          final file = File(song.filePath);
          final uri = Uri.file(file.path);

          // Unique ID generate for MediaItem (Fixes _audioHandler crash)
          final uniqueId = song.filePath.hashCode.toString();

          return AudioSource.uri(
            uri,
            tag: MediaItem(
              id: uniqueId,
              album: "Local Music",
              title: song.title.isNotEmpty ? song.title : "Unknown Title",
              artist: "AH Music Player",
            ),
          );
        }).toList(),
      );

      await player.setAudioSource(playlist, initialIndex: 0, initialPosition: Duration.zero);
    } catch (e, stackTrace) {
      debugPrint("AudioPlayerService SetPlaylist Error: $e");
      debugPrint("Stacktrace: $stackTrace");
      rethrow;
    }
  }

  // ⏯️ প্লেব্যাক কন্ট্রোল
  Future<void> play() async => await player.play();
  Future<void> pause() async => await player.pause();
  Future<void> seek(Duration position) async => await player.seek(position);
  
  Future<void> seekToNext() async {
    if (player.hasNext) {
      await player.seekToNext();
    }
  }

  Future<void> seekToPrevious() async {
    if (player.hasPrevious) {
      await player.seekToPrevious();
    }
  }

  Future<void> playSongAtIndex(int index) async {
    try {
      if (player.audioSource != null) {
        await player.seek(Duration.zero, index: index);
        await player.play();
      }
    } catch (e) {
      debugPrint("Error playing song at index $index: $e");
    }
  }

  Future<void> removeAudioSourceAt(int index) async {
    final source = player.audioSource;
    if (source is ConcatenatingAudioSource && index < source.length) {
      await source.removeAt(index);
    }
  }

  void dispose() {
    player.dispose();
  }
}
