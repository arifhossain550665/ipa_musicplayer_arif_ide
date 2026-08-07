import 'dart:io';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import '../models/song_model.dart';

class AudioPlayerService {
  final AudioPlayer player = AudioPlayer();

  // 🎵 প্লেলিস্ট লোড ও ফাইল প্লে করার সঠিক উপায়
  Future<void> setPlaylist(List<SongModel> songs) async {
    final playlist = ConcatenatingAudioSource(
      children: songs.map((song) {
        // 🔥 Uri.parse()-এর বদলে Uri.file() অথবা AudioSource.file ব্যবহার নিশ্চিত করবে যে ফাইলটি প্লেয়ারে সঠিকভাবে লোড হচ্ছে
        return AudioSource.uri(
          Uri.file(song.filePath), // <-- এখানে Uri.file ব্যবহার নিশ্চিত করতে হবে
          tag: MediaItem(
            id: song.filePath,
            album: "Local Music",
            title: song.title,
            artist: "AH Music Player",
          ),
        );
      }).toList(),
    );

    try {
      await player.setAudioSource(playlist);
    } catch (e) {
      print("Audio loading error: $e");
    }
  }

  // ⏯️ প্লে / পজ প্লেব্যাক
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
      print("Error playing song at index: $e");
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
