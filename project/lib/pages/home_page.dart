import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../model/song.dart';
import '../services/analytics_service.dart';
import '../services/firestore_service.dart';
import '../services/upload_service.dart';
import 'playlist_provider.dart';
import 'song_page.dart';
import 'profile_page.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final _firestoreService = FirestoreService();
  String _greeting = '';

  @override
  void initState() {
    super.initState();
    _setGreeting();
    AnalyticsService.logScreenView('home_page');
  }

  void _setGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      _greeting = 'Good morning';
    } else if (hour < 17) {
      _greeting = 'Good afternoon';
    } else {
      _greeting = 'Good evening';
    }
  }

  void goToSong(int index) {
    final provider = Provider.of<PlaylistProvider>(context, listen: false);
    final song = provider.playlist[index];
    provider.currentSongIndex = index;
    AnalyticsService.logSongPlayed(
        songName: song.songName, artistName: song.artistName);
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const SongPage(),
        transitionsBuilder: (_, anim, __, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(
              CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  String get _userName {
    final user = FirebaseAuth.instance.currentUser;
    return user?.displayName?.split(' ').first ?? 'Listener';
  }

  void _showAddSongSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddSongSheet(
        onSongAdded: (song) async {
          final provider =
          Provider.of<PlaylistProvider>(context, listen: false);
          provider.addSong(song);
          await _firestoreService.addCustomSong(song);
          AnalyticsService.logSongUploaded(songName: song.songName);
        },
      ),
    );
  }

  Future<void> _confirmDelete(int index, Song song) async {
    // Only uploaded (network) songs can be fully deleted
    final isUploaded = song.isNetworkSource;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Remove Song',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700)),
        content: Text(
          isUploaded
              ? 'Delete "${song.songName}" permanently? This will remove it from your playlist and storage.'
              : 'Remove "${song.songName}" from your playlist?',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              isUploaded ? 'Delete' : 'Remove',
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final provider =
      Provider.of<PlaylistProvider>(context, listen: false);
      provider.removeSong(index);
      AnalyticsService.logSongDeleted(songName: song.songName);

      if (isUploaded) {
        // Delete from Firestore and Firebase Storage in the background
        try {
          await _firestoreService.deleteCustomSongByAudioUrl(song.audioPath);
          await UploadService.deleteByUrl(song.audioPath);
        } catch (e) {
          debugPrint('Delete error: $e');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Header ─────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _greeting,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 13,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _userName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ProfilePage()),
                    ),
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Color(0xFF7C4DFF), Color(0xFFB388FF)],
                        ),
                      ),
                      child: Center(
                        child: Text(
                          _userName.isNotEmpty
                              ? _userName[0].toUpperCase()
                              : 'U',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // ─── Section title + controls ────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Your Playlist',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Row(
                    children: [
                      Consumer<PlaylistProvider>(
                        builder: (_, p, __) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF7C4DFF)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: const Color(0xFF7C4DFF)
                                    .withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            '${p.playlist.length} songs',
                            style: const TextStyle(
                              color: Color(0xFFB388FF),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _showAddSongSheet,
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF7C4DFF)
                                .withValues(alpha: 0.18),
                            border: Border.all(
                                color: const Color(0xFF7C4DFF)
                                    .withValues(alpha: 0.4)),
                          ),
                          child: const Icon(Icons.add_rounded,
                              color: Color(0xFFB388FF), size: 20),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Long-press a song to remove it',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.25),
                  fontSize: 11,
                ),
              ),
            ),

            const SizedBox(height: 8),

            // ─── Song list ───────────────────────────────────
            Expanded(
              child: Consumer<PlaylistProvider>(
                builder: (context, provider, child) {
                  if (provider.isLoadingCustomSongs) {
                    return const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFFB388FF)),
                    );
                  }
                  final playlist = provider.playlist;
                  return ListView.builder(
                    padding: const EdgeInsets.only(
                        left: 16, right: 16, bottom: 100),
                    itemCount: playlist.length,
                    itemBuilder: (context, index) {
                      final song = playlist[index];
                      final isCurrentSong =
                          provider.currentSongIndex == index;
                      return GestureDetector(
                        onTap: () => goToSong(index),
                        onLongPress: () => _confirmDelete(index, song),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isCurrentSong
                                ? const Color(0xFF7C4DFF)
                                .withValues(alpha: 0.18)
                                : const Color(0xFF1A1A2E),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isCurrentSong
                                  ? const Color(0xFF7C4DFF)
                                  .withValues(alpha: 0.5)
                                  : Colors.white.withValues(alpha: 0.05),
                            ),
                          ),
                          child: Row(
                            children: [
                              // Album art
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  color: const Color(0xFF2A2A3E),
                                ),
                                child: _AlbumArt(song: song, size: 52, radius: 10),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      song.songName,
                                      style: TextStyle(
                                        color: isCurrentSong
                                            ? const Color(0xFFB388FF)
                                            : Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      song.artistName,
                                      style: TextStyle(
                                        color: Colors.white
                                            .withValues(alpha: 0.45),
                                        fontSize: 12,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              if (isCurrentSong && provider.isPlaying)
                                Padding(
                                  padding: const EdgeInsets.only(right: 4),
                                  child: _PlayingIndicator(),
                                )
                              else
                                Icon(
                                  Icons.play_circle_filled_rounded,
                                  color: isCurrentSong
                                      ? const Color(0xFFB388FF)
                                      : Colors.white.withValues(alpha: 0.2),
                                  size: 28,
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),

      // ─── Mini Player ─────────────────────────────────────
      bottomSheet: Consumer<PlaylistProvider>(
        builder: (context, provider, child) {
          if (provider.currentSongIndex == null ||
              provider.currentSongIndex! >= provider.playlist.length) {
            return const SizedBox.shrink();
          }
          final song = provider.playlist[provider.currentSongIndex!];
          return GestureDetector(
            onTap: () => Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (_, __, ___) => const SongPage(),
                transitionsBuilder: (_, anim, __, child) => SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 1),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                      parent: anim, curve: Curves.easeOutCubic)),
                  child: child,
                ),
                transitionDuration: const Duration(milliseconds: 400),
              ),
            ),
            child: Container(
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2E),
                border: Border(
                  top: BorderSide(
                      color: Colors.white.withValues(alpha: 0.07)),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _AlbumArt(song: song, size: 44, radius: 8),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          song.songName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          song.artistName,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.45),
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: provider.playPreviousSong,
                    icon: const Icon(Icons.skip_previous_rounded,
                        color: Colors.white70, size: 26),
                    padding: EdgeInsets.zero,
                  ),
                  IconButton(
                    onPressed: provider.pauseOrResumeSong,
                    icon: Icon(
                      provider.isPlaying
                          ? Icons.pause_circle_filled_rounded
                          : Icons.play_circle_filled_rounded,
                      color: const Color(0xFFB388FF),
                      size: 38,
                    ),
                    padding: EdgeInsets.zero,
                  ),
                  IconButton(
                    onPressed: provider.playNextSong,
                    icon: const Icon(Icons.skip_next_rounded,
                        color: Colors.white70, size: 26),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}


