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

  // Cloudinary video thumbnail: swapping /video/upload/ → /video/upload/so_0/ and using .jpg
  String get videoThumbnailUrl {
    if (!isVideo) return mediaUrl;
    final thumb = mediaUrl.replaceFirst('/video/upload/', '/video/upload/so_0/');
    final dotIndex = thumb.lastIndexOf('.');
    if (dotIndex != -1) return '${thumb.substring(0, dotIndex)}.jpg';
    return '$thumb.jpg';
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
}