import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http_parser/http_parser.dart';
import 'package:http/http.dart' as http;
import '../models/profile.dart';
import '../models/post.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String baseUrl = 'http://192.168.1.6:8000/api';
  
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

  // Cache
  static const _cacheKey = 'cached_feed';
  static const _cacheTimeKey = 'cached_feed_time';
  static const _staleDuration = Duration(minutes: 30);

  // Getters
  static String? get accessToken => _accessToken;
  static Profile? get currentUser => _currentUser;
  static String get currentUsername => _currentUser?.user?.username ?? _currentUser?.syncedUsername ?? '';
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

  // Checking if stored token is still valid
  static Future<bool> _validateToken() async {
    if (_accessToken == null) return false;
    
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/user/profile/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_accessToken',
        },
      ).timeout(Duration(seconds: 10));
      
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

        await _fetchUserProfile();

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

  // Change password
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
        message = error.values.map((v) => v is List ? v.join(', ') : v.toString()).join('\n');
      } else {
        message = error.toString();
      }
      return {'success': false, 'message': message};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  //Forgot password, otp, reset password
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

  Future<Map<String, dynamic>> resetPassword(
      String email, String otp, String newPassword, String confirmPassword) async {
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

  // For other user's profile
  Future<Map<String, dynamic>> fetchUserProfile(int userId) async {
    try {
      final response = await authenticatedRequest(
        method: 'GET',
        endpoint: '/user/profile/$userId/',
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);
      if ((data['IsSuccess'] ?? false) == true) {
        return {'success': true, 'profile': Profile.fromJson(data['Result']['data'])};
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
        'message': _parseErrorMessage(data['ErrorMessage'], 'Failed to update profile'),
      };
    } catch (e) {
      return {'success': false, 'message': 'Network error: Please check your connection'};
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
    //logout endpoint to blacklist tokens
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
        ).timeout(const Duration(seconds: 54));
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
    await clearFeedCache();
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

  // Fetch Posts with cache fallback
  Future<Map<String, dynamic>> fetchPosts({String? nextUrl, String? username}) async {
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

  Future<Map<String, dynamic>> _fetchPostsFromNetwork({String? nextUrl, String? username}) async {
    String endpoint;
    if (nextUrl != null) {
      final uri = Uri.parse(nextUrl);
      endpoint = '/post/?${uri.query}';
    } else if (username != null) {
      endpoint = '/post/?posted_by=$username';
    }
    else {
      endpoint = '/post/';
    }

    final response = await authenticatedRequest(
      method: 'GET',
      endpoint: endpoint,
    ).timeout(const Duration(seconds: 10));

    final data = jsonDecode(response.body);
    return _parsePosts(data);
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
        'fromCache': false,
      };
    }
    final error = data['ErrorMessage'];
    return {
      'success': false,
      'message': error is List ? error.join(', ') : error.toString(),
    };
  }

  // Cache helpers
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
      final posts = (payload['posts'] as List)
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

  Future<void> updateCachedPost(Post updated) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null) return;

      final payload = jsonDecode(raw) as Map<String, dynamic>;
      final posts = (payload['posts'] as List)
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

  static Future<void> clearFeedCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
      await prefs.remove(_cacheTimeKey);
    } catch (_) {}
  }

  // Delete Post
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

  Future<void> _removeFromFeedCache(int postId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null) return;

      final payload = jsonDecode(raw) as Map<String, dynamic>;
      final posts = (payload['posts'] as List)
          .map((p) => Post.fromJson(p as Map<String, dynamic>))
          .where((p) => p.id != postId)
          .toList();

      payload['posts'] = posts.map((p) => p.toJson()).toList();
      await prefs.setString(_cacheKey, jsonEncode(payload));
    } catch (_) {}
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

  // Create post
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
        for (final tag in typeOfPost){
          request.fields['type_of_post'] = typeOfPost.join(',');
        }
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

  // Send friend request
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

  Future<Map<String, dynamic>> checkFriendRequestStatus(String toUsername) async {
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
          (r) => r['from_user'] == currentUsername &&
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
      return {'success': false, 'sent': false, 'received': false, 'received_request_id': null};
    } catch (e) {
      return {'success': false, 'sent': false, 'received': false, 'received_request_id': null};
    }
  }

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
        final requests = results
            .map((r) => {
                  ...Map<String, dynamic>.from(r),
                  'is_received': r['to_user'] == currentUsername,
                })
            .toList();
        return {'success': true, 'requests': requests};
      }
      return {'success': false, 'message': 'Failed to load requests'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> respondFriendRequest(int id, String status) async {
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

  Future<Map<String, dynamic>> checkFriendship(int userId) async {
    try {
      final response = await authenticatedRequest(
        method: 'GET',
        endpoint: '/friends/',
      );
      final body = jsonDecode(response.body);
      if (body['IsSuccess'] == true) {
        final results = body['Result']['data']['results'] as List;
        final isFriend = results.any((r) =>
            r['user1'] == userId || r['user2'] == userId);
        return {'success': true, 'is_friend': isFriend};
      }
      return {'success': false, 'is_friend': false};
    } catch (e) {
      return {'success': false, 'is_friend': false};
    }
  }

  // Delete Account
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

  // Search users
  Future<Map<String, dynamic>> searchUsers(String query, {String? nextUrl}) async {
    try {
      final endpoint = nextUrl != null
          ? '/user/search/?${Uri.parse(nextUrl).query}'
          : '/user/search/?q=${Uri.encodeComponent(query)}';
      final response = await authenticatedRequest(method: 'GET', endpoint: endpoint);
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

  // Messages
  Future<Map<String, dynamic>> fetchConversations() async {
    try {
      final response = await authenticatedRequest(
        method: 'GET',
        endpoint: '/conversation-list/',
      );
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

  Future<Map<String, dynamic>> createOrGetConversation(int userId) async {
    try {
      final response = await authenticatedRequest(
        method: 'POST',
        endpoint: '/conversation-create/',
        body: {'participants': [userId], 'is_group': false},
      );
      final body = jsonDecode(response.body);
      if (body['IsSuccess'] == true) {
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

  // Conversation options
  Future<Map<String, dynamic>> deleteConversationForUser(String conversationId) async {
    try {
      final response = await authenticatedRequest(
        method: 'DELETE',
        endpoint: '/conversation-soft-delete-for-user/$conversationId/',
      );
      if (response.statusCode == 200) return {'success': true};
      final body = jsonDecode(response.body);
      return {'success': false, 'message': body['ErrorMessage'].toString()};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> leaveGroup(String conversationId) async {
    try {
      final response = await authenticatedRequest(
        method: 'POST',
        endpoint: '/leave_group/$conversationId/',
        body: {'confirmation': true},
      );
      final body = jsonDecode(response.body);
      if (body['IsSuccess'] == true) return {'success': true};
      return {'success': false, 'message': body['ErrorMessage'].toString()};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> addParticipant(String conversationId, int userId) async {
    try {
      final response = await authenticatedRequest(
        method: 'POST',
        endpoint: '/add_participant/$conversationId/',
        body: {'user_ids': [userId]},
      );
      final body = jsonDecode(response.body);
      if (body['IsSuccess'] == true) return {'success': true};
      return {'success': false, 'message': body['ErrorMessage'].toString()};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> removeParticipant(String conversationId, int userId, {bool confirmation = false}) async {
    try {
      final response = await authenticatedRequest(
        method: 'POST',
        endpoint: '/remove_participant/$conversationId/',
        body: {'user_ids': [userId], 'confirmation': confirmation},
      );
      final body = jsonDecode(response.body);
      if ((body['IsSuccess'] ?? body['is_success']) == true) return {'success': true};

      final result = body['Result'] ?? body['result'];
      if (result is Map && result['requires_confirmation'] == true) {
        return {
          'success': false,
          'requires_confirmation': true,
          'message': result['message']?.toString() ?? 'This action requires confirmation.',
        };
      }

      final errorMessage = body['ErrorMessage'] ?? body['error_message'] ?? result?['message'];
      return {'success': false, 'message': errorMessage?.toString() ?? 'Failed to remove participant'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> updateConversation(String conversationId, String groupName) async {
    try {
      final response = await authenticatedRequest(
        method: 'PATCH',
        endpoint: '/conversation-update/$conversationId/',
        body: {'group_name': groupName},
      );
      final body = jsonDecode(response.body);
      if (body['IsSuccess'] == true) return {'success': true};
      return {'success': false, 'message': body['ErrorMessage'].toString()};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // Admin Dashboard
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

  Future<List<Map<String, dynamic>>> fetchScreenTimeStats() async {
    try {
      final response = await authenticatedRequest(
        method: 'GET',
        endpoint: '/admin/dashboard/screentime/',
      );
      final body = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(body);
    } catch (e) {
      return [];
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
    final userRole = _currentUser?.role.toLowerCase().trim();
    final targetRole = role.toLowerCase().trim();
    return userRole == targetRole;
  }

  // Helper methods for role checks
  static bool isAdmin() => hasRole('admin');
  static bool isSuperUser() => hasRole('superuser');
  static bool isUser() => hasRole('user');
}