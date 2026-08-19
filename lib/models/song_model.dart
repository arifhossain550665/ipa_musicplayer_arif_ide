import 'dart:convert';

class SongModel {
  final String title;

  // 🔴 ফিক্স: আগে পুরো absolute path (filePath) সেভ করা হতো, যেটা
  // iOS-এ প্রতিবার app reinstall/update হলে (sandbox UUID বদলানোর কারণে)
  // ভেঙে যেত। এখন শুধু ফাইলের নাম (fileName) সেভ করা হয়, আর runtime-এ
  // AudioPlayerService প্রতিবার fresh Documents directory-র সাথে জোড়া
  // লাগিয়ে আসল path বানায় — তাই reinstall/update করলেও গান ভাঙে না।
  final String fileName;

  SongModel({
    required this.title,
    required this.fileName,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'fileName': fileName,
    };
  }

  factory SongModel.fromMap(Map<String, dynamic> map) {
    // 🔁 Migration: পুরনো ডেটাতে যদি শুধু 'filePath' (absolute) থাকে,
    // সেখান থেকে filename বের করে নেওয়া হচ্ছে যাতে পুরনো ব্যবহারকারীদের
    // প্লেলিস্ট নতুন version এ এসে সম্পূর্ণ হারিয়ে না যায়।
    String resolvedFileName;
    if (map['fileName'] != null && map['fileName'].toString().isNotEmpty) {
      resolvedFileName = map['fileName'];
    } else if (map['filePath'] != null) {
      final oldPath = map['filePath'].toString();
      resolvedFileName = oldPath.split(RegExp(r'[\\/]')).last;
    } else {
      resolvedFileName = '';
    }

    return SongModel(
      title: map['title'] ?? 'Unknown Title',
      fileName: resolvedFileName,
    );
  }

  String toJson() => json.encode(toMap());

  factory SongModel.fromJson(String source) =>
      SongModel.fromMap(json.decode(source));
}
