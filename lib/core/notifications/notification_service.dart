// lib/core/notifications/notification_service.dart
import 'package:flutter/foundation.dart'; // Pour kReleaseMode si besoin de logs conditionnels
import 'package:timezone/timezone.dart' as tz;
// Attention à l'import de 'timezone/data/latest.dart'
// Il est préférable de l'importer avec un préfixe différent si vous utilisez déjà 'tz' pour timezone.dart
// ou d'utiliser 'package:timezone/data/latest_all.dart' pour inclure tous les fuseaux horaires.
// Pour cet exemple, je vais supposer que vous voulez tous les fuseaux, ce qui est plus sûr.
import 'package:timezone/data/latest_all.dart' as tz_data; // Ou latest.dart si vous filtrez les données
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart'; // Pour obtenir le fuseau horaire local


class NotificationService {
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  // Pour une initialisation correcte des fuseaux horaires, il est mieux de le faire une fois au démarrage.
  // Cette méthode peut être appelée dans main.dart
  static Future<void> configureLocalTimeZone() async {
    tz_data.initializeTimeZones(); // Initialise la base de données des fuseaux horaires
    try {
      final String timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName)); // Définit le fuseau horaire local pour le package timezone
    } catch (e) {
      if (kDebugMode) { // Affiche l'erreur seulement en mode debug
        print('Impossible d\'obtenir le fuseau horaire local via flutter_timezone: $e');
      }
      // Fallback sur UTC si la détection échoue
      tz.setLocalLocation(tz.getLocation('Etc/UTC'));
    }
  }


  Future<void> initialize() async {
    // L'initialisation des fuseaux horaires (tz_data.initializeTimeZones() et tz.setLocalLocation())
    // devrait idéalement être faite une seule fois au démarrage de l'application, par exemple dans main.dart
    // en appelant NotificationService.configureLocalTimeZone().
    // Si vous l'appelez ici, assurez-vous que ce n'est pas redondant.
    // Pour cet exemple, je vais supposer que configureLocalTimeZone a déjà été appelé.

    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher'); // Assurez-vous que ce fichier existe

    // Pour iOS, il est bon de demander les permissions explicitement
    const DarwinInitializationSettings initializationSettingsIOS =
    DarwinInitializationSettings(
      requestAlertPermission: true, // Ou false et les demander plus tard via requestIOSPermissions()
      requestBadgePermission: true,
      requestSoundPermission: true,
      // onDidReceiveLocalNotification: onDidReceiveLocalNotification, // Pour iOS < 10
    );

    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
      // macOS: DarwinInitializationSettings(...), // Si vous ciblez macOS
    );

    // Créer le canal de notification Android AVANT d'initialiser si possible,
    // ou s'assurer qu'il est créé.
    await _createAndroidNotificationChannel();

    await _notificationsPlugin.initialize(
      initializationSettings,
      // Callback quand une notification est reçue alors que l'app est au premier plan,
      // ou quand l'utilisateur tape sur une notification (app ouverte ou en arrière-plan).
      onDidReceiveNotificationResponse: onDidReceiveNotificationResponse,
      // Callback pour gérer les notifications reçues lorsque l'application est terminée (background).
      onDidReceiveBackgroundNotificationResponse: onDidReceiveBackgroundNotificationResponse,
    );
  }

  /// Crée un canal de notification pour Android (nécessaire pour Android 8.0+).
  Future<void> _createAndroidNotificationChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'treatment_channel', // ID du canal (doit correspondre à celui utilisé dans AndroidNotificationDetails)
      'Traitement',       // Nom du canal (visible par l'utilisateur dans les paramètres de l'app)
      description: 'Notifications pour les traitements et rendez-vous', // Description du canal
      importance: Importance.high, // Importance de la notification
      playSound: true,
      // sound: RawResourceAndroidNotificationSound('nom_du_son_personnalise'), // Si son personnalisé
    );

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  /// Demande les permissions de notification sur iOS.
  Future<bool?> requestIOSPermissions() async {
    return _notificationsPlugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  /// Demande les permissions de notification sur Android (pour Android 13+).
  Future<bool?> requestAndroidPermissions() async {
    final AndroidFlutterLocalNotificationsPlugin? platformImplementation =
    _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (platformImplementation != null) {
      return await platformImplementation.requestNotificationsPermission();
    }
    return false; // Si ce n'est pas Android ou si l'implémentation n'est pas trouvée
  }


  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    // S'assurer que tz.local est initialisé.
    if (tz.local == null) {
      if (kDebugMode) {
        print("ERREUR: tz.local n'est pas initialisé. Appelez NotificationService.configureLocalTimeZone() dans main.dart.");
      }
      // Vous pourriez tenter de le reconfigurer ici en fallback, mais c'est moins propre.
      // await NotificationService.configureLocalTimeZone();
      // if (tz.local == null) return; // Si toujours null, ne pas planifier
      return;
    }

    final tz.TZDateTime tzScheduledDate = tz.TZDateTime.from(scheduledDate, tz.local);

    // Vérifier si la date planifiée est dans le futur
    if (tzScheduledDate.isBefore(tz.TZDateTime.now(tz.local))) {
      if (kDebugMode) {
        print("Notification (ID: $id, Titre: $title) non planifiée car la date est dans le passé: $tzScheduledDate");
      }
      return; // Ne pas planifier une notification pour le passé
    }

    await _notificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tzScheduledDate,
      const NotificationDetails( // Rendre const si possible
        android: AndroidNotificationDetails(
          'treatment_channel', // Doit correspondre à l'ID du canal créé
          'Traitement',       // Nom du canal
          channelDescription: 'Notifications pour les traitements et rendez-vous',
          importance: Importance.max, // Utiliser Importance.max pour une visibilité maximale
          priority: Priority.high,
          // icon: '@mipmap/ic_notification', // Icône spécifique pour la notif si différente de l'icône de l'app
          // largeIcon: FilePathAndroidBitmap('chemin_vers_grande_icone'),
          // styleInformation: BigTextStyleInformation(''), // Pour texte long
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          // sound: 'custom_sound.caf', // Si son personnalisé
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle, // Pour la précision sur Android
      // DÉCOMMENTER ET UTILISER CE PARAMÈTRE OBLIGATOIRE :
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      // Pour gérer le clic sur la notification quand l'app est terminée (payload)
      // payload: 'notification_id=$id&title=$title',
      // Pour les notifications récurrentes (ex: quotidien à la même heure)
      // matchDateTimeComponents: DateTimeComponents.time,
    );
    if (kDebugMode) {
      print("Notification (ID: $id, Titre: $title) planifiée pour: $tzScheduledDate");
    }
  }

  /// Annule une notification spécifique par son ID.
  Future<void> cancelNotification(int id) async {
    await _notificationsPlugin.cancel(id);
    if (kDebugMode) {
      print("Notification (ID: $id) annulée.");
    }
  }

  /// Annule toutes les notifications planifiées.
  Future<void> cancelAllNotifications() async {
    await _notificationsPlugin.cancelAll();
    if (kDebugMode) {
      print("Toutes les notifications ont été annulées.");
    }
  }
}

