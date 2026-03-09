import 'dart:io';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http_parser/http_parser.dart';
import 'package:http/http.dart' as http;
import '../models/profile.dart';
import '../models/post.dart';

class AuthService {
  static const String baseUrl = 'http://192.168.1.5:8000/api';
  
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
  
  bool _hasCompletedInterests = false;
  bool get hasCompletedInterests => _hasCompletedInterests;

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

  static String _parseBackendErrorMessage(dynamic errorData, [String defaultMessage = 'An error occurred']) {
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
      
      return errorMessages.isNotEmpty ? errorMessages.join('\n') : defaultMessage;
    } else if (errorData is List && errorData.isNotEmpty) {
      List<String> errorMessages = [];
      for (var error in errorData) {
        if (error != null) {
          errorMessages.add(error.toString());
        }
      }
      return errorMessages.isNotEmpty ? errorMessages.join('\n') : defaultMessage;
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

      // print('Login response status: ${response.statusCode}');
      // print('Login response body: ${response.body}');

      final data = jsonDecode(response.body);

      // Handle success case - check both formats
      if (data['is_success'] == true || data['IsSuccess'] == true) {
        final result = data['result'] ?? data['Result'];
        final tokenData = result['data'];

        _accessToken = tokenData['access_token'];
        _refreshToken = tokenData['refresh_token'];
        _hasCompletedInterests = tokenData['has_completed_interests'] == true;

        await _secureStorage.write(key: _accessTokenKey, value: _accessToken!);
        await _secureStorage.write(key: _refreshTokenKey, value: _refreshToken!);

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
          errorMessage = _parseErrorMessage(data['error_message'], 'Login failed.');
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
        request.files.add(await http.MultipartFile.fromPath(
          'selfie_image',
          selfieImage.path,
        ));
      }
      if (idCardImage != null) {
        request.files.add(await http.MultipartFile.fromPath(
          'idcard_image',
          idCardImage.path,
        ));
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
          'message': data['result']?['message'] ?? 
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
          errorMessage = _parseErrorMessage(data['error_message'], 'Registration failed.');
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

  // Method for uploading profile picture
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

        return {
          'success': true,
          'interests': interests,
        };
      } else {
        final error = data['ErrorMessage'] ?? data['error_message'];
        return {
          'success': false,
          'message': _parseBackendErrorMessage(
              error, 'Failed to load interests.'),
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

  Future<Map<String, dynamic>> saveUserInterests(int interestId) async {
    try {
      final response = await authenticatedRequest(
        method: 'POST',
        endpoint: '/user-interests/',
        body: {
          'users_interest': interestId,
        },
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
              error, 'Failed to save interests.'),
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


  // Fetch Post logic
  Future<Map<String, dynamic>> fetchPosts({String? nextUrl}) async {
    try {
      String endpoint;
      if (nextUrl != null) {
        final uri = Uri.parse(nextUrl);
        endpoint = '/post/?${uri.query}';
      } else {
        endpoint = '/post/';
      }
      final response = await authenticatedRequest(method: 'GET', endpoint: endpoint);
      final data = jsonDecode(response.body);
      return _parsePosts(data);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Map<String, dynamic> _parsePosts(Map<String, dynamic> data) {
    if ((data['IsSuccess'] ?? false) == true) {
      final result = data['Result'];
      final pagination = result['data'];
      final List rawPosts = pagination['results'] ?? [];
      return {
        'success': true,
        'posts': rawPosts.map((p) => Post.fromJson(p)).toList(),
        'next': pagination['next'],
      };
    }
    final error = data['ErrorMessage'];
    return {
      'success': false,
      'message': error is List ? error.join(', ') : error.toString(),
    };
  }

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

  // Create post
  Future<Map<String, dynamic>> createPost({
    String? caption,
    required String visibility,
    String? typeOfPost,
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
      if (typeOfPost != null && typeOfPost.isNotEmpty) {
        request.fields['type_of_post'] = typeOfPost;
      }

      for (final file in mediaFiles) {
        final mimeType = _getMimeType(file.path);
        request.files.add(await http.MultipartFile.fromPath(
          'media', // backend field name
          file.path,
          contentType: mimeType,
        ));
      }

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      final data = jsonDecode(response.body);

      if ((data['IsSuccess'] ?? false) == true) {
        return {'success': true};
      }
      final error = data['ErrorMessage'];
      String message;
      if (error is Map) {
        message = error.values.map((v) => v is List ? v.join(', ') : v.toString()).join('\n');
      } else if (error is List) {
        message = error.join(', ');
      } else {
        message = error.toString();
      }
      return {
        'success': false,
        'message': message,
      };
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

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
  static bool isAdmin() => hasRole('admin');
  static bool isSuperUser() => hasRole('superuser');
  static bool isUser() => hasRole('user');
}