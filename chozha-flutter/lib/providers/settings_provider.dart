// lib/providers/settings_provider.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/constants.dart';

/// Exposes the current backend URL as a live stream from Firestore,
/// falling back to SharedPreferences cache, then kFallbackUrl.
final backendUrlProvider = StreamProvider<String>((ref) {
  return FirebaseFirestore.instance
      .collection(kFirestoreCollection)
      .doc(kFirestoreDoc)
      .snapshots()
      .asyncMap((snap) async {
    final url = snap.data()?[kFirestoreField] as String?;
    final prefs = await SharedPreferences.getInstance();
    if (url != null && url.isNotEmpty) {
      await prefs.setString(kPrefUrl, url);
      return url;
    }
    return prefs.getString(kPrefUrl) ?? kFallbackUrl;
  });
});

/// One-shot read used by ApiService instantiation.
Future<String> resolveBackendUrl() async {
  final prefs = await SharedPreferences.getInstance();
  try {
    final snap = await FirebaseFirestore.instance
        .collection(kFirestoreCollection)
        .doc(kFirestoreDoc)
        .get();
    final url = snap.data()?[kFirestoreField] as String?;
    if (url != null && url.isNotEmpty) {
      await prefs.setString(kPrefUrl, url);
      return url;
    }
  } catch (_) {}
  return prefs.getString(kPrefUrl) ?? kFallbackUrl;
}

/// Writes new URL to Firestore + local cache.
Future<void> saveBackendUrl(String url) async {
  await FirebaseFirestore.instance
      .collection(kFirestoreCollection)
      .doc(kFirestoreDoc)
      .set({kFirestoreField: url});
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(kPrefUrl, url);
}
