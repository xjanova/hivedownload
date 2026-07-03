import 'dart:convert';

/// A signed-in member. Backed by netwix.online once live; until then a local
/// guest/session record persisted on-device.
class Member {
  const Member({
    required this.id,
    required this.name,
    this.avatar,
    this.email,
    this.provider = 'guest',
    this.referralCode = '',
    this.token,
    this.isPro = false,
  });

  final String id;
  final String name;
  final String? avatar;
  final String? email;

  /// 'google' | 'line' | 'email' | 'guest'
  final String provider;

  /// The member's own code to invite friends.
  final String referralCode;

  /// NetWix app bearer token (null while guest).
  final String? token;

  /// Server plan is a paid tier (ad-free).
  final bool isPro;

  bool get isGuest => provider == 'guest';
  bool get isLoggedIn => provider != 'guest';

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'avatar': avatar,
        'email': email,
        'provider': provider,
        'referral_code': referralCode,
        'token': token,
        'is_pro': isPro,
      };

  factory Member.fromJson(Map<String, dynamic> j) => Member(
        id: '${j['id'] ?? ''}',
        name: (j['name'] as String?) ?? 'สมาชิก',
        avatar: j['avatar'] as String?,
        email: j['email'] as String?,
        provider: (j['provider'] as String?) ?? 'guest',
        referralCode: (j['referral_code'] ?? j['referralCode'] ?? '') as String,
        token: j['token'] as String?,
        isPro: j['is_pro'] == true,
      );

  /// Build from the `/api/app/auth/me` (or exchange) user payload + token.
  factory Member.fromNetwixUser(Map<String, dynamic> u, {String? token}) => Member(
        id: '${u['id'] ?? ''}',
        name: (u['name'] as String?) ?? 'สมาชิก',
        avatar: u['avatar'] as String?,
        email: u['email'] as String?,
        // server sends null provider for email/password accounts
        provider: (u['provider'] as String?) ?? 'email',
        token: token,
        isPro: u['is_pro'] == true,
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

  Member copyWith({String? name, String? avatar, String? referralCode, String? token, bool? isPro}) =>
      Member(
        id: id,
        name: name ?? this.name,
        avatar: avatar ?? this.avatar,
        email: email,
        provider: provider,
        referralCode: referralCode ?? this.referralCode,
        token: token ?? this.token,
        isPro: isPro ?? this.isPro,
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