// Callbacks statiques ou top-level pour la gestion des réponses aux notifications.
// Ces fonctions doivent être en dehors de la classe si elles sont utilisées comme points d'entrée
// pour le background isolate (onDidReceiveBackgroundNotificationResponse).

/// Callback pour gérer la réponse lorsqu'une notification est cliquée
/// (app ouverte, en arrière-plan, ou terminée - mais pour terminée, onDidReceiveBackgroundNotificationResponse est clé).
void onDidReceiveNotificationResponse(NotificationResponse notificationResponse) {
  if (kDebugMode) {
    print('Notification cliquée (onDidReceiveNotificationResponse):');
    print('  ID: ${notificationResponse.id}');
    print('  Action ID: ${notificationResponse.actionId}');
    print('  Input: ${notificationResponse.input}');
    print('  Payload: ${notificationResponse.payload}');
    print('  Notification Type: ${notificationResponse.notificationResponseType}');
  }
  // Mettez ici votre logique de navigation ou d'action basée sur le payload.
  // Par exemple, si le payload contient l'ID d'un traitement, naviguez vers l'écran de ce traitement.
  // final String? payload = notificationResponse.payload;
  // if (payload != null && payload.startsWith('treatment_id=')) {
  //   final treatmentId = payload.split('=')[1];
  //   // MyApp.navigatorKey.currentState?.pushNamed('/treatmentDetail', arguments: treatmentId);
  // }
}

/// Callback pour gérer les notifications reçues lorsque l'application est terminée.
/// Important: Ce callback s'exécute dans un isolate séparé sur Android.
@pragma('vm:entry-point') // Nécessaire pour que le tree shaking ne le supprime pas.
void onDidReceiveBackgroundNotificationResponse(NotificationResponse notificationResponse) {
  if (kDebugMode) {
    print('Notification cliquée (BACKGROUND - onDidReceiveBackgroundNotificationResponse):');
    print('  ID: ${notificationResponse.id}');
    print('  Payload: ${notificationResponse.payload}');
  }
  // N'essayez PAS de mettre à jour l'UI Flutter directement depuis cet isolate.
  // Vous pouvez:
  // 1. Stocker l'information (ex: SharedPreferences) pour que l'app la lise au prochain démarrage.
  // 2. Utiliser des plugins comme flutter_isolate ou des SendPort/ReceivePort pour communiquer avec l'isolate principal.
  // 3. Effectuer des tâches en arrière-plan qui n'impliquent pas l'UI.
}
