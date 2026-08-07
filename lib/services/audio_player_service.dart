import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import '../models/song_model.dart';

class AudioPlayerService {
  final AudioPlayer player = AudioPlayer();

  // 🎵 প্লেলিস্ট সেট করা
  Future<void> setPlaylist(List<SongModel> songs) async {
    final playlist = ConcatenatingAudioSource(
      children: songs.map((song) {
        final uri = Uri.file(song.filePath);
        return AudioSource.uri(
          uri,
          tag: MediaItem(
            id: song.filePath,
            album: "Local Music",
            title: song.title,
            artist: "AH Music Player",
          ),
        );
      }).toList(),
    );

    // এখন আর error ট লুকিয়ে রাখবে না, উপরে ছুঁড়ে দেব যাতে UI তে দেখানো যায়
    await player.setAudioSource(playlist);
  }

  // ⏯️ প্লেবক কন্ট্রোল
  Future<void> play() async => await player.play();
  Future<void> pause() async => await player.pause();
  Future<void> seek(Duration position) async => await player.seek(position);
  Future<void> seekToNext() async => await player.seekToNext();
  Future<void> seekToPrevious() async => await player.seekToPrevious();

  Future<void> playSongAtIndex(int index) async {
    try {
      await player.seek(Duration.zero, index: index);
      await player.play();
    } catch (e) {
      debugPrint("Error playing song at index $index: $e");
    }
  }

  Future<void> removeAudioSourceAt(int index) async {
    final source = player.audioSource;
    if (source is ConcatenatingAudioSource) {
      await source.removeAt(index);
    }
  }

  void dispose() {
    player.dispose();
  }
}
