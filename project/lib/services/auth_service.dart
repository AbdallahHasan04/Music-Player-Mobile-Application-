import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign In
  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );
  }

  // Sign Up
  Future<UserCredential> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    UserCredential cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );

    // Update display name
    await cred.user?.updateDisplayName(displayName);

    // Save user profile to Firestore
    await _firestore.collection('users').doc(cred.user!.uid).set({
      'uid': cred.user!.uid,
      'email': email.trim(),
      'displayName': displayName,
      'createdAt': FieldValue.serverTimestamp(),
      'favoriteCount': 0,
    });

    return cred;
  }

  // Sign Out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Get user profile from Firestore
  Future<Map<String, dynamic>?> getUserProfile() async {
    if (currentUser == null) return null;
    final doc = await _firestore
        .collection('users')
        .doc(currentUser!.uid)
        .get();
    return doc.data();
  }

  // Update display name
  Future<void> updateDisplayName(String name) async {
    await currentUser?.updateDisplayName(name);
    await _firestore
        .collection('users')
        .doc(currentUser!.uid)
        .update({'displayName': name});
  }
}
