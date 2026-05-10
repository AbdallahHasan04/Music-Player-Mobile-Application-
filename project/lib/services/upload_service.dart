import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Web-compatible upload service — uses raw bytes instead of dart:io File,
/// so it works correctly on Flutter Web (Chrome).
class UploadService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static String get _uid => FirebaseAuth.instance.currentUser!.uid;

  /// Upload audio [bytes] to Firebase Storage and return the download URL.
  /// [fileName] is the original file name (e.g. "mysong.mp3").
  /// [onProgress] receives values from 0.0 to 1.0 during upload.
  static Future<String> uploadAudioBytes(
      Uint8List bytes,
      String fileName, {
        void Function(double progress)? onProgress,
      }) async {
    final uniqueName =
        '${DateTime.now().millisecondsSinceEpoch}_$fileName';
    final ref = _storage.ref().child('users/$_uid/songs/$uniqueName');

    final uploadTask = ref.putData(
      bytes,
      SettableMetadata(contentType: 'audio/mpeg'),
    );

    if (onProgress != null) {
      uploadTask.snapshotEvents.listen((snapshot) {
        if (snapshot.totalBytes > 0) {
          onProgress(snapshot.bytesTransferred / snapshot.totalBytes);
        }
      });
    }

    await uploadTask;
    return await ref.getDownloadURL();
  }

  /// Delete an uploaded file by its Firebase Storage download URL.
  static Future<void> deleteByUrl(String downloadUrl) async {
    try {
      final ref = _storage.refFromURL(downloadUrl);
      await ref.delete();
    } catch (_) {
      // Silently ignore if already deleted.
    }
  }
}