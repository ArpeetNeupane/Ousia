class MediaFile {
  final int id;
  final String publicId;
  final bool isVideo;
  final int uploadOrder;
  final String mediaUrl;

  MediaFile({
    required this.id,
    required this.publicId,
    required this.isVideo,
    required this.uploadOrder,
    required this.mediaUrl,
  });

  factory MediaFile.fromJson(Map<String, dynamic> json) => MediaFile(
        id: json['id'],
        publicId: json['public_id'],
        isVideo: json['is_video'],
        uploadOrder: json['upload_order'],
        mediaUrl: json['media_url'],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'public_id': publicId,
        'is_video': isVideo,
        'upload_order': uploadOrder,
        'media_url': mediaUrl,
      };

  String get videoThumbnailUrl {
    if (!isVideo) return mediaUrl;
    return mediaUrl.replaceFirst('/video/upload/', '/video/upload/so_0,f_jpg/');
  }
}

class PostedByProfile {
  final String? pfpUrl;
  final String username;

  PostedByProfile({this.pfpUrl, required this.username});

  factory PostedByProfile.fromJson(Map<String, dynamic> json) => PostedByProfile(
        pfpUrl: json['pfp_url'],
        username: json['username'] ?? '',
      );

  Map<String, dynamic> toJson() => {
        'pfp_url': pfpUrl,
        'username': username,
      };
}

class Post {
  final int id;
  final String? caption;
  final String visibilityLabel;
  final DateTime createdAt;
  final int postedBy;
  final String postedByUsername;
  final PostedByProfile? postedByProfile;
  final String typeOfPost;
  final List<MediaFile> mediaFiles;
  int postLikeCount;
  final int postCommentCount;
  bool isLiked;
  int? likeId;

  Post({
    required this.id,
    this.caption,
    required this.visibilityLabel,
    required this.createdAt,
    required this.postedBy,
    required this.postedByUsername,
    this.postedByProfile,
    required this.typeOfPost,
    required this.mediaFiles,
    required this.postLikeCount,
    required this.postCommentCount,
    this.isLiked = false,
    this.likeId,
  });

  factory Post.fromJson(Map<String, dynamic> json) => Post(
        id: json['id'],
        caption: json['caption'],
        visibilityLabel: json['visibility_label'] ?? '',
        createdAt: DateTime.parse(json['created_at']),
        postedBy: json['posted_by'],
        postedByUsername: json['posted_by_username'] ?? '',
        postedByProfile: json['posted_by_profile'] != null
            ? PostedByProfile.fromJson(json['posted_by_profile'])
            : null,
        typeOfPost: json['type_of_post'] ?? '',
        mediaFiles: (json['media_files'] as List<dynamic>)
            .map((m) => MediaFile.fromJson(m))
            .toList(),
        postLikeCount: json['post_like_count'] ?? 0,
        postCommentCount: json['post_comment_count'] ?? 0,
        isLiked: json['is_liked'] ?? false,
        likeId: json['user_like_id'],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'caption': caption,
        'visibility_label': visibilityLabel,
        'created_at': createdAt.toIso8601String(),
        'posted_by': postedBy,
        'posted_by_username': postedByUsername,
        'posted_by_profile': postedByProfile?.toJson(),
        'type_of_post': typeOfPost,
        'media_files': mediaFiles.map((m) => m.toJson()).toList(),
        'post_like_count': postLikeCount,
        'post_comment_count': postCommentCount,
        'is_liked': isLiked,
        'user_like_id': likeId,
      };
}