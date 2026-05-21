import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      final User? user = userCredential.user;
      
      if (user != null) {
        final docRef = _firestore.collection('users').doc(user.uid);
        final docSnap = await docRef.get();

        if (!docSnap.exists) {
          final newUser = UserModel(
            id: user.uid,
            displayName: user.displayName ?? 'User',
            email: user.email ?? '',
            photoUrl: user.photoURL,
            points: 0,
            badge: 'bronze',
            currentSkin: 'default',
            unlockedSkins: ['default'],
            submissionsCount: 0,
            createdAt: DateTime.now(),
          );
          
          await docRef.set(newUser.toMap());
        }
        return userCredential;
      }
    } catch (e) {
      debugPrint('Error signInWithGoogle: \$e');
    }
    return null;
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  Future<UserModel?> getCurrentUserModel() async {
    try {
      final user = currentUser;
      if (user != null) {
        final docSnap = await _firestore.collection('users').doc(user.uid).get();
        if (docSnap.exists && docSnap.data() != null) {
          return UserModel.fromMap(docSnap.data() as Map<String, dynamic>);
        }
      }
    } catch (e) {
      debugPrint('Error getCurrentUserModel: \$e');
    }
    return null;
  }
}
