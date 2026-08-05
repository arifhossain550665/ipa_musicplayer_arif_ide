import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/playlist_model.dart';

class StorageService {
  static const String _playlistsKey = 'saved_playlists_v2';

  Future<void> savePlaylists(List<PlaylistModel> playlists) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> playlistJsonList =
        playlists.map((pl) => pl.toJson()).toList();
    await prefs.setStringList(_playlistsKey, playlistJsonList);
  }

  Future<List<PlaylistModel>> loadPlaylists() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? playlistJsonList = prefs.getStringList(_playlistsKey);

    if (playlistJsonList == null || playlistJsonList.isEmpty) return [];

    return playlistJsonList
        .map((plJson) => PlaylistModel.fromJson(plJson))
        .toList();
  }
}
