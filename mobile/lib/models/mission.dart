/// A watch-to-earn mission from `GET /api/app/missions` — the same admin-defined
/// missions as the web "ภารกิจ" page. The server (MissionService) is authoritative
/// for progress + the reward; the app only reports focused-playback heartbeats.
class MissionItem {
  const MissionItem({
    required this.id,
    required this.title,
    this.description,
    required this.videoSource,
    required this.videoRef,
    this.poster,
    required this.requiredSeconds,
    required this.rewardKind,
    required this.rewardAmount,
    required this.rewardLabel,
    required this.repeat,
    required this.status,
    this.watched = 0,
  });

  final int id;
  final String title;
  final String? description;

  /// 'youtube' (videoRef = YT id) | 'url' (videoRef = direct mp4/m3u8 URL).
  final String videoSource;
  final String videoRef;
  final String? poster;

  /// Seconds of validated watching required to earn the reward.
  final int requiredSeconds;

  /// 'silver' | 'gold'.
  final String rewardKind;
  final int rewardAmount;

  /// Server-rendered Thai label, e.g. "5 เหรียญเงิน".
  final String rewardLabel;

  /// 'once' | 'daily'.
  final String repeat;

  /// 'earned' (done for this period) | 'available'.
  final String status;

  /// Validated seconds already watched in the current attempt.
  final int watched;

  bool get isYoutube => videoSource == 'youtube';
  bool get earned => status == 'earned';
  bool get isDaily => repeat == 'daily';
  bool get isGold => rewardKind == 'gold';

  static MissionItem fromJson(Map<String, dynamic> j) => MissionItem(
        id: (j['id'] as num).toInt(),
        title: (j['title'] ?? '').toString(),
        description: j['description'] as String?,
        videoSource: (j['video_source'] ?? 'url').toString(),
        videoRef: (j['video_ref'] ?? '').toString(),
        poster: j['poster'] as String?,
        requiredSeconds: (j['required_seconds'] as num?)?.toInt() ?? 0,
        rewardKind: (j['reward_kind'] ?? 'silver').toString(),
        rewardAmount: (j['reward_amount'] as num?)?.toInt() ?? 0,
        rewardLabel: (j['reward_label'] ?? '').toString(),
        repeat: (j['repeat'] ?? 'once').toString(),
        status: (j['status'] ?? 'available').toString(),
        watched: (j['watched'] as num?)?.toInt() ?? 0,
      );
}

/// Result of `POST /missions/{id}/start`.
class MissionStart {
  const MissionStart({required this.ok, this.token, this.required = 0, this.error, this.alreadyEarned = false});

  final bool ok;
  final String? token;
  final int required;
  final String? error;
  final bool alreadyEarned;
}

/// Result of `POST /missions/{id}/beat`.
class MissionBeat {
  const MissionBeat({
    required this.ok,
    this.done = false,
    this.watched = 0,
    this.required = 0,
    this.rewardLabel,
    this.membership,
    this.error,
  });

  final bool ok;
  final bool done;
  final int watched;
  final int required;

  /// Set the moment the mission completes (e.g. "5 เหรียญเงิน").
  final String? rewardLabel;

  /// Fresh membership state (coins/gold/Pro) sent along with the reward.
  final Map<String, dynamic>? membership;
  final String? error;
}
