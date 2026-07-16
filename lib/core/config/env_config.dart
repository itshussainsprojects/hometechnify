import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvConfig {
  static String get baseUrl => dotenv.env['BASE_URL'] ?? 'http://localhost:3000';
  static String get apiUrl => '$baseUrl/api';
  static String get environment => dotenv.env['ENVIRONMENT'] ?? 'development';
  static bool get isProduction => environment == 'production';

  static Future<void> load() async {
    await dotenv.load(fileName: ".env");
  }

  // Clerk Authentication
  static String get clerkPublishableKey => dotenv.env['CLERK_PUBLISHABLE_KEY'] ?? '';
}
