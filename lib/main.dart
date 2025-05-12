// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'common/theme/app_theme.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'features/home/home_screen.dart'; // Assurez-vous que ce fichier existe
import 'core/notifications/notification_service.dart';
import 'package:suivi_cancer/core/storage/database_helper.dart';
import 'package:suivi_cancer/utils/logger.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sqflite/sqflite.dart';
import 'package:suivi_cancer/core/storage/database_helper.dart';

Future<void> requestPermissions() async {
  await [
    Permission.camera,
    Permission.photos,
    Permission.storage,
  ].request();
}

void _initBase() async {
  await Sqflite.devSetDebugModeOn(true);
  // Vérifier si la base de données existe
  final dbPath = await getDatabasesPath();
  final path = join(dbPath, 'suivi_cancer.db');

  Log.d("Main: Verification de la version slqlite");
  await DatabaseHelper().checkDatabaseVersion();

  bool dbExists = await databaseExists(path);

  if (!dbExists) {
    // La base de données n'existe pas, on l'initialise
    Log.d("Main: Base de données non trouvée, initialisation...");
    await DatabaseHelper().database;
    Log.d("Main: Base de données initialisée avec succès");
  } else {
    // La base de données existe déjà
    Log.d("Main: Base de données existante trouvée à $path");
    // Vérifier que la connexion fonctionne
    try {
      final db = await DatabaseHelper().database;
      await db.rawQuery('SELECT 1');
      Log.d("Main: Connexion à la base de données réussie");
    } catch (e) {
      Log.e("Main: Erreur lors de la connexion à la base de données: $e");
      // En cas d'erreur, on peut tenter de réinitialiser la base
      await deleteDatabase(path);
      await DatabaseHelper().database;
      Log.d("Main: Base de données réinitialisée après erreur");
    }
  }

  Log.d("Main:checkDatabaseAccess");
  await DatabaseHelper().checkDatabaseAccess();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialiser les services
  final notificationService = NotificationService();
  await notificationService.initialize();

  // Réinitialiser la base de données
  try {
    _initBase();
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
