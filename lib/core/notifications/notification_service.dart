// lib/core/notifications/notification_service.dart
import 'package:flutter/foundation.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  static bool _isTimeZoneConfigured = false;

  /// Configure le fuseau horaire local pour les notifications
  static Future<void> configureLocalTimeZone() async {
    if (_isTimeZoneConfigured) return; // Éviter la double initialisation

    try {
      tz_data.initializeTimeZones();
      final String timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));
      _isTimeZoneConfigured = true;

      if (kDebugMode) {
        print('Fuseau horaire configuré: ${tz.local.name}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Impossible d\'obtenir le fuseau horaire local: $e');
      }
      // Fallback sur UTC si la détection échoue
      try {
        tz.setLocalLocation(tz.getLocation('Etc/UTC'));
        _isTimeZoneConfigured = true;
      } catch (fallbackError) {
        _isTimeZoneConfigured = false;
        if (kDebugMode) {
          print('Impossible de configurer même UTC: $fallbackError');
        }
      }
    }
  }

  /// Getter pour vérifier si le fuseau horaire est configuré
  static bool get isTimeZoneConfigured => _isTimeZoneConfigured;

  /// Vérifie si les notifications peuvent être planifiées
  static bool canScheduleNotifications() {
    if (!_isTimeZoneConfigured) return false;

    try {
      tz.TZDateTime.now(tz.local);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Initialise le service de notifications
  Future<void> initialize() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
    DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _createAndroidNotificationChannel();

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: onDidReceiveNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: onDidReceiveBackgroundNotificationResponse,
    );
  }

  /// Crée un canal de notification pour Android
  Future<void> _createAndroidNotificationChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'treatment_channel',
      'Traitement',
      description: 'Notifications pour les traitements et rendez-vous',
      importance: Importance.high,
      playSound: true,
    );

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  /// Demande les permissions de notification sur iOS
  Future<bool?> requestIOSPermissions() async {
    return _notificationsPlugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  /// Demande les permissions de notification sur Android (pour Android 13+)
  Future<bool?> requestAndroidPermissions() async {
    final AndroidFlutterLocalNotificationsPlugin? platformImplementation =
    _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (platformImplementation != null) {
      return await platformImplementation.requestNotificationsPermission();
    }
    return false;
  }

  /// Planifie une notification à une date donnée
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    if (!NotificationService.isTimeZoneConfigured || !NotificationService.canScheduleNotifications()) {
      if (kDebugMode) {
        print("ERREUR: Le fuseau horaire n'est pas configuré. Appelez NotificationService.configureLocalTimeZone() dans main.dart.");
      }
      return;
    }

    try {
      final tz.TZDateTime tzScheduledDate = tz.TZDateTime.from(scheduledDate, tz.local);

      // Vérifier si la date planifiée est dans le futur
      if (tzScheduledDate.isBefore(tz.TZDateTime.now(tz.local))) {
        if (kDebugMode) {
          print("Notification (ID: $id, Titre: $title) non planifiée car la date est dans le passé: $tzScheduledDate");
        }
        return;
      }

      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tzScheduledDate,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'treatment_channel',
            'Traitement',
            channelDescription: 'Notifications pour les traitements et rendez-vous',
            importance: Importance.max,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );

      if (kDebugMode) {
        print("Notification (ID: $id, Titre: $title) planifiée pour: $tzScheduledDate");
      }
    } catch (e) {
      if (kDebugMode) {
        print("Erreur lors de la planification de la notification: $e");
      }
    }
  }

  /// Affiche une notification immédiate
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: AndroidNotificationDetails(
        'treatment_channel',
        'Traitement',
        channelDescription: 'Notifications pour les traitements et rendez-vous',
        importance: Importance.max,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _notificationsPlugin.show(
      id,
      title,
      body,
      platformChannelSpecifics,
      payload: payload,
    );
  }

  /// Annule une notification spécifique par son ID
  Future<void> cancelNotification(int id) async {
    await _notificationsPlugin.cancel(id);
    if (kDebugMode) {
      print("Notification (ID: $id) annulée.");
    }
  }

  /// Annule toutes les notifications planifiées
  Future<void> cancelAllNotifications() async {
    await _notificationsPlugin.cancelAll();
    if (kDebugMode) {
      print("Toutes les notifications ont été annulées.");
    }
  }

  /// Récupère toutes les notifications en attente
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _notificationsPlugin.pendingNotificationRequests();
  }
}

/// Callback pour gérer la réponse lorsqu'une notification est cliquée
void onDidReceiveNotificationResponse(NotificationResponse notificationResponse) {
  if (kDebugMode) {
    print('Notification cliquée (onDidReceiveNotificationResponse):');
    print('  ID: ${notificationResponse.id}');
    print('  Action ID: ${notificationResponse.actionId}');
    print('  Input: ${notificationResponse.input}');
    print('  Payload: ${notificationResponse.payload}');
    print('  Notification Type: ${notificationResponse.notificationResponseType}');
  }

  // Ajoutez ici votre logique de navigation basée sur le payload
  // Exemple :
  // final String? payload = notificationResponse.payload;
  // if (payload != null) {
  //   // Navigation vers l'écran approprié
  // }
}

/// Callback pour gérer les notifications reçues lorsque l'application est terminée
@pragma('vm:entry-point')
void onDidReceiveBackgroundNotificationResponse(NotificationResponse notificationResponse) {
  if (kDebugMode) {
    print('Notification cliquée (BACKGROUND):');
    print('  ID: ${notificationResponse.id}');
    print('  Payload: ${notificationResponse.payload}');
  }

  // N'essayez PAS de mettre à jour l'UI Flutter directement depuis cet isolate
  // Utilisez SharedPreferences ou d'autres méthodes de persistance
}
