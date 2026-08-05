import 'dart:convert';
import 'song_model.dart';

class PlaylistModel {
  final String id;
  final String name;
  final List<SongModel> songs;

  PlaylistModel({
    required this.id,
    required this.name,
    required this.songs,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'songs': songs.map((x) => x.toMap()).toList(),
    };
  }

  factory PlaylistModel.fromMap(Map<String, dynamic> map) {
    return PlaylistModel(
      id: map['id'] ?? '',
      name: map['name'] ?? 'Untitled Playlist',
      songs: List<SongModel>.from(
        (map['songs'] as List<dynamic>).map((x) => SongModel.fromMap(x)),
      ),
    );
  }

  String toJson() => json.encode(toMap());

  factory PlaylistModel.fromJson(String source) =>
      PlaylistModel.fromMap(json.decode(source));
}
