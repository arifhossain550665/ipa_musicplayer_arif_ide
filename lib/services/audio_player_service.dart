import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import '../models/song_model.dart';

class AudioPlayerService {
  final AudioPlayer _player = AudioPlayer();
  ConcatenatingAudioSource? _playlistSource;

  AudioPlayer get player => _player;

  Future<void> setPlaylist(List<SongModel> playlist) async {
    if (playlist.isEmpty) {
      await _player.stop();
      _playlistSource = ConcatenatingAudioSource(children: []);
      return;
    }

    // iOS Control Center / AirPods-এ মেটাডাটা দেখানোর জন্য MediaItem যুক্ত করা হলো
    final audioSources = playlist.map((song) {
      return AudioSource.uri(
        Uri.file(song.filePath),
        tag: MediaItem(
          id: song.filePath,
          album: "My Playlist",
          title: song.title,
          artist: "Local Storage",
        ),
      );
    }).toList();

    try {
      _playlistSource = ConcatenatingAudioSource(
        children: audioSources,
        useLazyPreparation: true,
      );

      await _player.setAudioSource(_playlistSource!);
      await _player.setLoopMode(LoopMode.all);
    } catch (e) {
      print("Error setting playlist: $e");
    }
  }

  Future<void> playSongAtIndex(int index) async {
    try {
      await _player.seek(Duration.zero, index: index);
      await _player.play();
    } catch (e) {
      print("Error playing song: $e");
    }
  }

  Future<void> removeAudioSourceAt(int index) async {
    if (_playlistSource != null && index >= 0 && index < _playlistSource!.length) {
      await _playlistSource!.removeAt(index);
    }
  }

  Future<void> seekToNext() async => await _player.seekToNext();
  Future<void> seekToPrevious() async => await _player.seekToPrevious();
  Future<void> seek(Duration position) async => await _player.seek(position);

  void play() => _player.play();
  void pause() => _player.pause();
  void dispose() => _player.dispose();
}
