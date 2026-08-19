import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/song_model.dart';

class AudioPlayerService {
  static final AudioPlayerService _instance = AudioPlayerService._internal();
  factory AudioPlayerService() => _instance;
  AudioPlayerService._internal();

  final AudioPlayer player = AudioPlayer();

  // 🔴 কোন গানগুলো শেষবার সফলভাবে লোড হয়েছিল (missing বাদ দিয়ে) সেটা
  // বাইরে থেকে জানার জন্য — UI চাইলে ঘোস্ট/broken এন্ট্রি ক্লিন করতে পারবে
  List<String> lastMissingFileNames = [];

  // 🎯 প্রতিটা গানের filename দিয়ে fresh absolute path বানানো (প্রতিবার
  // app চালু হওয়ার সময় বা reinstall/update এর পরও ঠিকভাবে কাজ করবে)
  Future<String> _resolveAbsolutePath(String fileName) async {
    final appDir = await getApplicationDocumentsDirectory();
    return p.join(appDir.path, fileName);
  }

  // 🎵 প্লেলিস্ট সেট করা — এখন প্রতিটা ফাইল আগে exist করে কিনা চেক করে,
  // missing ফাইল থাকলে পুরো প্লেলিস্ট fail না করিয়ে শুধু সেটা বাদ দেয়
  Future<void> setPlaylist(List<SongModel> songs) async {
    try {
      lastMissingFileNames = [];

      if (songs.isEmpty) {
        await player.stop();
        return;
      }

      final List<AudioSource> children = [];

      for (final song in songs) {
        if (song.fileName.isEmpty) {
          lastMissingFileNames.add(song.title);
          continue;
        }

        final absPath = await _resolveAbsolutePath(song.fileName);
        final exists = await File(absPath).exists();

        if (!exists) {
          debugPrint("Skipping missing file: $absPath");
          lastMissingFileNames.add(song.title);
          continue;
        }

        final uri = Uri.file(absPath);
        final uniqueId = absPath.hashCode.toString();

        children.add(
          AudioSource.uri(
            uri,
            tag: MediaItem(
              id: uniqueId,
              album: "Storage Music",
              title: song.title.isNotEmpty ? song.title : "Unknown Title",
              artist: "AH Music Player",
            ),
          ),
        );
      }

      if (children.isEmpty) {
        await player.stop();
        return;
      }

      final playlist = ConcatenatingAudioSource(
        useLazyPreparation: true,
        children: children,
      );

      await player.setAudioSource(playlist,
          initialIndex: 0, initialPosition: Duration.zero);
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
