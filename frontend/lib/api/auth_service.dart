import 'package:supabase_flutter/supabase_flutter.dart';

class AuthFailure implements Exception {
  final String message;
  const AuthFailure(this.message);
  @override
  String toString() => message;
}

abstract class AuthService {
  bool get isSignedIn;
  String? get email;

  /// Emits whenever the session changes (sign in, sign out, expiry).
  Stream<void> get changes;

  /// A valid access token, refreshed if it is about to expire. Null when signed out.
  Future<String?> accessToken();

  /// Returns true when the account must be confirmed by email before signing in.
  Future<bool> register(String email, String password);
  Future<void> signIn(String email, String password);
  Future<void> signOut();

  /// Password reset with an emailed one-time code (no redirect links involved).
  Future<void> sendPasswordReset(String email);
  Future<void> verifyResetCode(String email, String code);
  Future<void> updatePassword(String newPassword);
}

class SupabaseAuthService implements AuthService {
  GoTrueClient get _auth => Supabase.instance.client.auth;

  @override
  bool get isSignedIn => _auth.currentSession != null;

  @override
  String? get email => _auth.currentUser?.email;

  @override
  Stream<void> get changes => _auth.onAuthStateChange.map((_) {});

  @override
  Future<String?> accessToken() async {
    var session = _auth.currentSession;
    if (session == null) return null;
    final exp = session.expiresAt; // seconds since epoch
    if (exp != null) {
      final left = DateTime.fromMillisecondsSinceEpoch(exp * 1000).difference(DateTime.now());
      if (left.inSeconds < 60) {
        try {
          final res = await _auth.refreshSession();
          session = res.session ?? session;
        } catch (_) {
          // fall through: the API will answer 401 and the app will sign the user out
        }
      }
    }
    return session?.accessToken;
  }

  @override
  Future<bool> register(String email, String password) async {
    try {
      final res = await _auth.signUp(email: email, password: password);
      return res.session == null;
    } on AuthException catch (e) {
      throw AuthFailure(_friendly(e.message));
    } catch (_) {
      throw const AuthFailure('Could not reach the sign-in service. Check your connection and try again.');
    }
  }

  @override
  Future<void> signIn(String email, String password) async {
    try {
      await _auth.signInWithPassword(email: email, password: password);
    } on AuthException catch (e) {
      throw AuthFailure(_friendly(e.message));
    } catch (_) {
      throw const AuthFailure('Could not reach the sign-in service. Check your connection and try again.');
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (_) {
      // Local session is cleared even if the network call fails.
    }
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.resetPasswordForEmail(email);
    } on AuthException catch (e) {
      throw AuthFailure(_friendly(e.message));
    } catch (_) {
      throw const AuthFailure('Could not reach the sign-in service. Check your connection and try again.');
    }
  }

  @override
  Future<void> verifyResetCode(String email, String code) async {
    try {
      await _auth.verifyOTP(email: email, token: code, type: OtpType.recovery);
    } on AuthException catch (e) {
      throw AuthFailure(_friendly(e.message));
    } catch (_) {
      throw const AuthFailure('Could not reach the sign-in service. Check your connection and try again.');
    }
  }

  @override
  Future<void> updatePassword(String newPassword) async {
    try {
      await _auth.updateUser(UserAttributes(password: newPassword));
    } on AuthException catch (e) {
      throw AuthFailure(_friendly(e.message));
    } catch (_) {
      throw const AuthFailure('Could not reach the sign-in service. Check your connection and try again.');
    }
  }

  String _friendly(String raw) {
    final m = raw.toLowerCase();
    if (m.contains('invalid login')) return 'Email or password is incorrect.';
    if (m.contains('already registered') || m.contains('already been registered')) {
      return 'An account with this email already exists. Sign in instead.';
    }
    if (m.contains('email not confirmed')) return 'Confirm your email first. Check your inbox for the link.';
    if (m.contains('rate limit')) return 'Too many attempts. Wait a few minutes and try again.';
    if (m.contains('token') && (m.contains('expired') || m.contains('invalid'))) {
      return 'That code is incorrect or has expired. Request a new one.';
    }
    if (m.contains('different from the old')) return 'Choose a password you have not used before.';
    if (m.contains('password')) return raw;
    return raw.isEmpty ? 'Something went wrong. Try again.' : raw;
  }
}