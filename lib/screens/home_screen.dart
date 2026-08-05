import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart'; // স্মুথ সিকবারের জন্য
import '../models/song_model.dart';
import '../models/playlist_model.dart';
import '../services/audio_player_service.dart';
import '../services/storage_service.dart';

// PositionData Class (স্মুথ সিকবারের জন্য)
class PositionData {
  final Duration position;
  final Duration bufferedPosition;
  final Duration duration;

  PositionData(this.position, this.bufferedPosition, this.duration);
}

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

    if (_playlists.isNotEmpty &&
        _playlists[_activePlaylistIndex].songs.isNotEmpty) {
      await _audioService.setPlaylist(_playlists[_activePlaylistIndex].songs);
    }
  }

  // ➕ নতুন প্লেলিস্ট তৈরি
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

  // 🗑️ প্লেলিস্ট ডিলিট অ্যালার্ট ডায়ালগ
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
                  _activePlaylistIndex = _playlists.isEmpty ? 0 : _playlists.length - 1;
                }
              });
              await _storageService.savePlaylists(_playlists);
              if (_playlists.isNotEmpty) {
                await _audioService.setPlaylist(_playlists[_activePlaylistIndex].songs);
              } else {
                await _audioService.setPlaylist([]);
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
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

  // 🗑️ গান রিমুভ অ্যালার্ট ডায়ালগ
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

  // ℹ️ About Dialog (App Developer Name)
  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: 'AH Music Player',
      applicationVersion: '1.0.0',
      applicationIcon: const Icon(Icons.music_note, size: 40, color: Colors.deepPurpleAccent),
      children: [
        const SizedBox(height: 10),
        const Text(
          'App Developer: Arif Hossain',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 5),
        const Text('Built with Flutter for high-performance iOS music playback.'),
      ],
    );
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

  // 🔥 স্মুথ সিকবারের জন্য Rx.combineLatest3 স্ট্রিম
  Stream<PositionData> get _positionDataStream =>
      Rx.combineLatest3<Duration, Duration, Duration?, PositionData>(
        _audioService.player.positionStream,
        _audioService.player.bufferedPositionStream,
        _audioService.player.durationStream,
        (position, bufferedPosition, duration) =>
            PositionData(position, bufferedPosition, duration ?? Duration.zero),
      );

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
        title: const Text('Music Player Pro'),
        actions: [
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
                // 📂 প্লেলিস্ট চিপস ও লং-প্রেস দিয়ে ডিলিট সাপোর্ট
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
                                      child: const Icon(Icons.cancel, size: 16, color: Colors.white70),
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
                                  await _audioService.setPlaylist(_playlists[index].songs);
                                }
                              },
                            ),
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
                              confirmDismiss: (direction) async {
                                _confirmDeleteSong(index);
                                return false; // অ্যালার্ট দিয়ে কাস্টম ডিলিট হ্যান্ডেল করা
                              },
                              background: Container(
                                color: Colors.redAccent,
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                child: const Icon(Icons.delete, color: Colors.white),
                              ),
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

          // 🔥 অতি স্মুথ সিকবার (PositionData Stream)
          StreamBuilder<PositionData>(
            stream: _positionDataStream,
            builder: (context, snapshot) {
              final positionData = snapshot.data;
              final position = positionData?.position ?? Duration.zero;
              final duration = positionData?.duration ?? Duration.zero;

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
