import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

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

  /// Crea un usuario con correo y contraseña.
  Future<UserCredential> registerWithEmail({
    required String email,
    required String password,
  }) {
    return _firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Inicia sesión con Google y Firebase.
  Future<UserCredential> signInWithGoogle() async {
    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) {
      throw FirebaseAuthException(
        code: 'sign_in_canceled',
        message: 'Inicio de sesión cancelado',
      );
    }

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    return _firebaseAuth.signInWithCredential(credential);
  }

  /// Envía un código SMS y devuelve el [verificationId] que debe usarse con [signInWithSmsCode].
  Future<String> sendSmsCode(String phoneNumber) async {
    final completer = Completer<String>();
    var isCompleted = false;

    await _firebaseAuth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (PhoneAuthCredential credential) async {
        if (isCompleted) return;
        isCompleted = true;
        await _firebaseAuth.signInWithCredential(credential);
        completer.complete('');
      },
      verificationFailed: (FirebaseAuthException e) {
        if (isCompleted) return;
        isCompleted = true;
        completer.completeError(e);
      },
      codeSent: (String verificationId, int? resendToken) {
        if (isCompleted) return;
        isCompleted = true;
        completer.complete(verificationId);
      },
      codeAutoRetrievalTimeout: (_) {
        if (isCompleted) return;
        isCompleted = true;
        completer.completeError(
          FirebaseAuthException(
            code: 'timeout',
            message: 'Tiempo de espera excedido para el código SMS',
          ),
        );
      },
    );

    return completer.future;
  }

  /// Confirma el código SMS enviado previamente.
  Future<UserCredential> signInWithSmsCode({
    required String verificationId,
    required String smsCode,
  }) {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );

    return _firebaseAuth.signInWithCredential(credential);
  }

  /// Cierra la sesión del usuario actual.
  Future<void> signOut() => _firebaseAuth.signOut();
}
