// lib/core/storage/database_helper.dart
import 'dart:async';
import 'dart:io';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:suivi_cancer/utils/logger.dart';
import 'package:path_provider/path_provider.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;
  static Completer<Database>? _dbCompleter;

  Future<Database> get database async {
    // Si la base est déjà ouverte, on la retourne immédiatement (chemin le plus rapide)
    if (_database != null && _database!.isOpen) {
      return _database!;
    }
    // Si l'initialisation n'a jamais été lancée, on la démarre
    if (_dbCompleter == null) {
      _dbCompleter = Completer<Database>();
      // On lance l'initialisation SANS l'attendre ici
      _initDatabase().then((db) {
        // Une fois terminée, on complète le Future avec la base de données
        _dbCompleter!.complete(db);
      }).catchError((e, stackTrace) {
        // En cas d'erreur, on la propage aux écouteurs et on réinitialise le completer
        _dbCompleter!.completeError(e, stackTrace);
        _dbCompleter = null; // Permet de retenter l'initialisation plus tard
      });
    }
    // On retourne le Future du Completer. Tous les appels concurrents
    // recevront le même Future et attendront sa résolution.
    _database = await _dbCompleter!.future;
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'suivi_cancer.db');

    Log.d("DatabaseHelper: Initialisation de la base de données à $path");

    // Approche simplifiée - ouvrir ou créer
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
      onOpen: (db) async {
        await db.execute('PRAGMA foreign_keys = ON;'); // Activation des clés étrangères
        Log.d("DatabaseHelper: Base de données ouverte avec succès");
      },
    );
  }

  Future _onCreate(Database db, int version) async {
    Log.d("DatabaseHelper: Création des tables de la base de données");

    await db.execute('''
      CREATE TABLE IF NOT EXISTS health_professional_categories(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        isActive INTEGER NOT NULL DEFAULT 1
      )
      ''');

    // Création de la table des professionnels de santé
    await db.execute('''
      CREATE TABLE IF NOT EXISTS health_professionals(
        id TEXT PRIMARY KEY,
        firstName TEXT NOT NULL,
        lastName TEXT NOT NULL,
        categoryId TEXT NOT NULL,
        specialtyDetails TEXT,
        notes TEXT,
        FOREIGN KEY (categoryId) REFERENCES health_professional_categories (id) ON DELETE CASCADE
      )
      ''');

    // Création de la table des contacts des professionnels de santé
    await db.execute('''
      CREATE TABLE IF NOT EXISTS health_professional_contacts(
        id TEXT PRIMARY KEY,
        healthProfessionalId TEXT NOT NULL,
        type INTEGER NOT NULL,
        value TEXT NOT NULL,
        label TEXT,
        isPrimary INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (healthProfessionalId) REFERENCES health_professionals (id) ON DELETE CASCADE
      )
      ''');

    // Création de la table des adresses des professionnels de santé
    await db.execute('''
      CREATE TABLE IF NOT EXISTS health_professional_addresses(
        id TEXT PRIMARY KEY,
        healthProfessionalId TEXT NOT NULL,
        street TEXT,
        city TEXT NOT NULL,
        postalCode TEXT,
        country TEXT DEFAULT 'France',
        label TEXT,
        isPrimary INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (healthProfessionalId) REFERENCES health_professionals (id) ON DELETE CASCADE
      )
      ''');

    // Création de la table de relation entre professionnels de santé et établissements
    await db.execute('''
      CREATE TABLE IF NOT EXISTS health_professional_establishments(
        healthProfessionalId TEXT NOT NULL,
        establishmentId TEXT NOT NULL,
        role TEXT,
        PRIMARY KEY (healthProfessionalId, establishmentId),
        FOREIGN KEY (healthProfessionalId) REFERENCES health_professionals (id) ON DELETE CASCADE,
        FOREIGN KEY (establishmentId) REFERENCES establishments (id) ON DELETE CASCADE
      )
      ''');

    // Initialisation avec les catégories courantes de professionnels de santé
    await _initializeHealthProfessionalCategories(db);

    // Table des établissements
    await db.execute('''
      CREATE TABLE establishments(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        address TEXT,
        city TEXT,
        postalCode TEXT,
        phone TEXT,
        email TEXT,
        website TEXT,
        notes TEXT
      )
    ''');
    Log.d("DatabaseHelper: Table 'establishments' créée");

    // Table des traitements
    await db.execute('''
      CREATE TABLE treatments(
        id TEXT PRIMARY KEY,
        label TEXT NOT NULL,
        startDate TEXT NOT NULL,
        endDate TEXT,
        isCompleted INTEGER NOT NULL DEFAULT 0
      )
    ''');
    Log.d("DatabaseHelper: Table 'treatments' créée");

    // Table de relation entre traitements et médecins
    await db.execute('''
      CREATE TABLE treatment_doctors(
        treatmentId TEXT NOT NULL,
        PRIMARY KEY (treatmentId),
        FOREIGN KEY (treatmentId) REFERENCES treatments (id) ON DELETE CASCADE
      )
    ''');
    Log.d("DatabaseHelper: Table 'treatment_doctors' créée");

    await db.execute('''
  CREATE TABLE IF NOT EXISTS treatment_health_professionals(
    treatmentId TEXT NOT NULL,
    healthProfessionalId TEXT NOT NULL,
    PRIMARY KEY (treatmentId, healthProfessionalId),
    FOREIGN KEY (treatmentId) REFERENCES treatments (id) ON DELETE CASCADE,
    FOREIGN KEY (healthProfessionalId) REFERENCES health_professionals (id) ON DELETE CASCADE
  )
''');
    Log.d("DatabaseHelper: Table 'treatment_health_professionals' créée");

    // Table de relation entre traitements et établissements
    await db.execute('''
      CREATE TABLE treatment_establishments(
        treatmentId TEXT NOT NULL,
        establishmentId TEXT NOT NULL,
        PRIMARY KEY (treatmentId, establishmentId),
        FOREIGN KEY (treatmentId) REFERENCES treatments (id) ON DELETE CASCADE,
        FOREIGN KEY (establishmentId) REFERENCES establishments (id) ON DELETE CASCADE
      )
    ''');
    Log.d("DatabaseHelper: Table 'treatment_establishments' créée");

    // Table des cycles
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cycles(
        id TEXT PRIMARY KEY,
        treatmentId TEXT NOT NULL,
        type INTEGER NOT NULL,
        startDate TEXT NOT NULL,
        endDate TEXT NOT NULL,
        establishmentId TEXT NOT NULL,
        sessionCount INTEGER NOT NULL,
        sessionInterval INTEGER NOT NULL,
        conclusion TEXT,
        isCompleted INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (treatmentId) REFERENCES treatments (id) ON DELETE CASCADE,
        FOREIGN KEY (establishmentId) REFERENCES establishments (id) ON DELETE CASCADE
      )
    ''');
    Log.d("DatabaseHelper: Table 'cycles' créée");

    // Table des médicaments
    await db.execute('''
      CREATE TABLE IF NOT EXISTS medications(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        quantity TEXT,
        unit TEXT,
        duration INTEGER,
        notes TEXT,
        isRinsing INTEGER NOT NULL DEFAULT 0
      )
    ''');
    Log.d("DatabaseHelper: Table 'medications' créée");

    // Table des sessions
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sessions(
        id TEXT PRIMARY KEY,
        cycleId TEXT NOT NULL,
        dateTime TEXT NOT NULL,
        establishmentId TEXT NOT NULL,
        notes TEXT,
        isCompleted INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (cycleId) REFERENCES cycles (id) ON DELETE CASCADE,
        FOREIGN KEY (establishmentId) REFERENCES establishments (id) ON DELETE CASCADE
      )
    ''');
    Log.d("DatabaseHelper: Table 'sessions' créée");

    // Table de relation entre sessions et médicaments
    await db.execute('''
      CREATE TABLE IF NOT EXISTS session_medications(
        sessionId TEXT NOT NULL,
        medicationId TEXT NOT NULL,
        PRIMARY KEY (sessionId, medicationId),
        FOREIGN KEY (sessionId) REFERENCES sessions (id) ON DELETE CASCADE,
        FOREIGN KEY (medicationId) REFERENCES medications (id) ON DELETE CASCADE
      )
    ''');
    Log.d("DatabaseHelper: Table 'session_medications' créée");

    // Table des rendez-vous
    await db.execute('''
      CREATE TABLE IF NOT EXISTS appointments(
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        dateTime TEXT NOT NULL,
        duration INTEGER,
        healthProfessionalId TEXT,
        establishmentId TEXT,
        notes TEXT,
        isCompleted INTEGER NOT NULL DEFAULT 0,
        Type TEXT NOT NULL,
        FOREIGN KEY (healthProfessionalId) REFERENCES health_professionals (id) ON DELETE SET NULL,
        FOREIGN KEY (establishmentId) REFERENCES establishments (id) ON DELETE SET NULL
      )
    ''');
    Log.d("DatabaseHelper: Table 'appointments' créée");

    await db.execute('''
        CREATE TABLE cycle_appointments(
          cycleId TEXT NOT NULL,
          appointmentId TEXT NOT NULL,
          PRIMARY KEY (cycleId, appointmentId),
          FOREIGN KEY (cycleId) REFERENCES cycles(id) ON DELETE CASCADE,
          FOREIGN KEY (appointmentId) REFERENCES appointments(id) ON DELETE CASCADE
        )
      ''');
    Log.d("DatabaseHelper: Table cycle_appointments créée avec succès");

    // Table des documents
    await db.execute('''
      CREATE TABLE IF NOT EXISTS documents(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        path TEXT NOT NULL,
        type INTEGER NOT NULL,
        dateAdded TEXT NOT NULL,
        description TEXT,
        size INTEGER
      )
    ''');
    Log.d("DatabaseHelper: Table 'documents' créée");

    // Table de relation entre documents et autres entités
    await db.execute('''
      CREATE TABLE IF NOT EXISTS entity_documents(
        documentId TEXT NOT NULL,
        entityType TEXT NOT NULL,
        entityId TEXT NOT NULL,
        PRIMARY KEY (documentId, entityType, entityId),
        FOREIGN KEY (documentId) REFERENCES documents (id) ON DELETE CASCADE
      )
    ''');
    Log.d("DatabaseHelper: Table 'entity_documents' créée");

    await db.execute('''
  CREATE TABLE side_effects(
    id TEXT PRIMARY KEY,
    entityType TEXT NOT NULL,
    entityId TEXT NOT NULL,
    date TEXT NOT NULL,
    description TEXT NOT NULL,
    severity INTEGER NOT NULL,
    notes TEXT,
    FOREIGN KEY (entityId) REFERENCES sessions (id) ON DELETE CASCADE
  )
''');
    Log.d("DatabaseHelper: Table 'side_effects' créée");

    // Modification de la table examinations pour ajouter le champ prereqForSessionId
    await db.execute('''
  CREATE TABLE IF NOT EXISTS examinations(
    id TEXT PRIMARY KEY,
    cycleId TEXT NOT NULL,
    title TEXT NOT NULL,
    type INTEGER NOT NULL,
    otherType TEXT,
    dateTime TEXT NOT NULL,
    establishmentId TEXT NOT NULL,
    prescripteurId TEXT,
    executantId TEXT,
    notes TEXT,
    isCompleted INTEGER NOT NULL DEFAULT 0,
    prereqForSessionId TEXT,
    examGroupId TEXT,
    FOREIGN KEY (cycleId) REFERENCES cycles (id) ON DELETE CASCADE,
    FOREIGN KEY (establishmentId) REFERENCES establishments (id) ON DELETE CASCADE,
    FOREIGN KEY (prescripteurId) REFERENCES health_professionals (id) ON DELETE SET NULL,
    FOREIGN KEY (executantId) REFERENCES health_professionals (id) ON DELETE SET NULL,
    FOREIGN KEY (prereqForSessionId) REFERENCES sessions (id) ON DELETE SET NULL
  )
''');
    Log.d("DatabaseHelper: Table 'examinations' créée");

    await db.execute('''
      CREATE TABLE medication_intakes(
        id TEXT PRIMARY KEY,
        dateTime TEXT NOT NULL,
        cycleId TEXT NOT NULL,
        isCompleted INTEGER NOT NULL DEFAULT 0,
        notes TEXT,
        FOREIGN KEY (cycleId) REFERENCES cycles (id) ON DELETE CASCADE
      )
    ''');
    Log.d("DatabaseHelper: Table 'medication_intakes' créée");

    await db.execute('''
      CREATE TABLE medication_intake_items(
        id TEXT PRIMARY KEY,
        intakeId TEXT NOT NULL,
        medicationId TEXT NOT NULL,
        medicationName TEXT NOT NULL,
        quantity INTEGER NOT NULL DEFAULT 1,
        FOREIGN KEY (intakeId) REFERENCES medication_intakes (id) ON DELETE CASCADE,
        FOREIGN KEY (medicationId) REFERENCES medications (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE measure (
        id TEXT PRIMARY KEY,
        cycleId TEXT NOT NULL,
        type TEXT NOT NULL,
        weight REAL,
        heartRate INTEGER,
        spo2 REAL,
        temperature REAL,
        systolicBP INTEGER,
        diastolicBP INTEGER,
        date TEXT NOT NULL,
        unit TEXT NOT NULL,
        note TEXT
      )
    ''');
    Log.d("DatabaseHelper: Table 'measure' créée");

    await db.execute('''
        CREATE TABLE cycle_measure(
          cycleId TEXT NOT NULL,
          measureId TEXT NOT NULL,
          PRIMARY KEY (cycleId, measureId),
          FOREIGN KEY (cycleId) REFERENCES cycles(id) ON DELETE CASCADE,
          FOREIGN KEY (measureId) REFERENCES measure(id) ON DELETE CASCADE
        )
      ''');
    Log.d("DatabaseHelper: Table cycle_measure créée avec succès");
  }

  // Méthodes pour les établissements
  Future<List<Map<String, dynamic>>> getEstablishments() async {
    final db = await database;
    return await db.query('establishments');
  }

  Future<Map<String, dynamic>?> getEstablishment(String id) async {
    Log.d("Recherche de l'établissement avec ID: $id");
    final db = await database;
    try {
      final results = await db.query(
        'establishments',
        where: 'id = ?',
        whereArgs: [id],
      );

      Log.d("Résultat de la requête établissement: $results");

      if (results.isNotEmpty) {
        return results.first;
      }

      Log.d("Établissement non trouvé pour ID: $id");
      return null;
    } catch (e) {
      Log.d("Erreur lors de la recherche de l'établissement: $e");
      return null;
    }
  }

  Future<int> insertEstablishment(Map<String, dynamic> establishment) async {
    Log.d('Insertion de l\'établissement : [${establishment.toString()}]');
    final db = await database;
    return await db.insert(
      'establishments',
      establishment,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> updateEstablishment(Map<String, dynamic> establishment) async {
    try {
      Log.d(
        "DatabaseHelper: Mise à jour d'un établissement avec ID: ${establishment['id']}",
      );
      final db = await database;
      final result = await db.update(
        'establishments',
        establishment,
        where: 'id = ?',
        whereArgs: [establishment['id']],
      );
      Log.d(
        "DatabaseHelper: Établissement mis à jour avec succès, lignes affectées: $result",
      );
      return result;
    } catch (e) {
      Log.d(
        "DatabaseHelper: Erreur lors de la mise à jour de l'établissement: $e",
      );
      return -1;
    }
  }

  Future<int> deleteEstablishment(String id) async {
    try {
      Log.d("DatabaseHelper: Suppression de l'établissement avec ID $id");
      final db = await database;

      // Vérifier d'abord si l'établissement existe
      final List<Map<String, dynamic>> check = await db.query(
        'establishments',
        where: 'id = ?',
        whereArgs: [id],
      );

      if (check.isEmpty) {
        Log.d("DatabaseHelper: Établissement introuvable avec ID $id");
        return 0;
      }

      // Supprimer les relations avec les traitements
      await db.delete(
        'treatment_establishments',
        where: 'establishmentId = ?',
        whereArgs: [id],
      );

      // Mettre à null les références dans les cycles
      await db.update(
        'cycles',
        {'establishmentId': null},
        where: 'establishmentId = ?',
        whereArgs: [id],
      );

      // Enfin, supprimer l'établissement
      final result = await db.delete(
        'establishments',
        where: 'id = ?',
        whereArgs: [id],
      );

      Log.d(
        "DatabaseHelper: Établissement supprimé avec succès, lignes affectées: $result",
      );
      return result;
    } catch (e) {
      Log.d(
        "DatabaseHelper: Erreur lors de la suppression de l'établissement: $e",
      );
      return -1;
    }
  }

  // Méthodes pour les traitements
  Future<List<Map<String, dynamic>>> getTreatments() async {
    final db = await database;
    return await db.query('treatments');
  }

  Future<Map<String, dynamic>?> getTreatment(String id) async {
    final db = await database;
    final results = await db.query(
      'treatments',
      where: 'id = ?',
      whereArgs: [id],
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<int> insertTreatment(Map<String, dynamic> treatment) async {
    final db = await database;
    return await db.insert(
      'treatments',
      treatment,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> updateTreatment(Map<String, dynamic> treatment) async {
    final db = await database;
    return await db.update(
      'treatments',
      treatment,
      where: 'id = ?',
      whereArgs: [treatment['id']],
    );
  }

  Future<int> deleteTreatment(String id) async {
    final db = await database;
    return await db.delete('treatments', where: 'id = ?', whereArgs: [id]);
  }

  // Méthodes pour les relations
  Future<int> linkTreatmentDoctor(String treatmentId, String doctorId) async {
    final db = await database;
    return await db.insert('treatment_doctors', {
      'treatmentId': treatmentId,
      'doctorId': doctorId,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> linkTreatmentHealthProfessional(
    String treatmentId,
    String healthProfessionalId,
  ) async {
    final db = await database;
    return await db.insert(
      'treatment_health_professionals',
      {
        'treatmentId': treatmentId,
        'healthProfessionalId': healthProfessionalId,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> linkTreatmentEstablishment(
    String treatmentId,
    String establishmentId,
  ) async {
    final db = await database;
    return await db.insert('treatment_establishments', {
      'treatmentId': treatmentId,
      'establishmentId': establishmentId,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> unlinkTreatmentDoctor(String treatmentId, String doctorId) async {
    final db = await database;
    return await db.delete(
      'treatment_doctors',
      where: 'treatmentId = ? AND doctorId = ?',
      whereArgs: [treatmentId, doctorId],
    );
  }

  Future<int> unlinkTreatmentEstablishment(
    String treatmentId,
    String establishmentId,
  ) async {
    final db = await database;
    return await db.delete(
      'treatment_establishments',
      where: 'treatmentId = ? AND establishmentId = ?',
      whereArgs: [treatmentId, establishmentId],
    );
  }

  Future<int> unlinkTreatmentHealthProfessional(
    String treatmentId,
    String healthProfessionalId,
  ) async {
    final db = await database;
    return await db.delete(
      'treatment_health_professionals',
      where: 'treatmentId = ? AND healthProfessionalId = ?',
      whereArgs: [treatmentId, healthProfessionalId],
    );
  }

  Future<List<Map<String, dynamic>>> getTreatmentHealthProfessionals(
    String treatmentId,
  ) async {
    final db = await database;
    return await db.rawQuery(
      '''
    SELECT hp.* FROM health_professionals hp
    INNER JOIN treatment_health_professionals thp ON hp.id = thp.healthProfessionalId
    WHERE thp.treatmentId = ?
  ''',
      [treatmentId],
    );
  }

  Future<List<Map<String, dynamic>>> getTreatmentEstablishments(
    String treatmentId,
  ) async {
    final db = await database;
    return await db.rawQuery(
      '''
      SELECT e.* FROM establishments e
      INNER JOIN treatment_establishments te ON e.id = te.establishmentId
      WHERE te.treatmentId = ?
    ''',
      [treatmentId],
    );
  }

  Future<Database> getReadableDatabase() async {
    return await database;
  }

  Future<Database> getWritableDatabase() async {
    return await database;
  }

  Future<void> resetDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'suivi_cancer.db');

    // Supprimer la base de données existante
    await deleteDatabase(path);

    // Réinitialiser la référence à la base de données
    _database = null;

    // Ouvrir une nouvelle base de données (cela déclenchera onCreate)
    await database;
  }

  Future<void> checkDatabase() async {
    final db = await openDatabase('suivi_cancer.db');

    // Vérifier les tables existantes
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table'",
    );
    for (var table in tables) {
      Log.d("Table trouvée: ${table['name']}");
    }

    // Essayer de compter les entrées
    try {
      final count = await db.rawQuery("SELECT COUNT(*) FROM doctors");
      Log.d("Nombre d'entrées dans doctors: $count");
    } catch (e) {
      Log.d("Erreur lors de l'accès à la table doctors: $e");
    }

    await db.close();
  }

  Future<void> checkDatabaseVersion() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'suivi_cancer.db');

    final db = await openDatabase(path);
    final version = await db.getVersion();
    Log.d(
      "Version actuelle de la base de données: $version dbPath:[${dbPath.toString()}] path:[${path.toString()}]",
    );

    await db.close();
  }

  Future<void> verifyDatabaseSetup() async {
    final db = await database;

    // Vérifier les tables
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table'",
    );
    Log.d("Tables dans la base de données:");
    for (var table in tables) {
      Log.d("- ${table['name']}");
    }

    // Vérifier la structure de la table doctors
    final columns = await db.rawQuery("PRAGMA table_info(doctors)");
    Log.d("Structure de la table doctors:");
    for (var column in columns) {
      Log.d("- ${column['name']} (${column['type']})");
    }
  }

  Future<int> insertSideEffect(Map<String, dynamic> sideEffect) async {
    Log.d("DatabaseHelper: Insertion d'un effet secondaire: $sideEffect");
    final db = await database;
    try {
      final result = await db.insert(
        'side_effects',
        sideEffect,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      Log.d(
        "DatabaseHelper: Effet secondaire inséré avec succès, résultat: $result",
      );
      return result;
    } catch (e) {
      Log.d(
        "DatabaseHelper: Erreur lors de l'insertion de l'effet secondaire: $e",
      );
      return -1;
    }
  }

  // Récupérer tous les effets secondaires pour une entité spécifique
  Future<List<Map<String, dynamic>>> getSideEffectsForEntity(
    String entityType,
    String entityId,
  ) async {
    Log.d(
      "DatabaseHelper: Récupération des effets secondaires pour $entityType avec ID $entityId",
    );
    final db = await database;
    try {
      final results = await db.query(
        'side_effects',
        where: 'entityType = ? AND entityId = ?',
        whereArgs: [entityType, entityId],
        orderBy: 'date DESC',
      );
      Log.d("DatabaseHelper: ${results.length} effets secondaires récupérés");
      return results;
    } catch (e) {
      Log.d(
        "DatabaseHelper: Erreur lors de la récupération des effets secondaires: $e",
      );
      return [];
    }
  }

  // Mettre à jour un effet secondaire
  Future<int> updateSideEffect(Map<String, dynamic> sideEffect) async {
    Log.d(
      "DatabaseHelper: Mise à jour de l'effet secondaire avec ID ${sideEffect['id']}",
    );
    final db = await database;
    try {
      final result = await db.update(
        'side_effects',
        sideEffect,
        where: 'id = ?',
        whereArgs: [sideEffect['id']],
      );
      Log.d(
        "DatabaseHelper: Effet secondaire mis à jour avec succès, lignes affectées: $result",
      );
      return result;
    } catch (e) {
      Log.d(
        "DatabaseHelper: Erreur lors de la mise à jour de l'effet secondaire: $e",
      );
      return -1;
    }
  }

  // Supprimer un effet secondaire
  Future<int> deleteSideEffect(String id) async {
    Log.d("DatabaseHelper: Suppression de l'effet secondaire avec ID $id");
    final db = await database;
    try {
      final result = await db.delete(
        'side_effects',
        where: 'id = ?',
        whereArgs: [id],
      );
      Log.d(
        "DatabaseHelper: Effet secondaire supprimé avec succès, lignes affectées: $result",
      );
      return result;
    } catch (e) {
      Log.d(
        "DatabaseHelper: Erreur lors de la suppression de l'effet secondaire: $e",
      );
      return -1;
    }
  }

  Future<void> checkDatabaseAccess() async {
    try {
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, 'suivi_cancer.db');

      // Vérifier si le fichier existe
      final exists = await databaseExists(path);
      Log.d("Le fichier de base de données existe : $exists");

      // Vérifier les permissions du fichier
      if (exists) {
        try {
          final db = await openDatabase(path, readOnly: false);
          await db.execute("SELECT 1");
          Log.d("La base de données peut être ouverte en lecture/écriture");
          await db.close();
        } catch (e) {
          Log.d("cacth : ${e.toString()}");
          if (!e.toString().contains("not an error")) {
            Log.d("Erreur lors de l'ouverture de la base de données : $e");
          } else {
            Log.d(
              "La base de données peut être ouverte en lecture/écriture (ignoré faux positif)",
            );
          }
        }
      }
    } catch (e) {
      Log.d("Erreur lors de la vérification de la base de données : $e");
    }
  }

  Future<List<Map<String, dynamic>>> getSessionsByCycle(String cycleId) async {
    final db = await database;

    // Ajouter un log pour vérifier l'ID du cycle utilisé dans la requête
    Log.d("Requête des séances pour le cycle ID : $cycleId");

    try {
      final results = await db.query(
        'sessions',
        where: 'cycleId = ?',
        whereArgs: [cycleId],
      );

      Log.d("Nombre de résultats de la requête : ${results.length}");

      if (results.isEmpty) {
        // Vérifier si le cycle existe
        final cycleCheck = await db.query(
          'cycles',
          where: 'id = ?',
          whereArgs: [cycleId],
        );
        Log.d("Le cycle existe-t-il ? ${cycleCheck.isNotEmpty}");

        // Vérifier les séances existantes (pour déboguer)
        final allSessions = await db.query('sessions');
        Log.d("Toutes les séances dans la base : ${allSessions.length}");
        for (var session in allSessions) {
          Log.d("Session cycleId: ${session['cycleId']}");
        }
      }

      Log.d("results : $results");
      return results;
    } catch (e) {
      Log.d("Erreur lors de la requête des séances : $e");
      return [];
    }
  }

  // Méthodes pour les cycles
  Future<Map<String, dynamic>?> getCycle(String id) async {
    final db = await database;

    Log.d("Récupération du cycle avec ID : $id");

    final results = await db.query('cycles', where: 'id = ?', whereArgs: [id]);

    Log.d("Résultat de la requête cycle : $results");

    if (results.isNotEmpty) {
      return results.first;
    }

    return null;
  }

  Future<int> insertCycle(Map<String, dynamic> cycle) async {
    final db = await database;
    return await db.insert('cycles', cycle);
  }

  Future<int> updateCycle(Map<String, dynamic> cycle) async {
    final db = await database;
    return await db.update(
      'cycles',
      cycle,
      where: 'id = ?',
      whereArgs: [cycle['id']],
    );
  }

  Future<int> deleteCycle(String id) async {
    final db = await database;
    final String fichier;

    return 0;
    // Recherche des examens
    /*
    fichier = await db.rawQuery(
      '''
      SELECT d.path
      FROM documents d
      WHERE c.treatmentId = ?
      ORDER BY c.startDate
    ''',
      [id],
    );


    db.delete('treatment_establishments', where: 'treatmentId = ?', whereArgs: [id]);
    db.delete('treatment_health_professionals', where: 'treatmentId = ?', whereArgs: [id]);
    db.delete('treatments', where: 'treatmentId = ?', whereArgs: [id]);
    db.delete('treatments', where: 'treatmentId = ?', whereArgs: [id]);
    return await db.delete('cycles', where: 'id = ?', whereArgs: [id]);
 */
  }

  Future<void> deleteTreatmentAndAllItsDependenciesFromCycle(String cycleIdToDelete,) async {
    final db = await database;
    Log.d("DatabaseHelper: Début de la suppression complète du traitement basé sur le cycle $cycleIdToDelete.",);
    // Liste pour stocker les IDs des appointments à supprimer explicitement car ne focntionne pas le on delete cascade
    List<String> appointmentIdsToDeleteExplicitly = [];

    await db
        .transaction((txn) async {
      // --- Étape 1: Récupérer l'ID du traitement associé au cycle donné ---
      final cycleInfoList = await txn.query(
        'cycles',
        columns: ['treatmentId'],
        where: 'id = ?',
        whereArgs: [cycleIdToDelete],
      );
      if (cycleInfoList.isEmpty) {
        Log.w(
          "DatabaseHelper: Cycle $cycleIdToDelete non trouvé. Aucune suppression effectuée.",
        );
        return;
      }
      final treatmentId = cycleInfoList.first['treatmentId'] as String;
      Log.d(
        "DatabaseHelper: Le cycle $cycleIdToDelete appartient au traitement $treatmentId. Poursuite de la suppression du traitement complet.",
      );

      // --- Étape 2: Collecter les IDs de toutes les entités dépendantes du TRAITEMENT qui pourraient avoir des documents ---
      // Cette liste contiendra des maps {'id': entityId, 'type': entityType}
      List<Map<String, String>> entitiesWithPotentialDocuments = [
        {'id': treatmentId, 'type': 'treatment'}, // Le traitement lui-même
      ];

      // Tous les Cycles du traitement et leurs sous-dépendances
      final allCyclesOfTreatment = await txn.query(
        'cycles',
        columns: ['id'],
        where: 'treatmentId = ?',
        whereArgs: [treatmentId],
      );
      for (final cycleMap in allCyclesOfTreatment) {
        final cycleId = cycleMap['id'] as String;
        entitiesWithPotentialDocuments.add({
          'id': cycleId,
          'type': 'cycle',
        });

        // Sessions du cycle
        final sessions = await txn.query(
          'sessions',
          columns: ['id'],
          where: 'cycleId = ?',
          whereArgs: [cycleId],
        );
        for (final sessionMap in sessions) {
          entitiesWithPotentialDocuments.add({
            'id': sessionMap['id'] as String,
            'type': 'session',
          });
          // Si les side_effects sont liés par entityType='session' et entityId=session.id
          // et que side_effects peut avoir des documents (via entity_documents)
          // entitiesWithPotentialDocuments.add({'id': sessionMap['id'] as String, 'type': 'side_effect_source'}); // ou un type plus spécifique
        }

        // Examinations du cycle
        final examinations = await txn.query(
          'examinations',
          columns: ['id'],
          where: 'cycleId = ?',
          whereArgs: [cycleId],
        );
        for (final examMap in examinations) {
          entitiesWithPotentialDocuments.add({
            'id': examMap['id'] as String,
            'type': 'examination',
          });
        }

        // Appointments liés au cycle
        final cycleAppointments = await txn.query(
          'cycle_appointments',
          columns: ['appointmentId'],
          where: 'cycleId = ?',
          whereArgs: [cycleId],
        );
        for (final caMap in cycleAppointments) {
          entitiesWithPotentialDocuments.add({
            'id': caMap['appointmentId'] as String,
            'type': 'appointment',
          });
        }

        // MedicationIntakes du cycle
        final medicationIntakes = await txn.query(
          'medication_intakes',
          columns: ['id'],
          where: 'cycleId = ?',
          whereArgs: [cycleId],
        );
        for (final miMap in medicationIntakes) {
          entitiesWithPotentialDocuments.add({
            'id': miMap['id'] as String,
            'type': 'medication_intake',
          });
          // Les medication_intake_items sont des sous-détails, généralement pas des entités avec documents propres
        }

        // Measures liées au cycle (si elles peuvent avoir des documents via entity_documents)
        final measures = await txn.query(
          'measure',
          columns: ['id'],
          where: 'cycleId = ?',
          whereArgs: [cycleId],
        );
        for (final measureMap in measures) {
          entitiesWithPotentialDocuments.add({
            'id': measureMap['id'] as String,
            'type': 'measure',
          });
        }
      }

      // Collecter les appointments liés à ce cycle pour suppression explicite et suppression de leurs documents
      final cycleAppointmentsLinks = await txn.query('cycle_appointments', columns: ['appointmentId'], where: 'cycleId = ?', whereArgs: [cycleIdToDelete]);
      for (final caMap in cycleAppointmentsLinks) {
        final appointmentId = caMap['appointmentId'] as String;
        if (!appointmentIdsToDeleteExplicitly.contains(appointmentId)) {
          appointmentIdsToDeleteExplicitly.add(appointmentId);
        }
        // On ajoute aussi à entitiesWithPotentialDocuments pour la suppression des documents
        entitiesWithPotentialDocuments.add({'id': appointmentId, 'type': 'appointment'});
      }

      // --- Étape 3: Collecter les ID et chemins de tous les documents uniques associés ---
      Set<String> uniqueDocumentIds = {};
      List<Map<String, String>> documentsToDelete =
      []; // Contiendra {'id': docId, 'path': filePath}

      for (final entityInfo in entitiesWithPotentialDocuments) {
        final entityId = entityInfo['id']!;
        final entityType = entityInfo['type']!;

        final docLinks = await txn.query(
          'entity_documents',
          columns: ['documentId'],
          where: 'entityId = ? AND entityType = ?',
          whereArgs: [entityId, entityType],
        );

        for (final link in docLinks) {
          final docId = link['documentId'] as String;
          if (uniqueDocumentIds.add(docId)) {
            final docDetailsList = await txn.query(
              'documents',
              columns: ['path'],
              where: 'id = ?',
              whereArgs: [docId],
              limit: 1,
            );
            if (docDetailsList.isNotEmpty) {
              final path = docDetailsList.first['path'] as String?;
              if (path != null && path.isNotEmpty) {
                documentsToDelete.add({'id': docId, 'path': path});
              } else {
                documentsToDelete.add({'id': docId, 'path': ''});
              }
            }
          }
        }
      }

      // --- Étape 4: Supprimer les fichiers physiques et les enregistrements de documents ---
      final appDir = await getApplicationDocumentsDirectory();

      for (final docInfo in documentsToDelete) {
        final docId = docInfo['id']!;
        final filePath = "${appDir.path}/${docInfo['path']!}";

        await txn.delete(
          'entity_documents',
          where: 'documentId = ?',
          whereArgs: [docId],
        );
        Log.d(
          "DatabaseHelper: Liaisons entity_documents pour $docId supprimées.",
        );

        await txn.delete('documents', where: 'id = ?', whereArgs: [docId]);
        Log.d(
          "DatabaseHelper: Enregistrement document $docId supprimé de la DB.",
        );

        if (filePath.isNotEmpty) {
          try {
            final file = File(filePath);
            if (await file.exists()) {
              await file.delete();
              Log.d(
                "DatabaseHelper: Fichier physique $filePath supprimé pour document $docId.",
              );
            } else {
              Log.d(
                "DatabaseHelper: Fichier physique $filePath non trouvé pour document $docId.",
              );
            }
          } catch (e) {
            Log.e(
              "DatabaseHelper: Erreur lors de la suppression du fichier physique $filePath pour $docId: $e.",
            );
          }
        } else {
          Log.d(
            "DatabaseHelper: Pas de chemin de fichier pour document $docId.",
          );
        }
      }

      for (final appointmentId in appointmentIdsToDeleteExplicitly) {
        Log.d("DatabaseHelper: Suppression explicite de l'appointment $appointmentId.");
        await txn.delete('appointments', where: 'id = ?', whereArgs: [appointmentId]);
      }

      // --- Étape 5: Supprimer l'enregistrement du traitement principal ---
      // Grâce aux contraintes ON DELETE CASCADE, cela devrait supprimer :
      // - Tous les cycles liés au traitement (y compris celui donné, cycleIdToDelete).
      // - Toutes les sessions liées à ces cycles.
      // - Toutes les examinations liées à ces cycles.
      // - Toutes les medication_intakes (et medication_intake_items par cascade) liées à ces cycles.
      // - Toutes les cycle_appointments (et potentiellement appointments si ON DELETE CASCADE est sur appointments.id).
      // - Toutes les cycle_measure (et potentiellement measures si ON DELETE CASCADE).
      // - Toutes les tables de jonction liées au traitement (treatment_doctors, treatment_health_professionals, treatment_establishments).
      //
      // La suppression des side_effects se fera si sessions.id a ON DELETE CASCADE vers side_effects.entityId.
      // La suppression des session_medications se fera si sessions.id a ON DELETE CASCADE vers session_medications.sessionId.

      final deletedRows = await txn.delete(
        'treatments',
        where: 'id = ?',
        whereArgs: [treatmentId],
      );
      Log.d(
        "DatabaseHelper: Traitement $treatmentId et toutes ses dépendances (y compris le cycle $cycleIdToDelete) supprimés. Lignes affectées pour 'treatments': $deletedRows.",
      );

      if (deletedRows == 0) {
        Log.w(
          "DatabaseHelper: Aucun traitement trouvé avec l'ID $treatmentId pour suppression.",
        );
      }
    })
        .catchError((e, stackTrace) {
      Log.e(
        "DatabaseHelper: Erreur lors de la transaction de suppression du traitement basé sur le cycle $cycleIdToDelete: $e\nStackTrace: $stackTrace",
      );
      throw e;
    });

    Log.d(
      "DatabaseHelper: Suppression du traitement basé sur le cycle $cycleIdToDelete (potentiellement) terminée.",
    );
  }


  Future<void> deleteFullTreatmentAndDependencies(String treatmentId) async {
    final db = await database;
    Log.d(
      "DatabaseHelper: Début de la suppression complète du traitement $treatmentId et de ses dépendances.",
    );

    await db
        .transaction((txn) async {
          // --- Étape 1: Collecter les IDs de toutes les entités dépendantes qui pourraient avoir des documents ---
          // Cette liste contiendra des maps {'id': entityId, 'type': entityType}
          List<Map<String, String>> entitiesWithPotentialDocuments = [
            {'id': treatmentId, 'type': 'treatment'},
          ];

          // Cycles et leurs sous-dépendances
          final cycles = await txn.query(
            'cycles',
            columns: ['id'],
            where: 'treatmentId = ?',
            whereArgs: [treatmentId],
          );
          for (final cycleMap in cycles) {
            final cycleId = cycleMap['id'] as String;
            entitiesWithPotentialDocuments.add({
              'id': cycleId,
              'type': 'cycle',
            });

            final sessions = await txn.query(
              'sessions',
              columns: ['id'],
              where: 'cycleId = ?',
              whereArgs: [cycleId],
            );
            for (final sessionMap in sessions) {
              entitiesWithPotentialDocuments.add({
                'id': sessionMap['id'] as String,
                'type': 'session',
              });
            }

            final examinations = await txn.query(
              'examinations',
              columns: ['id'],
              where: 'cycleId = ?',
              whereArgs: [cycleId],
            );
            for (final examMap in examinations) {
              entitiesWithPotentialDocuments.add({
                'id': examMap['id'] as String,
                'type': 'examination',
              });
            }

            // Rendez-vous liés aux cycles
            final cycleAppointments = await txn.query(
              'cycle_appointments',
              columns: ['appointmentId'],
              where: 'cycleId = ?',
              whereArgs: [cycleId],
            );
            for (final caMap in cycleAppointments) {
              // On considère que si un cycle est supprimé, les documents des RDV qui lui sont spécifiquement liés via ce cycle
              // doivent aussi être considérés (même si le RDV lui-même peut persister s'il a d'autres liens).
              // Cependant, la suppression de documents pour des RDV qui pourraient exister hors traitement est délicate.
              // Pour une suppression stricte des dépendances *du traitement*, on inclut les documents des RDV liés au cycle.
              entitiesWithPotentialDocuments.add({
                'id': caMap['appointmentId'] as String,
                'type': 'appointment',
              });
            }
          }

          // --- Étape 2: Collecter les ID et chemins de tous les documents uniques associés ---
          Set<String> uniqueDocumentIds = {};
          List<Map<String, String>> documentsToDelete =
              []; // Contiendra {'id': docId, 'path': filePath}

          for (final entityInfo in entitiesWithPotentialDocuments) {
            final entityId = entityInfo['id']!;
            final entityType = entityInfo['type']!;

            final docLinks = await txn.query(
              'entity_documents',
              columns: ['documentId'],
              where: 'entityId = ? AND entityType = ?',
              whereArgs: [entityId, entityType],
            );

            for (final link in docLinks) {
              final docId = link['documentId'] as String;
              if (uniqueDocumentIds.add(docId)) {
                // Ajoute seulement si pas déjà présent, et continue si c'est un nouveau docId
                final docDetailsList = await txn.query(
                  'documents',
                  columns: ['path'],
                  where: 'id = ?',
                  whereArgs: [docId],
                  limit: 1,
                );
                if (docDetailsList.isNotEmpty) {
                  final path = docDetailsList.first['path'] as String?;
                  if (path != null && path.isNotEmpty) {
                    documentsToDelete.add({'id': docId, 'path': path});
                  } else {
                    // Document sans chemin, on le supprimera de la DB uniquement
                    documentsToDelete.add({
                      'id': docId,
                      'path': '',
                    }); // Marquer le chemin comme vide
                  }
                }
              }
            }
          }

          // --- Étape 3: Supprimer les fichiers physiques et les enregistrements de documents ---
          for (final docInfo in documentsToDelete) {
            final docId = docInfo['id']!;
            final filePath = docInfo['path']!;

            // Supprimer les liaisons dans entity_documents pour ce documentId
            await txn.delete(
              'entity_documents',
              where: 'documentId = ?',
              whereArgs: [docId],
            );
            Log.d(
              "DatabaseHelper: Liaisons entity_documents pour $docId supprimées (transaction globale).",
            );

            // Supprimer l'enregistrement de la table documents
            await txn.delete('documents', where: 'id = ?', whereArgs: [docId]);
            Log.d(
              "DatabaseHelper: Enregistrement document $docId supprimé de la DB (transaction globale).",
            );

            // Supprimer le fichier physique s'il a un chemin valide
            if (filePath.isNotEmpty) {
              try {
                final file = File(filePath);
                if (await file.exists()) {
                  await file.delete();
                  Log.d(
                    "DatabaseHelper: Fichier physique $filePath supprimé pour document $docId.",
                  );
                } else {
                  Log.d(
                    "DatabaseHelper: Fichier physique $filePath non trouvé pour document $docId.",
                  );
                }
              } catch (e) {
                Log.e(
                  "DatabaseHelper: Erreur lors de la suppression du fichier physique $filePath pour $docId: $e. L'enregistrement DB a été supprimé.",
                );
                // On continue même si la suppression du fichier échoue pour ne pas bloquer la suppression du reste.
              }
            } else {
              Log.d(
                "DatabaseHelper: Pas de chemin de fichier pour document $docId ou chemin vide, fichier non supprimé.",
              );
            }
          }

          // --- Étape 4: Supprimer l'enregistrement du traitement principal ---
          // Grâce aux contraintes ON DELETE CASCADE, cela devrait supprimer les cycles, sessions, chirurgies,
          // et toutes leurs sous-dépendances directes (comme session_medications, etc.).
          final deletedRows = await txn.delete(
            'treatments',
            where: 'id = ?',
            whereArgs: [treatmentId],
          );
          Log.d(
            "DatabaseHelper: Traitement $treatmentId supprimé de la DB. Lignes affectées: $deletedRows.",
          );

          if (deletedRows == 0) {
            Log.w(
              "DatabaseHelper: Aucun traitement trouvé avec l'ID $treatmentId pour suppression lors de la transaction.",
            );
            // Vous pourriez vouloir gérer ce cas, par exemple en ne considérant pas cela comme une erreur si le but est de s'assurer qu'il n'existe plus.
          }
        })
        .catchError((e, stackTrace) {
          // Ajout de stackTrace pour un meilleur débogage
          Log.e(
            "DatabaseHelper: Erreur lors de la transaction de suppression complète du traitement $treatmentId: $e\nStackTrace: $stackTrace",
          );
          // Propager l'erreur pour que l'appelant sache que l'opération a échoué.
          throw e;
        });

    Log.d(
      "DatabaseHelper: Suppression complète du traitement $treatmentId (potentiellement) terminée.",
    );
  }

  Future<List<Map<String, dynamic>>> getCyclesByTreatment(
    String treatmentId,
  ) async {
    final db = await database;
    return await db.rawQuery(
      '''
      SELECT c.*
      FROM cycles c
      WHERE c.treatmentId = ?
      ORDER BY c.startDate
    ''',
      [treatmentId],
    );
  }

  // 1. Modification de la méthode insertSession pour prendre en compte tous les champs nécessaires
  Future<int> insertSession(Map<String, dynamic> session) async {
    final db = await database;
    try {
      Log.d("DatabaseHelper: Insertion d'une session: ${session['id']}");
      final id = await db.insert(
        'sessions',
        session,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      Log.d("DatabaseHelper: Session insérée avec succès, résultat: $id");
      return id;
    } catch (e) {
      Log.d('DatabaseHelper: Erreur lors de l\'insertion de la session: $e');
      return -1;
    }
  }

  Future<int> updateSession(Map<String, dynamic> session) async {
    final db = await database;
    return await db.update(
      'sessions',
      session,
      where: 'id = ?',
      whereArgs: [session['id']],
    );
  }

  Future<List<Map<String, dynamic>>> getSessionMedications(
    String sessionId,
  ) async {
    final db = await database;
    return await db.rawQuery(
      '''
    SELECT m.* FROM medications m
    INNER JOIN session_medications sm ON m.id = sm.medicationId
    WHERE sm.sessionId = ?
  ''',
      [sessionId],
    );
  }

  Future<int> linkSessionMedication(
    String sessionId,
    String medicationId,
  ) async {
    final db = await database;
    return await db.insert('session_medications', {
      'sessionId': sessionId,
      'medicationId': medicationId,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getEstablishmentsByTreatment(
    String treatmentId,
  ) async {
    final db = await database;
    return await db.rawQuery(
      '''
    SELECT e.*
    FROM establishments e
    JOIN treatment_establishments te ON e.id = te.establishmentId
    WHERE te.treatmentId = ?
    ORDER BY e.name
  ''',
      [treatmentId],
    );
  }

  // Fonction pour récupérer les effets secondaires par entité
  Future<List<Map<String, dynamic>>> getSideEffectsByEntity(
    String entityType,
    String entityId,
  ) async {
    final db = await database;
    return await db.query(
      'side_effects',
      where: 'entityType = ? AND entityId = ?',
      whereArgs: [entityType, entityId],
      orderBy: 'date DESC',
    );
  }

  // Fonction pour supprimer une session
  Future<int> deleteSession(String id) async {
    final db = await database;
    return await db.delete('sessions', where: 'id = ?', whereArgs: [id]);
  }

  // Méthodes mises à jour pour la gestion des radiothérapies avec relations

  /// Récupère tous les médicaments disponibles
  Future<List<Map<String, dynamic>>> getMedications() async {
    final db = await database;
    try {
      final results = await db.query('medications', orderBy: 'name ASC');
      return results;
    } catch (e) {
      Log.d("Erreur lors de la récupération des médicaments: $e");
      return [];
    }
  }

  Future<int> insertMedication(Map<String, dynamic> medication) async {
    final db = await database;
    try {
      final result = await db.insert(
        'medications',
        medication,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return result;
    } catch (e) {
      Log.d("Erreur lors de l'insertion du médicament: $e");
      return -1;
    }
  }

  // Mettre à jour un médicament existant
  Future<int> updateMedication(Map<String, dynamic> medication) async {
    final db = await database;
    try {
      final result = await db.update(
        'medications',
        medication,
        where: 'id = ?',
        whereArgs: [medication['id']],
      );
      return result;
    } catch (e) {
      Log.d("Erreur lors de la mise à jour du médicament: $e");
      return -1;
    }
  }

  /// Ajoute des médicaments à une nouvelle session
  Future<void> addSessionMedications(
    String sessionId,
    List<String> medicationIds,
    List<String> rinsingProductIds,
  ) async {
    Log.d("DatabaseHelper: Ajout de médicaments pour la session $sessionId");

    // Pour une nouvelle session, on peut réutiliser la même méthode
    return updateSessionMedications(
      sessionId,
      medicationIds,
      rinsingProductIds,
    );
  }

  /// Met à jour les médicaments associés à une session
  Future<void> updateSessionMedications(
    String sessionId,
    List<String> medicationIds,
    List<String> rinsingProductIds,
  ) async {
    Log.d(
      "DatabaseHelper: Mise à jour des médicaments pour la session $sessionId",
    );
    final db = await database;

    return await db.transaction((txn) async {
      try {
        // Supprimer toutes les associations actuelles
        await txn.delete(
          'session_medications',
          where: 'sessionId = ?',
          whereArgs: [sessionId],
        );

        Log.d("DatabaseHelper: Anciennes associations supprimées");

        // Ajouter les médicaments standards
        for (final medicationId in medicationIds) {
          await txn.insert('session_medications', {
            'sessionId': sessionId,
            'medicationId': medicationId,
          });
        }

        Log.d(
          "DatabaseHelper: ${medicationIds.length} médicaments standards ajoutés",
        );

        // Ajouter les produits de rinçage
        for (final rinsingProductId in rinsingProductIds) {
          await txn.insert('session_medications', {
            'sessionId': sessionId,
            'medicationId': rinsingProductId,
          });
        }

        Log.d(
          "DatabaseHelper: ${rinsingProductIds.length} produits de rinçage ajoutés",
        );

        return;
      } catch (e) {
        Log.d(
          "DatabaseHelper: Erreur lors de la mise à jour des médicaments: $e",
        );
        rethrow; // Propager l'erreur pour que la transaction échoue
      }
    });
  }

  /// Récupère les médicaments associés à une session spécifique
  Future<List<Map<String, dynamic>>> getSessionMedicationDetails(
    String sessionId,
  ) async {
    // Log.d("DatabaseHelper: Récupération des médicaments détaillés pour la session $sessionId");
    final db = await database;

    try {
      // Récupérer tous les médicaments avec un flag pour indiquer s'il s'agit d'un produit de rinçage
      final List<Map<String, dynamic>> medications = await db.rawQuery(
        '''
      SELECT m.*, sm.sessionId
      FROM medications m
      INNER JOIN session_medications sm ON m.id = sm.medicationId
      WHERE sm.sessionId = ?
    ''',
        [sessionId],
      );

      Log.d(
        "DatabaseHelper: ${medications.length} médicaments récupérés pour la session",
      );
      return medications;
    } catch (e) {
      Log.d(
        "DatabaseHelper: Erreur lors de la récupération des médicaments de la session: $e",
      );
      return [];
    }
  }

  /// Alternative plus détaillée pour récupérer les médicaments d'une session
  /// Cette version sépare directement les médicaments standards et les produits de rinçage
  Future<Map<String, List<Map<String, dynamic>>>> getSessionMedicationsByType(
    String sessionId,
  ) async {
    Log.d(
      "DatabaseHelper: Récupération des médicaments par type pour la session $sessionId",
    );
    final db = await database;

    try {
      // Récupérer les médicaments standards (non-rinçage)
      final List<Map<String, dynamic>> standardMeds = await db.rawQuery(
        '''
      SELECT m.*
      FROM medications m
      INNER JOIN session_medications sm ON m.id = sm.medicationId
      WHERE sm.sessionId = ? AND m.isRinsing = 0
    ''',
        [sessionId],
      );

      // Récupérer les produits de rinçage
      final List<Map<String, dynamic>> rinsingMeds = await db.rawQuery(
        '''
      SELECT m.*
      FROM medications m
      INNER JOIN session_medications sm ON m.id = sm.medicationId
      WHERE sm.sessionId = ? AND m.isRinsing = 1
    ''',
        [sessionId],
      );

      Log.d(
        "DatabaseHelper: ${standardMeds.length} médicaments standards et ${rinsingMeds.length} produits de rinçage récupérés",
      );

      return {'standard': standardMeds, 'rinsing': rinsingMeds};
    } catch (e) {
      Log.d(
        "DatabaseHelper: Erreur lors de la récupération des médicaments par type: $e",
      );
      return {'standard': [], 'rinsing': []};
    }
  }

  // Fonctions supplémentaires à ajouter à votre classe DatabaseHelper

  // Fonction pour insérer un rendez-vous
  Future<int> insertAppointment(Map<String, dynamic> appointment) async {
    Log.d("DatabaseHelper: Insertion d'un rendez-vous");
    final db = await database;

    try {
      // Insertion de base dans la table appointments
      final baseAppointmentData = {
        'id': appointment['id'],
        'title': appointment['title'],
        'dateTime': appointment['dateTime'],
        'duration': appointment['duration'],
        'healthProfessionalId': appointment['healthProfessionalId'],
        'establishmentId': appointment['establishmentId'],
        'notes': appointment['notes'],
        'isCompleted': appointment['isCompleted'] ?? 0,
        'type': appointment['type'],
      };
      Log.d('baseAppointmentData:[${baseAppointmentData.toString()}]');

      final result = await db.insert('appointments', baseAppointmentData);

      // Création de la relation avec le cycle
      if (appointment['cycleId'] != null) {
        await db.insert('cycle_appointments', {
          'cycleId': appointment['cycleId'],
          'appointmentId': appointment['id'],
        });
      }

      Log.d("DatabaseHelper: Rendez-vous inséré avec succès");
      return result;
    } catch (e) {
      Log.d("DatabaseHelper: Erreur lors de l'insertion du rendez-vous: $e");
      return -1;
    }
  }

  // Fonction pour récupérer les rendez-vous d'un cycle
  Future<List<Map<String, dynamic>>> getAppointmentsByCycle(
    String cycleId,
  ) async {
    Log.d(
      "DatabaseHelper: Récupération des rendez-vous pour le cycle $cycleId",
    );
    final db = await database;

    try {
      final results = await db.rawQuery(
        '''
      SELECT a.*, ps.firstName, ps.lastName, e.name as establishmentName 
      FROM appointments a
      LEFT JOIN health_professionals ps ON a.healthProfessionalId = ps.id
      LEFT JOIN establishments e ON a.establishmentId = e.id
      INNER JOIN cycle_appointments ca ON a.id = ca.appointmentId
      WHERE ca.cycleId = ?
      ORDER BY a.dateTime
    ''',
        [cycleId],
      );

      Log.d("DatabaseHelper: ${results.length} rendez-vous récupérés");
      return results;
    } catch (e) {
      Log.d(
        "DatabaseHelper: Erreur lors de la récupération des rendez-vous: $e",
      );
      return [];
    }
  }

  // Fonction pour mettre à jour un rendez-vous
  Future<int> updateAppointment(Map<String, dynamic> appointment) async {
    Log.d("DatabaseHelper: Mise à jour du rendez-vous ${appointment['id']}");
    final db = await database;

    try {
      final result = await db.update(
        'appointments',
        appointment,
        where: 'id = ?',
        whereArgs: [appointment['id']],
      );

      Log.d(
        "DatabaseHelper: Rendez-vous mis à jour avec succès, lignes affectées: $result",
      );
      return result;
    } catch (e) {
      Log.d("DatabaseHelper: Erreur lors de la mise à jour du rendez-vous: $e");
      return -1;
    }
  }

  // Fonction pour supprimer un rendez-vous
  Future<int> deleteAppointment(String id) async {
    Log.d("DatabaseHelper: Suppression du rendez-vous $id");
    final db = await database;

    try {
      // Supprimer les relations cycle-rendez-vous
      await db.delete(
        'cycle_appointments',
        where: 'appointmentId = ?',
        whereArgs: [id],
      );

      // Supprimer le rendez-vous
      final result = await db.delete(
        'appointments',
        where: 'id = ?',
        whereArgs: [id],
      );

      Log.d(
        "DatabaseHelper: Rendez-vous supprimé avec succès, lignes affectées: $result",
      );
      return result;
    } catch (e) {
      Log.d("DatabaseHelper: Erreur lors de la suppression du rendez-vous: $e");
      return -1;
    }
  }

  // Fonction pour ajouter un prérequis à une session
  Future<int> insertPrerequisite(Map<String, dynamic> prerequisite) async {
    Log.d("DatabaseHelper: Insertion d'un prérequis");
    final db = await database;

    try {
      final result = await db.insert('prerequisites', prerequisite);
      Log.d("DatabaseHelper: Prérequis inséré avec succès");
      return result;
    } catch (e) {
      Log.d("DatabaseHelper: Erreur lors de l'insertion du prérequis: $e");
      return -1;
    }
  }

  // Fonction pour récupérer les prérequis d'une session
  Future<List<Map<String, dynamic>>> getPrerequisitesBySession(
    String sessionId,
  ) async {
    Log.d(
      "DatabaseHelper: Récupération des prérequis pour la session $sessionId",
    );
    final db = await database;

    try {
      final results = await db.rawQuery(
        '''
      SELECT p.*, a.title as appointmentTitle, a.dateTime as appointmentDateTime 
      FROM prerequisites p
      LEFT JOIN appointments a ON p.appointmentId = a.id
      WHERE p.sessionId = ?
      ORDER BY p.deadline
    ''',
        [sessionId],
      );

      Log.d("DatabaseHelper: ${results.length} prérequis récupérés");
      return results;
    } catch (e) {
      Log.d("DatabaseHelper: Erreur lors de la récupération des prérequis: $e");
      return [];
    }
  }

  // Fonction pour mettre à jour uniquement la date/heure d'une session
  Future<int> updateSessionDateTime(String sessionId, DateTime dateTime) async {
    Log.d(
      "DatabaseHelper: Mise à jour de la date/heure de la session $sessionId",
    );
    final db = await database;

    try {
      final result = await db.update(
        'sessions',
        {'dateTime': dateTime.toIso8601String()},
        where: 'id = ?',
        whereArgs: [sessionId],
      );

      Log.d(
        "DatabaseHelper: Date/heure de la session mise à jour avec succès, lignes affectées: $result",
      );
      return result;
    } catch (e) {
      Log.d(
        "DatabaseHelper: Erreur lors de la mise à jour de la date/heure de la session: $e",
      );
      return -1;
    }
  }

  // Fonction pour marquer une session comme terminée ou non
  Future<int> updateSessionCompletionStatus(
    String sessionId,
    bool isCompleted,
  ) async {
    final db = await database;
    try {
      final result = await db.update(
        'sessions',
        {'isCompleted': isCompleted ? 1 : 0},
        where: 'id = ?',
        whereArgs: [sessionId],
      );
      return result;
    } catch (e) {
      Log.d(
        "Erreur lors de la mise à jour du statut de complétion de la session: $e",
      );
      return -1;
    }
  }

  // Fonction pour créer la structure de la table cycle_appointments si elle n'existe pas
  Future<void> ensureCycleAppointmentsTableExists() async {
    Log.d(
      "DatabaseHelper: Vérification de l'existence de la table cycle_appointments",
    );
    final db = await database;

    try {
      // Vérifier si la table existe
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='cycle_appointments'",
      );

      if (tables.isEmpty) {
        Log.d("DatabaseHelper: Création de la table cycle_appointments");
        await db.execute('''
        CREATE TABLE cycle_appointments(
          cycleId TEXT NOT NULL,
          appointmentId TEXT NOT NULL,
          PRIMARY KEY (cycleId, appointmentId),
          FOREIGN KEY (cycleId) REFERENCES cycles(id) ON DELETE CASCADE,
          FOREIGN KEY (appointmentId) REFERENCES appointments(id) ON DELETE CASCADE
        )
      ''');
        Log.d("DatabaseHelper: Table cycle_appointments créée avec succès");
      } else {
        Log.d("DatabaseHelper: La table cycle_appointments existe déjà");
      }
    } catch (e) {
      Log.d(
        "DatabaseHelper: Erreur lors de la vérification/création de la table cycle_appointments: $e",
      );
    }
  }

  // Récupérer les médecins d'une radiothérapie
  // Mettre à jour les champs d'un cycle
  Future<int> updateCycleFields(Map<String, dynamic> cycleFields) async {
    Log.d(
      "DatabaseHelper: Mise à jour des champs du cycle ${cycleFields['id']}",
    );
    final db = await database;

    try {
      final result = await db.update(
        'cycles',
        cycleFields,
        where: 'id = ?',
        whereArgs: [cycleFields['id']],
      );

      Log.d(
        "DatabaseHelper: Champs du cycle mis à jour avec succès, lignes affectées: $result",
      );
      return result;
    } catch (e) {
      Log.d(
        "DatabaseHelper: Erreur lors de la mise à jour des champs du cycle: $e",
      );
      return -1;
    }
  }

  /// Vérifie si tous les cycles d'un traitement sont terminés
  /// Retourne true si tous les cycles ont isCompleted = 1, false sinon
  Future<bool> isTreatmentCyclesCompleted(String treatmentId) async {
    Log.d(
      "DatabaseHelper: Vérification si tous les cycles du traitement $treatmentId sont terminés",
    );

    try {
      final db = await database;

      // Récupérer tous les cycles du traitement
      final List<Map<String, dynamic>> cycles = await db.query(
        'cycles',
        where: 'treatmentId = ?',
        whereArgs: [treatmentId],
      );

      if (cycles.length == 0) {
        Log.d('Pas de cycle trouvé pour le traitement');
        return true;
      }

      Log.d(
        "DatabaseHelper: ${cycles.length} cycles trouvés pour le traitement $treatmentId",
      );
      Log.d("DatabaseHelper: ${cycles.length} cycles :[${cycles.toString()}]");

      // Si aucun cycle n'existe, considérer comme non terminé
      if (cycles.isEmpty) {
        Log.d(
          "DatabaseHelper: Aucun cycle trouvé, traitement considéré comme non terminé",
        );
        return false;
      }

      // Vérifier si tous les cycles sont terminés
      bool allCompleted = cycles.every((cycle) => cycle['isCompleted'] == 1);

      if (allCompleted) {
        Log.d(
          "DatabaseHelper: Tous les cycles du traitement $treatmentId sont terminés",
        );
      } else {
        final incompleteCycles =
            cycles.where((cycle) => cycle['isCompleted'] != 1).length;
        Log.d(
          "DatabaseHelper: $incompleteCycles cycles non terminés sur ${cycles.length} pour le traitement $treatmentId",
        );
      }

      return allCompleted;
    } catch (e) {
      Log.e(
        "DatabaseHelper: Erreur lors de la vérification des cycles du traitement: $e",
      );
      return false;
    }
  }

  // Mettre à jour les champs d'une radiothérapie
  Future<int> updateRadiotherapyFields(
    Map<String, dynamic> radiotherapyFields,
  ) async {
    Log.d(
      "DatabaseHelper: Mise à jour des champs de la radiothérapie ${radiotherapyFields['id']}",
    );
    final db = await database;

    try {
      final result = await db.update(
        'radiotherapies',
        radiotherapyFields,
        where: 'id = ?',
        whereArgs: [radiotherapyFields['id']],
      );

      Log.d(
        "DatabaseHelper: Champs de la radiothérapie mis à jour avec succès, lignes affectées: $result",
      );
      return result;
    } catch (e) {
      Log.d(
        "DatabaseHelper: Erreur lors de la mise à jour des champs de la radiothérapie: $e",
      );
      return -1;
    }
  }

  // Méthode pour récupérer un traitement complet avec ses détails
  Future<Map<String, dynamic>> getCompleteTreatment(String treatmentId) async {
    Log.d("DatabaseHelper: Récupération complète du traitement $treatmentId");
    final db = await database;

    // Récupérer les informations de base du traitement
    final treatmentResults = await db.query(
      'treatments',
      where: 'id = ?',
      whereArgs: [treatmentId],
    );

    if (treatmentResults.isEmpty) {
      return {};
    }

    final treatmentMap = treatmentResults.first;

    // Récupérer les établissements associés
    final establishmentResults = await getTreatmentEstablishments(treatmentId);

    // Récupérer les cycles
    final cycleResults = await getCyclesByTreatment(treatmentId);

    // Déterminer le type principal
    String mainType = "Non spécifié";

    if (cycleResults.isNotEmpty) {
      final cycleType = cycleResults.first['type'];
      if (cycleType == 0) {
        mainType = "Chimiothérapie";
      } else if (cycleType == 1) {
        mainType = "Immunothérapie";
      } else if (cycleType == 2) {
        mainType = "Hormonothérapie";
      } else if (cycleType == 3) {
        mainType = "Traitement combiné";
      } else if (cycleType == 4) {
        mainType = "Chirurgie";
      } else if (cycleType == 5) {
        mainType = "Radiothérapie";
      }
    }

    // Construire l'objet complet
    final completeData = {
      ...treatmentMap,
      'mainType': mainType,
      'establishments': establishmentResults,
      'cycles': cycleResults,
    };

    return completeData;
  }

  // Méthode pour récupérer directement le premier cycle d'un traitement
  Future<Map<String, dynamic>?> getFirstCycleForTreatment(
    String treatmentId,
  ) async {
    Log.d(
      "DatabaseHelper: Récupération du premier cycle pour le traitement $treatmentId",
    );
    final db = await database;

    // Récupérer le premier cycle du traitement
    final cycleResults = await db.query(
      'cycles',
      where: 'treatmentId = ?',
      whereArgs: [treatmentId],
      orderBy: 'startDate',
      limit: 1,
    );

    if (cycleResults.isEmpty) {
      return null;
    }

    return cycleResults.first;
  }

  // Méthode pour récupérer directement la première radiothérapie d'un traitement
  Future<Map<String, dynamic>?> getFirstRadiotherapyForTreatment(
    String treatmentId,
  ) async {
    Log.d(
      "DatabaseHelper: Récupération de la première radiothérapie pour le traitement $treatmentId",
    );
    final db = await database;

    // Récupérer la première radiothérapie du traitement
    final radiotherapyResults = await db.query(
      'radiotherapies',
      where: 'treatmentId = ?',
      whereArgs: [treatmentId],
      orderBy: 'startDate',
      limit: 1,
    );

    if (radiotherapyResults.isEmpty) {
      return null;
    }

    return radiotherapyResults.first;
  }

  /// Récupère un examen spécifique par son ID avec toutes ses relations
  Future<Map<String, dynamic>?> getExamination(String examinationId) async {
    final db = await database;

    try {
      // Récupérer l'examen
      final List<Map<String, dynamic>> examinationMaps = await db.rawQuery(
        '''
      SELECT e.*, est.id as establishmentId, est.name as establishmentName, 
             est.address as establishmentAddress, est.phone as establishmentPhone, 
             d.id as doctorId, d.firstName as doctorFirstName, d.lastName as doctorLastName, 
             d.specialty as doctorSpecialty, d.phone as doctorPhone, d.email as doctorEmail
      FROM examinations e
      LEFT JOIN establishments est ON e.establishmentId = est.id
      LEFT JOIN doctors d ON e.doctorId = d.id
      WHERE e.id = ?
    ''',
        [examinationId],
      );

      if (examinationMaps.isEmpty) {
        return null;
      }

      final Map<String, dynamic> examinationMap = examinationMaps.first;

      // Construire l'objet établissement
      final Map<String, dynamic> establishmentMap = {
        'id': examinationMap['establishmentId'],
        'name': examinationMap['establishmentName'],
        'address': examinationMap['establishmentAddress'],
        'phone': examinationMap['establishmentPhone'],
      };

      // Construire l'objet médecin si présent
      Map<String, dynamic>? doctorMap;
      if (examinationMap['doctorId'] != null) {
        doctorMap = {
          'id': examinationMap['doctorId'],
          'firstName': examinationMap['doctorFirstName'],
          'lastName': examinationMap['doctorLastName'],
          'specialty': examinationMap['doctorSpecialty'],
          'phone': examinationMap['doctorPhone'],
          'email': examinationMap['doctorEmail'],
        };
      }

      // Formater le résultat final
      final Map<String, dynamic> result = {
        'id': examinationMap['id'],
        'type': examinationMap['type'],
        'otherType': examinationMap['otherType'],
        'title': examinationMap['title'],
        'dateTime': examinationMap['dateTime'],
        'notes': examinationMap['notes'],
        'isCompleted': examinationMap['isCompleted'],
        'prereqForSessionId': examinationMap['prereqForSessionId'],
        'examGroupId': examinationMap['examGroupId'],
        'establishment': establishmentMap,
        'doctor': doctorMap,
      };

      // Récupérer les documents associés
      final List<Map<String, dynamic>> documentMaps =
          await getDocumentsByEntity('examination', examinationId);
      result['documents'] = documentMaps;

      return result;
    } catch (e) {
      Log.d("Erreur lors de la récupération de l'examen: $e");
      return null;
    }
  }

  // Méthode pour récupérer les examens associés à un cycle
  Future<List<Map<String, dynamic>>> getExaminationsByCycle(
    String cycleId,
  ) async {
    Log.d("DatabaseHelper: Récupération des examens pour le cycle $cycleId");
    final db = await database;

    try {
      Log.d("Requête d'examens pour le cycle : $cycleId");
      // Vérifier d'abord si la table des examens existe
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='examinations'",
      );

      if (tables.isEmpty) {
        // Si la table n'existe pas encore, la créer
        await db.execute('''
      CREATE TABLE examinations(
        id TEXT PRIMARY KEY,
        cycleId TEXT NOT NULL,
        title TEXT NOT NULL,
        type INTEGER NOT NULL,
        otherType TEXT,
        dateTime TEXT NOT NULL,
        establishmentId TEXT NOT NULL,
        prescripteurId TEXT,
        executantId TEXT,
        notes TEXT,
        isCompleted INTEGER NOT NULL DEFAULT 0,
        prereqForSessionId TEXT,
        examGroupId TEXT,
        FOREIGN KEY (cycleId) REFERENCES cycles (id) ON DELETE CASCADE,
        FOREIGN KEY (establishmentId) REFERENCES establishments (id) ON DELETE CASCADE,
        FOREIGN KEY (prescripteurId) REFERENCES health_professionals (id) ON DELETE SET NULL,
        FOREIGN KEY (executantId) REFERENCES health_professionals (id) ON DELETE SET NULL,
        FOREIGN KEY (prereqForSessionId) REFERENCES sessions (id) ON DELETE SET NULL
      )
    ''');
        Log.d("DatabaseHelper: Table 'examinations' créée");
        return [];
      }

      // Approche alternative: faire des requêtes séparées pour éviter les problèmes d'alias
      // 1. Récupérer les examens de base
      final examinations = await db.query(
        'examinations',
        where: 'cycleId = ?',
        whereArgs: [cycleId],
        orderBy: 'dateTime',
      );

      Log.d(
        "DatabaseHelper: ${examinations.length} examens trouvés dans la base",
      );

      // 2. Pour chaque examen, enrichir avec l'établissement et le médecin
      List<Map<String, dynamic>> result = [];

      for (var exam in examinations) {
        // Créer une nouvelle map pour l'examen enrichi
        Map<String, dynamic> enrichedExam = Map.from(exam);

        try {
          // Récupérer l'établissement
          final String establishmentId = exam['establishmentId'] as String;
          final establishments = await db.query(
            'establishments',
            where: 'id = ?',
            whereArgs: [establishmentId],
          );

          if (establishments.isNotEmpty) {
            enrichedExam['establishment'] = establishments.first;
          } else {
            // Établissement par défaut si non trouvé
            enrichedExam['establishment'] = {
              'id': establishmentId,
              'name': 'Établissement inconnu',
            };
          }

          // Récupérer le médecin si présent
          if (exam['doctorId'] != null) {
            final doctors = await db.query(
              'doctors',
              where: 'id = ?',
              whereArgs: [exam['doctorId']],
            );

            if (doctors.isNotEmpty) {
              enrichedExam['doctor'] = doctors.first;
            }
          }

          result.add(enrichedExam);
        } catch (examError) {
          Log.e(
            "DatabaseHelper: Erreur lors de l'enrichissement de l'examen ${exam['id']}: $examError",
          );
          // Ajouter quand même l'examen de base
          result.add(enrichedExam);
        }
      }

      Log.d("DatabaseHelper: ${result.length} examens enrichis");
      return result;
    } catch (e) {
      Log.e("DatabaseHelper: Erreur lors de la récupération des examens: $e");
      return [];
    }
  }

  // Méthode pour insérer un nouvel examen
  Future<int> insertExamination(Map<String, dynamic> examination) async {
    Log.d("DatabaseHelper: Insertion d'un examen");
    final db = await database;
    try {
      // Vérifier d'abord si la table des examens existe
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='examinations'",
      );

      if (tables.isEmpty) {
        // Si la table n'existe pas encore, la créer
        await db.execute('''
        CREATE TABLE examinations(
          id TEXT PRIMARY KEY,
          cycleId TEXT NOT NULL,
          title TEXT NOT NULL,
          type INTEGER NOT NULL,
          otherType TEXT,
          dateTime TEXT NOT NULL,
          establishmentId TEXT NOT NULL,
          prescripteurId TEXT,
          executantId TEXT,
          notes TEXT,
          isCompleted INTEGER NOT NULL DEFAULT 0,
          prereqForSessionId TEXT,
          examGroupId TEXT,
          FOREIGN KEY (cycleId) REFERENCES cycles (id) ON DELETE CASCADE,
          FOREIGN KEY (establishmentId) REFERENCES establishments (id) ON DELETE CASCADE,
          FOREIGN KEY (prescripteurId) REFERENCES health_professionals (id) ON DELETE SET NULL,
          FOREIGN KEY (executantId) REFERENCES health_professionals (id) ON DELETE SET NULL,
          FOREIGN KEY (prereqForSessionId) REFERENCES sessions (id) ON DELETE SET NULL
        )
      ''');
        Log.d("DatabaseHelper: Table 'examinations' créée");
      }

      final result = await db.insert(
        'examinations',
        examination,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      Log.d("DatabaseHelper: Examen inséré avec succès, résultat: $result");
      return result;
    } catch (e) {
      Log.e("DatabaseHelper: Erreur lors de l'insertion de l'examen: $e");
      return -1;
    }
  }

  // Méthode pour insérer un nouvel examen
  Future<int> updateExamination(Map<String, dynamic> examination) async {
    Log.d("DatabaseHelper: Mise à jour de l'examen ${examination['id']}");
    final db = await database;

    try {
      // Vérifier que l'examen existe
      final examinationId = examination['id'];
      final existing = await db.query(
        'examinations',
        where: 'id = ?',
        whereArgs: [examinationId],
      );

      if (existing.isEmpty) {
        Log.e(
          "DatabaseHelper: Examen introuvable, impossible de mettre à jour",
        );
        return 0;
      }

      // Mise à jour de l'examen
      final result = await db.update(
        'examinations',
        examination,
        where: 'id = ?',
        whereArgs: [examinationId],
      );

      Log.d(
        "DatabaseHelper: Examen mis à jour avec succès, lignes affectées: $result",
      );
      return result;
    } catch (e) {
      Log.e("DatabaseHelper: Erreur lors de la mise à jour de l'examen: $e");
      return -1;
    }
  }

  // Méthode pour récupérer les documents associés à un cycle
  Future<List<Map<String, dynamic>>> getDocumentsByCycle(String cycleId) async {
    Log.d("DatabaseHelper: Récupération des documents pour le cycle $cycleId");
    final db = await database;

    try {
      // Récupérer les documents liés au cycle
      final documentData = await db.rawQuery(
        '''
      SELECT d.*
      FROM documents d
      INNER JOIN entity_documents ed ON d.id = ed.documentId
      WHERE ed.entityId = ? AND ed.entityType = 'cycle'
      ORDER BY d.dateAdded DESC
    ''',
        [cycleId],
      );

      Log.d("DatabaseHelper: ${documentData.length} documents récupérés");
      return documentData;
    } catch (e) {
      Log.e("DatabaseHelper: Erreur lors de la récupération des documents: $e");
      return [];
    }
  }

  Future<int> insertDocument_ForAddDocumentScreen(
    Map<String, dynamic> document, [
    String? entityType,
    String? entityId,
  ]) async {
    final db = await database;
    try {
      Log.d("DatabaseHelper: Insertion d'un document: ${document['name']}");

      return await db.transaction((txn) async {
        // Insérer le document
        final result = await txn.insert(
          'documents',
          document,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        // Si l'insertion a réussi et les paramètres entityType et entityId sont fournis,
        // créer également la liaison
        if (result > 0 && entityType != null && entityId != null) {
          final linkData = {
            'documentId': document['id'],
            'entityType': entityType,
            'entityId': entityId,
          };

          await txn.insert(
            'entity_documents',
            linkData,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }

        Log.d("DatabaseHelper: Document inséré avec succès, résultat: $result");
        return result;
      });
    } catch (e) {
      Log.e("DatabaseHelper: Erreur lors de l'insertion du document: $e");
      return -1;
    }
  }

  // Méthode pour insérer un nouveau document
  Future<int> insertDocument(Map<String, dynamic> document) async {
    final db = await database;
    try {
      Log.d("DatabaseHelper: Insertion d'un document: ${document['name']}");
      final result = await db.insert(
        'documents',
        document,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      Log.d("DatabaseHelper: Document inséré avec succès, résultat: $result");
      return result;
    } catch (e) {
      Log.e("DatabaseHelper: Erreur lors de l'insertion du document: $e");
      return -1;
    }
  }

  // Lier un document à une entité (examen, séance, etc.)
  Future<int> linkDocumentToEntity(
    String entityType,
    String entityId,
    String documentId,
  ) async {
    final db = await database;
    try {
      Log.d(
        "DatabaseHelper: Liaison du document $documentId à $entityType $entityId",
      );

      // Vérifier si la table entity_documents existe
      final tableCheck = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='entity_documents'",
      );

      if (tableCheck.isEmpty) {
        Log.d(
          "DatabaseHelper: La table entity_documents n'existe pas encore, création...",
        );

        // Créer la table si elle n'existe pas
        await db.execute('''
        CREATE TABLE IF NOT EXISTS entity_documents(
          documentId TEXT NOT NULL,
          entityType TEXT NOT NULL,
          entityId TEXT NOT NULL,
          PRIMARY KEY (documentId, entityType, entityId),
          FOREIGN KEY (documentId) REFERENCES documents (id) ON DELETE CASCADE
        )
      ''');
      }

      // Vérifier si le document existe
      final docCheck = await db.query(
        'documents',
        columns: ['id'],
        where: 'id = ?',
        whereArgs: [documentId],
      );

      if (docCheck.isEmpty) {
        Log.e("DatabaseHelper: Le document $documentId n'existe pas");
        return 0;
      }

      // Vérifier si la liaison existe déjà
      final existingCheck = await db.query(
        'entity_documents',
        columns: ['documentId'],
        where: 'documentId = ? AND entityType = ? AND entityId = ?',
        whereArgs: [documentId, entityType, entityId],
      );

      if (existingCheck.isNotEmpty) {
        Log.d(
          "DatabaseHelper: La liaison existe déjà, aucune action nécessaire",
        );
        return 1; // Succès, liaison déjà existante
      }

      // Créer la liaison
      final linkData = {
        'documentId': documentId,
        'entityType': entityType,
        'entityId': entityId,
      };

      final result = await db.insert(
        'entity_documents',
        linkData,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      Log.d("DatabaseHelper: Document lié avec succès, résultat: $result");

      // Vérifier que la liaison a bien été créée
      final verifyCheck = await db.query(
        'entity_documents',
        columns: ['documentId'],
        where: 'documentId = ? AND entityType = ? AND entityId = ?',
        whereArgs: [documentId, entityType, entityId],
      );

      if (verifyCheck.isEmpty) {
        Log.e("DatabaseHelper: La liaison n'a pas été créée correctement");
        return 0;
      }

      Log.d("DatabaseHelper: Liaison vérifiée avec succès");
      return result;
    } catch (e) {
      Log.e("DatabaseHelper: Erreur lors de la liaison du document: $e");
      return -1;
    }
  }

  // Supprimer la liaison entre un document et une entité
  Future<int> unlinkDocumentFromEntity(
    String entityType,
    String entityId,
    String documentId,
  ) async {
    final db = await database;
    try {
      Log.d(
        "DatabaseHelper: Suppression de la liaison du document $documentId avec $entityType $entityId",
      );

      final result = await db.delete(
        'entity_documents',
        where: 'documentId = ? AND entityType = ? AND entityId = ?',
        whereArgs: [documentId, entityType, entityId],
      );

      Log.d(
        "DatabaseHelper: Liaison supprimée avec succès, lignes affectées: $result",
      );
      return result;
    } catch (e) {
      Log.e("DatabaseHelper: Erreur lors de la suppression de la liaison: $e");
      return -1;
    }
  }

  Future<List<Map<String, dynamic>>> getEntitiesLinkedToDocument(
    String documentId,
  ) async {
    final db = await database;
    return await db.rawQuery(
      '''
    SELECT entityType, entityId 
    FROM entity_documents 
    WHERE documentId = ?
  ''',
      [documentId],
    );
  }

  // Méthode pour mettre à jour le statut d'un examen
  Future<int> updateExaminationCompletionStatus(
    String examinationId,
    bool isCompleted,
  ) async {
    Log.d("DatabaseHelper: Mise à jour du statut de l'examen $examinationId");
    final db = await database;

    try {
      final result = await db.update(
        'examinations',
        {'isCompleted': isCompleted ? 1 : 0},
        where: 'id = ?',
        whereArgs: [examinationId],
      );

      Log.d(
        "DatabaseHelper: Statut de l'examen mis à jour, lignes affectées: $result",
      );
      return result;
    } catch (e) {
      Log.e(
        "DatabaseHelper: Erreur lors de la mise à jour du statut de l'examen: $e",
      );
      return -1;
    }
  }

  // Méthode pour supprimer un document
  Future<int> deleteDocument(String documentId) async {
    final db = await database;
    try {
      Log.d("DatabaseHelper: Suppression du document $documentId");

      return await db.transaction((txn) async {
        // Supprimer d'abord toutes les liaisons
        Log.d(
          'Suppression du lien dans entity_documents avec documentId:[$documentId}]',
        );
        await txn.delete(
          'entity_documents',
          where: 'documentId = ?',
          whereArgs: [documentId],
        );

        // Puis supprimer le document lui-même
        Log.d('Suppression du documents avec is:[$documentId}]');
        final result = await txn.delete(
          'documents',
          where: 'id = ?',
          whereArgs: [documentId],
        );

        Log.d(
          "DatabaseHelper: Document supprimé avec succès, lignes affectées: $result",
        );
        return result;
      });
    } catch (e) {
      Log.e("DatabaseHelper: Erreur lors de la suppression du document: $e");
      return -1;
    }
  }

  // Méthode pour supprimer un examen
  Future<int> deleteExamination(String examinationId) async {
    Log.d("DatabaseHelper: Suppression de l'examen $examinationId");
    final db = await database;

    try {
      final result = await db.delete(
        'examinations',
        where: 'id = ?',
        whereArgs: [examinationId],
      );

      Log.d("DatabaseHelper: Examen supprimé, lignes affectées: $result");
      return result;
    } catch (e) {
      Log.e("DatabaseHelper: Erreur lors de la suppression de l'examen: $e");
      return -1;
    }
  }

  // Méthode pour récupérer les détails d'un document
  Future<Map<String, dynamic>?> getDocument(String documentId) async {
    Log.d("DatabaseHelper: Récupération du document $documentId");
    final db = await database;

    try {
      final results = await db.query(
        'documents',
        where: 'id = ?',
        whereArgs: [documentId],
      );

      if (results.isEmpty) {
        Log.d("DatabaseHelper: Document non trouvé");
        return null;
      }

      Log.d("DatabaseHelper: Document récupéré avec succès");
      return results.first;
    } catch (e) {
      Log.e("DatabaseHelper: Erreur lors de la récupération du document: $e");
      return null;
    }
  }

  // Remplacer la méthode getDocumentsByEntity dans DatabaseHelper

  // Récupérer tous les documents liés à une entité avec journalisation détaillée
  Future<List<Map<String, dynamic>>> getDocumentsByEntity(
    String entityType,
    String entityId,
  ) async {
    final db = await database;
    try {
      Log.d(
        "DatabaseHelper: Début de récupération des documents pour $entityType $entityId",
      );

      // Vérifier si la table entity_documents existe
      final tableCheck = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='entity_documents'",
      );

      if (tableCheck.isEmpty) {
        Log.d("DatabaseHelper: La table entity_documents n'existe pas encore");
        return [];
      }

      // D'abord, vérifier quels documents sont liés à cette entité
      final linkedDocIds = await db.query(
        'entity_documents',
        columns: ['documentId'],
        where: 'entityType = ? AND entityId = ?',
        whereArgs: [entityType, entityId],
      );

      Log.d(
        "DatabaseHelper: ${linkedDocIds.length} liens trouvés pour $entityType $entityId",
      );

      if (linkedDocIds.isEmpty) {
        return [];
      }

      // Extraire les IDs des documents
      final docIds =
          linkedDocIds.map((row) => row['documentId'] as String).toList();

      // Construire la clause WHERE pour récupérer ces documents
      final placeholders = docIds.map((_) => '?').join(',');
      final whereClause = 'id IN ($placeholders)';

      // Récupérer les documents correspondants
      final results = await db.query(
        'documents',
        where: whereClause,
        whereArgs: docIds,
        orderBy: 'dateAdded DESC',
      );

      Log.d(
        "DatabaseHelper: ${results.length} documents récupérés pour $entityType $entityId",
      );

      // Journal pour déboguer chaque document trouvé
      for (var doc in results) {
        Log.d("Document trouvé - ID: ${doc['id']}, Nom: ${doc['name']}");
      }

      return results;
    } catch (e) {
      Log.e("DatabaseHelper: Erreur lors de la récupération des documents: $e");
      return [];
    }
  }

  Future<int?> getDocumentDoctor(String documentId) async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.rawQuery(
      '''
    SELECT doctorId FROM documents
    WHERE id = ?
  ''',
      [documentId],
    );

    if (result.isNotEmpty && result.first['doctorId'] != null) {
      return result.first['doctorId'] as int;
    }
    return null;
  }

  Future<int> updateDocument(Map<String, dynamic> document) async {
    final db = await database;
    try {
      Log.d("DatabaseHelper: Mise à jour du document ${document['id']}");

      final result = await db.update(
        'documents',
        document,
        where: 'id = ?',
        whereArgs: [document['id']],
      );

      Log.d(
        "DatabaseHelper: Document mis à jour avec succès, lignes affectées: $result",
      );
      return result;
    } catch (e) {
      Log.e("DatabaseHelper: Erreur lors de la mise à jour du document: $e");
      return -1;
    }
  }

  Future<int> linkDocumentDoctor(String documentId, String doctorId) async {
    final db = await database;
    return await db.update(
      'documents',
      {'doctorId': doctorId},
      where: 'id = ?',
      whereArgs: [documentId],
    );
  }

  Future<int> unlinkDocumentDoctor(String documentId) async {
    final db = await database;
    return await db.update(
      'documents',
      {'doctorId': null},
      where: 'id = ?',
      whereArgs: [documentId],
    );
  }

  // 3. Méthode pour générer toutes les sessions d'un cycle
  Future<bool> generateSessionsForCycle(String cycleId) async {
    Log.d("DatabaseHelper: Génération de sessions pour le cycle $cycleId");
    final db = await database;

    try {
      // Récupérer les informations du cycle
      final cycleResults = await db.query(
        'cycles',
        where: 'id = ?',
        whereArgs: [cycleId],
      );

      if (cycleResults.isEmpty) {
        Log.d("DatabaseHelper: Cycle introuvable");
        return false;
      }

      final cycle = cycleResults.first;
      final sessionCount = cycle['sessionCount'] as int;
      final intervalDays = cycle['sessionInterval'] as int;
      final startDate = DateTime.parse(cycle['startDate'] as String);
      final establishmentId = cycle['establishmentId'] as String;

      // Supprimer les sessions existantes (si on regénère)
      await db.delete('sessions', where: 'cycleId = ?', whereArgs: [cycleId]);

      // Générer les nouvelles sessions
      for (int i = 0; i < sessionCount; i++) {
        final sessionId = Uuid().v4();
        final sessionDate = startDate.add(Duration(days: i * intervalDays));

        final sessionData = {
          'id': sessionId,
          'cycleId': cycleId,
          'establishmentId': establishmentId,
          'dateTime': sessionDate.toIso8601String(),
          'isCompleted': 0,
        };

        await db.insert('sessions', sessionData);
        Log.d("DatabaseHelper: Session $i générée avec ID $sessionId");
      }

      Log.d(
        "DatabaseHelper: Sessions générées avec succès pour le cycle $cycleId",
      );
      return true;
    } catch (e) {
      Log.d("DatabaseHelper: Erreur lors de la génération des sessions: $e");
      return false;
    }
  }

  /// Récupère tous les examens appartenant à un même groupe
  Future<List<Map<String, dynamic>>> getExaminationsByGroup(
    String groupId,
  ) async {
    Log.d("DatabaseHelper: Récupération des examens du groupe $groupId");
    final db = await database;

    try {
      // Récupérer les examens de base
      final examinations = await db.query(
        'examinations',
        where: 'examGroupId = ?',
        whereArgs: [groupId],
        orderBy: 'dateTime',
      );

      Log.d(
        "DatabaseHelper: ${examinations.length} examens trouvés dans le groupe",
      );

      // Pour chaque examen, enrichir avec l'établissement et le médecin
      List<Map<String, dynamic>> result = [];

      for (var exam in examinations) {
        // Créer une nouvelle map pour l'examen enrichi
        Map<String, dynamic> enrichedExam = Map.from(exam);

        try {
          // Récupérer l'établissement
          final String establishmentId = exam['establishmentId'] as String;
          final establishments = await db.query(
            'establishments',
            where: 'id = ?',
            whereArgs: [establishmentId],
          );

          if (establishments.isNotEmpty) {
            enrichedExam['establishment'] = establishments.first;
          } else {
            // Établissement par défaut si non trouvé
            enrichedExam['establishment'] = {
              'id': establishmentId,
              'name': 'Établissement inconnu',
            };
          }

          // Récupérer le médecin si présent
          if (exam['prescripteurId'] != null) {
            final doctors = await db.query(
              'prescripteurId',
              where: 'id = ?',
              whereArgs: [exam['prescripteurId']],
            );

            if (doctors.isNotEmpty) {
              enrichedExam['prescripteur'] = doctors.first;
            }
          }

          // Récupérer le médecin si présent
          if (exam['executantId'] != null) {
            final doctors = await db.query(
              'executantId',
              where: 'id = ?',
              whereArgs: [exam['executantId']],
            );

            if (doctors.isNotEmpty) {
              enrichedExam['executant'] = doctors.first;
            }
          }

          result.add(enrichedExam);
        } catch (examError) {
          Log.e(
            "DatabaseHelper: Erreur lors de l'enrichissement de l'examen ${exam['id']}: $examError",
          );
          // Ajouter quand même l'examen de base
          result.add(enrichedExam);
        }
      }

      Log.d("DatabaseHelper: ${result.length} examens enrichis");
      return result;
    } catch (e) {
      Log.e(
        "DatabaseHelper: Erreur lors de la récupération des examens du groupe: $e",
      );
      return [];
    }
  }

  // Méthode pour vérifier l'état des documents dans la base de données
  Future<void> verifyDocumentLinks(String entityType, String entityId) async {
    Log.d("==== VÉRIFICATION DES LIENS DE DOCUMENTS ====");
    Log.d("Vérification pour $entityType $entityId");

    final db = await database;

    try {
      // Vérifier les documents existants
      final documents = await db.query('documents');
      Log.d("Nombre total de documents dans la base: ${documents.length}");

      // Vérifier les liens dans entity_documents
      final links = await db.query(
        'entity_documents',
        where: 'entityType = ? AND entityId = ?',
        whereArgs: [entityType, entityId],
      );

      Log.d(
        "Nombre de liens trouvés pour $entityType $entityId: ${links.length}",
      );

      // Afficher les détails de chaque lien
      for (var link in links) {
        final docId = link['documentId'];

        // Récupérer les détails du document
        final docDetails = await db.query(
          'documents',
          where: 'id = ?',
          whereArgs: [docId],
        );

        if (docDetails.isNotEmpty) {
          Log.d(
            "Document lié trouvé - ID: $docId, Nom: ${docDetails.first['name']}",
          );
        } else {
          Log.e("ERREUR: Document lié introuvable - ID: $docId");
        }
      }

      Log.d("==== FIN DE LA VÉRIFICATION ====");
    } catch (e) {
      Log.e("Erreur lors de la vérification des liens de documents: $e");
    }
  }

  Future<Map<String, dynamic>?> getSessionById(String sessionId) async {
    final db = await database;
    final results = await db.query(
      'sessions',
      where: 'id = ?',
      whereArgs: [sessionId],
    );

    return results.isNotEmpty ? results.first : null;
  }

  Future _initializeHealthProfessionalCategories(Database db) async {
    Log.d(
      "DatabaseHelper: Initialisation des catégories de professionnels de santé",
    );

    final categories = [
      {
        'id': Uuid().v4(),
        'name': 'Médecin généraliste',
        'description':
            'Médecin de premier recours assurant le suivi médical global',
        'isActive': 1,
      },
      {
        'id': Uuid().v4(),
        'name': 'Pneumologue',
        'description': 'Spécialiste des maladies respiratoires',
        'isActive': 1,
      },
      {
        'id': Uuid().v4(),
        'name': 'Cardiologue',
        'description': 'Spécialiste des maladies cardiovasculaires',
        'isActive': 1,
      },
      {
        'id': Uuid().v4(),
        'name': 'ORL',
        'description': 'Spécialiste en oto-rhino-laryngologie',
        'isActive': 1,
      },
      {
        'id': Uuid().v4(),
        'name': 'Chirurgien',
        'description':
            'Médecin spécialisé dans les interventions chirurgicales',
        'isActive': 1,
      },
      {
        'id': Uuid().v4(),
        'name': 'Anesthésiste',
        'description': 'Médecin spécialisé dans l\'anesthésie',
        'isActive': 1,
      },
      {
        'id': Uuid().v4(),
        'name': 'Oncologue',
        'description': 'Spécialiste du traitement des cancers',
        'isActive': 1,
      },
      {
        'id': Uuid().v4(),
        'name': 'Radiologue',
        'description': 'Spécialiste de l\'imagerie médicale',
        'isActive': 1,
      },
      {
        'id': Uuid().v4(),
        'name': 'Infirmier',
        'description': 'Professionnel de santé assurant les soins infirmiers',
        'isActive': 1,
      },
      {
        'id': Uuid().v4(),
        'name': 'Kinésithérapeute',
        'description': 'Spécialiste de la rééducation fonctionnelle',
        'isActive': 1,
      },
      {
        'id': Uuid().v4(),
        'name': 'Sage-femme',
        'description':
            'Professionnel de santé spécialisé dans le suivi de grossesse et l\'accouchement',
        'isActive': 1,
      },
      {
        'id': Uuid().v4(),
        'name': 'Dentiste',
        'description': 'Spécialiste des soins dentaires',
        'isActive': 1,
      },
      {
        'id': Uuid().v4(),
        'name': 'Pharmacien',
        'description': 'Spécialiste du médicament',
        'isActive': 1,
      },
      {
        'id': Uuid().v4(),
        'name': 'Psychologue',
        'description': 'Spécialiste de la santé mentale',
        'isActive': 1,
      },
      {
        'id': Uuid().v4(),
        'name': 'Diététicien',
        'description': 'Spécialiste de la nutrition',
        'isActive': 1,
      },
      {
        'id': Uuid().v4(),
        'name': 'Ergothérapeute',
        'description': 'Spécialiste de la réadaptation',
        'isActive': 1,
      },
      {
        'id': Uuid().v4(),
        'name': 'Orthophoniste',
        'description': 'Spécialiste des troubles de la communication',
        'isActive': 1,
      },
      {
        'id': Uuid().v4(),
        'name': 'Podologue',
        'description': 'Spécialiste des affections du pied',
        'isActive': 1,
      },
    ];

    // Insertion des catégories dans la base de données
    for (var category in categories) {
      await db.insert(
        'health_professional_categories',
        category,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    Log.d(
      "DatabaseHelper: ${categories.length} catégories de professionnels de santé initialisées",
    );
  }

  Future<List<Map<String, dynamic>>> getPS() async {
    Log.d("DatabaseHelper: Récupération des professionnels de santé");
    final db = await database;
    try {
      // Récupérer tous les professionnels de santé
      final List<Map<String, dynamic>> professionals = await db.query(
        'health_professionals',
      );
      Log.d("DatabaseHelper: ${professionals.length} professionnels récupérés");

      // Pour chaque professionnel, récupérer ses contacts, adresses et établissements
      List<Map<String, dynamic>> result = [];

      for (var professional in professionals) {
        // Créer une copie modifiable du professionnel
        final Map<String, dynamic> professionalCopy = Map<String, dynamic>.from(
          professional,
        );

        // Récupérer les contacts
        final contacts = await db.query(
          'health_professional_contacts',
          where: 'healthProfessionalId = ?',
          whereArgs: [professional['id']],
        );
        Log.d(
          'Récupération health_professional_contacts:[${contacts.toString()}]',
        );

        // Convertir chaque contact en Map modifiable
        List<Map<String, dynamic>> contactsCopy = [];
        for (var contact in contacts) {
          contactsCopy.add(Map<String, dynamic>.from(contact));
        }
        professionalCopy['contacts'] = contactsCopy;

        // Récupérer les adresses
        final addresses = await db.query(
          'health_professional_addresses',
          where: 'healthProfessionalId = ?',
          whereArgs: [professional['id']],
        );
        Log.d(
          'Récupération health_professional_addresses:[${addresses.toString()}]',
        );

        // Convertir chaque adresse en Map modifiable
        List<Map<String, dynamic>> addressesCopy = [];
        for (var address in addresses) {
          addressesCopy.add(Map<String, dynamic>.from(address));
        }
        professionalCopy['addresses'] = addressesCopy;

        // Récupérer les établissements
        final establishmentLinks = await db.query(
          'health_professional_establishments',
          where: 'healthProfessionalId = ?',
          whereArgs: [professional['id']],
        );
        Log.d(
          'Récupération health_professional_establishments:[${establishmentLinks.toString()}]',
        );

        List<Map<String, dynamic>> establishments = [];
        for (var link in establishmentLinks) {
          final establishmentResults = await db.query(
            'establishments',
            where: 'id = ?',
            whereArgs: [link['establishmentId']],
          );

          if (establishmentResults.isNotEmpty) {
            // Créer une copie modifiable de l'établissement
            final Map<String, dynamic> establishment =
                Map<String, dynamic>.from(establishmentResults.first);
            establishment['role'] = link['role'];
            establishments.add(establishment);
          }
        }

        professionalCopy['establishments'] = establishments;

        // Récupérer la catégorie
        final categoryResults = await db.query(
          'health_professional_categories',
          where: 'id = ?',
          whereArgs: [professional['categoryId']],
        );

        if (categoryResults.isNotEmpty) {
          professionalCopy['category'] = Map<String, dynamic>.from(
            categoryResults.first,
          );
        }

        result.add(professionalCopy);
      }

      return result;
    } catch (e) {
      Log.d(
        "DatabaseHelper: Erreur lors de la récupération des professionnels de santé: $e",
      );
      return [];
    }
  }

  Future<bool> insertPS(Map<String, dynamic> healthProfessional) async {
    Log.d("DatabaseHelper: Insertion d'un professionnel de santé");
    final db = await database;

    return await db.transaction((txn) async {
      // Insérer le professionnel de santé de base
      final professionalData = {
        'id': healthProfessional['id'] ?? Uuid().v4(),
        'firstName': healthProfessional['firstName'],
        'lastName': healthProfessional['lastName'],
        'categoryId': healthProfessional['categoryId'],
        'specialtyDetails': healthProfessional['specialtyDetails'],
        'notes': healthProfessional['notes'],
      };

      try {
        await txn.insert(
          'health_professionals',
          professionalData,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      } catch (e) {
        Log.d('Erreur lors de l nsertion de health_professionals $e');
      }
      Log.d('Insertion de health_professionals OK');

      // Insérer les contacts
      if (healthProfessional['contacts'] != null) {
        Log.d('Insertion Contact');
        for (var contact in healthProfessional['contacts']) {
          Log.d('    contact:[${healthProfessional['contacts']}]');
          final contactData = {
            'id': contact['id'] ?? Uuid().v4(),
            'healthProfessionalId': professionalData['id'],
            'type': contact['type'],
            'value': contact['value'],
            'label': contact['label'],
            'isPrimary': contact['isPrimary'],
          };
          try {
            Log.d('    contactData:[${contactData.toString()}]');
            await txn.insert(
              'health_professional_contacts',
              contactData,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          } catch (e) {
            Log.d(
              'Erreur lors de l insertion de health_professional_contacts $e',
            );
          }
          Log.d(
            'Insertion de health_professional_contacts id:[${contact['id']}] healthProfessionalId:[${professionalData['id']} type:[${contact['type']} value:[${contact['value']} label:[${contact['label']} isPrimary:[${contact['isPrimary']}] OK',
          );
        }
        Log.d('Insertion de health_professional_contacts OK');
      }

      // Insérer les adresses
      if (healthProfessional['addresses'] != null) {
        for (var address in healthProfessional['addresses']) {
          final addressData = {
            'id': address['id'] ?? Uuid().v4(),
            'healthProfessionalId': professionalData['id'],
            'street': address['street'],
            'city': address['city'],
            'postalCode': address['postalCode'],
            'country': address['country'] ?? 'France',
            'label': address['label'],
            'isPrimary': address['isPrimary'],
          };
          try {
            await txn.insert(
              'health_professional_addresses',
              addressData,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          } catch (e) {
            Log.d(
              'Erreur lors de l nsertion de health_professional_addresses $e',
            );
          }
        }
        Log.d('Insertion de health_professional_addresses OK');
      }

      // Lier aux établissements
      if (healthProfessional['establishments'] != null) {
        for (var establishment in healthProfessional['establishments']) {
          final linkData = {
            'healthProfessionalId': professionalData['id'],
            'establishmentId': establishment['id'],
            'role': establishment['role'],
          };
          try {
            await txn.insert(
              'health_professional_establishments',
              linkData,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          } catch (e) {
            Log.d(
              'Erreur lors de l nsertion de health_professional_establishments $e',
            );
          }
        }
        Log.d('Insertion de health_professional_establishments OK');
      }

      return true; // Succès
    });
  }

  Future<int> deleteHealthProfessional(String id) async {
    Log.d("DatabaseHelper: Suppression du professionnel de santé avec ID $id");
    final db = await database;

    try {
      // Vérifier d'abord si le professionnel existe
      final List<Map<String, dynamic>> check = await db.query(
        'health_professionals',
        where: 'id = ?',
        whereArgs: [id],
      );

      if (check.isEmpty) {
        Log.d("DatabaseHelper: Professionnel introuvable avec ID $id");
        return 0;
      }

      // Les tables liées seront supprimées en cascade grâce aux contraintes FOREIGN KEY
      final result = await db.delete(
        'health_professionals',
        where: 'id = ?',
        whereArgs: [id],
      );

      Log.d(
        "DatabaseHelper: Professionnel supprimé avec succès, lignes affectées: $result",
      );
      return result;
    } catch (e) {
      Log.e(
        "DatabaseHelper: Erreur lors de la suppression du professionnel de santé: $e",
      );
      return -1;
    }
  }

  Future<bool> updatePS(Map<String, dynamic> healthProfessional) async {
    Log.d(
      "DatabaseHelper: Mise à jour du professionnel de santé ${healthProfessional['id']}",
    );
    final db = await database;

    try {
      return await db.transaction((txn) async {
        // Mettre à jour le professionnel de santé de base
        final professionalData = {
          'firstName': healthProfessional['firstName'],
          'lastName': healthProfessional['lastName'],
          'categoryId': healthProfessional['categoryId'],
          'specialtyDetails': healthProfessional['specialtyDetails'],
          'notes': healthProfessional['notes'],
        };

        await txn.update(
          'health_professionals',
          professionalData,
          where: 'id = ?',
          whereArgs: [healthProfessional['id']],
        );

        // Supprimer les contacts existants
        await txn.delete(
          'health_professional_contacts',
          where: 'healthProfessionalId = ?',
          whereArgs: [healthProfessional['id']],
        );

        // Insérer les nouveaux contacts
        if (healthProfessional['contacts'] != null) {
          for (var contact in healthProfessional['contacts']) {
            final contactData = {
              'id': contact['id'] ?? Uuid().v4(),
              'healthProfessionalId': healthProfessional['id'],
              'type': contact['type'],
              'value': contact['value'],
              'label': contact['label'],
              'isPrimary': contact['isPrimary'],
            };
            await txn.insert(
              'health_professional_contacts',
              contactData,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        }

        // Supprimer les adresses existantes
        await txn.delete(
          'health_professional_addresses',
          where: 'healthProfessionalId = ?',
          whereArgs: [healthProfessional['id']],
        );

        // Insérer les nouvelles adresses
        if (healthProfessional['addresses'] != null) {
          for (var address in healthProfessional['addresses']) {
            final addressData = {
              'id': address['id'] ?? Uuid().v4(),
              'healthProfessionalId': healthProfessional['id'],
              'street': address['street'],
              'city': address['city'],
              'postalCode': address['postalCode'],
              'country': address['country'] ?? 'France',
              'label': address['label'],
              'isPrimary': address['isPrimary'],
            };
            await txn.insert(
              'health_professional_addresses',
              addressData,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        }

        // Supprimer les liens avec les établissements existants
        await txn.delete(
          'health_professional_establishments',
          where: 'healthProfessionalId = ?',
          whereArgs: [healthProfessional['id']],
        );

        // Lier aux établissements
        if (healthProfessional['establishments'] != null) {
          Log.d('Traitement Etablissment du PS');
          for (var establishment in healthProfessional['establishments']) {
            Log.d('   establishment ${establishment.toString()}');
            final linkData = {
              'healthProfessionalId': healthProfessional['id'],
              'establishmentId': establishment['id'],
              'role': establishment['role'],
            };
            await txn.insert(
              'health_professional_establishments',
              linkData,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        } else {
          Log.d("Pad d'établissment pour le PS");
        }

        return true; // Succès
      });
    } catch (e) {
      Log.e(
        "DatabaseHelper: Erreur lors de la mise à jour du professionnel de santé: $e",
      );
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getPSContacts(
    String healthProfessionalId,
  ) async {
    final db = await database;
    return await db.query(
      'health_professional_contacts',
      where: 'healthProfessionalId = ?',
      whereArgs: [healthProfessionalId],
    );
  }

  Future<List<Map<String, dynamic>>> getPSAddresses(
    String healthProfessionalId,
  ) async {
    final db = await database;
    return await db.query(
      'health_professional_addresses',
      where: 'healthProfessionalId = ?',
      whereArgs: [healthProfessionalId],
    );
  }

  Future<List<Map<String, dynamic>>> getPSEstablishments(
    String healthProfessionalId,
  ) async {
    final db = await database;
    // Récupérer les ID des établissements liés au PS
    final links = await db.query(
      'health_professional_establishments',
      where: 'healthProfessionalId = ?',
      whereArgs: [healthProfessionalId],
    );

    List<Map<String, dynamic>> result = [];

    for (var link in links) {
      final establishmentId = link['establishmentId'];
      // Récupérer les détails de l'établissement
      final establishments = await db.query(
        'establishments',
        where: 'id = ?',
        whereArgs: [establishmentId],
      );

      if (establishments.isNotEmpty) {
        // Ajouter le rôle à l'établissement
        final establishment = Map<String, dynamic>.from(establishments.first);
        establishment['role'] = link['role'];
        result.add(establishment);
      }
    }

    return result;
  }

  Future<Map<String, dynamic>?> getHealthProfessional(String id) async {
    Log.d(
      "DatabaseHelper: Récupération du professionnel de santé avec ID: $id",
    );
    final db = await database;

    try {
      final results = await db.query(
        'health_professionals',
        where: 'id = ?',
        whereArgs: [id],
      );

      if (results.isEmpty) {
        return null;
      }

      final professional = results.first;
      final Map<String, dynamic> completeProfile = Map.from(professional);

      // Récupérer les contacts
      final List<Map<String, dynamic>> contacts = await db.query(
        'health_professional_contacts',
        where: 'healthProfessionalId = ?',
        whereArgs: [id],
      );
      completeProfile['contacts'] = contacts;

      // Récupérer les adresses
      final List<Map<String, dynamic>> addresses = await db.query(
        'health_professional_addresses',
        where: 'healthProfessionalId = ?',
        whereArgs: [id],
      );
      completeProfile['addresses'] = addresses;

      // Récupérer les établissements liés
      final List<Map<String, dynamic>> establishments = await db.rawQuery(
        '''
      SELECT e.*, hpe.role
      FROM establishments e
      INNER JOIN health_professional_establishments hpe ON e.id = hpe.establishmentId
      WHERE hpe.healthProfessionalId = ?
    ''',
        [id],
      );
      completeProfile['establishments'] = establishments;

      // Récupérer la catégorie
      final List<Map<String, dynamic>> categories = await db.query(
        'health_professional_categories',
        where: 'id = ?',
        whereArgs: [professional['categoryId']],
      );
      if (categories.isNotEmpty) {
        completeProfile['category'] = categories.first;
      }

      return completeProfile;
    } catch (e) {
      Log.e(
        "DatabaseHelper: Erreur lors de la récupération du professionnel de santé: $e",
      );
      return null;
    }
  }

  // Insérer une catégorie
  Future<int> insertHealthProfessionalCategory(
    Map<String, dynamic> category,
  ) async {
    Log.d(
      "DatabaseHelper: Insertion d'une catégorie de professionnel de santé",
    );
    final db = await database;

    try {
      final categoryData = {
        'id': category['id'] ?? Uuid().v4(),
        'name': category['name'],
        'description': category['description'],
        'isActive': category['isActive'],
      };

      final result = await db.insert(
        'health_professional_categories',
        categoryData,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      Log.d("DatabaseHelper: Catégorie insérée avec succès, résultat: $result");
      return result;
    } catch (e) {
      Log.e("DatabaseHelper: Erreur lors de l'insertion de la catégorie: $e");
      return -1;
    }
  }

  // Récupérer toutes les catégories
  Future<List<Map<String, dynamic>>> getHealthProfessionalCategories() async {
    Log.d(
      "DatabaseHelper: Récupération des catégories de professionnels de santé",
    );
    final db = await database;

    try {
      final categories = await db.query(
        'health_professional_categories',
        orderBy: 'name',
      );

      Log.d("DatabaseHelper: ${categories.length} catégories récupérées");
      return categories;
    } catch (e) {
      Log.e(
        "DatabaseHelper: Erreur lors de la récupération des catégories: $e",
      );
      return [];
    }
  }

  // Insérer une prise de médicament
  Future<int> insertMedicationIntake(Map<String, dynamic> intake) async {
    final db = await database;

    // Extraire les médicaments pour les stocker séparément
    List<Map<String, dynamic>> medications = List<Map<String, dynamic>>.from(
      intake['medications'],
    );

    // Créer une copie de l'intake sans les médicaments pour la table principale
    Map<String, dynamic> intakeData = Map<String, dynamic>.from(intake);
    intakeData.remove('medications');

    // Stocker les données de base de la prise
    int result = await db.insert('medication_intakes', intakeData);

    // Stocker chaque médicament dans une table de relation
    for (var med in medications) {
      await db.insert('medication_intake_items', {
        'intakeId': intake['id'],
        'medicationId': med['medicationId'],
        'medicationName': med['medicationName'],
        'quantity': med['quantity'],
      });
    }

    return result;
  }

  // Récupérer les prises de médicaments pour un cycle
  Future<List<Map<String, dynamic>>> getMedicationIntakesByCycle(
    String cycleId,
  ) async {
    final db = await database;

    // Récupérer les prises de médicaments pour ce cycle
    final List<Map<String, dynamic>> intakes = await db.query(
      'medication_intakes',
      where: 'cycleId = ?',
      whereArgs: [cycleId],
    );

    // Pour chaque prise, récupérer les médicaments associés
    List<Map<String, dynamic>> result = [];
    for (var intake in intakes) {
      final List<Map<String, dynamic>> medications = await db.query(
        'medication_intake_items',
        where: 'intakeId = ?',
        whereArgs: [intake['id']],
      );

      Map<String, dynamic> completeIntake = Map<String, dynamic>.from(intake);
      completeIntake['medications'] = medications;

      result.add(completeIntake);
    }

    return result;
  }

  // Mettre à jour une prise de médicament
  Future<int> updateMedicationIntake(Map<String, dynamic> intake) async {
    final db = await database;

    // Extraire les médicaments
    List<Map<String, dynamic>> medications = List<Map<String, dynamic>>.from(
      intake['medications'],
    );

    // Créer une copie de l'intake sans les médicaments
    Map<String, dynamic> intakeData = Map<String, dynamic>.from(intake);
    intakeData.remove('medications');

    // Mettre à jour les données de base
    await db.update(
      'medication_intakes',
      intakeData,
      where: 'id = ?',
      whereArgs: [intake['id']],
    );

    // Supprimer les anciens médicaments
    await db.delete(
      'medication_intake_items',
      where: 'intakeId = ?',
      whereArgs: [intake['id']],
    );

    // Ajouter les nouveaux médicaments
    for (var med in medications) {
      await db.insert('medication_intake_items', {
        'intakeId': intake['id'],
        'medicationId': med['medicationId'],
        'medicationName': med['medicationName'],
        'quantity': med['quantity'],
      });
    }

    return 1;
  }

  // Supprimer une prise de médicament
  Future<int> deleteMedicationIntake(String id) async {
    Log.d("DatabaseHelper: Suppression de la prise de médicament avec ID $id");
    final db = await database;
    try {
      final result = await db.delete(
        'medication_intakes',
        where: 'id = ?',
        whereArgs: [id],
      );
      Log.d(
        "DatabaseHelper: Prise de médicament supprimée avec succès, lignes affectées: $result",
      );
      return result;
    } catch (e) {
      Log.d(
        "DatabaseHelper: Erreur lors de la suppression de la prise de médicament: $e",
      );
      return -1;
    }
  }

  // Mettre à jour le statut d'une prise de médicament (pris/non pris)
  Future<int> updateMedicationIntakeCompletionStatus(
    String id,
    bool isCompleted,
  ) async {
    final db = await database;
    try {
      final result = await db.update(
        'medication_intakes',
        {'isCompleted': isCompleted ? 1 : 0},
        where: 'id = ?',
        whereArgs: [id],
      );
      return result;
    } catch (e) {
      Log.d(
        "Erreur lors de la mise à jour du statut de la prise de médicament: $e",
      );
      return -1;
    }
  }

  Future<List<Map<String, dynamic>>> getUpcomingEvents(int limit) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    // Requête pour les prochaines séances
    final sessionsQuery = '''
      SELECT id, dateTime as date, 'Séance' as title, 'session' as type
      FROM sessions
      WHERE dateTime > ? AND isCompleted = 0
    ''';

    // Requête pour les prochains rendez-vous
    final appointmentsQuery = '''
      SELECT id, dateTime as date, title, 'appointment' as type
      FROM appointments
      WHERE dateTime > ? AND isCompleted = 0
    ''';

    // Requête pour les prochains examens
    final examinationsQuery = '''
      SELECT id, dateTime as date, title, 'examination' as type
      FROM examinations
      WHERE dateTime > ? AND isCompleted = 0
    ''';

    // Combinaison des requêtes
    final String fullQuery = '''
      SELECT * FROM (
        $sessionsQuery
        UNION ALL
        $appointmentsQuery
        UNION ALL
        $examinationsQuery
      )
      ORDER BY date ASC
      LIMIT ?
    ''';

    final results = await db.rawQuery(fullQuery, [now, now, now, limit]);

    // Conversion de la date en DateTime
    return results.map((map) {
      final newMap = Map<String, dynamic>.from(map);
      newMap['date'] = DateTime.parse(map['date'] as String);
      return newMap;
    }).toList();
  }

  /// Récupère la progression (séances complétées / total) pour tous les cycles d'un traitement.
  Future<Map<String, int>> getSessionProgress(String treatmentId) async {
    final db = await database;
    int totalSessions = 0;
    int completedSessions = 0;

    // Récupérer tous les cycles pour le traitement donné
    final cycles = await db.query(
      'cycles',
      where: 'treatmentId = ?',
      whereArgs: [treatmentId],
    );

    if (cycles.isEmpty) {
      return {'completed': 0, 'total': 0};
    }

    List<String> cycleIds = cycles.map((c) => c['id'] as String).toList();

    // Construire la clause WHERE pour les IDs de cycle
    final placeholders = cycleIds.map((_) => '?').join(',');

    // Compter le nombre total de séances pour ces cycles
    final totalResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM sessions WHERE cycleId IN ($placeholders)',
      cycleIds,
    );
    if (totalResult.isNotEmpty) {
      totalSessions = (totalResult.first['count'] as int?) ?? 0;
    }

    // Compter le nombre de séances complétées pour ces cycles
    final completedResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM sessions WHERE cycleId IN ($placeholders) AND isCompleted = 1',
      cycleIds,
    );
    if (completedResult.isNotEmpty) {
      completedSessions = (completedResult.first['count'] as int?) ?? 0;
    }

    return {'completed': completedSessions, 'total': totalSessions};
  }

// ===== AJOUTER CETTE MÉTHODE DANS la classe DatabaseHelper =====

  /// Récupère les prochains événements (séances, rdv, examens) à venir pour un cycle spécifique.
  Future<List<Map<String, dynamic>>> getUpcomingEventsForCycle(String cycleId, int limit, [int? inNextDays]) async {
    final db = await database;
    final now = DateTime.now();
    final nowStr = now.toIso8601String();

    // NOUVEAU : Calculer la date limite si 'inNextDays' est fourni
    String dateLimitStr = '';
    if (inNextDays != null) {
      final dateLimit = now.add(Duration(days: inNextDays));
      dateLimitStr = "AND dateTime <= '${dateLimit.toIso8601String()}'";
    }

    // NOUVEAU : Intégration de la limite de date dans les requêtes
    final sessionsQuery = '''
      SELECT id, dateTime as date, 'Séance' as title, 'session' as type
      FROM sessions
      WHERE cycleId = ? AND dateTime > ? $dateLimitStr AND isCompleted = 0
    ''';

    final appointmentsQuery = '''
      SELECT a.id, a.dateTime as date, a.title, 'appointment' as type
      FROM appointments a
      INNER JOIN cycle_appointments ca ON a.id = ca.appointmentId
      WHERE ca.cycleId = ? AND a.dateTime > ? $dateLimitStr AND a.isCompleted = 0
    ''';

    final examinationsQuery = '''
      SELECT id, dateTime as date, title, 'examination' as type
      FROM examinations
      WHERE cycleId = ? AND dateTime > ? $dateLimitStr AND isCompleted = 0
    ''';

    final String fullQuery = '''
      SELECT * FROM (
        $sessionsQuery
        UNION ALL
        $appointmentsQuery
        UNION ALL
        $examinationsQuery
      )
      ORDER BY date ASC
      LIMIT ?
    ''';

    final results = await db.rawQuery(fullQuery, [cycleId, nowStr, cycleId, nowStr, cycleId, nowStr, limit]);

    return results.map((map) {
      final newMap = Map<String, dynamic>.from(map);
      newMap['date'] = DateTime.parse(map['date'] as String);
      return newMap;
    }).toList();
  }

  // Récupère le nom du traitement associé à un événement (session, rdv, examen)
  Future<String?> getTreatmentNameForEvent(String eventType, String eventId) async {
    final db = await database;
    String? treatmentId;

    if (eventType == 'session' || eventType == 'examination' || eventType == 'appointment') {
      // Pour une session, un examen ou un rdv, on remonte au cycle pour trouver le treatmentId
      final cycleLink = await db.rawQuery('''
        SELECT c.treatmentId FROM cycles c
        INNER JOIN (
          SELECT cycleId FROM sessions WHERE id = ?
          UNION ALL
          SELECT cycleId FROM examinations WHERE id = ?
          UNION ALL
          SELECT ca.cycleId FROM cycle_appointments ca WHERE ca.appointmentId = ?
        ) AS event_link ON c.id = event_link.cycleId
        LIMIT 1
      ''', [eventId, eventId, eventId]);

      if (cycleLink.isNotEmpty) {
        treatmentId = cycleLink.first['treatmentId'] as String?;
      }
    }

    if (treatmentId != null) {
      final treatment = await getTreatment(treatmentId);
      return treatment?['label'] as String?;
    }

    return null;
  }
}
