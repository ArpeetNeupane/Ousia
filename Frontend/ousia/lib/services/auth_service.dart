import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../models/profile.dart';

class AuthService {
  static const String baseUrl = 'http://192.168.1.7:8000/api';
  
  // Secure storage for JWT tokens
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
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

  // Getters
  static String? get accessToken => _accessToken;
  static Profile? get currentUser => _currentUser;
  static bool get isLoggedIn => _accessToken != null && _currentUser != null;

  // Initialize auth service - load tokens from secure storage
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
        }
      }
    } catch (e) {
      print('Error initializing auth service: $e');
      await logout(); // Clear any corrupted data
    }
  }

  // Check if stored token is still valid
  static Future<bool> _validateToken() async {
    if (_accessToken == null) return false;
    
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
        // Handle your custom response format
        if (data['is_success'] == true) {
          _currentUser = Profile.fromJson(data['result']['data']);
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
    } catch (e) {
      print('Error validating token: $e');
    }
    
    return false;
  }

  // Parse API error messages consistently
  static String _parseErrorMessage(dynamic errorData, [String defaultMessage = 'An error occurred']) {
    if (errorData == null) return defaultMessage;
    
    if (errorData is String) {
      return errorData;
    } else if (errorData is Map) {
      List<String> errorMessages = [];
      
      errorData.forEach((field, messages) {
        if (messages is List) {
          for (var message in messages) {
            errorMessages.add(message.toString());
          }
        } else if (messages is String) {
          errorMessages.add(messages);
        }
      });
      
      return errorMessages.isNotEmpty ? errorMessages.join(', ') : defaultMessage;
    } else if (errorData is List && errorData.isNotEmpty) {
      return errorData.first.toString();
    }
    
    return defaultMessage;
  }

  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login/'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      );

      print('Login response status: ${response.statusCode}');
      print('Login response body: ${response.body}');

      final data = jsonDecode(response.body);

      // Handle your custom response format (lowercase keys)
      if (data['is_success'] == true) {
        // Extract tokens from the Result.data field
        final result = data['result'];
        final tokenData = result['data'];
        _accessToken = tokenData['access_token'];
        _refreshToken = tokenData['refresh_token'];
        
        // Store tokens securely
        await _secureStorage.write(key: _accessTokenKey, value: _accessToken!);
        await _secureStorage.write(key: _refreshTokenKey, value: _refreshToken!);
        
        // Fetch user profile after successful login
        await _fetchUserProfile();
        
        return {
          'success': true,
          'message': result['message'] ?? 'Login successful',
          'user': _currentUser,
        };
      } else {
        return {
          'success': false,
          'message': _parseErrorMessage(data['error_message'], 'Login failed'),
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

  Future<Map<String, dynamic>> signup(String username, String email, String phoneNumber, String password, String confirmPassword) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register/'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'username': username,
          'email': email,
          'phone_number': phoneNumber,
          'password': password,
          'confirm_password': confirmPassword,
          'role': 'user', // Default role
        }),
      );

      print('Signup response status: ${response.statusCode}');
      print('Signup response body: ${response.body}');

      final data = jsonDecode(response.body);

      if (data['is_success'] == true) {
        return {
          'success': true,
          'message': data['result']['message'] ?? 'Account created successfully! Please login to continue.',
        };
      } else {
        return {
          'success': false,
          'message': _parseErrorMessage(data['error_message'], 'Registration failed'),
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

  // New password change functionality
  Future<Map<String, dynamic>> changePassword(String currentPassword, String newPassword, String confirmNewPassword) async {
    try {
      final response = await authenticatedRequest(
        method: 'PUT',
        endpoint: '/user/password/update/',
        body: {
          'current_password': currentPassword,
          'new_password': newPassword,
          'confirm_new_password': confirmNewPassword,
        },
      );

      final data = jsonDecode(response.body);

      if (data['is_success'] == true) {
        // Password changed successfully, logout and require re-login for security
        await logout();
        return {
          'success': true,
          'message': data['result']['message'] ?? 'Password updated successfully. Please login again.',
        };
      } else {
        return {
          'success': false,
          'message': _parseErrorMessage(data['error_message'], 'Failed to update password'),
        };
      }
    } catch (e) {
      print('Change password error: $e');
      return {
        'success': false,
        'message': 'Network error: Please check your connection',
      };
    }
  }

  Future<bool> forgotPassword(String email) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/forgot-password/'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': email,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

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
        if (data['is_success'] == true) {
          _currentUser = Profile.fromJson(data['result']['data']);
          
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

  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> profileData) async {
    try {
      final response = await authenticatedRequest(
        method: 'PATCH',
        endpoint: '/user/profile/update/',
        body: profileData,
      );

      final data = jsonDecode(response.body);

      if (data['is_success'] == true) {
        _currentUser = Profile.fromJson(data['result']['data']);
        // Update stored profile
        await _secureStorage.write(
          key: _userProfileKey, 
          value: jsonEncode(_currentUser!.toJson()),
        );
        
        return {
          'success': true,
          'message': data['result']['message'] ?? 'Profile updated successfully',
          'user': _currentUser,
        };
      } else {
        return {
          'success': false,
          'message': _parseErrorMessage(data['error_message'], 'Failed to update profile'),
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: Please check your connection',
      };
    }
  }

  // New method for uploading profile picture
  Future<Map<String, dynamic>> updateProfilePicture(String imagePath) async {
    try {
      var request = http.MultipartRequest(
        'PATCH', 
        Uri.parse('$baseUrl/user/profile/update/'),
      );
      
      request.headers['Authorization'] = 'Bearer $_accessToken';
      request.files.add(await http.MultipartFile.fromPath('pfp', imagePath));
      
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      final data = jsonDecode(response.body);

      if (data['is_success'] == true) {
        _currentUser = Profile.fromJson(data['result']['data']);
        await _secureStorage.write(
          key: _userProfileKey, 
          value: jsonEncode(_currentUser!.toJson()),
        );
        
        return {
          'success': true,
          'message': data['result']['message'] ?? 'Profile picture updated successfully',
          'user': _currentUser,
        };
      } else {
        return {
          'success': false,
          'message': _parseErrorMessage(data['error_message'], 'Failed to update profile picture'),
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: Please check your connection',
      };
    }
  }

  static Future<bool> refreshAccessToken() async {
    if (_refreshToken == null) return false;

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/token/refresh/'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'refresh': _refreshToken,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['access'] != null) {
          _accessToken = data['access'];
          
          // Update stored access token
          await _secureStorage.write(key: _accessTokenKey, value: _accessToken!);
          return true;
        }
      }
    } catch (e) {
      print('Error refreshing token: $e');
    }
    
    return false;
  }

  static Future<void> logout() async {
    // Optionally call logout endpoint to blacklist tokens
    try {
      if (_refreshToken != null) {
        await http.post(
          Uri.parse('$baseUrl/logout/'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_accessToken',
          },
          body: jsonEncode({
            'refresh_token': _refreshToken,
          }),
        );
      }
    } catch (e) {
      print('Error during logout API call: $e');
    }
    
    // Clear in-memory data
    _accessToken = null;
    _refreshToken = null;
    _currentUser = null;
    
    // Clear secure storage
    await _secureStorage.delete(key: _accessTokenKey);
    await _secureStorage.delete(key: _refreshTokenKey);
    await _secureStorage.delete(key: _userProfileKey);
  }

  // Helper method to make authenticated requests with auto-retry on token refresh
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
        response = await http.post(uri, headers: headers, body: body != null ? jsonEncode(body) : null);
        break;
      case 'PUT':
        response = await http.put(uri, headers: headers, body: body != null ? jsonEncode(body) : null);
        break;
      case 'PATCH':
        response = await http.patch(uri, headers: headers, body: body != null ? jsonEncode(body) : null);
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
            response = await http.post(uri, headers: headers, body: body != null ? jsonEncode(body) : null);
            break;
          case 'PUT':
            response = await http.put(uri, headers: headers, body: body != null ? jsonEncode(body) : null);
            break;
          case 'PATCH':
            response = await http.patch(uri, headers: headers, body: body != null ? jsonEncode(body) : null);
            break;
          case 'DELETE':
            response = await http.delete(uri, headers: headers);
            break;
        }
      }
    }

    return response;
  }

  // Helper method to check if user has specific role
  static bool hasRole(String role) {
    return _currentUser?.user?.role == role;
  }

  // Helper methods for role checks
  static bool isAdmin() => hasRole('admin') || hasRole('superuser');
  static bool isSuperUser() => hasRole('superuser');
  static bool isUser() => hasRole('user');
}