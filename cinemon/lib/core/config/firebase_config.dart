import 'package:firebase_core/firebase_core.dart';
import '../../firebase_options.dart';

/// Firebase configuration and initialization
class FirebaseConfig {
  /// Initialize Firebase with default options for current platform
  static Future<void> initialize() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
}
