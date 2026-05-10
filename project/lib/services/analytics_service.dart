import 'package:firebase_analytics/firebase_analytics.dart';

/// Centralised wrapper around FirebaseAnalytics.
/// Call these methods at key interaction points throughout the app.
class AnalyticsService {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  static FirebaseAnalyticsObserver get observer =>
      FirebaseAnalyticsObserver(analytics: _analytics);

  // ─── Auth events ──────────────────────────────────────────

  static Future<void> logLogin() async {
    await _analytics.logLogin(loginMethod: 'email');
  }

  static Future<void> logSignUp() async {
    await _analytics.logSignUp(signUpMethod: 'email');
  }

  // ─── Playback events ──────────────────────────────────────

  static Future<void> logSongPlayed({
    required String songName,
    required String artistName,
  }) async {
    await _analytics.logEvent(
      name: 'song_played',
      parameters: {
        'song_name': songName,
        'artist_name': artistName,
      },
    );
  }

  static Future<void> logSongPaused({
    required String songName,
  }) async {
    await _analytics.logEvent(
      name: 'song_paused',
      parameters: {'song_name': songName},
    );
  }

  static Future<void> logSkipNext() async {
    await _analytics.logEvent(name: 'skip_next');
  }

  static Future<void> logSkipPrevious() async {
    await _analytics.logEvent(name: 'skip_previous');
  }

  static Future<void> logShuffleToggled({required bool enabled}) async {
    await _analytics.logEvent(
      name: 'shuffle_toggled',
      parameters: {'enabled': enabled.toString()},
    );
  }

  static Future<void> logRepeatToggled({required bool enabled}) async {
    await _analytics.logEvent(
      name: 'repeat_toggled',
      parameters: {'enabled': enabled.toString()},
    );
  }

  // ─── Favorites events ─────────────────────────────────────

  static Future<void> logFavoriteAdded({required String songName}) async {
    await _analytics.logEvent(
      name: 'favorite_added',
      parameters: {'song_name': songName},
    );
  }

  static Future<void> logFavoriteRemoved({required String songName}) async {
    await _analytics.logEvent(
      name: 'favorite_removed',
      parameters: {'song_name': songName},
    );
  }

  // ─── Upload / playlist events ─────────────────────────────

  static Future<void> logSongUploaded({required String songName}) async {
    await _analytics.logEvent(
      name: 'song_uploaded',
      parameters: {'song_name': songName},
    );
  }

  static Future<void> logSongAddedManually({required String songName}) async {
    await _analytics.logEvent(
      name: 'song_added_manually',
      parameters: {'song_name': songName},
    );
  }

  static Future<void> logSongDeleted({required String songName}) async {
    await _analytics.logEvent(
      name: 'song_deleted',
      parameters: {'song_name': songName},
    );
  }

  // ─── Screen view ──────────────────────────────────────────

  static Future<void> logScreenView(String screenName) async {
    await _analytics.logScreenView(screenName: screenName);
  }
}
