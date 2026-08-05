import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/song_model.dart';

class StorageService {
  static const String _playlistKey = 'saved_playlist';

  // প্লেলিস্ট সেভ করা
  Future<void> savePlaylist(List<SongModel> playlist) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> songJsonList =
        playlist.map((song) => song.toJson()).toList();
    await prefs.setStringList(_playlistKey, songJsonList);
  }

  // সেভ করা প্লেলিস্ট লোড করা
  Future<List<SongModel>> loadPlaylist() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? songJsonList = prefs.getStringList(_playlistKey);

    if (songJsonList == null) return [];

    return songJsonList
        .map((songJson) => SongModel.fromJson(songJson))
        .toList();
  }

  // নির্দিষ্ট গান রিমুভ করে আপডেট সেভ করা
  Future<void> removeSongAtIndex(int index, List<SongModel> currentPlaylist) async {
    if (index >= 0 && index < currentPlaylist.length) {
      currentPlaylist.removeAt(index);
      await savePlaylist(currentPlaylist);
    }
  }
}
