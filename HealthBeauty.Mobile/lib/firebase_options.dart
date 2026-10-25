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
        return android;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBUK4krPi7NTfTQcjoGVgH3aXwVnXp0A-g',
    appId: '1:748230119172:web:5a51936b156901e19d0a51',
    messagingSenderId: '748230119172',
    projectId: 'healthbeautyapp-2d30f',
    authDomain: 'healthbeautyapp-2d30f.firebaseapp.com',
    storageBucket: 'healthbeautyapp-2d30f.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAmw3dFMdYXZVBpiqwCHBYZl9uPW1nor2c',
    appId: '1:748230119172:android:5a51936b156901e19d0a51',
    messagingSenderId: '748230119172',
    projectId: 'healthbeautyapp-2d30f',
    storageBucket: 'healthbeautyapp-2d30f.firebasestorage.app',
  );
}
