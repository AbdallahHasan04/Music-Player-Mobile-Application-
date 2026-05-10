import 'package:flutter/material.dart';
import '../model/song.dart';
import 'package:provider/provider.dart';
import '../services/firestore_service.dart';
import '../services/analytics_service.dart';
import 'playlist_provider.dart';

class SongPage extends StatefulWidget {
  const SongPage({super.key});

  @override
  State<SongPage> createState() => _SongPageState();
}

class _SongPageState extends State<SongPage>
    with SingleTickerProviderStateMixin {
  final _firestoreService = FirestoreService();
  bool _isFavorite = false;
  bool _loadingFavorite = true;
  late AnimationController _albumAnimController;

  @override
  void initState() {
    super.initState();
    _albumAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
    _checkFavorite();
    AnalyticsService.logScreenView('song_page');
  }

  Future<void> _checkFavorite() async {
    final provider =
    Provider.of<PlaylistProvider>(context, listen: false);
    if (provider.currentSongIndex == null) return;
    final song = provider.playlist[provider.currentSongIndex!];
    try {
      final fav = await _firestoreService.isFavorite(song);
      if (mounted) {
        setState(() {
          _isFavorite = fav;
          _loadingFavorite = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingFavorite = false);
    }
  }

  Future<void> _toggleFavorite() async {
    final provider =
    Provider.of<PlaylistProvider>(context, listen: false);
    if (provider.currentSongIndex == null) return;
    final song = provider.playlist[provider.currentSongIndex!];
    setState(() => _isFavorite = !_isFavorite);
    try {
      if (_isFavorite) {
        await _firestoreService.addFavorite(song);
        AnalyticsService.logFavoriteAdded(songName: song.songName);
      } else {
        await _firestoreService.removeFavorite(song);
        AnalyticsService.logFavoriteRemoved(songName: song.songName);
      }
    } catch (_) {
      if (mounted) setState(() => _isFavorite = !_isFavorite);
    }
  }

  @override
  void dispose() {
    _albumAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PlaylistProvider>(
      builder: (context, provider, child) {
        if (provider.currentSongIndex == null) {
          return const Scaffold(
            backgroundColor: Color(0xFF0F0F1A),
            body: Center(
              child: Text('No song selected',
                  style: TextStyle(color: Colors.white)),
            ),
          );
        }
        final playlist = provider.playlist;
        final currentSong = playlist[provider.currentSongIndex!];

        if (provider.isPlaying) {
          _albumAnimController.forward();
        } else {
          _albumAnimController.stop();
        }

        return Scaffold(
          backgroundColor: const Color(0xFF0F0F1A),
          body: SafeArea(
            child: Column(
              children: [
                // ─── Top bar ───────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.keyboard_arrow_down_rounded,
                            color: Colors.white70, size: 32),
                      ),
                      const Expanded(
                        child: Column(
                          children: [
                            Text(
                              'NOW PLAYING',
                              style: TextStyle(
                                color: Color(0xFFB388FF),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 2,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'P L A Y L I S T',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _loadingFavorite
                          ? const SizedBox(
                        width: 48,
                        height: 48,
                        child: Center(
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Color(0xFFB388FF),
                              strokeWidth: 2,
                            ),
                          ),
                        ),
                      )
                          : IconButton(
                        onPressed: _toggleFavorite,
                        icon: Icon(
                          _isFavorite
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: _isFavorite
                              ? Colors.pinkAccent
                              : Colors.white38,
                          size: 26,
                        ),
                      ),
                    ],
                  ),
                ),

                // ─── Album Art ────────────────────────────────
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: RotationTransition(
                        turns: _albumAnimController,
                        child: Container(
                          width: double.infinity,
                          constraints: const BoxConstraints(maxWidth: 300),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF7C4DFF)
                                    .withOpacity(0.35),
                                blurRadius: 60,
                                spreadRadius: 10,
                              ),
                            ],
                          ),
                          child: _AlbumArtCircle(song: currentSong),
                        ),
                      ),
                    ),
                  ),
                ),

                // ─── Song Info & Controls ──────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 12, 28, 0),
                  child: Column(
                    children: [
                      // Song name & artist
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  currentSong.songName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  currentSong.artistName,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.5),
                                    fontSize: 15,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // ─── Seek Slider ─────────────────────────
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 3.5,
                          thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 6),
                          overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 14),
                          activeTrackColor: const Color(0xFFB388FF),
                          inactiveTrackColor: Colors.white12,
                          thumbColor: Colors.white,
                          overlayColor:
                          const Color(0xFF7C4DFF).withOpacity(0.2),
                        ),
                        child: Slider(
                          min: 0,
                          max: provider.totalDuration.inSeconds
                              .toDouble()
                              .clamp(0.001, double.infinity),
                          value: provider.currentDuration.inSeconds
                              .toDouble()
                              .clamp(
                              0,
                              provider.totalDuration.inSeconds
                                  .toDouble()
                                  .clamp(0.001, double.infinity)),
                          onChanged: (_) {},
                          onChangeEnd: (value) {
                            provider
                                .seekTo(Duration(seconds: value.toInt()));
                          },
                        ),
                      ),

                      // Duration labels
                      Padding(
                        padding:
                        const EdgeInsets.symmetric(horizontal: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              provider.formatDuration(
                                  provider.currentDuration),
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.45),
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              provider
                                  .formatDuration(provider.totalDuration),
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.45),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ─── Playback Controls ───────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Shuffle
                          _ControlButton(
                            icon: Icons.shuffle_rounded,
                            isActive: provider.isShuffling,
                            size: 24,
                            onTap: () {
                              provider.toggleShuffle();
                              AnalyticsService.logShuffleToggled(
                                  enabled: provider.isShuffling);
                            },
                          ),

                          // Previous
                          _ControlButton(
                            icon: Icons.skip_previous_rounded,
                            size: 34,
                            onTap: () {
                              provider.playPreviousSong();
                              AnalyticsService.logSkipPrevious();
                            },
                          ),

                          // Play/Pause
                          GestureDetector(
                            onTap: provider.pauseOrResumeSong,
                            child: Container(
                              width: 70,
                              height: 70,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF7C4DFF),
                                    Color(0xFFB388FF)
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF7C4DFF)
                                        .withOpacity(0.55),
                                    blurRadius: 28,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: Icon(
                                provider.isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 38,
                              ),
                            ),
                          ),

                          // Next
                          _ControlButton(
                            icon: Icons.skip_next_rounded,
                            size: 34,
                            onTap: () {
                              provider.playNextSong();
                              AnalyticsService.logSkipNext();
                            },
                          ),

                          // Repeat
                          _ControlButton(
                            icon: Icons.repeat_rounded,
                            isActive: provider.isRepeating,
                            size: 24,
                            onTap: () {
                              provider.toggleRepeat();
                              AnalyticsService.logRepeatToggled(
                                  enabled: provider.isRepeating);
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),

                      // ─── Song selector dots ──────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          playlist.length,
                              (i) => AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            margin:
                            const EdgeInsets.symmetric(horizontal: 4),
                            width:
                            provider.currentSongIndex == i ? 20 : 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: provider.currentSongIndex == i
                                  ? const Color(0xFFB388FF)
                                  : Colors.white24,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}


// ─── Album Art Circle Widget ────────────────────────────────────────────────

class _AlbumArtCircle extends StatelessWidget {
  final Song song;
  const _AlbumArtCircle({required this.song});

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      color: const Color(0xFF1A1A2E),
      child: const Center(
        child: Icon(Icons.music_note_rounded,
            color: Color(0xFF7C4DFF), size: 80),
      ),
    );

    if (song.albumArtImagePath.isEmpty) {
      return ClipOval(child: AspectRatio(aspectRatio: 1, child: placeholder));
    }

    return ClipOval(
      child: AspectRatio(
        aspectRatio: 1,
        child: song.isNetworkSource
            ? Image.network(song.albumArtImagePath,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => placeholder)
            : Image.asset(song.albumArtImagePath,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => placeholder),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final bool isActive;

  const _ControlButton({
    required this.icon,
    required this.onTap,
    this.size = 28,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            icon,
            color: isActive ? const Color(0xFFB388FF) : Colors.white60,
            size: size,
          ),
          if (isActive)
            Positioned(
              bottom: 0,
              child: Container(
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                  color: Color(0xFFB388FF),
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}