// ─── Album Art Widget ───────────────────────────────────────────────────────

class _AlbumArt extends StatelessWidget {
  final Song song;
  final double size;
  final double radius;

  const _AlbumArt({required this.song, required this.size, required this.radius});

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A3E),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(Icons.music_note_rounded,
          color: const Color(0xFF7C4DFF), size: size * 0.45),
    );

    if (song.albumArtImagePath.isEmpty) return placeholder;

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: song.isNetworkSource
          ? Image.network(song.albumArtImagePath,
          width: size, height: size, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => placeholder)
          : Image.asset(song.albumArtImagePath,
          width: size, height: size, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => placeholder),
    );
  }
}

// ─── Add Song Bottom Sheet ──────────────────────────────────────────────────

class _AddSongSheet extends StatefulWidget {
  final Future<void> Function(Song song) onSongAdded;
  const _AddSongSheet({required this.onSongAdded});

  @override
  State<_AddSongSheet> createState() => _AddSongSheetState();
}

class _AddSongSheetState extends State<_AddSongSheet> {
  final _nameController = TextEditingController();
  final _artistController = TextEditingController();

  Uint8List? _pickedBytes;
  String? _pickedFileName;
  double _uploadProgress = 0;
  bool _uploading = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _artistController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: false,
      withData: true, // Required for web — loads bytes into memory
    );
    if (result != null && result.files.single.bytes != null) {
      setState(() {
        _pickedBytes = result.files.single.bytes!;
        _pickedFileName = result.files.single.name;
        // Pre-fill song name from filename if empty
        if (_nameController.text.isEmpty) {
          _nameController.text = result.files.single.name
              .replaceAll(RegExp(r'\.[^.]+$'), '');
        }
      });
    }
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final artist = _artistController.text.trim();

    if (name.isEmpty || artist.isEmpty) {
      setState(() => _error = 'Please fill in song name and artist.');
      return;
    }
    if (_pickedBytes == null) {
      setState(() => _error = 'Please select an audio file.');
      return;
    }

    setState(() {
      _saving = true;
      _uploading = true;
      _error = null;
    });

    try {
      final audioUrl = await UploadService.uploadAudioBytes(
        _pickedBytes!,
        _pickedFileName!,
        onProgress: (p) => setState(() => _uploadProgress = p),
      );

      setState(() => _uploading = false);

      final song = Song(
        songName: name,
        artistName: artist,
        albumArtImagePath: '', // no art for uploaded songs — shows placeholder
        audioPath: audioUrl,
        isNetworkSource: true,
      );

      await widget.onSongAdded(song);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _error = 'Upload failed. Check your connection and try again.';
        _saving = false;
        _uploading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
      EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A2E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            const Text(
              'Add Song to Playlist',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),

            _label('Song Name'),
            const SizedBox(height: 8),
            _field(_nameController, 'e.g. Blinding Lights',
                Icons.music_note_outlined),
            const SizedBox(height: 14),

            _label('Artist'),
            const SizedBox(height: 8),
            _field(_artistController, 'e.g. The Weeknd',
                Icons.person_outline_rounded),
            const SizedBox(height: 20),

            _label('Audio File'),
            const SizedBox(height: 8),

            // File picker button
            GestureDetector(
              onTap: (_saving || _uploading) ? null : _pickFile,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F0F1A),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _pickedBytes != null
                        ? const Color(0xFF7C4DFF).withValues(alpha: 0.6)
                        : Colors.white.withValues(alpha: 0.1),
                    width: 1.5,
                  ),
                ),
                child: _pickedBytes == null
                    ? Column(
                  children: [
                    Icon(Icons.upload_file_rounded,
                        color: Colors.white.withValues(alpha: 0.4),
                        size: 32),
                    const SizedBox(height: 8),
                    Text(
                      'Tap to select an audio file',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'MP3, WAV, AAC supported',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.25),
                          fontSize: 11),
                    ),
                  ],
                )
                    : Row(
                  children: [
                    const Icon(Icons.audio_file_rounded,
                        color: Color(0xFFB388FF), size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _pickedFileName ?? '',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    GestureDetector(
                      onTap: (_saving || _uploading) ? null : _pickFile,
                      child: const Icon(Icons.swap_horiz_rounded,
                          color: Color(0xFFB388FF), size: 20),
                    ),
                  ],
                ),
              ),
            ),

            // Upload progress bar
            if (_uploading) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _uploadProgress,
                  backgroundColor: Colors.white12,
                  color: const Color(0xFFB388FF),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Uploading… ${(_uploadProgress * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12),
              ),
            ],

            const SizedBox(height: 16),

            if (_error != null) ...[
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        color: Colors.redAccent, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_error!,
                          style: const TextStyle(
                              color: Colors.redAccent, fontSize: 13)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: (_saving || _uploading) ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C4DFF),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: (_saving || _uploading)
                    ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5))
                    : const Text('Upload & Add',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.55),
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String hint, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F1A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: TextField(
        controller: ctrl,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
              color: Colors.white.withValues(alpha: 0.25), fontSize: 14),
          prefixIcon: Icon(icon, color: Colors.white30, size: 20),
          border: InputBorder.none,
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}

// ─── Animated playing bars indicator ───────────────────────────────────────

class _PlayingIndicator extends StatefulWidget {
  @override
  State<_PlayingIndicator> createState() => _PlayingIndicatorState();
}

class _PlayingIndicatorState extends State<_PlayingIndicator>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      3,
          (i) => AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 400 + i * 120),
      )..repeat(reverse: true),
    );
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: _controllers[i],
          builder: (_, __) => Container(
            width: 3,
            height: 6 + _controllers[i].value * 14,
            margin: const EdgeInsets.symmetric(horizontal: 1.5),
            decoration: BoxDecoration(
              color: const Color(0xFFB388FF),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}