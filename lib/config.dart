// config.dart
//
// The only file you need to edit before running the app.

class AppConfig {
  /// Your Render service URL (no trailing slash), e.g.
  /// 'https://face-verification-abcd.onrender.com'
  /// For testing against your own PC instead, use your PC's local IP,
  /// e.g. 'http://192.168.1.23:5000' (phone and PC on the same Wi-Fi).
  static const String baseUrl = 'https://YOUR-SERVICE-NAME.onrender.com';

  /// Must match the API_KEY environment variable on Render.
  /// Leave as '' if you did not set an API_KEY.
  static const String apiKey = '';

  /// How many reference photos the register screen asks for.
  static const int referencePhotoCount = 5;

  /// Minimum time between two live checks (milliseconds).
  static const int frameIntervalMs = 300;

  /// Number of recent live scores averaged so the verdict doesn't flicker.
  static const int smoothingFrames = 5;
}
