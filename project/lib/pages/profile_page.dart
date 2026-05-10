import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'playlist_provider.dart';
import '../services/auth_service.dart';
import '../services/analytics_service.dart';
import '../services/firestore_service.dart';
import '../model/song.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _authService = AuthService();
  final _firestoreService = FirestoreService();
  final _nameController = TextEditingController();
  bool _editingName = false;
  bool _savingName = false;

  User? get user => FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _nameController.text = user?.displayName ?? '';
    AnalyticsService.logScreenView('profile_page');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    setState(() => _savingName = true);
    try {
      await _authService.updateDisplayName(_nameController.text.trim());
      if (mounted) {
        setState(() => _editingName = false);
        ScaffoldMessenger.of(context).showSnackBar(
          _snackBar('Name updated!', isError: false),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          _snackBar('Failed to update name.', isError: true),
        );
      }
    } finally {
      if (mounted) setState(() => _savingName = false);
    }
  }

  // ─── FIX: Sign-out now pops the entire navigation stack so AuthGate
  //         can rebuild and show LoginPage correctly.
  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Sign Out',
            style:
            TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        content: Text(
          'Are you sure you want to sign out?',
          style: TextStyle(color: Colors.white.withOpacity(0.6)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: TextStyle(color: Colors.white.withOpacity(0.5))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign Out',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      // Pop ALL routes so AuthGate is the active widget and can redirect to
      // LoginPage after the sign-out stream fires.
      Navigator.of(context).popUntil((route) => route.isFirst);
      // Clear this user's songs before signing out so the next user
      // doesn't see them when they log in.
      if (mounted) {
        Provider.of<PlaylistProvider>(context, listen: false).clearCustomSongs();
      }
      await _authService.signOut();
    }
  }

  SnackBar _snackBar(String msg, {required bool isError}) {
    return SnackBar(
      content: Text(msg),
      backgroundColor:
      isError ? Colors.redAccent : const Color(0xFF7C4DFF),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      body: SafeArea(
        child: Column(
          children: [
            // ─── App bar ─────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios_rounded,
                        color: Colors.white70),
                  ),
                  const Expanded(
                    child: Text(
                      'Profile',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _signOut,
                    icon: const Icon(Icons.logout_rounded,
                        color: Colors.redAccent, size: 18),
                    label: const Text('Sign Out',
                        style: TextStyle(color: Colors.redAccent)),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const SizedBox(height: 8),

                    // ─── Avatar ──────────────────────────────
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF7C4DFF), Color(0xFFB388FF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF7C4DFF).withOpacity(0.5),
                            blurRadius: 30,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          (user?.displayName?.isNotEmpty == true
                              ? user!.displayName![0]
                              : user?.email?[0] ?? 'U')
                              .toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 38,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ─── Display name ────────────────────────
                    _buildCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionLabel('Display Name'),
                          const SizedBox(height: 10),
                          if (_editingName)
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _nameController,
                                    autofocus: true,
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 15),
                                    decoration: InputDecoration(
                                      hintText: 'Your name',
                                      hintStyle: TextStyle(
                                          color:
                                          Colors.white.withOpacity(0.3)),
                                      border: InputBorder.none,
                                    ),
                                  ),
                                ),
                                if (_savingName)
                                  const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        color: Color(0xFFB388FF),
                                        strokeWidth: 2),
                                  )
                                else ...[
                                  GestureDetector(
                                    onTap: _saveName,
                                    child: const Icon(Icons.check_rounded,
                                        color: Color(0xFFB388FF), size: 22),
                                  ),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () =>
                                        setState(() => _editingName = false),
                                    child: Icon(Icons.close_rounded,
                                        color: Colors.white.withOpacity(0.4),
                                        size: 22),
                                  ),
                                ],
                              ],
                            )
                          else
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    user?.displayName?.isNotEmpty == true
                                        ? user!.displayName!
                                        : 'Tap to set name',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () =>
                                      setState(() => _editingName = true),
                                  child: const Icon(Icons.edit_rounded,
                                      color: Color(0xFFB388FF), size: 20),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // ─── Email ───────────────────────────────
                    _buildCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionLabel('Email'),
                          const SizedBox(height: 8),
                          Text(
                            user?.email ?? '—',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ─── Favorites ───────────────────────────
                    Row(
                      children: [
                        const Icon(Icons.favorite_rounded,
                            color: Colors.pinkAccent, size: 18),
                        const SizedBox(width: 8),
                        const Text(
                          'Favorite Songs',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    StreamBuilder<List<Song>>(
                      stream: _firestoreService.favoritesStream(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: CircularProgressIndicator(
                                  color: Color(0xFFB388FF)),
                            ),
                          );
                        }
                        if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return _buildCard(
                            child: Padding(
                              padding:
                              const EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: Column(
                                  children: [
                                    Icon(Icons.favorite_border_rounded,
                                        color:
                                        Colors.white.withOpacity(0.2),
                                        size: 36),
                                    const SizedBox(height: 10),
                                    Text(
                                      'No favorites yet.\nTap ♡ on a song to save it.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color:
                                        Colors.white.withOpacity(0.35),
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }
                        final favorites = snapshot.data!;
                        return Column(
                          children: favorites
                              .map((song) => _buildCard(
                            margin:
                            const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    borderRadius:
                                    BorderRadius.circular(8),
                                    color: const Color(0xFF2A2A3E),
                                  ),
                                  child: _FavAlbumArt(song: song),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Text(song.songName,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight:
                                            FontWeight.w600,
                                            fontSize: 14,
                                          )),
                                      Text(song.artistName,
                                          style: TextStyle(
                                            color: Colors.white
                                                .withOpacity(0.45),
                                            fontSize: 12,
                                          )),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.favorite_rounded,
                                    color: Colors.pinkAccent,
                                    size: 18),
                              ],
                            ),
                          ))
                              .toList(),
                        );
                      },
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildCard(
      {required Widget child, EdgeInsets margin = EdgeInsets.zero}) {
    return Container(
      margin: margin,
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: child,
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.4),
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
      ),
    );
  }
}

// ─── Favorites Album Art ──────────────────────────────────────────────────────

class _FavAlbumArt extends StatelessWidget {
  final Song song;
  const _FavAlbumArt({required this.song});

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A3E),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.music_note_rounded,
          color: Color(0xFF7C4DFF), size: 20),
    );

    if (song.albumArtImagePath.isEmpty) return placeholder;

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: song.isNetworkSource
          ? Image.network(song.albumArtImagePath,
          width: 44, height: 44, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => placeholder)
          : Image.asset(song.albumArtImagePath,
          width: 44, height: 44, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => placeholder),
    );
  }
}