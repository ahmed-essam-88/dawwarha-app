/// Firebase web client configuration supplied by the app owner (project wasteapp-d683c).
/// This is a client identifier, not an admin credential: access is controlled by the
/// project's Authentication settings and security rules, not by keeping this value hidden.
class FirebaseConfig {
  static const apiKey = String.fromEnvironment('FIREBASE_API_KEY', defaultValue: '');
  static const projectId = 'wasteapp-d683c';
  static const identityHost = 'https://identitytoolkit.googleapis.com';
  static const tokenHost = 'https://securetoken.googleapis.com';
}
