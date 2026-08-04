import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:just_audio/just_audio.dart';
import '../models/song_model.dart';
import '../services/audio_player_service.dart';
import '../services/storage_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AudioPlayerService _audioService = AudioPlayerService();
  final StorageService _storageService = StorageService();

  List<SongModel> _playlist = [];
  bool _isLoading = true;
  int? _currentIndex;

  @override
  void initState() {
    super.initState();
    _loadSavedPlaylist();
    _listenToCurrentSongIndex();
  }

  // পূর্বে সেভ করা প্লেলিস্ট লোড
  Future<void> _loadSavedPlaylist() async {
    final savedSongs = await _storageService.loadPlaylist();
    setState(() {
      _playlist = savedSongs;
      _isLoading = false;
    });

    if (_playlist.isNotEmpty) {
      await _audioService.setPlaylist(_playlist);
    }
  }

  // আইফোনের Files থেকে গান পিক করা
  Future<void> _pickSongs() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'wav', 'aac', 'm4a'],
      allowMultiple: true,
    );

    if (result != null && result.files.isNotEmpty) {
      List<SongModel> newSongs = [];

      for (var file in result.files) {
        if (file.path != null) {
          newSongs.add(
            SongModel(
              title: file.name.replaceAll(RegExp(r'\.[^.]+$'), ''),
              filePath: file.path!,
            ),
          );
        }
      }

      setState(() {
        _playlist.addAll(newSongs);
      });

      await _storageService.savePlaylist(_playlist);
      await _audioService.setPlaylist(_playlist);
    }
  }

  // গানের প্লেব্যাক ট্র্যাক রাখা
  void _listenToCurrentSongIndex() {
    _audioService.player.currentIndexStream.listen((index) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Apple Files Music Player'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_to_photos),
            onPressed: _pickSongs,
            tooltip: 'Add Songs from Files',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _playlist.isEmpty
              ? const Center(
                  child: Text(
                    'No songs added yet.\nTap + icon to add from Apple Files.',
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.builder(
                  itemCount: _playlist.length,
                  itemBuilder: (context, index) {
                    final song = _playlist[index];
                    final isSelected = index == _currentIndex;

                    return ListTile(
                      leading: Icon(
                        isSelected ? Icons.music_note : Icons.music_note_outlined,
                        color: isSelected ? Colors.deepPurpleAccent : Colors.grey,
                      ),
                      title: Text(
                        song.title,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? Colors.deepPurpleAccent : Colors.white,
                        ),
                      ),
                      onTap: () async {
                        await _audioService.playSongAtIndex(index);
                      },
                    );
                  },
                ),
      bottomNavigationBar: _playlist.isNotEmpty ? _buildMiniPlayer() : null,
    );
  }

  // নিচে ছোট মিউজিক কন্ট্রোল বার (Mini Player)
  Widget _buildMiniPlayer() {
    return StreamBuilder<PlayerState>(
      stream: _audioService.player.playerStateStream,
      builder: (context, snapshot) {
        final playerState = snapshot.data;
        final processingState = playerState?.processingState;
        final playing = playerState?.playing;

        if (processingState == ProcessingState.idle) {
          return const SizedBox.shrink();
        }

        final currentSong = (_currentIndex != null && _currentIndex! < _playlist.length)
            ? _playlist[_currentIndex!]
            : null;

        return Container(
          color: Colors.grey[900],
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  currentSong?.title ?? 'Select a song',
                  maxLines: 1,
                  overflow: TextSpanOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: Icon(
                  playing == true ? Icons.pause_circle_filled : Icons.play_circle_fill,
                  size: 36,
                  color: Colors.deepPurpleAccent,
                ),
                onPressed: () {
                  if (playing == true) {
                    _audioService.pause();
                  } else {
                    _audioService.play();
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
