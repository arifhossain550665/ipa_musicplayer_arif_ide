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

  // 🔥 গান রিমুভ করার ফাংশন
  Future<void> _removeSong(int index) async {
    final songTitle = _playlist[index].title;

    // জাস্ট অডিও প্লেয়ার এবং লোকাল স্টোরেজ থেকে ডিলিট করা
    await _audioService.removeAudioSourceAt(index);
    await _storageService.removeSongAtIndex(index, _playlist);

    setState(() {});

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$songTitle removed from playlist'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

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

  String _formatDuration(Duration? duration) {
    if (duration == null) return "00:00";
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AH Music Player'),
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

                    // 🔥 Swipe to Delete functionality
                    return Dismissible(
                      key: Key(song.filePath + index.toString()),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: Colors.redAccent,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      onDismissed: (direction) {
                        _removeSong(index);
                      },
                      child: ListTile(
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
                        // 🔥 Delete Button
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.grey),
                          onPressed: () {
                            _showDeleteDialog(index, song.title);
                          },
                        ),
                        onTap: () async {
                          await _audioService.playSongAtIndex(index);
                        },
                      ),
                    );
                  },
                ),
      bottomNavigationBar: _playlist.isNotEmpty ? _buildPlayerControls() : null,
    );
  }

  // ডিলিট কনফার্মেশন পপআপ ডায়ালগ
  void _showDeleteDialog(int index, String title) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Song'),
        content: Text('Are you sure you want to remove "$title" from playlist?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _removeSong(index);
            },
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerControls() {
    final currentSong = (_currentIndex != null && _currentIndex! < _playlist.length)
        ? _playlist[_currentIndex!]
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

          // Seekbar
          StreamBuilder<Duration>(
            stream: _audioService.player.positionStream,
            builder: (context, snapshotPosition) {
              final position = snapshotPosition.data ?? Duration.zero;
              final duration = _audioService.player.duration ?? Duration.zero;

              return Column(
                children: [
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 12.0),
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
                        _audioService.seek(Duration(milliseconds: value.toInt()));
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
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                        Text(
                          _formatDuration(duration),
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),

          // Media Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.skip_previous, size: 32, color: Colors.white),
                onPressed: () async {
                  await _audioService.seekToPrevious();
                },
              ),
              const SizedBox(width: 16),
              StreamBuilder<PlayerState>(
                stream: _audioService.player.playerStateStream,
                builder: (context, snapshot) {
                  final playerState = snapshot.data;
                  final playing = playerState?.playing ?? false;

                  return IconButton(
                    icon: Icon(
                      playing ? Icons.pause_circle_filled : Icons.play_circle_fill,
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
                icon: const Icon(Icons.skip_next, size: 32, color: Colors.white),
                onPressed: () async {
                  await _audioService.seekToNext();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
