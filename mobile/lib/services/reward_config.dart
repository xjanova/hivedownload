/// Coin economy + episode gating. These are the **client defaults**; once
/// netwix.online is live it can override them via `GET /api/config`.
///
/// Model: first [freeEpisodes] episodes of each series are free (with ads);
/// further episodes unlock with coins ([unlockCost] each). Pro (129฿/mo) is
/// ad-free AND unlocks everything without spending coins. Coins are earned via
/// the activities below.
class RewardConfig {
  RewardConfig._();

  static const int freeEpisodes = 3; // ดูฟรี 3 ตอนแรก
  static const int unlockCost = 5; // เหรียญ/ตอน

  // ---- ways to earn coins (I define these; backend can override) ----
  static const int firstLoginBonus = 10; // ล็อกอินครั้งแรกด้วยบัญชี
  static const int dailyCheckin = 2; // เช็คอินรายวัน
  static const int rewardWatchCoins = 3; // ดูคลิปรับรางวัลจบ 1 คลิป
  static const int rewardWatchSeconds = 30; // ต้องดูอย่างน้อย (วินาที)
  static const int rewardWatchDailyMax = 5; // จำกัดต่อวัน
  static const int referralSignupBonus = 15; // เพื่อนสมัครผ่านโค้ดเรา
  static const int watchFiveDaily = 5; // ดูครบ 5 ตอนใน 1 วัน
}

/// A coin-earning activity shown on the "หาเหรียญ" screen.
class RewardActivity {
  const RewardActivity({
    required this.key,
    required this.titleTh,
    required this.titleEn,
    required this.coins,
    required this.icon,
    this.perDayMax,
  });

  final String key;
  final String titleTh;
  final String titleEn;
  final int coins;
  final int icon; // IconData codepoint (kept int to avoid importing material here)
  final int? perDayMax;
}
