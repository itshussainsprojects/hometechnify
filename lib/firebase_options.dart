// Firebase project: hometechnify (444217288447)
//
// NOTE: main.dart calls `Firebase.initializeApp()` with no options, so on
// Android these values are not used — the config comes from
// android/app/google-services.json via the Gradle plugin. This file exists for
// the web build and must be kept in sync with that project.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'No Firebase config for $defaultTargetPlatform. Register the app in '
          'the hometechnify console and add it here.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDqs-JjGwwuAJ49hZkhCwQGsOFbgALw9Kw',
    appId: '1:444217288447:android:6cd67b106211be1b230eca',
    messagingSenderId: '444217288447',
    projectId: 'hometechnify',
    storageBucket: 'hometechnify.firebasestorage.app',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDqs-JjGwwuAJ49hZkhCwQGsOFbgALw9Kw',
    appId: '1:444217288447:web:9066d692f2b70790230eca',
    messagingSenderId: '444217288447',
    projectId: 'hometechnify',
    authDomain: 'hometechnify.firebaseapp.com',
    storageBucket: 'hometechnify.firebasestorage.app',
  );
}
