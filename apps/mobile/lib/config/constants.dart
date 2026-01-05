import 'dart:io';

class AppConstants {
  static const bool isProduction = true;

  static String get baseUrl {
    if (isProduction) {
      return 'https://basalt-prod.up.railway.app/api';
    }
    
    // Use localhost for iOS, 10.0.2.2 for Android Emulator
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:3000/api';
    }
    return 'http://localhost:3000/api';
  }
}
