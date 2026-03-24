class User {
  final String username;
  final String email;
  final String role;
  final String phoneNumber;

  User({
    required this.username,
    required this.email,
    required this.role,
    required this.phoneNumber,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? 'user',
      phoneNumber: json['phone_number'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'email': email,
      'role': role,
      'phone_number': phoneNumber,
    };
  }
}

class Profile {
  final int id;
  final String? syncedUsername;
  final String? syncedEmail;
  final String? syncedPhoneNumber;
  final String? pfpPublicId;
  final String? pfpUrl;
  final String? bio;
  final String? address;
  final DateTime? birthDate;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final User? user;
  final String? serverRole;

  Profile({
    required this.id,
    this.syncedUsername,
    this.syncedEmail,
    this.syncedPhoneNumber,
    this.pfpPublicId,
    this.pfpUrl,
    this.bio,
    this.address,
    this.birthDate,
    this.createdAt,
    this.updatedAt,
    this.user,
    this.serverRole,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] ?? 0,
      syncedUsername: json['synced_username'],
      syncedEmail: json['synced_email'],
      syncedPhoneNumber: json['synced_phone_number'],
      pfpPublicId: json['pfp_public_id'],
      pfpUrl: json['pfp_url'],
      bio: json['bio'],
      address: json['address'],
      birthDate: json['birth_date'] != null && json['birth_date'].toString().isNotEmpty
          ? DateTime.tryParse(json['birth_date'])
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'])
          : null,
      user: json['user'] != null ? User.fromJson(json['user']) : null,
      serverRole: json['role'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'role': role,
      'synced_username': syncedUsername,
      'synced_email': syncedEmail,
      'synced_phone_number': syncedPhoneNumber,
      'pfp_public_id': pfpPublicId,
      'pfp_url': pfpUrl,
      'bio': bio,
      'address': address,
      'birth_date': birthDate?.toIso8601String().split('T')[0],
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      if (user != null) 'user': user!.toJson(),
    };
  }

  Profile copyWith({
    int? id,
    String? syncedUsername,
    String? syncedEmail,
    String? syncedPhoneNumber,
    String? pfpPublicId,
    String? pfpUrl,
    String? bio,
    String? address,
    DateTime? birthDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    User? user,
  }) {
    return Profile(
      id: id ?? this.id,
      syncedUsername: syncedUsername ?? this.syncedUsername,
      syncedEmail: syncedEmail ?? this.syncedEmail,
      syncedPhoneNumber: syncedPhoneNumber ?? this.syncedPhoneNumber,
      pfpPublicId: pfpPublicId ?? this.pfpPublicId,
      pfpUrl: pfpUrl ?? this.pfpUrl,
      bio: bio ?? this.bio,
      address: address ?? this.address,
      birthDate: birthDate ?? this.birthDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      user: user ?? this.user,
    );
  }

  // Convenience getters for accessing user data
  String get username => user?.username ?? syncedUsername ?? '';
  String get email => user?.email ?? syncedEmail ?? '';
  String get phoneNumber => user?.phoneNumber ?? syncedPhoneNumber ?? '';

  String get role {
    if (user != null) return user!.role;
    return serverRole ?? 'user';
  }
}