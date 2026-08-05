import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:just_audio/just_audio.dart';
import '../models/song_model.dart';
import '../models/playlist_model.dart';
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

  List<PlaylistModel> _playlists = [];
  int _activePlaylistIndex = 0;
  bool _isLoading = true;
  int? _currentIndex;

  @override
  void initState() {
    super.initState();
    _loadSavedData();
    _listenToCurrentSongIndex();
  }

  Future<void> _loadSavedData() async {
    final savedPlaylists = await _storageService.loadPlaylists();
    setState(() {
      _playlists = savedPlaylists;
      _isLoading = false;
    });

    if (_playlists.isNotEmpty && _playlists[_activePlaylistIndex].songs.isNotEmpty) {
      await _audioService.setPlaylist(_playlists[_activePlaylistIndex].songs);
    }
  }

  // ➕ নতুন নামের প্লেলিস্ট তৈরি করা
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
                await _audioService.setPlaylist([]);
              }
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  // 🎵 কারেন্ট প্লেলিস্টে গান পিক করা
  Future<void> _pickSongs() async {
    if (_playlists.isEmpty) {
      _createNewPlaylistDialog();
      return;
    }

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
        _playlists[_activePlaylistIndex].songs.addAll(newSongs);
      });

      await _storageService.savePlaylists(_playlists);
      await _audioService.setPlaylist(_playlists[_activePlaylistIndex].songs);
    }
  }

  Future<void> _removeSong(int index) async {
    final currentSongs = _playlists[_activePlaylistIndex].songs;
    await _audioService.removeAudioSourceAt(index);
    setState(() {
      currentSongs.removeAt(index);
    });
    await _storageService.savePlaylists(_playlists);
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
    final activePlaylist = _playlists.isNotEmpty ? _playlists[_activePlaylistIndex] : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AH Music Player'),
        actions: [
          IconButton(
            icon: const Icon(Icons.playlist_add),
            onPressed: _createNewPlaylistDialog,
            tooltip: 'Create New Playlist',
          ),
          IconButton(
            icon: const Icon(Icons.add_to_photos),
            onPressed: _pickSongs,
            tooltip: 'Add Songs from Files',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 📂 প্লেলিস্ট ট্যাব/লিস্ট (Horizontal Scroll)
                if (_playlists.isNotEmpty)
                  SizedBox(
                    height: 50,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _playlists.length,
                      itemBuilder: (context, index) {
                        final isSelected = index == _activePlaylistIndex;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 6.0),
                          child: ChoiceChip(
                            label: Text(_playlists[index].name),
                            selected: isSelected,
                            selectedColor: Colors.deepPurpleAccent,
                            onSelected: (bool selected) async {
                              if (selected) {
                                setState(() {
                                  _activePlaylistIndex = index;
                                });
                                await _audioService.setPlaylist(_playlists[index].songs);
                              }
                            },
                          ),
                        );
                      },
                    ),
                  ),
                const Divider(height: 1),

                // 🎵 গানের লিস্ট
                Expanded(
                  child: (activePlaylist == null || activePlaylist.songs.isEmpty)
                      ? const Center(
                          child: Text(
                            'No songs in this playlist.\nTap + icon to add from Apple Files.',
                            textAlign: TextAlign.center,
                          ),
                        )
                      : ListView.builder(
                          itemCount: activePlaylist.songs.length,
                          itemBuilder: (context, index) {
                            final song = activePlaylist.songs[index];
                            final isSelected = index == _currentIndex;

                            return Dismissible(
                              key: Key(song.filePath + index.toString()),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                color: Colors.redAccent,
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                child: const Icon(Icons.delete, color: Colors.white),
                              ),
                              onDismissed: (_) => _removeSong(index),
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
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.grey),
                                  onPressed: () => _removeSong(index),
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
      bottomNavigationBar: (activePlaylist != null && activePlaylist.songs.isNotEmpty)
          ? _buildPlayerControls(activePlaylist.songs)
          : null,
    );
  }

  Widget _buildPlayerControls(List<SongModel> songs) {
    final currentSong = (_currentIndex != null && _currentIndex! < songs.length)
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
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.skip_previous, size: 32, color: Colors.white),
                onPressed: () async => await _audioService.seekToPrevious(),
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
                onPressed: () async => await _audioService.seekToNext(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
