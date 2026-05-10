import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../model/song.dart';

class PlaylistProvider extends ChangeNotifier {
  // The one built-in song. Custom songs are loaded from Firestore on init.
  final List<Song> _playlist = [
    Song(
      songName: 'Baba',
      artistName: 'Amr Diab',
      albumArtImagePath: 'assets/image/image1.png',
      audioPath: 'audio/audio1.mp3',
    ),
  ];

  int? _currentSongIndex;
  final AudioPlayer _audioPlayer = AudioPlayer();
  Duration _currentDuration = Duration.zero;
  Duration _totalDuration = Duration.zero;
  bool _isPlaying = false;
  bool _isShuffling = false;
  bool _isRepeating = false;
  bool _isLoadingCustomSongs = false;

  PlaylistProvider() {
    listenToDuration();
    _loadCustomSongsFromFirestore();
  }

  // ─── Auto-fetch custom songs from Firestore ───────────────

  Future<void> _loadCustomSongsFromFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _isLoadingCustomSongs = true;
    notifyListeners();

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('custom_songs')
          .orderBy('songName')
          .get();

      final customSongs =
      snapshot.docs.map((d) => Song.fromMap(d.data())).toList();

      // Avoid duplicates if called more than once
      _playlist.removeWhere((s) => s.isNetworkSource);
      _playlist.addAll(customSongs);
    } catch (e) {
      debugPrint('Error loading custom songs: $e');
    } finally {
      _isLoadingCustomSongs = false;
      notifyListeners();
    }
  }

  /// Call this after login to reload custom songs.
  Future<void> reloadCustomSongs() => _loadCustomSongsFromFirestore();

  /// Call this on logout to wipe the previous user's songs from memory.
  void clearCustomSongs() {
    _playlist.removeWhere((s) => s.isNetworkSource);
    if (_currentSongIndex != null) {
      final remaining = _playlist.length;
      if (remaining == 0) {
        _audioPlayer.stop();
        _isPlaying = false;
        _currentSongIndex = null;
      } else if (_currentSongIndex! >= remaining) {
        _currentSongIndex = 0;
      }
    }
    notifyListeners();
  }

  // ─── Playlist Management ──────────────────────────────────

  void addSong(Song song) {
    _playlist.add(song);
    notifyListeners();
  }

  void removeSong(int index) {
    if (index < 0 || index >= _playlist.length) return;
    if (_currentSongIndex == index) {
      _audioPlayer.stop();
      _isPlaying = false;
      _currentSongIndex = null;
    } else if (_currentSongIndex != null && _currentSongIndex! > index) {
      _currentSongIndex = _currentSongIndex! - 1;
    }
    _playlist.removeAt(index);
    notifyListeners();
  }

  // ─── Playback ─────────────────────────────────────────────

  void playSong() async {
    if (_currentSongIndex == null) return;
    final song = _playlist[_currentSongIndex!];
    await _audioPlayer.stop();
    // Reset durations immediately so the previous song's values don't linger
    _currentDuration = Duration.zero;
    _totalDuration = Duration.zero;
    notifyListeners();
    if (song.isNetworkSource) {
      await _audioPlayer.play(UrlSource(song.audioPath));
    } else {
      await _audioPlayer.play(AssetSource(song.audioPath));
    }
    _isPlaying = true;
    notifyListeners();
  }

  void pauseSong() async {
    await _audioPlayer.pause();
    _isPlaying = false;
    notifyListeners();
  }

  void resumeSong() async {
    await _audioPlayer.resume();
    _isPlaying = true;
    notifyListeners();
  }

  void pauseOrResumeSong() {
    if (_isPlaying) {
      pauseSong();
    } else {
      resumeSong();
    }
  }

  void seekTo(Duration duration) async {
    await _audioPlayer.seek(duration);
    notifyListeners();
  }

  void playNextSong() {
    if (_isShuffling) {
      final next = (List.generate(_playlist.length, (i) => i)
        ..shuffle()
        ..removeWhere((i) => i == _currentSongIndex))
          .first;
      _currentSongIndex = next;
      playSong();
      return;
    }
    if (_currentSongIndex != null) {
      _currentSongIndex = (_currentSongIndex! + 1) % _playlist.length;
    } else {
      _currentSongIndex = 0;
    }
    playSong();
    notifyListeners();
  }

  void playPreviousSong() async {
    if (_currentDuration > const Duration(seconds: 2)) {
      await _audioPlayer.seek(Duration.zero);
    } else if (_currentSongIndex != null && _currentSongIndex! > 0) {
      _currentSongIndex = _currentSongIndex! - 1;
      playSong();
    } else {
      _currentSongIndex = _playlist.length - 1;
      playSong();
    }
    notifyListeners();
  }

  void toggleShuffle() {
    _isShuffling = !_isShuffling;
    notifyListeners();
  }

  void toggleRepeat() {
    _isRepeating = !_isRepeating;
    notifyListeners();
  }

  void listenToDuration() {
    _audioPlayer.onDurationChanged.listen((newDuration) {
      _totalDuration = newDuration;
      notifyListeners();
    });
    _audioPlayer.onPositionChanged.listen((newPosition) {
      _currentDuration = newPosition;
      notifyListeners();
    });
    _audioPlayer.onPlayerComplete.listen((_) {
      if (_isRepeating) {
        playSong();
      } else {
        playNextSong();
      }
    });
  }

  // ─── Getters ──────────────────────────────────────────────

  List<Song> get playlist => _playlist;
  int? get currentSongIndex => _currentSongIndex;
  bool get isPlaying => _isPlaying;
  bool get isShuffling => _isShuffling;
  bool get isRepeating => _isRepeating;
  bool get isLoadingCustomSongs => _isLoadingCustomSongs;
  Duration get currentDuration => _currentDuration;
  Duration get totalDuration => _totalDuration;

  set currentSongIndex(int? index) {
    _currentSongIndex = index;
    if (_currentSongIndex != null) {
      playSong();
    }
    notifyListeners();
  }

  // ─── Helpers ──────────────────────────────────────────────

  String formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(1, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}