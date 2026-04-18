import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http_parser/http_parser.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/profile.dart';
import '../models/post.dart';
import '../utils/route_names.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String baseUrl = 'http://192.168.1.5:8000/api';

  // Secure storage for JWT tokens
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  // Storage keys
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userProfileKey = 'user_profile';

  // In-memory cache
  static String? _accessToken;
  static String? _refreshToken;
  static Profile? _currentUser;
  static int? _activeSessionId;
  static WebSocketChannel? _notificationChannel;
  static StreamSubscription? _notificationSub;
  static Timer? _notificationReconnectTimer;
  static void Function(Map<String, dynamic> notification)?
  _notificationCallback;
  static bool _notificationReconnectEnabled = false;
  static StreamSubscription<String>? _fcmTokenRefreshSub;
  static StreamSubscription<RemoteMessage>? _messageOpenedSub;
  static StreamSubscription<RemoteMessage>? _foregroundMessageSub;
  static bool _initialPushMessageHandled = false;
  static bool _localNotificationsInitialized = false;
  static bool _localNotificationsAvailable = true;
  static String? _registeredFcmToken;
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static final ValueNotifier<int> unreadNotifications = ValueNotifier<int>(0);
  static final ValueNotifier<int> messageNotificationTick = ValueNotifier<int>(
    0,
  );
  static final ValueNotifier<int> conversationReadTick = ValueNotifier<int>(0);
  static final ValueNotifier<bool> dailyUsageLocked = ValueNotifier<bool>(
    false,
  );
  static final ValueNotifier<int> remainingDailyUsageSeconds =
      ValueNotifier<int>(0);
  static final ValueNotifier<int> dailyUsageLimitSeconds = ValueNotifier<int>(
    3600,
  );

  // Cache
  static const _cacheKey = 'cached_feed';
  static const _cacheTimeKey = 'cached_feed_time';
  static const _conversationCacheKey = 'cached_conversations';
  static const _conversationCacheTimeKey = 'cached_conversations_time';
  static const _staleDuration = Duration(minutes: 30);

  // Getters
  static String? get accessToken => _accessToken;
  static Profile? get currentUser => _currentUser;
  static String get currentUsername =>
      _currentUser?.user?.username ?? _currentUser?.syncedUsername ?? '';
  static bool get isLoggedIn => _accessToken != null && _currentUser != null;
  static int? get activeSessionId => _activeSessionId;

  bool _hasCompletedInterests = false;
  bool get hasCompletedInterests => _hasCompletedInterests;

  /// Loads any saved tokens/profile from secure storage and restores a session if still valid.
  static Future<void> initialize() async {
    try {
      _accessToken = await _secureStorage.read(key: _accessTokenKey);
      _refreshToken = await _secureStorage.read(key: _refreshTokenKey);

      final userProfileJson = await _secureStorage.read(key: _userProfileKey);
      if (userProfileJson != null) {
        final userMap = jsonDecode(userProfileJson);
        _currentUser = Profile.fromJson(userMap);
      }

      // If we have tokens, validate them
      if (_accessToken != null) {
        final isValid = await _validateToken();
        if (!isValid) {
          await logout();
        } else {
          await setupPushNotifications();
        }
      }
    } catch (e) {
      print('Error initializing auth service: $e');
      await logout(); // Clear any corrupted data
    }
  }

  /// Converts backend error payloads into a readable message string.
  static String _parseBackendErrorMessage(
    dynamic errorData, [
    String defaultMessage = 'An error occurred',
  ]) {
    if (errorData == null) return defaultMessage;

    List<String> errorMessages = [];

    if (errorData is Map) {
      errorData.forEach((field, messages) {
        if (messages is List) {
          for (var message in messages) {
            errorMessages.add(message.toString());
          }
        } else if (messages is String) {
          errorMessages.add(messages);
        }
      });
    } else if (errorData is String) {
      return errorData;
    } else if (errorData is List && errorData.isNotEmpty) {
      return errorData.first.toString();
    }

    return errorMessages.isNotEmpty ? errorMessages.join('\n') : defaultMessage;
  }

  /// Validates the current access token by calling the profile endpoint and refreshes if needed.
  static Future<bool> _validateToken() async {
    if (_accessToken == null) return false;

    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/user/profile/'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_accessToken',
            },
          )
          .timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Handling custom response format
        if (data['IsSuccess'] == true) {
          _currentUser = Profile.fromJson(data['Result']['data']);
          await _secureStorage.write(
            key: _userProfileKey,
            value: jsonEncode(_currentUser!.toJson()),
          );
          return true;
        }
      } else if (response.statusCode == 401) {
        // Token expired, try to refresh
        return await refreshAccessToken();
      }
      return true; //trusting locally stored session if any other issues occur
    } on TimeoutException {
      //slow network
      return true;
    } on SocketException {
      //no internet
      return true;
    } catch (e) {
      print('Error validating token: $e');
      return true;
    }
  }

  /// Normalizes various API error shapes (string/map/list) into a single user-facing message.
  static String _parseErrorMessage(
    dynamic errorData, [
    String defaultMessage = 'An error occurred',
  ]) {
    if (errorData == null) return defaultMessage;

    if (errorData is String) {
      return errorData;
    } else if (errorData is Map) {
      List<String> errorMessages = [];

      errorData.forEach((field, messages) {
        if (messages is List) {
          for (var message in messages) {
            if (message != null) {
              errorMessages.add(message.toString());
            }
          }
        } else if (messages is String) {
          errorMessages.add(messages);
        } else if (messages != null) {
          errorMessages.add(messages.toString());
        }
      });

      return errorMessages.isNotEmpty
          ? errorMessages.join('\n')
          : defaultMessage;
    } else if (errorData is List && errorData.isNotEmpty) {
      List<String> errorMessages = [];
      for (var error in errorData) {
        if (error != null) {
          errorMessages.add(error.toString());
        }
      }
      return errorMessages.isNotEmpty
          ? errorMessages.join('\n')
          : defaultMessage;
    }

    return defaultMessage;
  }

  /// Logs the user in, stores tokens securely, fetches profile, and sets up push notifications.
  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );

      final data = jsonDecode(response.body);

      // Handle success case - check both formats
      if (data['is_success'] == true || data['IsSuccess'] == true) {
        final result = data['result'] ?? data['Result'];
        final tokenData = result['data'];

        _accessToken = tokenData['access_token'];
        _refreshToken = tokenData['refresh_token'];
        _hasCompletedInterests = tokenData['has_completed_interests'] == true;

        await _secureStorage.write(key: _accessTokenKey, value: _accessToken!);
        await _secureStorage.write(
          key: _refreshTokenKey,
          value: _refreshToken!,
        );

        await _fetchUserProfile();
        await setupPushNotifications();

        return {
          'success': true,
          'message': result['message'] ?? 'Login successful',
        };
      } else {
        // Handle error case - extract from various error fields
        String errorMessage = 'Login failed.';

        // Check for ErrorMessage field (your backend format)
        if (data['ErrorMessage'] != null) {
          errorMessage = _parseBackendErrorMessage(data['ErrorMessage']);
        }
        // Check for error_message field
        else if (data['error_message'] != null) {
          errorMessage = _parseErrorMessage(
            data['error_message'],
            'Login failed.',
          );
        }
        // Check for Result field errors
        else if (data['Result'] != null && data['Result']['message'] != null) {
          errorMessage = data['Result']['message'];
        }
        // Check for result field errors (lowercase)
        else if (data['result'] != null && data['result']['message'] != null) {
          errorMessage = data['result']['message'];
        }

        return {
          'success': false,
          'message': errorMessage,
          'fieldErrors': data['ErrorMessage'] ?? data['error_message'] ?? {},
        };
      }
    } catch (e) {
      print('Login error: $e');
      return {
        'success': false,
        'message': 'Network error: Please check your connection',
      };
    }
  }

  /// Registers a new user account (optionally uploading selfie/ID images).
  Future<Map<String, dynamic>> signup({
    required String username,
    required String email,
    required DateTime birthDate,
    required String password,
    required String confirmPassword,
    File? selfieImage,
    File? idCardImage,
  }) async {
    try {
      var uri = Uri.parse('$baseUrl/register/');
      var request = http.MultipartRequest('POST', uri);

      // Add text fields
      request.fields['username'] = username;
      request.fields['email'] = email;
      request.fields['birth_date'] = birthDate.toIso8601String().split('T')[0];
      request.fields['password'] = password;
      request.fields['confirm_password'] = confirmPassword;
      request.fields['role'] = 'user';

      // Add images if provided
      if (selfieImage != null) {
        request.files.add(
          await http.MultipartFile.fromPath('selfie_image', selfieImage.path),
        );
      }
      if (idCardImage != null) {
        request.files.add(
          await http.MultipartFile.fromPath('idcard_image', idCardImage.path),
        );
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      print('Signup response status: ${response.statusCode}');
      print('Signup response body: ${response.body}');

      final data = jsonDecode(response.body);

      // Handle success case
      if (data['IsSuccess'] == true || data['is_success'] == true) {
        return {
          'success': true,
          'message':
              data['result']?['message'] ??
              'Account created successfully! Please login to start your adventure.',
        };
      } else {
        // Handle error case - extract from ErrorMessage field
        String errorMessage = 'Registration failed.';

        // Check for ErrorMessage field (your backend format)
        if (data['ErrorMessage'] != null) {
          errorMessage = _parseBackendErrorMessage(data['ErrorMessage']);
        }
        // Fallback to error_message field
        else if (data['error_message'] != null) {
          errorMessage = _parseErrorMessage(
            data['error_message'],
            'Registration failed.',
          );
        }
        // Check for Result field errors
        else if (data['Result'] != null && data['Result']['message'] != null) {
          errorMessage = data['Result']['message'];
        }

        return {
          'success': false,
          'message': errorMessage,
          'fieldErrors': data['ErrorMessage'] ?? data['error_message'] ?? {},
        };
      }
    } catch (e) {
      print('Signup error: $e');
      return {
        'success': false,
        'message': 'Network error: Please check your connection',
      };
    }
  }

  /// Updates the logged-in user's password.
  Future<Map<String, dynamic>> updatePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmNewPassword,
  }) async {
    try {
      final response = await authenticatedRequest(
        method: 'PUT',
        endpoint: '/update_password/',
        body: {
          'current_password': currentPassword,
          'new_password': newPassword,
          'confirm_new_password': confirmNewPassword,
        },
      );
      final body = jsonDecode(response.body);
      if (body['IsSuccess'] == true) {
        return {'success': true};
      }
      final error = body['ErrorMessage'];
      String message;
      if (error is Map) {
        message = error.values
            .map((v) => v is List ? v.join(', ') : v.toString())
            .join('\n');
      } else {
        message = error.toString();
      }
      return {'success': false, 'message': message};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Starts the forgot-password flow by requesting an OTP to be emailed.
  Future<Map<String, dynamic>> forgotPassword(String email) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/forgot-password/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );
      final body = jsonDecode(response.body);
      if (body['IsSuccess'] == true) return {'success': true};
      return {'success': false, 'message': body['ErrorMessage'].toString()};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Verifies an emailed OTP code for the forgot-password flow.
  Future<Map<String, dynamic>> verifyOtp(String email, String otp) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/verify-otp/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'otp': otp}),
      );
      final body = jsonDecode(response.body);
      if (body['IsSuccess'] == true) return {'success': true};
      return {'success': false, 'message': body['ErrorMessage'].toString()};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Resets the password using an OTP code.
  Future<Map<String, dynamic>> resetPassword(
    String email,
    String otp,
    String newPassword,
    String confirmPassword,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/reset-password/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'otp': otp,
          'new_password': newPassword,
          'confirm_password': confirmPassword,
        }),
      );
      final body = jsonDecode(response.body);
      if (body['IsSuccess'] == true) return {'success': true};
      return {'success': false, 'message': body['ErrorMessage'].toString()};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Starts (or reuses) a daily-usage session and applies server-provided screen-time limits.
  Future<bool> startSessionIfNeeded() async {
    if (!isLoggedIn) return false;
    if (_activeSessionId != null) {
      await fetchSessionLimitStatus();
      return !dailyUsageLocked.value;
    }

    try {
      final response = await authenticatedRequest(
        method: 'POST',
        endpoint: '/session/start/',
      );
      final body = jsonDecode(response.body);
      final result = body['Result'] ?? body['result'];
      _applySessionLimit(result);
      if ((body['IsSuccess'] ?? body['is_success']) == true) {
        _activeSessionId = result?['session_id'];
        return _activeSessionId != null;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Updates the active session end-time on the server and refreshes screen-time limit state.
  Future<bool> updateSessionHeartbeat() async {
    if (!isLoggedIn || _activeSessionId == null) return false;

    try {
      final response = await authenticatedRequest(
        method: 'PATCH',
        endpoint: '/session/update/$_activeSessionId/',
      );
      final body = jsonDecode(response.body);
      final result = body['Result'] ?? body['result'];
      _applySessionLimit(result);
      return (body['IsSuccess'] ?? body['is_success']) == true;
    } catch (_) {
      return false;
    }
  }

  /// Ends the active session on the server (best-effort) and clears local session state.
  Future<bool> endSessionIfNeeded() async {
    if (!isLoggedIn || _activeSessionId == null) return false;

    try {
      final response = await authenticatedRequest(
        method: 'POST',
        endpoint: '/session/end/$_activeSessionId/',
      );
      final body = jsonDecode(response.body);
      final result = body['Result'] ?? body['result'];
      _applySessionLimit(result);
      final ok = (body['IsSuccess'] ?? body['is_success']) == true;
      _activeSessionId = null;
      return ok;
    } catch (_) {
      _activeSessionId = null;
      return false;
    }
  }

  /// Fetches the current daily usage limit status without starting/ending a session.
  Future<bool> fetchSessionLimitStatus() async {
    if (!isLoggedIn) return false;

    try {
      final response = await authenticatedRequest(
        method: 'GET',
        endpoint: '/session/limit-status/',
      );
      final body = jsonDecode(response.body);
      final result = body['Result'] ?? body['result'];
      _applySessionLimit(result);
      return (body['IsSuccess'] ?? body['is_success']) == true;
    } catch (_) {
      return false;
    }
  }

  /// Safely converts dynamic values to int with an optional fallback.
  static int _asInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  /// Updates local notifiers for daily usage limits from an API response payload.
  static void _applySessionLimit(dynamic result) {
    if (result is! Map) return;

    final limit = result['session_limit'];
    if (limit is! Map) return;

    // Admins/superusers are exempt from screen-time limits.
    if (isAdmin() || isSuperUser()) {
      dailyUsageLocked.value = false;
      remainingDailyUsageSeconds.value = _asInt(
        limit['daily_limit_seconds'],
        fallback: remainingDailyUsageSeconds.value,
      );
      dailyUsageLimitSeconds.value = _asInt(
        limit['daily_limit_seconds'],
        fallback: dailyUsageLimitSeconds.value,
      );
      return;
    }

    dailyUsageLocked.value = limit['is_locked'] == true;
    remainingDailyUsageSeconds.value = _asInt(limit['remaining_seconds']);
    dailyUsageLimitSeconds.value = _asInt(
      limit['daily_limit_seconds'],
      fallback: dailyUsageLimitSeconds.value,
    );
  }

  /// Fetches and caches the current user's profile from the backend.
  Future<void> _fetchUserProfile() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/user/profile/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_accessToken',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print("RAW PROFILE DATA: $data");
        if (data['IsSuccess'] == true) {
          _currentUser = Profile.fromJson(data['Result']['data']);

          // Store user profile securely
          await _secureStorage.write(
            key: _userProfileKey,
            value: jsonEncode(_currentUser!.toJson()),
          );
        }
      }
    } catch (e) {
      print('Error fetching user profile: $e');
    }
  }

  /// Returns the cached profile if available, otherwise fetches it from the server.
  Future<Map<String, dynamic>> fetchProfile() async {
    if (_currentUser != null) {
      return {'success': true, 'data': _currentUser!.toJson()};
    }
    // fallback: fetch if not cached
    await _fetchUserProfile();
    if (_currentUser != null) {
      return {'success': true, 'data': _currentUser!.toJson()};
    }
    return {'success': false, 'message': 'Failed to load profile'};
  }

  /// Fetches another user's profile by ID.
  Future<Map<String, dynamic>> fetchUserProfile(int userId) async {
    try {
      final response = await authenticatedRequest(
        method: 'GET',
        endpoint: '/user/profile/$userId/',
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);
      if ((data['IsSuccess'] ?? false) == true) {
        return {
          'success': true,
          'profile': Profile.fromJson(data['Result']['data']),
        };
      }
      return {'success': false, 'message': 'Failed to load profile'};
    } on SocketException {
      return {'success': false, 'message': 'No internet connection.'};
    } on TimeoutException {
      return {'success': false, 'message': 'Request timed out.'};
    } catch (_) {
      return {'success': false, 'message': 'Something went wrong.'};
    }
  }

  /// Updates the current user's profile fields (username/bio/profile picture).
  Future<Map<String, dynamic>> updateProfile({
    String? username,
    String? bio,
    String? imagePath,
  }) async {
    try {
      final request = http.MultipartRequest(
        'PATCH',
        Uri.parse('$baseUrl/user/profile_update/'),
      );

      request.headers['Authorization'] = 'Bearer $_accessToken';

      if (username != null) request.fields['synced_username'] = username;
      if (bio != null) request.fields['bio'] = bio;
      if (imagePath != null) {
        request.files.add(await http.MultipartFile.fromPath('pfp', imagePath));
      }

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      final data = jsonDecode(response.body);

      if ((data['IsSuccess'] ?? false) == true) {
        _currentUser = Profile.fromJson(data['Result']['data']);
        await _secureStorage.write(
          key: _userProfileKey,
          value: jsonEncode(_currentUser!.toJson()),
        );
        return {'success': true};
      }

      return {
        'success': false,
        'message': _parseErrorMessage(
          data['ErrorMessage'],
          'Failed to update profile',
        ),
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: Please check your connection',
      };
    }
  }

  /// Refreshes the access token using the stored refresh token.
  static Future<bool> refreshAccessToken() async {
    if (_refreshToken == null) return false;

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/token/refresh/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh': _refreshToken}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['access'] != null) {
          _accessToken = data['access'];

          // Update stored access token
          await _secureStorage.write(
            key: _accessTokenKey,
            value: _accessToken!,
          );
          return true;
        }
      }
    } catch (e) {
      print('Error refreshing token: $e');
    }

    return false;
  }

  /// Logs out locally (clears tokens/cache) and best-effort blacklists refresh token server-side.
  static Future<void> logout() async {
    stopNotificationsStream();
    await unregisterCurrentDeviceToken();

    if (_activeSessionId != null && _accessToken != null) {
      try {
        await AuthService().authenticatedRequest(
          method: 'POST',
          endpoint: '/session/end/$_activeSessionId/',
        );
      } catch (_) {}
      _activeSessionId = null;
    }

    //logout endpoint to blacklist tokens
    try {
      if (_refreshToken != null) {
        await http
            .post(
              Uri.parse('$baseUrl/logout/'),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $_accessToken',
              },
              body: jsonEncode({'refresh_token': _refreshToken}),
            )
            .timeout(const Duration(seconds: 54));
      }
    } catch (e) {
      print('Error during logout API call: $e');
    }

    // Clear in-memory data
    _accessToken = null;
    _refreshToken = null;
    _currentUser = null;
    unreadNotifications.value = 0;
    dailyUsageLocked.value = false;
    remainingDailyUsageSeconds.value = 0;
    dailyUsageLimitSeconds.value = 3600;

    // Clear secure storage
    await _secureStorage.delete(key: _accessTokenKey);
    await _secureStorage.delete(key: _refreshTokenKey);
    await _secureStorage.delete(key: _userProfileKey);
    await clearFeedCache();
    await clearConversationCache();
  }

  /// Returns a short platform label used when registering device tokens.
  static String _platformLabel() {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return 'unknown';
  }

  /// Requests notification permissions, registers the FCM token, and wires notification listeners.
  static Future<void> setupPushNotifications() async {
    if (_accessToken == null) return;

    try {
      final messaging = FirebaseMessaging.instance;

      await _initializeLocalNotifications();

      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      final token = await messaging.getToken();
      if (token != null && token.isNotEmpty) {
        await registerDeviceToken(token);
      }

      _fcmTokenRefreshSub ??= FirebaseMessaging.instance.onTokenRefresh.listen((
        newToken,
      ) {
        if (newToken.isNotEmpty) {
          registerDeviceToken(newToken);
        }
      });

      _messageOpenedSub ??= FirebaseMessaging.onMessageOpenedApp.listen((
        message,
      ) {
        _handleOpenedPushMessage(message);
      });

      _foregroundMessageSub ??= FirebaseMessaging.onMessage.listen((message) {
        _showForegroundNotification(message);
      });

      if (!_initialPushMessageHandled) {
        _initialPushMessageHandled = true;
        final initialMessage = await messaging.getInitialMessage();
        if (initialMessage != null) {
          _handleOpenedPushMessage(initialMessage);
        }
      }
    } catch (e) {
      print('Push setup skipped: $e');
    }
  }

  /// Handles a push notification tap by routing to the correct in-app destination.
  static Future<void> _handleOpenedPushMessage(RemoteMessage message) async {
    final type = (message.data['notification_type'] ?? '').toString();
    await openNotificationTarget(
      notificationType: type,
      notificationData: message.data,
    );
  }

  /// Initializes local notifications (Android channel + click handler) for foreground messages.
  static Future<void> _initializeLocalNotifications() async {
    if (_localNotificationsInitialized || !_localNotificationsAvailable) return;

    try {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const settings = InitializationSettings(android: android);

      await _localNotifications.initialize(
        settings,
        onDidReceiveNotificationResponse: (response) {
          if (response.payload == null || response.payload!.isEmpty) {
            openNotificationTarget(notificationType: '');
            return;
          }

          try {
            final payload =
                jsonDecode(response.payload!) as Map<String, dynamic>;
            final type = (payload['notification_type'] ?? '').toString();
            openNotificationTarget(
              notificationType: type,
              notificationData: payload,
            );
          } catch (_) {
            openNotificationTarget(notificationType: '');
          }
        },
      );

      const androidChannel = AndroidNotificationChannel(
        'ousia_high_importance',
        'Ousia Notifications',
        description: 'Used for likes, friend requests, and messages.',
        importance: Importance.high,
      );
      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(androidChannel);

      _localNotificationsInitialized = true;
    } catch (e) {
      _localNotificationsAvailable = false;
      print('Local notifications unavailable: $e');
    }
  }

  /// Displays a local notification when an FCM message arrives while the app is foregrounded.
  static Future<void> _showForegroundNotification(RemoteMessage message) async {
    if (!_localNotificationsInitialized || !_localNotificationsAvailable)
      return;

    final title = (message.notification?.title ?? 'New notification').trim();
    final body = (message.notification?.body ?? '').trim();
    final payload = jsonEncode(message.data);

    try {
      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body.isEmpty ? null : body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'ousia_high_importance',
            'Ousia Notifications',
            channelDescription:
                'Used for likes, friend requests, and messages.',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        payload: payload,
      );
    } catch (e) {
      print('Foreground notification display failed: $e');
    }
  }

  /// Navigates to the screen implied by a notification type/payload (friend requests, chat, etc.).
  static Future<void> openNotificationTarget({
    required String notificationType,
    Map<String, dynamic>? notificationData,
  }) async {
    if (!isLoggedIn) return;

    final nav = navigatorKey.currentState;
    if (nav == null) return;

    final data = Map<String, dynamic>.from(
      notificationData ?? const <String, dynamic>{},
    );
    final type = notificationType.trim().toLowerCase();

    if (type == 'friend_request') {
      await nav.pushNamed(RouteNames.friendRequests);
      return;
    }

    if (type == 'message') {
      final conversationId = (data['conversation_id'] ?? '').toString();
      if (conversationId.isEmpty) {
        await nav.pushNamed(RouteNames.notifications);
        return;
      }

      await AuthService().markConversationRead(conversationId);

      final chatArgs = await _buildChatRouteArgs(conversationId);
      await nav.pushNamed(RouteNames.chat, arguments: chatArgs);
      return;
    }

    await nav.pushNamed(RouteNames.notifications);
  }

  /// Marks a conversation as read on the server and updates local cached unread counts.
  Future<bool> markConversationRead(String conversationId) async {
    if (conversationId.isEmpty) return false;

    bool serverOk = false;
    try {
      final response = await authenticatedRequest(
        method: 'POST',
        endpoint: '/conversation-mark-read/$conversationId/',
      );
      final body = jsonDecode(response.body);
      serverOk = (body['IsSuccess'] ?? false) == true;
    } catch (_) {
      serverOk = false;
    }

    await _markConversationReadLocally(conversationId);
    return serverOk;
  }

  /// Builds route arguments for the chat screen from cached/loaded conversation details.
  static Future<Map<String, dynamic>> _buildChatRouteArgs(
    String conversationId,
  ) async {
    final result = await AuthService().fetchConversations();
    if (result['success'] == true) {
      final conversations = List<Map<String, dynamic>>.from(
        result['conversations'] ?? [],
      );
      final match = conversations.cast<Map<String, dynamic>?>().firstWhere(
        (c) => c != null && c['id'].toString() == conversationId,
        orElse: () => null,
      );

      if (match != null) {
        final isGroup = match['is_group'] == true;
        if (isGroup) {
          return {
            'conversation_id': conversationId,
            'name': (match['group_name'] ?? 'Group').toString(),
            'pfp_url': null,
            'is_group': true,
          };
        }

        final current = currentUsername;
        final participants = (match['participants'] as List?) ?? [];
        Map<String, dynamic>? otherParticipant;
        for (final participant in participants) {
          if (participant is! Map) continue;
          final participantMap = Map<String, dynamic>.from(participant as Map);
          if ((participantMap['username'] ?? '').toString() != current) {
            otherParticipant = participantMap;
            break;
          }
        }
        if (otherParticipant == null && participants.isNotEmpty) {
          otherParticipant = Map<String, dynamic>.from(
            participants.first as Map,
          );
        }

        final pfpInfo = (match['pfp_info'] as List?) ?? [];
        final other = pfpInfo.firstWhere(
          (p) => p is Map<String, dynamic> && p['username'] != current,
          orElse:
              () => pfpInfo.isNotEmpty ? pfpInfo.first : <String, dynamic>{},
        );

        final otherMap = Map<String, dynamic>.from(other as Map);
        return {
          'conversation_id': conversationId,
          'name': (otherMap['username'] ?? 'Conversation').toString(),
          'pfp_url': otherMap['pfp_url'],
          'is_group': false,
          'other_user_id': otherParticipant?['id'],
        };
      }
    }

    return {
      'conversation_id': conversationId,
      'name': 'Conversation',
      'pfp_url': null,
      'is_group': false,
      'other_user_id': null,
    };
  }

  /// Updates the local conversations cache to set unread_count=0 for a conversation.
  static Future<void> _markConversationReadLocally(
    String conversationId,
  ) async {
    if (conversationId.isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_conversationCacheKey);
      if (raw == null) {
        conversationReadTick.value = conversationReadTick.value + 1;
        return;
      }

      final payload = jsonDecode(raw) as Map<String, dynamic>;
      final conversations =
          (payload['conversations'] as List?)
              ?.map((c) => Map<String, dynamic>.from(c as Map))
              .toList() ??
          <Map<String, dynamic>>[];

      bool changed = false;
      for (final convo in conversations) {
        if (convo['id'].toString() == conversationId &&
            (convo['unread_count'] ?? 0) != 0) {
          convo['unread_count'] = 0;
          changed = true;
          break;
        }
      }

      if (changed) {
        payload['conversations'] = conversations;
        await prefs.setString(_conversationCacheKey, jsonEncode(payload));
      }
    } catch (_) {
      // Best-effort local UX update only.
    }

    conversationReadTick.value = conversationReadTick.value + 1;
  }

  /// Registers the current device's FCM token with the backend.
  static Future<void> registerDeviceToken(String token) async {
    if (_accessToken == null || token.isEmpty) return;
    if (_registeredFcmToken == token) return;

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/device-token/register/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_accessToken',
        },
        body: jsonEncode({'token': token, 'platform': _platformLabel()}),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        _registeredFcmToken = token;
      }
    } catch (_) {}
  }

  /// Unregisters the device token from the backend and tears down push listeners locally.
  static Future<void> unregisterCurrentDeviceToken() async {
    if (_accessToken == null) {
      _fcmTokenRefreshSub?.cancel();
      _fcmTokenRefreshSub = null;
      _registeredFcmToken = null;
      return;
    }

    try {
      final token =
          _registeredFcmToken ?? await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        await http.post(
          Uri.parse('$baseUrl/device-token/unregister/'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_accessToken',
          },
          body: jsonEncode({'token': token}),
        );
      }
    } catch (_) {
    } finally {
      _fcmTokenRefreshSub?.cancel();
      _fcmTokenRefreshSub = null;
      _messageOpenedSub?.cancel();
      _messageOpenedSub = null;
      _foregroundMessageSub?.cancel();
      _foregroundMessageSub = null;
      _registeredFcmToken = null;
      _initialPushMessageHandled = false;
    }
  }

  /// Fetches the list of available interests/hashtags from the backend.
  Future<Map<String, dynamic>> fetchInterests() async {
    try {
      final response = await authenticatedRequest(
        method: 'GET',
        endpoint: '/interests/',
      );

      final data = jsonDecode(response.body);

      if ((data['IsSuccess'] ?? data['is_success']) == true) {
        final result = data['Result'] ?? data['result'];
        final List interests = result['data'] ?? [];

        return {'success': true, 'interests': interests};
      } else {
        final error = data['ErrorMessage'] ?? data['error_message'];
        return {
          'success': false,
          'message': _parseBackendErrorMessage(
            error,
            'Failed to load interests.',
          ),
        };
      }
    } catch (e) {
      print('fetchInterests error: $e');
      return {
        'success': false,
        'message': 'Network error: Please check your connection',
      };
    }
  }

  /// Saves a selected interest for the current user.
  Future<Map<String, dynamic>> saveUserInterests(int interestId) async {
    try {
      final response = await authenticatedRequest(
        method: 'POST',
        endpoint: '/user-interests/',
        body: {'users_interest': interestId},
      );

      final data = jsonDecode(response.body);

      if ((data['IsSuccess'] ?? data['is_success']) == true) {
        final result = data['Result'] ?? data['result'];

        return {
          'success': true,
          'message': result?['message'] ?? 'Interests saved successfully.',
          // 'interests': result?['data']?['results'] ?? [],
        };
      } else {
        final error = data['ErrorMessage'] ?? data['error_message'];
        return {
          'success': false,
          'message': _parseBackendErrorMessage(
            error,
            'Failed to save interests.',
          ),
        };
      }
    } catch (e) {
      print('saveUserInterests error: $e');
      return {
        'success': false,
        'message': 'Network error: Please check your connection',
      };
    }
  }

  /// Loads posts (feed or profile) with network-first behavior and cache fallback for the feed.
  Future<Map<String, dynamic>> fetchPosts({
    String? nextUrl,
    String? username,
  }) async {
    // Pagination pages are never cached
    if (nextUrl != null) {
      return _fetchPostsFromNetwork(nextUrl: nextUrl);
    }

    if (username != null) {
      return _fetchPostsFromNetwork(username: username);
    }

    // Try network first
    try {
      final result = await _fetchPostsFromNetwork();
      if (result['success'] == true) {
        await _writeFeedCache(result['posts'] as List<Post>, result['next']);
        return result;
      }
    } on SocketException {
      // No internet — fall through to cache
    } on TimeoutException {
      // Timeout — fall through to cache
    } catch (_) {
      // Any other error — fall through to cache
    }

    return _readFeedCache();
  }

  /// Fetches posts from the API (supports pagination and profile filtering).
  Future<Map<String, dynamic>> _fetchPostsFromNetwork({
    String? nextUrl,
    String? username,
  }) async {
    String endpoint;
    if (nextUrl != null) {
      final uri = Uri.parse(nextUrl);
      endpoint = '/post/?${uri.query}';
    } else if (username != null) {
      endpoint = '/post/?posted_by=$username';
    } else {
      endpoint = '/post/';
    }

    final response = await authenticatedRequest(
      method: 'GET',
      endpoint: endpoint,
    ).timeout(const Duration(seconds: 10));

    final data = jsonDecode(response.body);
    return _parsePosts(data);
  }

  /// Parses the backend post list response into Post models + pagination info.
  static Map<String, dynamic> _parsePosts(Map<String, dynamic> data) {
    if ((data['IsSuccess'] ?? false) == true) {
      final result = data['Result'];
      final pagination = result['data'];
      final List rawPosts = pagination['results'] ?? [];
      return {
        'success': true,
        'posts': rawPosts.map((p) => Post.fromJson(p)).toList(),
        'next': pagination['next'],
        'fromCache': false,
      };
    }
    final error = data['ErrorMessage'];
    return {
      'success': false,
      'message': error is List ? error.join(', ') : error.toString(),
    };
  }

  /// Writes the current feed page and next link into SharedPreferences.
  Future<void> _writeFeedCache(List<Post> posts, String? next) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = jsonEncode({
        'posts': posts.map((p) => p.toJson()).toList(),
        'next': next,
      });
      await prefs.setString(_cacheKey, payload);
      await prefs.setInt(_cacheTimeKey, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }

  /// Reads cached feed data from SharedPreferences (includes stale indicator).
  Future<Map<String, dynamic>> _readFeedCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null) {
        return {'success': false, 'message': 'No internet connection.'};
      }

      final savedAt = prefs.getInt(_cacheTimeKey) ?? 0;
      final age = DateTime.now().millisecondsSinceEpoch - savedAt;
      final isStale = age > _staleDuration.inMilliseconds;

      final payload = jsonDecode(raw) as Map<String, dynamic>;
      final posts =
          (payload['posts'] as List)
              .map((p) => Post.fromJson(p as Map<String, dynamic>))
              .toList();

      return {
        'success': true,
        'posts': posts,
        'next': payload['next'],
        'fromCache': true,
        'isStale': isStale,
      };
    } catch (_) {
      return {'success': false, 'message': 'No internet connection.'};
    }
  }

  /// Updates a single post in the local feed cache (best-effort).
  Future<void> updateCachedPost(Post updated) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null) return;

      final payload = jsonDecode(raw) as Map<String, dynamic>;
      final posts =
          (payload['posts'] as List)
              .map((p) => Post.fromJson(p as Map<String, dynamic>))
              .toList();

      final idx = posts.indexWhere((p) => p.id == updated.id);
      if (idx != -1) {
        posts[idx] = updated;
        payload['posts'] = posts.map((p) => p.toJson()).toList();
        await prefs.setString(_cacheKey, jsonEncode(payload));
      }
    } catch (_) {}
  }

  /// Clears cached feed data.
  static Future<void> clearFeedCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
      await prefs.remove(_cacheTimeKey);
    } catch (_) {}
  }

  /// Deletes a post and removes it from the local feed cache on success.
  Future<Map<String, dynamic>> deletePost(int postId) async {
    try {
      final response = await authenticatedRequest(
        method: 'DELETE',
        endpoint: '/post/$postId/',
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);
      if ((data['IsSuccess'] ?? false) == true) {
        await _removeFromFeedCache(postId);
        return {'success': true};
      }

      final error = data['ErrorMessage'];
      return {
        'success': false,
        'message': error is List ? error.join(', ') : error.toString(),
      };
    } on SocketException {
      return {'success': false, 'message': 'No internet connection.'};
    } on TimeoutException {
      return {'success': false, 'message': 'Request timed out.'};
    } catch (_) {
      return {'success': false, 'message': 'Something went wrong.'};
    }
  }

  /// Removes a post from the local feed cache by ID.
  Future<void> _removeFromFeedCache(int postId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null) return;

      final payload = jsonDecode(raw) as Map<String, dynamic>;
      final posts =
          (payload['posts'] as List)
              .map((p) => Post.fromJson(p as Map<String, dynamic>))
              .where((p) => p.id != postId)
              .toList();

      payload['posts'] = posts.map((p) => p.toJson()).toList();
      await prefs.setString(_cacheKey, jsonEncode(payload));
    } catch (_) {}
  }

  /// Likes a post (or returns an existing like) and returns the like ID.
  Future<Map<String, dynamic>> likePost(int postId) async {
    try {
      final response = await authenticatedRequest(
        method: 'POST',
        endpoint: '/likes/',
        body: {'post': postId},
      );
      final data = jsonDecode(response.body);
      if ((data['IsSuccess'] ?? false) == true) {
        return {'success': true, 'like_id': data['Result']['id']};
      }

      return {
        'success': false,
        'message': data['ErrorMessage'] ?? 'Failed to like post',
      };
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Removes a like by like ID.
  Future<Map<String, dynamic>> unlikePost(int likeId) async {
    try {
      final response = await authenticatedRequest(
        method: 'DELETE',
        endpoint: '/like-delete/$likeId/',
      );
      if (response.statusCode == 204 || response.statusCode == 200) {
        return {'success': true};
      }

      final data = jsonDecode(response.body);
      return {
        'success': false,
        'message': data['ErrorMessage'] ?? 'Failed to unlike post',
      };
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Fetches all available hashtags.
  Future<List<Map<String, dynamic>>> fetchHashtags() async {
    try {
      final response = await authenticatedRequest(
        method: 'GET',
        endpoint: '/hashtag/',
      );
      final body = jsonDecode(response.body);
      if (body['IsSuccess'] == true) {
        final results = body['Result']?['data']?['results'] ?? [];
        return (results as List).cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Creates a post with optional caption, hashtags, and media uploads.
  Future<Map<String, dynamic>> createPost({
    String? caption,
    required String visibility,
    List<String>? typeOfPost,
    List<File> mediaFiles = const [],
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/post/');
      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer $_accessToken';

      if (caption != null && caption.isNotEmpty) {
        request.fields['caption'] = caption;
      }
      request.fields['visibility'] = visibility;
      if (typeOfPost != null) {
        request.fields['type_of_post'] = typeOfPost.join(',');
      }

      for (final file in mediaFiles) {
        final mimeType = _getMimeType(file.path);
        request.files.add(
          await http.MultipartFile.fromPath(
            'media', // backend field name
            file.path,
            contentType: mimeType,
          ),
        );
      }

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      final data = jsonDecode(response.body);

      if ((data['IsSuccess'] ?? false) == true) {
        final result = data['Result'] as Map<String, dynamic>?;
        return {
          'success': true,
          'message':
              result?['message']?.toString() ?? 'Post created successfully.',
          'data': result?['data'],
        };
      }
      final error = data['ErrorMessage'];
      String message;
      if (error is Map) {
        message = error.values
            .map((v) => v is List ? v.join(', ') : v.toString())
            .join('\n');
      } else if (error is List) {
        message = error.join(', ');
      } else {
        message = error.toString();
      }
      return {'success': false, 'message': message};
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Fetches a single post by ID.
  Future<Map<String, dynamic>> fetchPostById(int postId) async {
    try {
      final response = await authenticatedRequest(
        method: 'GET',
        endpoint: '/post/$postId/',
      );

      final data = jsonDecode(response.body);
      if ((data['IsSuccess'] ?? false) == true) {
        final result = data['Result'] as Map<String, dynamic>?;
        return {
          'success': true,
          'message':
              result?['message']?.toString() ?? 'Post fetched successfully.',
          'data': result?['data'],
        };
      }

      final error = data['ErrorMessage'];
      return {
        'success': false,
        'message': _parseBackendErrorMessage(error, 'Failed to fetch post.'),
      };
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Returns a best-effort MIME type for a file path.
  MediaType _getMimeType(String path) {
    final ext = path.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return MediaType('image', 'jpeg');
      case 'png':
        return MediaType('image', 'png');
      case 'gif':
        return MediaType('image', 'gif');
      case 'mp4':
        return MediaType('video', 'mp4');
      case 'mov':
        return MediaType('video', 'quicktime');
      case 'avi':
        return MediaType('video', 'avi');
      default:
        return MediaType('application', 'octet-stream');
    }
  }

  /// Sends a friend request to a user identified by username.
  Future<Map<String, dynamic>> sendFriendRequest(String toUsername) async {
    try {
      final response = await authenticatedRequest(
        method: 'POST',
        endpoint: '/friend_request/',
        body: {'to_username': toUsername},
      );
      final body = jsonDecode(response.body);
      if (body['IsSuccess'] == true) {
        return {'success': true, 'data': body['Result']['data']};
      }
      return {'success': false, 'message': body['ErrorMessage'].toString()};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Checks whether there is a pending friend request between the current user and another username.
  Future<Map<String, dynamic>> checkFriendRequestStatus(
    String toUsername,
  ) async {
    try {
      final currentUsername = AuthService.currentUsername;
      final response = await authenticatedRequest(
        method: 'GET',
        endpoint: '/friend_request/',
      );
      final body = jsonDecode(response.body);
      if (body['IsSuccess'] == true) {
        final requests = body['Result']['data']['results'] as List;
        final sentRequest = requests.firstWhere(
          (r) =>
              r['from_user'] == currentUsername &&
              r['to_user'] == toUsername &&
              r['status'] == 'pending',
          orElse: () => null,
        );
        final receivedRequest = requests.firstWhere(
          (r) =>
              r['from_user'] == toUsername &&
              r['to_user'] == currentUsername &&
              r['status'] == 'pending',
          orElse: () => null,
        );
        return {
          'success': true,
          'sent': sentRequest != null,
          'sent_request_id': sentRequest?['id'],
          'received': receivedRequest != null,
          'received_request_id': receivedRequest?['id'],
        };
      }
      return {
        'success': false,
        'sent': false,
        'received': false,
        'received_request_id': null,
      };
    } catch (e) {
      return {
        'success': false,
        'sent': false,
        'received': false,
        'received_request_id': null,
      };
    }
  }

  /// Fetches friend requests involving the current user and marks which are received.
  Future<Map<String, dynamic>> fetchFriendRequests() async {
    try {
      final currentUsername = _currentUser?.username ?? '';

      final response = await authenticatedRequest(
        method: 'GET',
        endpoint: '/friend_request/',
      );
      final body = jsonDecode(response.body);
      if (body['IsSuccess'] == true) {
        final results = body['Result']['data']['results'] as List;
        final requests =
            results
                .map(
                  (r) => {
                    ...Map<String, dynamic>.from(r),
                    'is_received': r['to_user'] == currentUsername,
                  },
                )
                .toList();
        return {'success': true, 'requests': requests};
      }
      return {'success': false, 'message': 'Failed to load requests'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Accepts or rejects a friend request by ID.
  Future<Map<String, dynamic>> respondFriendRequest(
    int id,
    String status,
  ) async {
    try {
      final response = await authenticatedRequest(
        method: 'PATCH',
        endpoint: '/friend_request_response/$id/',
        body: {'status': status},
      );
      final body = jsonDecode(response.body);
      if (body['IsSuccess'] == true) {
        return {'success': true};
      }
      return {'success': false, 'message': body['ErrorMessage'].toString()};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Deletes a friend request by ID.
  Future<Map<String, dynamic>> deleteFriendRequest(int id) async {
    try {
      final response = await authenticatedRequest(
        method: 'DELETE',
        endpoint: '/friend_request_delete/$id/',
      );
      if (response.statusCode == 204 || response.statusCode == 200) {
        return {'success': true};
      }
      final body = jsonDecode(response.body);
      return {'success': false, 'message': body['ErrorMessage'].toString()};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Returns friendship/block status between the current user and a target user ID.
  Future<Map<String, dynamic>> checkFriendship(int userId) async {
    try {
      final response = await authenticatedRequest(
        method: 'GET',
        endpoint: '/friends/?include_blocked=1',
      );
      final body = jsonDecode(response.body);
      if (body['IsSuccess'] == true) {
        final results = body['Result']['data']['results'] as List;

        // Find friendship with this user (supports both legacy and current shapes)
        final friendship = results.firstWhere((r) {
          final friend = r['friend'];
          if (friend is Map<String, dynamic>) {
            return friend['id'] == userId;
          }
          return r['user1'] == userId || r['user2'] == userId;
        }, orElse: () => null);

        bool isFriend = friendship != null;
        bool isBlocked = false;
        bool isBlockedByMe = false;
        bool isBlockedMe = false;

        if (isFriend) {
          // blocked_by stores whichever side initiated the block.
          final blockedById = friendship['blocked_by'];
          isBlockedMe = blockedById != null && blockedById == userId;
          isBlockedByMe = blockedById != null && blockedById != userId;
          isBlocked = isBlockedMe || isBlockedByMe;
        }

        return {
          'success': true,
          'is_friend': isFriend,
          'is_blocked': isBlocked,
          'is_blocked_by_me': isBlockedByMe,
          'is_blocked_me': isBlockedMe,
        };
      }
      return {
        'success': false,
        'is_friend': false,
        'is_blocked': false,
        'is_blocked_by_me': false,
        'is_blocked_me': false,
      };
    } catch (e) {
      return {
        'success': false,
        'is_friend': false,
        'is_blocked': false,
        'is_blocked_by_me': false,
        'is_blocked_me': false,
      };
    }
  }

  /// Fetches a paginated friends list (optionally for another user).
  Future<Map<String, dynamic>> fetchFriends({
    int? userId,
    String? nextUrl,
  }) async {
    try {
      final endpoint =
          nextUrl != null
              ? '/friends/?${Uri.parse(nextUrl).query}'
              : userId != null
              ? '/friends/?user_id=$userId'
              : '/friends/';

      final response = await authenticatedRequest(
        method: 'GET',
        endpoint: endpoint,
      );
      final body = jsonDecode(response.body);
      if (body['IsSuccess'] == true) {
        final data = body['Result']['data'] as Map<String, dynamic>;
        final results =
            (data['results'] as List)
                .map((r) => Map<String, dynamic>.from(r as Map))
                .toList();
        final totalFriends =
            body['Result']['total_friends'] ?? data['count'] ?? results.length;

        return {
          'success': true,
          'friends': results,
          'total_friends': totalFriends,
          'next': data['next'],
        };
      }
      return {'success': false, 'friends': <Map<String, dynamic>>[]};
    } catch (e) {
      return {'success': false, 'friends': <Map<String, dynamic>>[]};
    }
  }

  /// Fetches all friends across pages and returns a combined list.
  Future<Map<String, dynamic>> fetchAllFriends({int? userId}) async {
    try {
      final allFriends = <Map<String, dynamic>>[];
      String? nextUrl;
      int totalFriends = 0;
      bool firstCall = true;

      do {
        final result = await fetchFriends(userId: userId, nextUrl: nextUrl);
        if (result['success'] != true) {
          return {'success': false, 'friends': <Map<String, dynamic>>[]};
        }

        final pageFriends =
            (result['friends'] as List).cast<Map<String, dynamic>>();
        allFriends.addAll(pageFriends);
        totalFriends = result['total_friends'] ?? allFriends.length;
        nextUrl = result['next'] as String?;
        firstCall = false;
      } while (nextUrl != null && firstCall == false);

      return {
        'success': true,
        'friends': allFriends,
        'total_friends': totalFriends,
      };
    } catch (e) {
      return {'success': false, 'friends': <Map<String, dynamic>>[]};
    }
  }

  /// Unfriends a user by ID.
  Future<Map<String, dynamic>> unfriendUser(int userId) async {
    try {
      final response = await authenticatedRequest(
        method: 'POST',
        endpoint: '/friends/unfriend/$userId/',
      );
      final body = jsonDecode(response.body);
      if (body['IsSuccess'] == true) {
        return {'success': true, 'message': body['Result']['message']};
      }
      return {'success': false, 'message': body['ErrorMessage'].toString()};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Blocks a user by ID (requires an existing friendship in this backend).
  Future<Map<String, dynamic>> blockUser(int userId) async {
    try {
      final response = await authenticatedRequest(
        method: 'POST',
        endpoint: '/friends/block/$userId/',
      );
      final body = jsonDecode(response.body);
      if (body['IsSuccess'] == true) {
        return {'success': true, 'message': body['Result']['message']};
      }
      return {'success': false, 'message': body['ErrorMessage'].toString()};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Deletes the current user's account and logs out locally on success.
  Future<Map<String, dynamic>> deleteAccount() async {
    try {
      final response = await authenticatedRequest(
        method: 'DELETE',
        endpoint: '/user/delete-account/',
      );
      final body = jsonDecode(response.body);
      if (body['IsSuccess'] == true) {
        await logout();
        return {'success': true};
      }
      return {'success': false, 'message': body['ErrorMessage'].toString()};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Searches users by query text (optionally limited to friends).
  Future<Map<String, dynamic>> searchUsers(
    String query, {
    String? nextUrl,
    bool friendsOnly = false,
  }) async {
    try {
      final friendsOnlyQuery = friendsOnly ? '&friends_only=true' : '';
      final endpoint =
          nextUrl != null
              ? '/user/search/?${Uri.parse(nextUrl).query}'
              : '/user/search/?q=${Uri.encodeComponent(query)}$friendsOnlyQuery';
      final response = await authenticatedRequest(
        method: 'GET',
        endpoint: endpoint,
      );
      final body = jsonDecode(response.body);
      if (body['IsSuccess'] == true) {
        final results = body['Result']['data'] as List;
        return {'success': true, 'users': results, 'next': null};
      }
      return {'success': false, 'users': []};
    } catch (e) {
      return {'success': false, 'users': []};
    }
  }

  /// Fetches the conversation list with network-first and cache fallback behavior.
  Future<Map<String, dynamic>> fetchConversations() async {
    try {
      final result = await _fetchConversationsFromNetwork();
      if (result['success'] == true) {
        await _writeConversationCache(
          List<Map<String, dynamic>>.from(result['conversations'] ?? const []),
        );
        return result;
      }
    } on SocketException {
      // No internet, fallback to cache.
    } on TimeoutException {
      // Network timeout, fallback to cache.
    } catch (_) {
      // Fallback to cache for any other issue.
    }

    return _readConversationCache();
  }

  /// Fetches the conversation list from the backend.
  Future<Map<String, dynamic>> _fetchConversationsFromNetwork() async {
    try {
      final response = await authenticatedRequest(
        method: 'GET',
        endpoint: '/conversation-list/',
      ).timeout(const Duration(seconds: 10));
      final body = jsonDecode(response.body);
      if (body['IsSuccess'] == true) {
        final results = body['Result']['data']['results'] as List;
        return {'success': true, 'conversations': results};
      }
      return {'success': false, 'message': 'Failed to load conversations'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Writes conversation list data into SharedPreferences.
  Future<void> _writeConversationCache(
    List<Map<String, dynamic>> conversations,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = jsonEncode({'conversations': conversations});
      await prefs.setString(_conversationCacheKey, payload);
      await prefs.setInt(
        _conversationCacheTimeKey,
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {}
  }

  /// Reads the cached conversation list from SharedPreferences (includes stale indicator).
  Future<Map<String, dynamic>> _readConversationCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_conversationCacheKey);
      if (raw == null) {
        return {'success': false, 'message': 'No internet connection.'};
      }

      final savedAt = prefs.getInt(_conversationCacheTimeKey) ?? 0;
      final age = DateTime.now().millisecondsSinceEpoch - savedAt;
      final isStale = age > _staleDuration.inMilliseconds;

      final payload = jsonDecode(raw) as Map<String, dynamic>;
      final conversations =
          (payload['conversations'] as List)
              .map((c) => Map<String, dynamic>.from(c as Map))
              .toList();

      return {
        'success': true,
        'conversations': conversations,
        'fromCache': true,
        'isStale': isStale,
      };
    } catch (_) {
      return {'success': false, 'message': 'No internet connection.'};
    }
  }

  /// Clears cached conversations.
  static Future<void> clearConversationCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_conversationCacheKey);
      await prefs.remove(_conversationCacheTimeKey);
    } catch (_) {}
  }

  /// Fetches notifications and updates the local unread count when loading the first page.
  Future<Map<String, dynamic>> fetchNotifications({String? nextUrl}) async {
    try {
      final endpoint =
          nextUrl != null
              ? '/notifications/?${Uri.parse(nextUrl).query}'
              : '/notifications/';

      final response = await authenticatedRequest(
        method: 'GET',
        endpoint: endpoint,
      );
      final body = jsonDecode(response.body);

      if ((body['IsSuccess'] ?? body['is_success']) == true) {
        final result = body['Result'] ?? body['result'];
        final data = result?['data'];

        if (data is Map) {
          final items = (data['results'] as List?) ?? [];
          final unread = items.where((n) => n['is_read'] != true).length;
          if (nextUrl == null) {
            unreadNotifications.value = unread;
          }
          return {
            'success': true,
            'items': List<Map<String, dynamic>>.from(items),
            'next': data['next'],
          };
        }

        final items = (data as List?) ?? [];
        unreadNotifications.value =
            items.where((n) => n['is_read'] != true).length;
        return {
          'success': true,
          'items': List<Map<String, dynamic>>.from(items),
          'next': null,
        };
      }

      return {'success': false, 'message': 'Failed to load notifications'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Convenience wrapper to fetch the next notification page.
  Future<Map<String, dynamic>> fetchNextNotifications(String nextUrl) async {
    return fetchNotifications(nextUrl: nextUrl);
  }

  /// Marks a single notification as read and decrements unread count locally.
  Future<bool> markNotificationRead(int notificationId) async {
    try {
      final response = await authenticatedRequest(
        method: 'PATCH',
        endpoint: '/notifications/read/$notificationId/',
      );
      final body = jsonDecode(response.body);
      final ok = (body['IsSuccess'] ?? body['is_success']) == true;
      if (ok && unreadNotifications.value > 0) {
        unreadNotifications.value = unreadNotifications.value - 1;
      }
      return ok;
    } catch (_) {
      return false;
    }
  }

  /// Marks all notifications as read and resets unread count locally.
  Future<bool> markAllNotificationsRead() async {
    try {
      final response = await authenticatedRequest(
        method: 'POST',
        endpoint: '/notifications/read-all/',
      );
      final body = jsonDecode(response.body);
      final ok = (body['IsSuccess'] ?? body['is_success']) == true;
      if (ok) {
        unreadNotifications.value = 0;
      }
      return ok;
    } catch (_) {
      return false;
    }
  }

  /// Refreshes the unread notification count from the backend.
  Future<void> refreshUnreadNotificationCount() async {
    try {
      final response = await authenticatedRequest(
        method: 'GET',
        endpoint: '/notifications/unread-count/',
      );
      final body = jsonDecode(response.body);
      if ((body['IsSuccess'] ?? body['is_success']) == true) {
        final result = body['Result'] ?? body['result'];
        final count = (result?['unread_count'] as num?)?.toInt() ?? 0;
        unreadNotifications.value = count;
      }
    } catch (_) {}
  }

  /// Starts the WebSocket notifications stream and reconnects automatically on disconnect.
  static void startNotificationsStream({
    void Function(Map<String, dynamic> notification)? onNotification,
  }) {
    if (_accessToken == null) return;

    if (onNotification != null) {
      _notificationCallback = onNotification;
    }
    _notificationReconnectEnabled = true;

    if (_notificationChannel != null) return;

    final wsBase = baseUrl
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://')
        .replaceFirst('/api', '');
    final uri = Uri.parse('$wsBase/ws/notifications/?token=$_accessToken');

    try {
      _notificationChannel = WebSocketChannel.connect(uri);
      _notificationSub = _notificationChannel!.stream.listen(
        (event) {
          try {
            final payload =
                jsonDecode(event.toString()) as Map<String, dynamic>;
            if (payload['notification'] is Map) {
              final notification = Map<String, dynamic>.from(
                payload['notification'],
              );
              if (notification['is_read'] != true) {
                unreadNotifications.value = unreadNotifications.value + 1;
              }
              if ((notification['notification_type'] ?? '').toString() ==
                  'message') {
                messageNotificationTick.value =
                    messageNotificationTick.value + 1;
              }
              _notificationCallback?.call(notification);
            }
          } catch (_) {}
        },
        onDone: () {
          _handleNotificationSocketDisconnect();
        },
        onError: (_) {
          _handleNotificationSocketDisconnect();
        },
      );

      AuthService().refreshUnreadNotificationCount();
    } catch (_) {
      _handleNotificationSocketDisconnect();
    }
  }

  /// Cleans up the socket subscription and schedules a reconnect if enabled.
  static void _handleNotificationSocketDisconnect() {
    _notificationSub?.cancel();
    _notificationSub = null;
    _notificationChannel?.sink.close();
    _notificationChannel = null;

    if (!_notificationReconnectEnabled || _accessToken == null) return;

    _notificationReconnectTimer?.cancel();
    _notificationReconnectTimer = Timer(const Duration(seconds: 3), () {
      if (_notificationReconnectEnabled) {
        startNotificationsStream();
      }
    });
  }

  /// Stops the WebSocket notifications stream and cancels reconnect attempts.
  static void stopNotificationsStream() {
    _notificationReconnectEnabled = false;
    _notificationReconnectTimer?.cancel();
    _notificationReconnectTimer = null;
    _notificationSub?.cancel();
    _notificationSub = null;
    _notificationChannel?.sink.close();
    _notificationChannel = null;
    _notificationCallback = null;
  }

  /// Creates (or fetches) a direct conversation with a user.
  Future<Map<String, dynamic>> createOrGetConversation(int userId) async {
    try {
      final response = await authenticatedRequest(
        method: 'POST',
        endpoint: '/conversation-create/',
        body: {
          'participants': [userId],
          'is_group': false,
        },
      );
      final body = jsonDecode(response.body);
      if (body['IsSuccess'] == true) {
        await clearConversationCache();
        final data = body['Result']['data'];
        final currentUsername = AuthService.currentUsername;
        final pfpInfo = data['pfp_info'] as List? ?? [];
        final other = pfpInfo.firstWhere(
          (p) => p['username'] != currentUsername,
          orElse: () => <String, dynamic>{},
        );
        return {
          'success': true,
          'conversation_id': data['id'],
          'pfp_url': other['pfp_url'],
        };
      }
      return {'success': false, 'message': 'Failed to create conversation'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Creates a group conversation with the given participants and name.
  Future<Map<String, dynamic>> createGroup({
    required List<int> participantIds,
    required String groupName,
  }) async {
    try {
      final response = await authenticatedRequest(
        method: 'POST',
        endpoint: '/conversation-create/',
        body: {
          'participants': participantIds,
          'is_group': true,
          'group_name': groupName,
        },
      );
      final body = jsonDecode(response.body);
      if (body['IsSuccess'] == true) {
        await clearConversationCache();
        final data = body['Result']['data'];
        return {
          'success': true,
          'conversation_id': data['id'],
          'name': data['group_name'],
        };
      }
      return {'success': false, 'message': 'Failed to create group'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Soft-deletes a conversation for the current user.
  Future<Map<String, dynamic>> deleteConversationForUser(
    String conversationId,
  ) async {
    try {
      final response = await authenticatedRequest(
        method: 'DELETE',
        endpoint: '/conversation-soft-delete-for-user/$conversationId/',
      );
      if (response.statusCode == 200) {
        await clearConversationCache();
        return {'success': true};
      }
      final body = jsonDecode(response.body);
      return {'success': false, 'message': body['ErrorMessage'].toString()};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Leaves a group conversation.
  Future<Map<String, dynamic>> leaveGroup(String conversationId) async {
    try {
      final response = await authenticatedRequest(
        method: 'POST',
        endpoint: '/leave_group/$conversationId/',
        body: {'confirmation': true},
      );
      final body = jsonDecode(response.body);
      if (body['IsSuccess'] == true) {
        await clearConversationCache();
        return {'success': true};
      }
      return {'success': false, 'message': body['ErrorMessage'].toString()};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Adds a participant to a group conversation.
  Future<Map<String, dynamic>> addParticipant(
    String conversationId,
    int userId,
  ) async {
    try {
      final response = await authenticatedRequest(
        method: 'POST',
        endpoint: '/add_participant/$conversationId/',
        body: {
          'user_ids': [userId],
        },
      );
      final body = jsonDecode(response.body);
      if (body['IsSuccess'] == true) {
        await clearConversationCache();
        return {'success': true};
      }
      return {'success': false, 'message': body['ErrorMessage'].toString()};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Removes a participant from a group conversation (may require confirmation).
  Future<Map<String, dynamic>> removeParticipant(
    String conversationId,
    int userId, {
    bool confirmation = false,
  }) async {
    try {
      final response = await authenticatedRequest(
        method: 'POST',
        endpoint: '/remove_participant/$conversationId/',
        body: {
          'user_ids': [userId],
          'confirmation': confirmation,
        },
      );
      final body = jsonDecode(response.body);
      if ((body['IsSuccess'] ?? body['is_success']) == true) {
        await clearConversationCache();
        return {'success': true};
      }

      final result = body['Result'] ?? body['result'];
      if (result is Map && result['requires_confirmation'] == true) {
        return {
          'success': false,
          'requires_confirmation': true,
          'message':
              result['message']?.toString() ??
              'This action requires confirmation.',
        };
      }

      final errorMessage =
          body['ErrorMessage'] ?? body['error_message'] ?? result?['message'];
      return {
        'success': false,
        'message': errorMessage?.toString() ?? 'Failed to remove participant',
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Updates a group's display name.
  Future<Map<String, dynamic>> updateConversation(
    String conversationId,
    String groupName,
  ) async {
    try {
      final response = await authenticatedRequest(
        method: 'PATCH',
        endpoint: '/conversation-update/$conversationId/',
        body: {'group_name': groupName},
      );
      final body = jsonDecode(response.body);
      if (body['IsSuccess'] == true) {
        await clearConversationCache();
        return {'success': true};
      }
      return {'success': false, 'message': body['ErrorMessage'].toString()};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Fetches summary stats for the admin dashboard.
  Future<Map<String, dynamic>> fetchAdminDashboardStats() async {
    try {
      final response = await authenticatedRequest(
        method: 'GET',
        endpoint: '/admin/dashboard/summary/',
      );
      final body = jsonDecode(response.body);
      if (body['IsSuccess'] == true) {
        return {'success': true, 'data': body['Result']};
      }
      return {'success': false, 'message': 'Failed to load stats'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Fetches admin screen-time stats aggregated per user.
  Future<List<Map<String, dynamic>>> fetchScreenTimeStats() async {
    try {
      final response = await authenticatedRequest(
        method: 'GET',
        endpoint: '/admin/dashboard/screentime/',
      );
      final body = jsonDecode(response.body);

      // Standard backend shape: { IsSuccess: true, Result: [ ... ] }
      if ((body['IsSuccess'] ?? body['is_success']) == true) {
        final result = body['Result'] ?? body['result'] ?? [];
        if (result is List) {
          return List<Map<String, dynamic>>.from(result);
        }
      }

      // Backward-compatible fallback if endpoint ever returns a raw list.
      if (body is List) {
        return List<Map<String, dynamic>>.from(body);
      }

      return [];
    } catch (e) {
      return [];
    }
  }

  /// Fetches the moderation queue items for admin review.
  Future<Map<String, dynamic>> fetchModerationQueue() async {
    try {
      final response = await authenticatedRequest(
        method: 'GET',
        endpoint: '/admin/moderation/queue/',
      );

      final body = jsonDecode(response.body);
      if ((body['IsSuccess'] ?? body['is_success']) == true) {
        final result = body['Result'] ?? body['result'];
        final items = (result?['data'] as List?) ?? [];
        return {
          'success': true,
          'items': List<Map<String, dynamic>>.from(items),
        };
      }

      return {
        'success': false,
        'message': _parseBackendErrorMessage(
          body['ErrorMessage'],
          'Failed to load moderation queue',
        ),
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Submits a moderation decision (approve/block) for a post.
  Future<Map<String, dynamic>> moderationAction({
    required int postId,
    required String action,
  }) async {
    try {
      final response = await authenticatedRequest(
        method: 'POST',
        endpoint: '/admin/moderation/action/',
        body: {'post_id': postId, 'action': action},
      );

      final body = jsonDecode(response.body);
      if ((body['IsSuccess'] ?? body['is_success']) == true) {
        return {'success': true};
      }

      return {
        'success': false,
        'message': _parseBackendErrorMessage(
          body['ErrorMessage'],
          'Failed to update moderation status',
        ),
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Makes an authenticated HTTP request and retries once if the access token is expired.
  Future<http.Response> authenticatedRequest({
    required String method,
    required String endpoint,
    Map<String, dynamic>? body,
    Map<String, String>? additionalHeaders,
  }) async {
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $_accessToken',
      ...?additionalHeaders,
    };

    final uri = Uri.parse('$baseUrl$endpoint');
    http.Response response;

    switch (method.toUpperCase()) {
      case 'GET':
        response = await http.get(uri, headers: headers);
        break;
      case 'POST':
        response = await http.post(
          uri,
          headers: headers,
          body: body != null ? jsonEncode(body) : null,
        );
        break;
      case 'PUT':
        response = await http.put(
          uri,
          headers: headers,
          body: body != null ? jsonEncode(body) : null,
        );
        break;
      case 'PATCH':
        response = await http.patch(
          uri,
          headers: headers,
          body: body != null ? jsonEncode(body) : null,
        );
        break;
      case 'DELETE':
        response = await http.delete(uri, headers: headers);
        break;
      default:
        throw ArgumentError('Unsupported HTTP method: $method');
    }

    // If unauthorized, try to refresh token and retry once
    if (response.statusCode == 401) {
      final refreshed = await refreshAccessToken();
      if (refreshed) {
        // Update headers with new token
        headers['Authorization'] = 'Bearer $_accessToken';

        // Retry the request
        switch (method.toUpperCase()) {
          case 'GET':
            response = await http.get(uri, headers: headers);
            break;
          case 'POST':
            response = await http.post(
              uri,
              headers: headers,
              body: body != null ? jsonEncode(body) : null,
            );
            break;
          case 'PUT':
            response = await http.put(
              uri,
              headers: headers,
              body: body != null ? jsonEncode(body) : null,
            );
            break;
          case 'PATCH':
            response = await http.patch(
              uri,
              headers: headers,
              body: body != null ? jsonEncode(body) : null,
            );
            break;
          case 'DELETE':
            response = await http.delete(uri, headers: headers);
            break;
        }
      }
    }

    return response;
  }

  /// Checks whether the current user has the given role string.
  static bool hasRole(String role) {
    final userRole = _currentUser?.role.toLowerCase().trim();
    final targetRole = role.toLowerCase().trim();
    return userRole == targetRole;
  }

  /// Returns true if the current user is an admin.
  static bool isAdmin() => hasRole('admin');
  /// Returns true if the current user is a superuser.
  static bool isSuperUser() => hasRole('superuser');
  /// Returns true if the current user is a regular user.
  static bool isUser() => hasRole('user');
}
