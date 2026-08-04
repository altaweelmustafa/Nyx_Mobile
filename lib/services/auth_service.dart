import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../repositories/profile_repository.dart';

/// Google Sign-In wraps a user's identity only -- it does not gate access to
/// anything server-side. Playlists/likes/library stay 100% local per device
/// (each install already has its own library), so signing in just gives the
/// profile a stable, globally-unique Gmail-derived identity instead of the
/// generic local "admin" name.
class AuthService extends ChangeNotifier {
  AuthService() {
    _restore();
  }

  final _profileRepo = ProfileRepository();
  final _googleSignIn = GoogleSignIn(scopes: ['email']);

  String? _email;
  String? _googleId;
  String? _photoUrl;
  bool _isLoading = false;
  String? _error;

  String? get email => _email;
  String? get photoUrl => _photoUrl;
  bool get isSignedIn => _googleId != null;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// google_sign_in only ships a real implementation for Android/iOS/macOS/Web.
  static bool get isSupported =>
      kIsWeb || Platform.isAndroid || Platform.isIOS || Platform.isMacOS;

  Future<void> _restore() async {
    final (googleId, googleEmail) = await _profileRepo.getGoogleAccount();
    _googleId = googleId;
    _email = googleEmail;
    notifyListeners();

    if (!isSupported) return;
    try {
      final account = await _googleSignIn.signInSilently();
      if (account != null) {
        await _applyAccount(account);
      }
    } catch (_) {
      // Silent restore failing (no cached session, revoked access, etc.) just
      // leaves the profile in its last-known signed-out/in local state.
    }
  }

  Future<void> signIn() async {
    if (!isSupported) {
      _error = "Google Sign-In isn't available on this platform yet.";
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final account = await _googleSignIn.signIn();
      if (account != null) {
        await _applyAccount(account);
      }
    } catch (e) {
      _error = 'Sign-in failed: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    if (isSupported) {
      try {
        await _googleSignIn.signOut();
      } catch (_) {
        // Best-effort -- clear local state regardless.
      }
    }
    _googleId = null;
    _email = null;
    _photoUrl = null;
    await _profileRepo.setGoogleAccount(googleId: null, googleEmail: null);
    notifyListeners();
  }

  Future<void> _applyAccount(GoogleSignInAccount account) async {
    _googleId = account.id;
    _email = account.email;
    _photoUrl = account.photoUrl;
    await _profileRepo.setGoogleAccount(googleId: account.id, googleEmail: account.email);

    // Replace the generic placeholder name with the real one on first link.
    // Never overwrites a name the user has already customized themselves.
    final currentName = await _profileRepo.getDisplayName();
    if (currentName == 'admin' && (account.displayName?.isNotEmpty ?? false)) {
      await _profileRepo.setDisplayName(account.displayName!);
    }
  }
}
