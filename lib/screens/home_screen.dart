import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../main.dart';
import '../models/song_model.dart';
import '../models/playlist_model.dart';
import '../models/position_data.dart';
import '../services/app_audio_service.dart';
import '../services/storage_service.dart';
import 'equalizer_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // 🎯 আগে AudioPlayerService (just_audio, শুধু Android-friendly) সরাসরি
  // ব্যবহার হতো। এখন AppAudioService facade ব্যবহার হচ্ছে, যেটা ভিতরে
  // ভিতরে Android-এ just_audio আর iOS-এ native AVAudioEngine বেছে নেয়।
  final AppAudioService _audioService = AppAudioService();
  final StorageService _storageService = StorageService();

  List<PlaylistModel> _playlists = [];
  int _activePlaylistIndex = 0;
  bool _isLoading = true;
  int? _currentIndex;

  @override
  void initState() {
    super.initState();
    _requestStoragePermission();
    _loadSavedData();
    _listenToCurrentSongIndex();

    // 🔴 Background audio init fail korle user ke জানানো (Android/just_audio_background)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!AudioBackendStatus.isReady && mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Audio Service Error'),
            content: SingleChildScrollView(
              child: Text(
                "Background audio service ঠিকমতো চালু হয়নি:\n\n${AudioBackendStatus.errorMessage}",
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    });
  }

  Future<void> _requestStoragePermission() async {
    if (Platform.isAndroid) {
      await [
        Permission.storage,
        Permission.audio,
        Permission.notification,
      ].request();
    }
  }

  Future<void> _loadSavedData() async {
    final savedPlaylists = await _storageService.loadPlaylists();

    // 🔴 ফিক্স: app reinstall/update এর পর কোনো গানের ফাইল আর না পাওয়া
    // গেলে (broken/ghost entry) সেটা এখানেই অটোমেটিক প্লেলিস্ট থেকে বাদ
    // দেওয়া হচ্ছে — যাতে ইউজারকে আর ম্যানুয়ালি পুরো প্লেলিস্ট ডিলিট
    // করে আবার শুরু করতে না হয়।
    final appDir = await getApplicationDocumentsDirectory();
    bool anyRemoved = false;

    for (final playlist in savedPlaylists) {
      final validSongs = <SongModel>[];
      for (final song in playlist.songs) {
        final path = p.join(appDir.path, song.fileName);
        if (song.fileName.isNotEmpty && await File(path).exists()) {
          validSongs.add(song);
        } else {
          anyRemoved = true;
        }
      }
      playlist.songs
        ..clear()
        ..addAll(validSongs);
    }

    if (anyRemoved) {
      await _storageService.savePlaylists(savedPlaylists);
    }

    setState(() {
      _playlists = savedPlaylists;
      _isLoading = false;
    });

    if (anyRemoved && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'কিছু পুরনো গানের ফাইল খুঁজে পাওয়া যায়নি, প্লেলিস্ট থেকে সরিয়ে দেওয়া হয়েছে।'),
        ),
      );
    }

    if (_playlists.isNotEmpty &&
        _playlists[_activePlaylistIndex].songs.isNotEmpty) {
      await _trySetPlaylist(_playlists[_activePlaylistIndex].songs);
    }
  }

  // 🔴 helper method - error ধরে স্ক্রিনে popup এ দেখাবে
  Future<void> _trySetPlaylist(List<SongModel> songs) async {
    try {
      await _audioService.setPlaylist(songs);
    } catch (e, st) {
      debugPrint("SET PLAYLIST ERROR: $e");
      debugPrint("STACK: $st");
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Playback Error'),
            content: SingleChildScrollView(
              child: Text(e.toString()),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  void _createNewPlaylistDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Playlist'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Enter playlist name...'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                final newPl = PlaylistModel(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: name,
                  songs: [],
                );
                setState(() {
                  _playlists.add(newPl);
                  _activePlaylistIndex = _playlists.length - 1;
                });
                await _storageService.savePlaylists(_playlists);
                await _trySetPlaylist([]);
              }
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _confirmDeletePlaylist(int index) {
    final playlistName = _playlists[index].name;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Playlist'),
        content: Text('Are you sure you want to delete playlist "$playlistName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() {
                _playlists.removeAt(index);
                if (_activePlaylistIndex >= _playlists.length) {
                  _activePlaylistIndex =
                      _playlists.isEmpty ? 0 : _playlists.length - 1;
                }
              });
              await _storageService.savePlaylists(_playlists);
              if (_playlists.isNotEmpty) {
                await _trySetPlaylist(_playlists[_activePlaylistIndex].songs);
              } else {
                await _trySetPlaylist([]);
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // 🔥 Android 11+ Fix: ফাইলটিকে অ্যাপের স্যান্ডবক্সে কপি করে নেওয়ার মেথড
  Future<void> _pickSongs() async {
    await _requestStoragePermission();

    if (_playlists.isEmpty) {
      _createNewPlaylistDialog();
      return;
    }

    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'wav', 'aac', 'm4a', 'flac'],
      allowMultiple: true,
    );

    if (result != null && result.files.isNotEmpty) {
      List<SongModel> newSongs = [];
      final appDir = await getApplicationDocumentsDirectory();

      for (var file in result.files) {
        if (file.path != null) {
          final originalFile = File(file.path!);
          final fileName = p.basename(file.path!);
          final savedPath = p.join(appDir.path, fileName);

          // ফাইল যদি আগে কপি না হয়ে থাকে তবে কপি করবে
          File targetFile = File(savedPath);
          if (!await targetFile.exists()) {
            targetFile = await originalFile.copy(savedPath);
          }

          newSongs.add(
            SongModel(
              title: file.name.replaceAll(RegExp(r'\.[^.]+$'), ''),
              // 🔴 ফিক্স: পুরো absolute path না রেখে শুধু filename রাখা হচ্ছে
              fileName: p.basename(targetFile.path),
            ),
          );
        }
      }

      setState(() {
        _playlists[_activePlaylistIndex].songs.addAll(newSongs);
      });

      await _storageService.savePlaylists(_playlists);
      await _trySetPlaylist(_playlists[_activePlaylistIndex].songs);
    }
  }

  void _confirmDeleteSong(int index) {
    final songTitle = _playlists[_activePlaylistIndex].songs[index].title;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Song'),
        content: Text('Are you sure you want to remove "$songTitle"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final currentSongs = _playlists[_activePlaylistIndex].songs;
              await _audioService.removeAudioSourceAt(index);
              setState(() {
                currentSongs.removeAt(index);
              });
              await _storageService.savePlaylists(_playlists);
            },
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: 'AH Music Player',
      applicationVersion: '1.0.0',
      applicationIcon: const Icon(Icons.music_note,
          size: 40, color: Colors.deepPurpleAccent),
      children: [
        const SizedBox(height: 10),
        const Text(
          'App Developer: Arif Hossain',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 5),
        const Text('High-performance audio player built with Flutter.'),
      ],
    );
  }

  void _listenToCurrentSongIndex() {
    _audioService.currentIndexStream.listen((index) {
      if (mounted) {
        setState(() {
          _currentIndex = index;
        });
      }
    });
  }

  @override
  void dispose() {
    _audioService.dispose();
    super.dispose();
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) return "00:00";
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    final activePlaylist =
        _playlists.isNotEmpty ? _playlists[_activePlaylistIndex] : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AH Music Player'),
        actions: [
          IconButton(
            icon: const Icon(Icons.equalizer),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EqualizerScreen()),
              );
            },
            tooltip: 'Equalizer',
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showAboutDialog,
            tooltip: 'About App',
          ),
          IconButton(
            icon: const Icon(Icons.playlist_add),
            onPressed: _createNewPlaylistDialog,
            tooltip: 'Create Playlist',
          ),
          IconButton(
            icon: const Icon(Icons.add_to_photos),
            onPressed: _pickSongs,
            tooltip: 'Add Songs',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_playlists.isNotEmpty)
                  SizedBox(
                    height: 50,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _playlists.length,
                      itemBuilder: (context, index) {
                        final isSelected = index == _activePlaylistIndex;
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4.0, vertical: 6.0),
                          child: GestureDetector(
                            onLongPress: () => _confirmDeletePlaylist(index),
                            child: ChoiceChip(
                              label: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(_playlists[index].name),
                                  if (isSelected) ...[
                                    const SizedBox(width: 4),
                                    InkWell(
                                      onTap: () => _confirmDeletePlaylist(index),
                                      child: const Icon(Icons.cancel,
                                          size: 16, color: Colors.white70),
                                    )
                                  ]
                                ],
                              ),
                              selected: isSelected,
                              selectedColor: Colors.deepPurpleAccent,
                              onSelected: (bool selected) async {
                                if (selected) {
                                  setState(() {
                                    _activePlaylistIndex = index;
                                  });
                                  await _trySetPlaylist(_playlists[index].songs);
                                }
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                const Divider(height: 1),
                Expanded(
                  child: (activePlaylist == null ||
                          activePlaylist.songs.isEmpty)
                      ? const Center(
                          child: Text(
                            'No songs in this playlist.\nTap + icon to add music files.',
                            textAlign: TextAlign.center,
                          ),
                        )
                      : ListView.builder(
                          itemCount: activePlaylist.songs.length,
                          itemBuilder: (context, index) {
                            final song = activePlaylist.songs[index];
                            final isSelected = index == _currentIndex;

                            return Dismissible(
                              key: Key(song.fileName + index.toString()),
                              direction: DismissDirection.endToStart,
                              confirmDismiss: (direction) async {
                                _confirmDeleteSong(index);
                                return false;
                              },
                              background: Container(
                                color: Colors.redAccent,
                                alignment: Alignment.centerRight,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 20),
                                child: const Icon(Icons.delete,
                                    color: Colors.white),
                              ),
                              child: ListTile(
                                leading: Icon(
                                  isSelected
                                      ? Icons.music_note
                                      : Icons.music_note_outlined,
                                  color: isSelected
                                      ? Colors.deepPurpleAccent
                                      : Colors.grey,
                                ),
                                title: Text(
                                  song.title,
                                  style: TextStyle(
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: isSelected
                                        ? Colors.deepPurpleAccent
                                        : Colors.white,
                                  ),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      color: Colors.grey),
                                  onPressed: () => _confirmDeleteSong(index),
                                ),
                                onTap: () async {
                                  await _audioService.playSongAtIndex(index);
                                },
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      bottomNavigationBar: (activePlaylist != null &&
              activePlaylist.songs.isNotEmpty)
          ? _buildPlayerControls(activePlaylist.songs)
          : null,
    );
  }

  Widget _buildPlayerControls(List<SongModel> songs) {
    final currentSong =
        (_currentIndex != null && _currentIndex! < songs.length)
            ? songs[_currentIndex!]
            : null;

    return Container(
      color: Colors.grey[900],
      padding: const EdgeInsets.only(top: 8, bottom: 16, left: 16, right: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            currentSong?.title ?? 'Select a song',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          StreamBuilder<PositionData>(
            stream: _audioService.positionDataStream,
            builder: (context, snapshot) {
              final positionData = snapshot.data;
              final position = positionData?.position ?? Duration.zero;
              final duration = positionData?.duration ?? Duration.zero;

              return Column(
                children: [
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      thumbShape:
                          const RoundSliderThumbShape(enabledThumbRadius: 6.0),
                      overlayShape:
                          const RoundSliderOverlayShape(overlayRadius: 12.0),
                      trackHeight: 3.0,
                    ),
                    child: Slider(
                      activeColor: Colors.deepPurpleAccent,
                      inactiveColor: Colors.grey[700],
                      min: 0.0,
                      max: duration.inMilliseconds.toDouble() > 0
                          ? duration.inMilliseconds.toDouble()
                          : 1.0,
                      value: position.inMilliseconds.toDouble().clamp(
                            0.0,
                            duration.inMilliseconds.toDouble() > 0
                                ? duration.inMilliseconds.toDouble()
                                : 1.0,
                          ),
                      onChanged: (value) {
                        _audioService
                            .seek(Duration(milliseconds: value.toInt()));
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDuration(position),
                          style:
                              const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                        Text(
                          _formatDuration(duration),
                          style:
                              const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.skip_previous,
                    size: 32, color: Colors.white),
                onPressed: () async => await _audioService.seekToPrevious(),
              ),
              const SizedBox(width: 16),
              StreamBuilder<bool>(
                stream: _audioService.playingStream,
                builder: (context, snapshot) {
                  final playing = snapshot.data ?? false;

                  return IconButton(
                    icon: Icon(
                      playing
                          ? Icons.pause_circle_filled
                          : Icons.play_circle_fill,
                      size: 48,
                      color: Colors.deepPurpleAccent,
                    ),
                    onPressed: () {
                      if (playing) {
                        _audioService.pause();
                      } else {
                        _audioService.play();
                      }
                    },
                  );
                },
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: const Icon(Icons.skip_next,
                    size: 32, color: Colors.white),
                onPressed: () async => await _audioService.seekToNext(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
