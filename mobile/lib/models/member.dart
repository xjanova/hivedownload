import 'dart:convert';

/// A signed-in member. Backed by netwix.online once live; until then a local
/// guest/session record persisted on-device.
class Member {
  const Member({
    required this.id,
    required this.name,
    this.avatar,
    this.provider = 'guest',
    this.referralCode = '',
    this.token,
  });

  final String id;
  final String name;
  final String? avatar;

  /// 'google' | 'line' | 'guest'
  final String provider;

  /// The member's own code to invite friends.
  final String referralCode;

  /// netwix.online Sanctum bearer token (null while offline/guest).
  final String? token;

  bool get isGuest => provider == 'guest';
  bool get isLoggedIn => provider != 'guest';

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'avatar': avatar,
        'provider': provider,
        'referral_code': referralCode,
        'token': token,
      };

  factory Member.fromJson(Map<String, dynamic> j) => Member(
        id: '${j['id'] ?? ''}',
        name: (j['name'] as String?) ?? 'สมาชิก',
        avatar: j['avatar'] as String?,
        provider: (j['provider'] as String?) ?? 'guest',
        referralCode: (j['referral_code'] ?? j['referralCode'] ?? '') as String,
        token: j['token'] as String?,
      );

  String encode() => jsonEncode(toJson());
  static Member? decode(String? s) {
    if (s == null || s.isEmpty) return null;
    try {
      return Member.fromJson(jsonDecode(s) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Member copyWith({String? name, String? avatar, String? referralCode, String? token}) => Member(
        id: id,
        name: name ?? this.name,
        avatar: avatar ?? this.avatar,
        provider: provider,
        referralCode: referralCode ?? this.referralCode,
        token: token ?? this.token,
      );
}

/// A comment on a series (netwix.online-backed).
class Comment {
  const Comment({
    required this.id,
    required this.author,
    this.avatar,
    required this.text,
    required this.createdAt,
  });

  final String id;
  final String author;
  final String? avatar;
  final String text;
  final DateTime createdAt;

  factory Comment.fromJson(Map<String, dynamic> j) => Comment(
        id: '${j['id'] ?? ''}',
        author: (j['author'] ?? j['name'] ?? 'สมาชิก') as String,
        avatar: j['avatar'] as String?,
        text: (j['text'] ?? j['body'] ?? '') as String,
        createdAt: DateTime.tryParse('${j['created_at'] ?? ''}') ?? DateTime.fromMillisecondsSinceEpoch(0),
      );
}
