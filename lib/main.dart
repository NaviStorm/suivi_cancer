// ===== $HOME/suivi_cancer/lib/main.dart =====
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'common/theme/app_theme.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'features/home/home_screen.dart';
import 'package:suivi_cancer/core/notifications/notification_service.dart';
import 'package:permission_handler/permission_handler.dart';

Future<void> requestPermissions() async {
  // Demande des permissions nécessaires au démarrage
  await [Permission.camera, Permission.photos, Permission.storage, Permission.notification].request();
}

void main() async {
  // Assure que les bindings Flutter sont prêts
  WidgetsFlutterBinding.ensureInitialized();

  // Initialiser les services qui ne dépendent pas de la BDD
  final notificationService = NotificationService();
  await notificationService.initialize();

  // Définir l'orientation de l'application
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Demander les permissions
  await requestPermissions();

  // Initialiser le support de la localisation pour les dates
  await initializeDateFormatting('fr_FR', null);

  // Lancer l'application
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      title: 'Suivi Cancer',
      theme: CupertinoThemeData(
        brightness: Brightness.light,
        primaryColor: CupertinoColors.systemTeal,
        scaffoldBackgroundColor: CupertinoColors.systemGroupedBackground,
      ),
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: [
        const Locale('fr', 'FR'), // Français
        const Locale('en', 'US'), // Anglais
      ],
      locale: const Locale('fr', 'FR'), // Forcer le français pour le formatage
      home: HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}