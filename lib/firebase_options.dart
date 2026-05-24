import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBlInABys6mncENzl84EpVU_dyPhQ4Dnhw',
    appId: '1:247996984139:web:1b39e630ebf34660ae56ce',
    messagingSenderId: '247996984139',
    projectId: 'okr-app-e5b16',
    authDomain: 'okr-app-e5b16.firebaseapp.com',
    storageBucket: 'okr-app-e5b16.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAGHj08ebb8w262ysV-dl69pYoHbkuwVL4',
    appId: '1:247996984139:android:7a09538674f61b25ae56ce',
    messagingSenderId: '247996984139',
    projectId: 'okr-app-e5b16',
    storageBucket: 'okr-app-e5b16.firebasestorage.app',
  );
}
