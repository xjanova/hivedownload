import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../state/notification_state.dart';
import 'settings_store.dart';

/// FCM push (Firebase project `netwix-online`, config in
/// android/app/google-services.json). **Topic-based**: no device-token registry
/// — the app subscribes to a topic per notification category (new_content /
/// news / other) and the backend broadcasts each admin notification to its
/// category topic. The user's in-app toggles map 1:1 to (un)subscribes, so
/// "ปิดหมวดนี้" really stops the push at FCM, not just in the UI.
class PushService {
  PushService._();

  static bool _ready = false;

  /// Initialise Firebase + ask for notification permission (Android 13+),
  /// then align topic subscriptions with the saved toggles. Never throws —
  /// push is an enhancement, not a dependency (e.g. devices without Google
  /// Play services just skip it).
  static Future<void> init(SettingsStore settings, NotificationState notifications) async {
    try {
      await Firebase.initializeApp();
      final fm = FirebaseMessaging.instance;

      await fm.requestPermission(); // no-op below Android 13

      // Route future toggle changes to FCM (see NotificationState.topicSync).
      NotificationState.topicSync = setTopic;

      // Align topics with the saved per-category toggles.
      for (final c in NotificationState.categories) {
        await setTopic(c, settings.notifyCategory(c));
      }

      // A push arriving while the app is OPEN isn't shown by the system —
      // refresh the inbox so the badge updates immediately instead.
      FirebaseMessaging.onMessage.listen((_) => notifications.refresh());
      // Tapping a system notification (app in background) also lands here.
      FirebaseMessaging.onMessageOpenedApp.listen((_) => notifications.refresh());

      _ready = true;
    } catch (e) {
      if (kDebugMode) debugPrint('push init: $e');
    }
  }

  /// Subscribe/unsubscribe a category topic. Called by the settings toggles.
  static Future<void> setTopic(String category, bool enabled) async {
    try {
      final fm = FirebaseMessaging.instance;
      if (enabled) {
        await fm.subscribeToTopic(category);
      } else {
        await fm.unsubscribeFromTopic(category);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('push topic $category: $e');
    }
  }

  static bool get isReady => _ready;
}
