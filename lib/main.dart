import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:permission_handler/permission_handler.dart';
import 'screens/home_screen.dart';

// 🔴 Global status flag - background init সফল হলো কিনা এটা ট্র্যাক করবে
class AudioBackendStatus {
  static bool isReady = true;
  static String? errorMessage;
}

Future<void> main() async {
  // ১. ফ্ল্যাটার ইঞ্জিন প্রস্তুত করা
  WidgetsFlutterBinding.ensureInitialized();

  // ২. নোটিফিকেশন পারমিশন আগে চাওয়া (Android 13+) - JustAudioBackground.init()
  //    এর আগে এটা না চাইলে audioHandler silently fail করে
  if (Platform.isAndroid) {
    await Permission.notification.request();
  }

  // ৩. JustAudioBackground ব্যাকগ্রাউন্ড প্রসেস সুরক্ষিতভাবে চালু করা
  try {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.example.musicplayer.channel.audio',
      androidNotificationChannelName: 'Audio Playback',
      androidNotificationOngoing: true,
    );
  } catch (e, st) {
    AudioBackendStatus.isReady = false;
    AudioBackendStatus.errorMessage = e.toString();
    debugPrint("JustAudioBackground Error: $e");
    debugPrint("StackTrace: $st");
  }

  // ৪. সার্ভিস চালু হোক বা না হোক, অ্যাপের UI লোড করে দেওয়া
  runApp(const MusicPlayerApp());
}

class MusicPlayerApp extends StatelessWidget {
  const MusicPlayerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AH Music Player',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          elevation: 0,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
