import 'dart:convert';

class SongModel {
  final String title;
  final String filePath;

  SongModel({
    required this.title,
    required this.filePath,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'filePath': filePath,
    };
  }

  factory SongModel.fromMap(Map<String, dynamic> map) {
    return SongModel(
      title: map['title'] ?? 'Unknown Title',
      filePath: map['filePath'] ?? '',
    );
  }

  String toJson() => json.encode(toMap());

  factory SongModel.fromJson(String source) =>
      SongModel.fromMap(json.decode(source));
}
