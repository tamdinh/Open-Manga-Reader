import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Keeps a `users/{uid}` profile document in Firestore in sync with the
/// signed-in Firebase user. Failures are logged and never block sign-in.
class UserProfileService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static String _providerOf(User user) {
    final ids = user.providerData.map((p) => p.providerId).toList();
    if (ids.contains('google.com')) return 'google.com';
    if (ids.contains('password')) return 'password';
    return 'other';
  }

  Future<void> syncProfile(User user) async {
    try {
      final ref = _db.collection('users').doc(user.uid);
      final snap = await ref.get();

      final data = <String, dynamic>{
        'email': user.email ?? '',
        'provider': _providerOf(user),
        'lastLoginAt': FieldValue.serverTimestamp(),
        if (user.displayName != null && user.displayName!.isNotEmpty)
          'displayName': user.displayName,
        if (user.photoURL != null && user.photoURL!.startsWith('http'))
          'photoURL': user.photoURL,
      };

      if (snap.exists) {
        // Preserve createdAt (immutable per security rules).
        await ref.update(data);
      } else {
        await ref.set({...data, 'createdAt': FieldValue.serverTimestamp()});
      }
    } catch (e) {
      debugPrint('UserProfileService.syncProfile error: $e');
    }
  }
}
