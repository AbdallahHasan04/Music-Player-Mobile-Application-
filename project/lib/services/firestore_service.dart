import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../model/song.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _uid => _auth.currentUser!.uid;

  // ─── FAVORITES (per-user) ─────────────────────────────────

  Future<void> addFavorite(Song song) async {
    await _db
        .collection('users')
        .doc(_uid)
        .collection('favorites')
        .doc(_songId(song))
        .set(song.toMap());
  }

  Future<void> removeFavorite(Song song) async {
    await _db
        .collection('users')
        .doc(_uid)
        .collection('favorites')
        .doc(_songId(song))
        .delete();
  }

  Stream<List<Song>> favoritesStream() {
    return _db
        .collection('users')
        .doc(_uid)
        .collection('favorites')
        .snapshots()
        .map((snap) =>
        snap.docs.map((d) => Song.fromMap(d.data())).toList());
  }

  Future<bool> isFavorite(Song song) async {
    final doc = await _db
        .collection('users')
        .doc(_uid)
        .collection('favorites')
        .doc(_songId(song))
        .get();
    return doc.exists;
  }

  // ─── USER CUSTOM SONGS (CRUD) ─────────────────────────────

  /// Save an uploaded/custom song to Firestore and return its doc ID.
  Future<String> addCustomSong(Song song) async {
    final ref = await _db
        .collection('users')
        .doc(_uid)
        .collection('custom_songs')
        .add(song.toMap());
    return ref.id;
  }

  /// Live stream of all custom songs for the current user.
  Stream<QuerySnapshot> customSongsStream() {
    return _db
        .collection('users')
        .doc(_uid)
        .collection('custom_songs')
        .orderBy('songName')
        .snapshots();
  }

  /// Update a custom song document.
  Future<void> updateCustomSong(
      String docId, Map<String, dynamic> data) async {
    await _db
        .collection('users')
        .doc(_uid)
        .collection('custom_songs')
        .doc(docId)
        .update(data);
  }

  /// Delete a custom song document by its Firestore doc ID.
  Future<void> deleteCustomSong(String docId) async {
    await _db
        .collection('users')
        .doc(_uid)
        .collection('custom_songs')
        .doc(docId)
        .delete();
  }

  /// Delete a custom song by matching its audioPath (download URL).
  /// Used when we don't have the doc ID but do have the audio URL.
  Future<void> deleteCustomSongByAudioUrl(String audioUrl) async {
    final snap = await _db
        .collection('users')
        .doc(_uid)
        .collection('custom_songs')
        .where('audioPath', isEqualTo: audioUrl)
        .get();
    for (final doc in snap.docs) {
      await doc.reference.delete();
    }
  }

  // ─── USER PROFILE ─────────────────────────────────────────

  Future<void> updateUserProfile(Map<String, dynamic> data) async {
    await _db.collection('users').doc(_uid).update(data);
  }

  // ─── Helpers ──────────────────────────────────────────────

  String _songId(Song song) =>
      '${song.artistName}_${song.songName}'
          .replaceAll(' ', '_')
          .toLowerCase();
}