import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

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
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBS3AshMPQP57xW89hqg4dX1RsorS9y1VY',
    appId: '1:1054904189680:android:d643124cc2291f086bb835',
    messagingSenderId: '1054904189680',
    projectId: 'studentportal-fb0c8',
    storageBucket: 'studentportal-fb0c8.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBS3AshMPQP57xW89hqg4dX1RsorS9y1VY',
    appId: '1:1054904189680:ios:d643124cc2291f086bb835',
    messagingSenderId: '1054904189680',
    projectId: 'studentportal-fb0c8',
    storageBucket: 'studentportal-fb0c8.firebasestorage.app',
    iosBundleId: 'com.studentportal.studentPortal',
  );
}
