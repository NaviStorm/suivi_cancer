// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'common/theme/app_theme.dart';
import 'features/home/home_screen.dart'; // Assurez-vous que ce fichier existe
import 'core/notifications/notification_service.dart';
import 'package:suivi_cancer/core/storage/database_helper.dart';
import 'package:suivi_cancer/utils/logger.dart';
import 'package:permission_handler/permission_handler.dart';

Future<void> requestPermissions() async {
  await [
    Permission.camera,
    Permission.photos,
    Permission.storage,
  ].request();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialiser les services
  final notificationService = NotificationService();
  await notificationService.initialize();

  // Réinitialiser la base de données
  try {
    Log.d("Main: Tentative de réinitialisation de la base de données");
//    await DatabaseHelper().resetDatabase();
    final lstDocteur = await DatabaseHelper().getDoctors();

    Log.d("Main: Verification de la version slqlite");
    await DatabaseHelper().checkDatabaseVersion();
    Log.d("Main: Verification de la base de donnée");
    Log.d("Main:checkDatabaseAccess");
    await DatabaseHelper().checkDatabaseAccess();

    Log.d("Main: Fin des vérifi");
    Log.d('${lstDocteur}');
  } catch (e) {
    Log.d("Main: Erreur lors de la réinitialisation de la base de données: $e");
  }



  // Définir l'orientation de l'application
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await requestPermissions();

  initializeDateFormatting('fr_FR', null).then((_) {
    runApp(MyApp());
  });
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Suivi Cancer',
      theme: AppTheme.lightTheme,
      home: HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
