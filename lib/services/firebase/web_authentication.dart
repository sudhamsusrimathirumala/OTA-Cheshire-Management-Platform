import 'package:firebase_auth/firebase_auth.dart';

abstract interface class WebAuthentication {
  Future<UserCredential> signInWithGoogle(FirebaseAuth auth);
  Future<void> reauthenticateWithGoogle(User user);
}

class FirebaseWebAuthentication implements WebAuthentication {
  const FirebaseWebAuthentication();

  @override
  Future<UserCredential> signInWithGoogle(FirebaseAuth auth) =>
      auth.signInWithPopup(createGoogleWebAuthProvider());

  @override
  Future<void> reauthenticateWithGoogle(User user) async {
    await user.reauthenticateWithPopup(createGoogleWebAuthProvider());
  }
}

GoogleAuthProvider createGoogleWebAuthProvider() =>
    GoogleAuthProvider()
      ..setCustomParameters(const <String, String>{'prompt': 'select_account'});
