// App-wide constants
class AppConstants {
  // App Info
  static const String appName = 'Udaan Edu ERP';
  static const String appVersion = '1.0.0';
  static const String brandName = 'Udaan Academy';
  static const String developedBy = 'Developed by Udaan Academy';
  
  // API Configuration
  static const String apiBaseUrl = 'https://api.udaancampus.com';
  static const int apiTimeoutSeconds = 30;
  
  // Local Storage Keys
  static const String userTokenKey = 'user_token';
  static const String userDataKey = 'user_data';
  static const String isLoggedInKey = 'is_logged_in';
  
  // Message Constants
  static const String loadingMessage = 'Loading...';
  static const String errorMessage = 'Something went wrong!';
  static const String networkErrorMessage = 'Please check your internet connection';
  static const String loginSuccessMessage = 'Login successful!';
  static const String logoutSuccessMessage = 'Logged out successfully';
  
  // Theme Constants
  static const double defaultPadding = 16.0;
  static const double defaultRadius = 12.0;
}
