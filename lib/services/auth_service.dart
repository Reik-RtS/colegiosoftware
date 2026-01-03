import 'package:firebase_auth/firebase_auth.dart';

/// Servicio centralizado para manejar la autenticación con Firebase.
class AuthService {
  AuthService({FirebaseAuth? firebaseAuth})
      : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseAuth _firebaseAuth;

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  User? get currentUser => _firebaseAuth.currentUser;

  /// Inicia sesión con correo y contraseña.
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) {
    return _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Cierra la sesión del usuario actual.
  Future<void> signOut() => _firebaseAuth.signOut();
}
