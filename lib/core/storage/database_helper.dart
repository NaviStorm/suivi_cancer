// lib/core/storage/database_helper.dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:suivi_cancer/utils/logger.dart';
import 'package:uuid/uuid.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) {
      // Vérifier si la base de données est fermée
      try {
        await _database!.rawQuery('SELECT 1');
      } catch (e) {
        Log.d("DatabaseHelper: La base de données était fermée, réouverture");
        _database = null;
      }
    }

    if (_database == null) {
      _database = await _initDatabase();
    }

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
      onOpen: (db) {
        Log.d("DatabaseHelper: Base de données ouverte avec succès");
      },
    );
  }

  Future<Database> _initDatabaseOLD() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'suivi_cancer.db');

    // Vérifier si la base de données existe déjà
    bool exists = await databaseExists(path);

    // La base de données n'existe pas, on la crée
    Log.d("DatabaseHelper: Création d'une nouvelle base de données");
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onOpen: (db) {
        Log.d("DatabaseHelper: Base de données ouverte avec succès");
      },// Optionnel, pour les futures mises à jour
      readOnly: false,
      singleInstance: true,
    );
  }

  Future _onCreate(Database db, int version) async {
    Log.d("DatabaseHelper: Création des tables de la base de données");

    // Table des médecins
    await db.execute('''
      CREATE TABLE doctors(
        id TEXT PRIMARY KEY,
        firstName TEXT NOT NULL,
        lastName TEXT NOT NULL,
        specialty INTEGER,
        otherSpecialty TEXT
      )
    ''');
    Log.d("DatabaseHelper: Table 'doctors' créée");


    // Table des contacts des médecins
    await db.execute('''
      CREATE TABLE IF NOT EXISTS doctor_contacts(
        id TEXT PRIMARY KEY,
        doctorId TEXT NOT NULL,
        type INTEGER NOT NULL,
        category INTEGER NOT NULL,
        value TEXT NOT NULL,
        FOREIGN KEY (doctorId) REFERENCES doctors (id) ON DELETE CASCADE
      )
    ''');
    Log.d("DatabaseHelper: Table 'doctor_contacts' créée");

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
        doctorId TEXT NOT NULL,
        PRIMARY KEY (treatmentId, doctorId),
        FOREIGN KEY (treatmentId) REFERENCES treatments (id) ON DELETE CASCADE,
        FOREIGN KEY (doctorId) REFERENCES doctors (id) ON DELETE CASCADE
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


    // Table de relation entre cycles et médecins
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cure_doctors(
        cycleId TEXT NOT NULL,
        doctorId TEXT NOT NULL,
        PRIMARY KEY (cycleId, doctorId),
        FOREIGN KEY (cycleId) REFERENCES cycles (id) ON DELETE CASCADE,
        FOREIGN KEY (doctorId) REFERENCES doctors (id) ON DELETE CASCADE
      )
    ''');
    Log.d("DatabaseHelper: Table 'cure_doctors' créée");


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


    // Table des opérations chirurgicales
    await db.execute('''
      CREATE TABLE IF NOT EXISTS surgeries(
        id TEXT PRIMARY KEY,
        treatmentId TEXT NOT NULL,
        title TEXT NOT NULL,
        date TEXT NOT NULL,
        establishmentId TEXT NOT NULL,
        description TEXT,
        isCompleted INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (treatmentId) REFERENCES treatments (id) ON DELETE CASCADE,
        FOREIGN KEY (establishmentId) REFERENCES establishments (id) ON DELETE CASCADE
      )
    ''');
    Log.d("DatabaseHelper: Table 'surgeries' créée");


// Ajout d'un champ 'role' à la table surgery_doctors pour distinguer chirurgiens et anesthésistes
// Si la table existe déjà, il faudra la modifier ou la recréer
    await db.execute('''
  DROP TABLE IF EXISTS surgery_doctors
''');

    await db.execute('''
  CREATE TABLE IF NOT EXISTS surgery_doctors(
    surgeryId TEXT NOT NULL,
    doctorId TEXT NOT NULL,
    role TEXT NOT NULL, -- 'surgeon' ou 'anesthetist'
    PRIMARY KEY (surgeryId, doctorId, role),
    FOREIGN KEY (surgeryId) REFERENCES surgeries (id) ON DELETE CASCADE,
    FOREIGN KEY (doctorId) REFERENCES doctors (id) ON DELETE CASCADE
  )
''');
    Log.d("DatabaseHelper: Table 'surgery_doctors' créée/modifiée");

    // Table des radiothérapies
    await db.execute('''
      CREATE TABLE IF NOT EXISTS radiotherapies(
        id TEXT PRIMARY KEY,
        treatmentId TEXT NOT NULL,
        title TEXT NOT NULL,
        startDate TEXT NOT NULL,
        endDate TEXT NOT NULL,
        establishmentId TEXT NOT NULL,
        sessionCount INTEGER NOT NULL,
        description TEXT,
        isCompleted INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (treatmentId) REFERENCES treatments (id) ON DELETE CASCADE,
        FOREIGN KEY (establishmentId) REFERENCES establishments (id) ON DELETE CASCADE
      )
    ''');
    Log.d("DatabaseHelper: Table 'radiotherapies' créée");


    // Table des rendez-vous
    await db.execute('''
      CREATE TABLE IF NOT EXISTS appointments(
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        dateTime TEXT NOT NULL,
        duration INTEGER,
        doctorId TEXT,
        establishmentId TEXT,
        notes TEXT,
        isCompleted INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (doctorId) REFERENCES doctors (id) ON DELETE SET NULL,
        FOREIGN KEY (establishmentId) REFERENCES establishments (id) ON DELETE SET NULL
      )
    ''');
    Log.d("DatabaseHelper: Table 'appointments' créée");


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
    FOREIGN KEY (entityId) REFERENCES sessions (id) ON DELETE CASCADE,
    FOREIGN KEY (entityId) REFERENCES surgeries (id) ON DELETE CASCADE,
    FOREIGN KEY (entityId) REFERENCES radiotherapies (id) ON DELETE CASCADE
  )
''');
    Log.d("DatabaseHelper: Table 'side_effects' créée");

// Table de relation entre radiothérapies et médecins
    await db.execute('''
  CREATE TABLE IF NOT EXISTS radiotherapy_doctors(
    radiotherapyId TEXT NOT NULL,
    doctorId TEXT NOT NULL,
    PRIMARY KEY (radiotherapyId, doctorId),
    FOREIGN KEY (radiotherapyId) REFERENCES radiotherapies (id) ON DELETE CASCADE,
    FOREIGN KEY (doctorId) REFERENCES doctors (id) ON DELETE CASCADE
  )
''');
    Log.d("DatabaseHelper: Table 'radiotherapy_doctors' créée");

// Table des sessions de radiothérapie
    await db.execute('''
  CREATE TABLE IF NOT EXISTS radiotherapy_sessions(
    id TEXT PRIMARY KEY,
    radiotherapyId TEXT NOT NULL,
    dateTime TEXT NOT NULL,
    area TEXT,
    dose REAL,
    notes TEXT,
    isCompleted INTEGER NOT NULL DEFAULT 0,
    FOREIGN KEY (radiotherapyId) REFERENCES radiotherapies (id) ON DELETE CASCADE
  )
''');
    Log.d("DatabaseHelper: Table 'radiotherapy_sessions' créée");

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
      CREATE TABLE IF NOT EXISTS medication_intakes(
        id TEXT PRIMARY KEY,
        dateTime TEXT NOT NULL,
        cycleId TEXT NOT NULL,
        medicationId TEXT NOT NULL,
        medicationName TEXT NOT NULL,
        isCompleted INTEGER NOT NULL DEFAULT 0,
        notes TEXT,
        FOREIGN KEY (cycleId) REFERENCES cycles (id) ON DELETE CASCADE,
        FOREIGN KEY (medicationId) REFERENCES medications (id) ON DELETE CASCADE
      )
      ''');
    Log.d("DatabaseHelper: Table 'medication_intakes' créée");

  }

  // Pour les futures mises à jour
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    Log.d("DatabaseHelper: Mise à jour de la base de données de la version $oldVersion vers $newVersion");

    // Logique de migration ici
  }

  // Méthodes pour les médecins
  Future<List<Map<String, dynamic>>> getDoctorsOLD() async {
    try {
      Log.d("DatabaseHelper: Récupération des médecins");
      final db = await database;

      // Récupérer tous les médecins
      final List<Map<String, dynamic>> doctors = await db.query('doctors');
      Log.d("DatabaseHelper: ${doctors.length} médecins récupérés");

      // Pour chaque médecin, récupérer ses contacts
      for (var doctor in doctors) {
        Log.d("DatabaseHelper: Récupération des contacts pour le médecin ${doctor['id']}");
        final List<Map<String, dynamic>> contacts = await db.query(
          'doctor_contacts',
          where: 'doctorId = ?',
          whereArgs: [doctor['id']],
        );

        Log.d("DatabaseHelper: ${contacts.length} contacts récupérés pour le médecin ${doctor['id']}");

        // Convertir les contacts au format attendu par ContactInfo.fromMap
        final List<Map<String, dynamic>> formattedContacts = contacts.map((contact) {
          return {
            'id': contact['id'],
            'type': contact['type'],
            'category': contact['category'],
            'value': contact['value'],
          };
        }).toList();

        // Ajouter les contacts au médecin
        doctor['contactInfos'] = formattedContacts;
      }

      return doctors;
    } catch (e) {
      Log.d("DatabaseHelper: Erreur lors de la récupération des médecins: $e");
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getDoctors() async {
    try {
      Log.d("DatabaseHelper: Récupération des médecins");
      final db = await database;

      // Récupérer tous les médecins
      final List<Map<String, dynamic>> doctors = await db.query('doctors');
      Log.d("DatabaseHelper: ${doctors.length} médecins récupérés");

      // Pour chaque médecin, créer une copie et y ajouter les contacts
      final List<Map<String, dynamic>> result = [];

      for (var doctor in doctors) {
        // Créer une copie du médecin pour éviter de modifier l'original
        final Map<String, dynamic> doctorWithContacts = Map.from(doctor);

        // Vérifier d'abord si la table doctor_contacts existe
        final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='doctor_contacts'");

        if (tables.isNotEmpty) {
          try {
            // Récupérer les contacts pour ce médecin
            final List<Map<String, dynamic>> contacts = await db.query(
              'doctor_contacts',
              where: 'doctorId = ?',
              whereArgs: [doctor['id']],
            );

            Log.d("DatabaseHelper: ${contacts.length} contacts récupérés pour le médecin ${doctor['id']}");

            // Ajouter les contacts au médecin
            doctorWithContacts['contactInfos'] = contacts;
          } catch (e) {
            Log.d("DatabaseHelper: Erreur lors de la récupération des contacts: $e");
            doctorWithContacts['contactInfos'] = [];
          }
        } else {
          Log.d("DatabaseHelper: La table doctor_contacts n'existe pas");
          doctorWithContacts['contactInfos'] = [];
        }

        result.add(doctorWithContacts);
      }

      return result;
    } catch (e) {
      Log.d("DatabaseHelper: Erreur lors de la récupération des médecins: $e");
      return [];
    }
  }

  Future<Map<String, dynamic>?> getDoctor(dynamic id) async {
    String doctorId = id is int ? id.toString() : id;
    Log.d("DatabaseHelper: Récupération du médecin avec ID: $doctorId");
    final db = await database;
    try {
      final results = await db.query('doctors', where: 'id = ?', whereArgs: [doctorId]);
      Log.d("DatabaseHelper: ${results.length} résultats trouvés");
      return results.isNotEmpty ? results.first : null;
    } catch (e) {
      Log.d("DatabaseHelper: Erreur lors de la récupération du médecin: $e");
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getDoctorContacts(dynamic doctorId) async {
    String id = doctorId is int ? doctorId.toString() : doctorId;
    try {
      Log.d("DatabaseHelper: Récupération des contacts pour le médecin $doctorId");
      final db = await database;
      final contacts = await db.query(
        'doctor_contacts',
        where: 'doctorId = ?',
        whereArgs: [id],
      );
      Log.d("DatabaseHelper: ${contacts.length} contacts récupérés");
      return contacts;
    } catch (e) {
      Log.d("DatabaseHelper: Erreur lors de la récupération des contacts: $e");
      return [];
    }
  }


  Future<int> insertDoctor(Map<String, dynamic> doctor) async {
    Log.d("DatabaseHelper: Insertion d'un médecin: $doctor");
    final db = await database;
    try {
      final result = await db.insert('doctors', doctor, conflictAlgorithm: ConflictAlgorithm.replace);
      Log.d("DatabaseHelper: Médecin inséré avec succès, résultat: $result");
      return result;
    } catch (e) {
      Log.d("DatabaseHelper: Erreur lors de l'insertion du médecin: $e");
      return -1;
    }
  }

// Insérer un contact pour un médecin
  Future<int> insertDoctorContact(Map<String, dynamic> contact) async {
    try {
      Log.d("DatabaseHelper: Insertion d'un contact pour le médecin ${contact['doctorId']}");
      final db = await database;
      final result = await db.insert('doctor_contacts', contact);
      Log.d("DatabaseHelper: Contact inséré avec succès, résultat: $result");
      return result;
    } catch (e) {
      Log.d("DatabaseHelper: Erreur lors de l'insertion du contact: $e");
      return -1;
    }
  }

  Future<int> deleteDoctor(String id) async {
    try {
      Log.d("DatabaseHelper: Suppression du médecin avec ID $id");
      final db = await database;

      // Vérifier d'abord si le médecin existe
      final List<Map<String, dynamic>> check = await db.query(
        'doctors',
        where: 'id = ?',
        whereArgs: [id],
      );

      if (check.isEmpty) {
        Log.d("DatabaseHelper: Médecin introuvable avec ID $id");
        return 0;
      }

      // Supprimer les relations avec les traitements
      await db.delete(
        'treatment_doctors',
        where: 'doctorId = ?',
        whereArgs: [id],
      );

      // Supprimer les relations avec les cycles
      await db.delete(
        'cure_doctors',
        where: 'doctorId = ?',
        whereArgs: [id],
      );

      // Supprimer les relations avec les chirurgies
      await db.delete(
        'surgery_doctors',
        where: 'doctorId = ?',
        whereArgs: [id],
      );

      // Enfin, supprimer le médecin
      final result = await db.delete(
        'doctors',
        where: 'id = ?',
        whereArgs: [id],
      );

      Log.d("DatabaseHelper: Médecin supprimé avec succès, lignes affectées: $result");
      return result;
    } catch (e) {
      Log.d("DatabaseHelper: Erreur lors de la suppression du médecin: $e");
      return -1;
    }
  }

  Future<int> updateDoctor(Map<String, dynamic> doctor) async {
    try {
      Log.d("DatabaseHelper: Mise à jour du médecin avec ID ${doctor['id']}");
      final db = await database;

      // Vérifier d'abord si le médecin existe
      final List<Map<String, dynamic>> check = await db.query(
        'doctors',
        where: 'id = ?',
        whereArgs: [doctor['id']],
      );

      if (check.isEmpty) {
        Log.d("DatabaseHelper: Médecin introuvable avec ID ${doctor['id']}");
        return 0;
      }

      // Mettre à jour le médecin
      final result = await db.update(
        'doctors',
        doctor,
        where: 'id = ?',
        whereArgs: [doctor['id']],
      );

      Log.d("DatabaseHelper: Médecin mis à jour avec succès, lignes affectées: $result");
      return result;
    } catch (e) {
      Log.d("DatabaseHelper: Erreur lors de la mise à jour du médecin: $e");
      return -1;
    }
  }

  // Méthodes pour les établissements
  Future<List<Map<String, dynamic>>> getEstablishments() async {
    final db = await database;
    return await db.query('establishments');
  }

  Future<Map<String, dynamic>?> getEstablishment(String id) async {
    print("Recherche de l'établissement avec ID: $id");
    final db = await database;
    try {
      final results = await db.query(
        'establishments',
        where: 'id = ?',
        whereArgs: [id],
      );

      print("Résultat de la requête établissement: $results");

      if (results.isNotEmpty) {
        return results.first;
      }

      print("Établissement non trouvé pour ID: $id");
      return null;
    } catch (e) {
      print("Erreur lors de la recherche de l'établissement: $e");
      return null;
    }
  }


  Future<int> insertEstablishment(Map<String, dynamic> establishment) async {
    final db = await database;
    return await db.insert('establishments', establishment, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> updateEstablishment(Map<String, dynamic> establishment) async {
    try {
      Log.d("DatabaseHelper: Mise à jour d'un établissement avec ID: ${establishment['id']}");
      final db = await database;
      final result = await db.update(
        'establishments',
        establishment,
        where: 'id = ?',
        whereArgs: [establishment['id']],
      );
      Log.d("DatabaseHelper: Établissement mis à jour avec succès, lignes affectées: $result");
      return result;
    } catch (e) {
      Log.d("DatabaseHelper: Erreur lors de la mise à jour de l'établissement: $e");
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

      // Mettre à null les références dans les chirurgies
      await db.update(
        'surgeries',
        {'establishmentId': null},
        where: 'establishmentId = ?',
        whereArgs: [id],
      );

      // Mettre à null les références dans les radiothérapies
      await db.update(
        'radiotherapies',
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

      Log.d("DatabaseHelper: Établissement supprimé avec succès, lignes affectées: $result");
      return result;
    } catch (e) {
      Log.d("DatabaseHelper: Erreur lors de la suppression de l'établissement: $e");
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
    final results = await db.query('treatments', where: 'id = ?', whereArgs: [id]);
    return results.isNotEmpty ? results.first : null;
  }

  Future<int> insertTreatment(Map<String, dynamic> treatment) async {
    final db = await database;
    return await db.insert('treatments', treatment, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> updateTreatment(Map<String, dynamic> treatment) async {
    final db = await database;
    return await db.update('treatments', treatment,
        where: 'id = ?',
        whereArgs: [treatment['id']]);
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
      'doctorId': doctorId
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> linkTreatmentHealthProfessional(String treatmentId, String healthProfessionalId) async {
    final db = await database;
    return await db.insert('treatment_health_professionals', {
      'treatmentId': treatmentId,
      'healthProfessionalId': healthProfessionalId
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> linkTreatmentEstablishment(String treatmentId, String establishmentId) async {
    final db = await database;
    return await db.insert('treatment_establishments', {
      'treatmentId': treatmentId,
      'establishmentId': establishmentId
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> unlinkTreatmentDoctor(String treatmentId, String doctorId) async {
    final db = await database;
    return await db.delete('treatment_doctors',
        where: 'treatmentId = ? AND doctorId = ?',
        whereArgs: [treatmentId, doctorId]
    );
  }

  Future<int> unlinkTreatmentEstablishment(String treatmentId, String establishmentId) async {
    final db = await database;
    return await db.delete('treatment_establishments',
        where: 'treatmentId = ? AND establishmentId = ?',
        whereArgs: [treatmentId, establishmentId]
    );
  }

  Future<int> unlinkTreatmentHealthProfessional(String treatmentId, String healthProfessionalId) async {
    final db = await database;
    return await db.delete('treatment_health_professionals',
        where: 'treatmentId = ? AND healthProfessionalId = ?',
        whereArgs: [treatmentId, healthProfessionalId]
    );
  }

  // Méthodes pour récupérer les médecins et établissements liés à un traitement
  Future<List<Map<String, dynamic>>> getTreatmentDoctors(String treatmentId) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT d.* FROM doctors d
      INNER JOIN treatment_doctors td ON d.id = td.doctorId
      WHERE td.treatmentId = ?
    ''', [treatmentId]);
  }

  Future<List<Map<String, dynamic>>> getTreatmentHealthProfessionals(String treatmentId) async {
    final db = await database;
    return await db.rawQuery('''
    SELECT hp.* FROM health_professionals hp
    INNER JOIN treatment_health_professionals thp ON hp.id = thp.healthProfessionalId
    WHERE thp.treatmentId = ?
  ''', [treatmentId]);
  }

  Future<List<Map<String, dynamic>>> getTreatmentEstablishments(String treatmentId) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT e.* FROM establishments e
      INNER JOIN treatment_establishments te ON e.id = te.establishmentId
      WHERE te.treatmentId = ?
    ''', [treatmentId]);
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
    final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
    for (var table in tables) {
      print("Table trouvée: ${table['name']}");
    }

    // Essayer de compter les entrées
    try {
      final count = await db.rawQuery("SELECT COUNT(*) FROM doctors");
      print("Nombre d'entrées dans doctors: $count");
    } catch (e) {
      print("Erreur lors de l'accès à la table doctors: $e");
    }

    await db.close();
  }

  Future<void> checkDatabaseVersion() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'suivi_cancer.db');

    final db = await openDatabase(path);
    final version = await db.getVersion();
    print("Version actuelle de la base de données: $version");

    await db.close();
  }

  Future<void> verifyDatabaseSetup() async {
    final db = await database;

    // Vérifier les tables
    final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
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
      final result = await db.insert('side_effects', sideEffect, conflictAlgorithm: ConflictAlgorithm.replace);
      Log.d("DatabaseHelper: Effet secondaire inséré avec succès, résultat: $result");
      return result;
    } catch (e) {
      Log.d("DatabaseHelper: Erreur lors de l'insertion de l'effet secondaire: $e");
      return -1;
    }
  }

// Récupérer tous les effets secondaires pour une entité spécifique
  Future<List<Map<String, dynamic>>> getSideEffectsForEntity(String entityType, String entityId) async {
    Log.d("DatabaseHelper: Récupération des effets secondaires pour $entityType avec ID $entityId");
    final db = await database;
    try {
      final results = await db.query(
          'side_effects',
          where: 'entityType = ? AND entityId = ?',
          whereArgs: [entityType, entityId],
          orderBy: 'date DESC'
      );
      Log.d("DatabaseHelper: ${results.length} effets secondaires récupérés");
      return results;
    } catch (e) {
      Log.d("DatabaseHelper: Erreur lors de la récupération des effets secondaires: $e");
      return [];
    }
  }

// Mettre à jour un effet secondaire
  Future<int> updateSideEffect(Map<String, dynamic> sideEffect) async {
    Log.d("DatabaseHelper: Mise à jour de l'effet secondaire avec ID ${sideEffect['id']}");
    final db = await database;
    try {
      final result = await db.update(
          'side_effects',
          sideEffect,
          where: 'id = ?',
          whereArgs: [sideEffect['id']]
      );
      Log.d("DatabaseHelper: Effet secondaire mis à jour avec succès, lignes affectées: $result");
      return result;
    } catch (e) {
      Log.d("DatabaseHelper: Erreur lors de la mise à jour de l'effet secondaire: $e");
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
          whereArgs: [id]
      );
      Log.d("DatabaseHelper: Effet secondaire supprimé avec succès, lignes affectées: $result");
      return result;
    } catch (e) {
      Log.d("DatabaseHelper: Erreur lors de la suppression de l'effet secondaire: $e");
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
          if (!e.toString().contains("not an error")) {
            Log.d("Erreur lors de l'ouverture de la base de données : $e");
          } else {
            Log.d("La base de données peut être ouverte en lecture/écriture (ignoré faux positif)");
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

      Log.d("results : ${results}");
      return results;
    } catch (e) {
      Log.d("Erreur lors de la requête des séances : $e");
      return [];
    }
  }

  // Méthodes pour les cycles
  Future<Map<String, dynamic>?> getCycle(String id) async {
    final db = await database;

    print("Récupération du cycle avec ID : $id");

    final results = await db.query(
      'cycles',
      where: 'id = ?',
      whereArgs: [id],
    );

    print("Résultat de la requête cycle : $results");

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
    return await db.delete(
      'cycles',
      where: 'id = ?',
      whereArgs: [id],
    );
  }


  Future<List<Map<String, dynamic>>> getCyclesByTreatment(String treatmentId) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT c.*
      FROM cycles c
      WHERE c.treatmentId = ?
      ORDER BY c.startDate
    ''', [treatmentId]);
  }


// 1. Modification de la méthode insertSession pour prendre en compte tous les champs nécessaires
  Future<int> insertSession(Map<String, dynamic> session) async {
    final db = await database;
    try {
      Log.d("DatabaseHelper: Insertion d'une session: ${session['id']}");
      final id = await db.insert('sessions', session, conflictAlgorithm: ConflictAlgorithm.replace);
      Log.d("DatabaseHelper: Session insérée avec succès, résultat: $id");
      return id;
    } catch (e) {
      Log.d('DatabaseHelper: Erreur lors de l\'insertion de la session: $e');
      return -1;
    }
  }

// 2. Méthode pour insérer une session de radiothérapie
  Future<int> insertRadiotherapySession(Map<String, dynamic> session) async {
    final db = await database;
    try {
      Log.d("DatabaseHelper: Insertion d'une session de radiothérapie: ${session['id']}");
      final id = await db.insert('radiotherapy_sessions', session, conflictAlgorithm: ConflictAlgorithm.replace);
      Log.d("DatabaseHelper: Session de radiothérapie insérée avec succès, résultat: $id");
      return id;
    } catch (e) {
      Log.d('DatabaseHelper: Erreur lors de l\'insertion de la session de radiothérapie: $e');
      return -1;
    }
  }

  Future<int> updateSession(Map<String, dynamic> session) async {
    final db = await database;
    return await db.update('sessions', session,
        where: 'id = ?',
        whereArgs: [session['id']]);
  }

  Future<List<Map<String, dynamic>>> getSessionMedications(String sessionId) async {
    final db = await database;
    return await db.rawQuery('''
    SELECT m.* FROM medications m
    INNER JOIN session_medications sm ON m.id = sm.medicationId
    WHERE sm.sessionId = ?
  ''', [sessionId]);
  }

  Future<int> linkSessionMedication(String sessionId, String medicationId) async {
    final db = await database;
    return await db.insert('session_medications', {
      'sessionId': sessionId,
      'medicationId': medicationId
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getEstablishmentsByTreatment(String treatmentId) async {
    final db = await database;
    return await db.rawQuery('''
    SELECT e.*
    FROM establishments e
    JOIN treatment_establishments te ON e.id = te.establishmentId
    WHERE te.treatmentId = ?
    ORDER BY e.name
  ''', [treatmentId]);
  }

// Fonction pour récupérer les médecins associés à un traitement
  Future<List<Map<String, dynamic>>> getDoctorsByTreatment(String treatmentId) async {
    final db = await database;
    return await db.rawQuery('''
    SELECT d.*
    FROM doctors d
    JOIN treatment_doctors td ON d.id = td.doctorId
    WHERE td.treatmentId = ?
    ORDER BY d.name
  ''', [treatmentId]);
  }

  // Fonction pour récupérer les effets secondaires par entité
  Future<List<Map<String, dynamic>>> getSideEffectsByEntity(String entityType, String entityId) async {
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
    return await db.delete(
      'sessions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

// Méthodes mises à jour pour la gestion des radiothérapies avec relations

// Récupérer les radiothérapies par traitement avec leurs relations
  Future<List<Map<String, dynamic>>> getRadiotherapiesByTreatment(String treatmentId) async {
    Log.d("DatabaseHelper: Récupération des radiothérapies pour le traitement $treatmentId");
    final db = await database;

    // Récupérer les radiothérapies de base
    final List<Map<String, dynamic>> radiotherapies = await db.query(
        'radiotherapies',
        where: 'treatmentId = ?',
        whereArgs: [treatmentId],
        orderBy: 'startDate'
    );

    Log.d("DatabaseHelper: ${radiotherapies.length} radiothérapies trouvées");
    List<Map<String, dynamic>> result = [];

    for (var radiotherapy in radiotherapies) {
      // Créer une copie pour éviter de modifier l'original
      final Map<String, dynamic> completeRadiotherapy = Map.from(radiotherapy);

      // Ajouter l'établissement
      final establishmentId = radiotherapy['establishmentId'];
      final List<Map<String, dynamic>> establishment = await db.query(
          'establishments',
          where: 'id = ?',
          whereArgs: [establishmentId]
      );

      if (establishment.isNotEmpty) {
        completeRadiotherapy['establishment'] = establishment.first;
      }

      // Vérifier si la table radiotherapy_doctors existe
      final tablesRadio = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='radiotherapy_doctors'");

      if (tablesRadio.isNotEmpty) {
        // Récupérer les médecins associés en utilisant rawQuery pour la jointure
        final List<Map<String, dynamic>> doctors = await db.rawQuery('''
        SELECT d.* 
        FROM doctors d
        INNER JOIN radiotherapy_doctors rd ON d.id = rd.doctorId
        WHERE rd.radiotherapyId = ?
      ''', [radiotherapy['id']]);

        completeRadiotherapy['doctors'] = doctors;
      } else {
        // Si la table n'existe pas, renvoyer une liste vide
        completeRadiotherapy['doctors'] = [];
      }

      // Vérifier si la table radiotherapy_sessions existe
      final tablesSessions = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='radiotherapy_sessions'");

      if (tablesSessions.isNotEmpty) {
        // Récupérer les sessions
        final List<Map<String, dynamic>> sessions = await db.query(
            'radiotherapy_sessions',
            where: 'radiotherapyId = ?',
            whereArgs: [radiotherapy['id']],
            orderBy: 'dateTime'
        );
        completeRadiotherapy['sessions'] = sessions;
      } else {
        // Si la table n'existe pas, renvoyer une liste vide
        completeRadiotherapy['sessions'] = [];
      }

      // Récupérer les documents en utilisant rawQuery pour la jointure
      final List<Map<String, dynamic>> documents = await db.rawQuery('''
      SELECT d.* 
      FROM documents d
      INNER JOIN entity_documents ed ON d.id = ed.documentId
      WHERE ed.entityId = ? AND ed.entityType = ?
    ''', [radiotherapy['id'], 'radiotherapy']);

      completeRadiotherapy['documents'] = documents;

      result.add(completeRadiotherapy);
    }

    return result;
  }


// Insérer une radiothérapie avec ses relations
  Future<int> insertRadiotherapy(Map<String, dynamic> radiotherapy) async {
    Log.d("DatabaseHelper: Insertion d'une radiothérapie");
    final db = await database;

    try {
      return await db.transaction((txn) async {
        // Insérer la radiothérapie de base
        final radiotherapyData = {
          'id': radiotherapy['id'],
          'treatmentId': radiotherapy['treatmentId'],
          'title': radiotherapy['title'],
          'startDate': radiotherapy['startDate'],
          'endDate': radiotherapy['endDate'],
          'establishmentId': radiotherapy['establishmentId'],
          'sessionCount': radiotherapy['sessionCount'],
          'description': radiotherapy['notes'],
          'isCompleted': radiotherapy['isCompleted'] ? 1 : 0,
        };

        await txn.insert('radiotherapies', radiotherapyData);
        Log.d("DatabaseHelper: Radiothérapie de base insérée avec ID: ${radiotherapy['id']}");

        // Vérifier si la table radiotherapy_doctors existe
        final tablesRadio = await txn.rawQuery(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='radiotherapy_doctors'"
        );

        // Insérer les médecins associés
        if (tablesRadio.isNotEmpty && radiotherapy['doctorIds'] != null) {
          for (String doctorId in radiotherapy['doctorIds']) {
            await txn.insert('radiotherapy_doctors', {
              'radiotherapyId': radiotherapy['id'],
              'doctorId': doctorId,
            });
          }
          Log.d("DatabaseHelper: Relations médecins ajoutées");
        }

        // Vérifier si la table radiotherapy_sessions existe
        final tablesSessions = await txn.rawQuery(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='radiotherapy_sessions'"
        );

        // Insérer les sessions
        if (tablesSessions.isNotEmpty && radiotherapy['sessions'] != null) {
          for (var session in radiotherapy['sessions']) {
            await txn.insert('radiotherapy_sessions', {
              'id': session['id'],
              'radiotherapyId': radiotherapy['id'],
              'dateTime': session['dateTime'],
              'area': session['area'],
              'dose': session['dose'],
              'notes': session['notes'],
              'isCompleted': session['isCompleted'] ? 1 : 0,
            });
          }
          Log.d("DatabaseHelper: Sessions de radiothérapie ajoutées");
        }

        return 1; // Succès
      });
    } catch (e) {
      Log.d("DatabaseHelper: Erreur lors de l'insertion de la radiothérapie: $e");
      return -1;
    }
  }

// Mettre à jour une radiothérapie avec ses relations
  Future<int> updateRadiotherapy(Map<String, dynamic> radiotherapy) async {
    Log.d("DatabaseHelper: Mise à jour d'une radiothérapie avec ID: ${radiotherapy['id']}");
    final db = await database;

    try {
      return await db.transaction((txn) async {
        // Mettre à jour la radiothérapie de base
        final radiotherapyData = {
          'title': radiotherapy['title'],
          'startDate': radiotherapy['startDate'],
          'endDate': radiotherapy['endDate'],
          'establishmentId': radiotherapy['establishmentId'],
          'sessionCount': radiotherapy['sessionCount'],
          'description': radiotherapy['notes'],
          'isCompleted': radiotherapy['isCompleted'] ? 1 : 0,
        };

        await txn.update(
            'radiotherapies',
            radiotherapyData,
            where: 'id = ?',
            whereArgs: [radiotherapy['id']]
        );

        // Vérifier si la table radiotherapy_doctors existe
        final tablesRadio = await txn.rawQuery(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='radiotherapy_doctors'"
        );

        // Mettre à jour les médecins associés
        if (tablesRadio.isNotEmpty && radiotherapy['doctorIds'] != null) {
          // Supprimer les associations existantes
          await txn.delete(
              'radiotherapy_doctors',
              where: 'radiotherapyId = ?',
              whereArgs: [radiotherapy['id']]
          );

          // Insérer les nouvelles associations
          for (String doctorId in radiotherapy['doctorIds']) {
            await txn.insert('radiotherapy_doctors', {
              'radiotherapyId': radiotherapy['id'],
              'doctorId': doctorId,
            });
          }
        }

        return 1; // Succès
      });
    } catch (e) {
      Log.d("DatabaseHelper: Erreur lors de la mise à jour de la radiothérapie: $e");
      return -1;
    }
  }

// Supprimer une radiothérapie (les relations seront supprimées en cascade)
  Future<int> deleteRadiotherapy(String id) async {
    Log.d("DatabaseHelper: Suppression de la radiothérapie avec ID: $id");
    final db = await database;

    try {
      final result = await db.delete(
          'radiotherapies',
          where: 'id = ?',
          whereArgs: [id]
      );

      Log.d("DatabaseHelper: Radiothérapie supprimée avec succès, lignes affectées: $result");
      return result;
    } catch (e) {
      Log.d("DatabaseHelper: Erreur lors de la suppression de la radiothérapie: $e");
      return -1;
    }
  }

// Méthodes mises à jour pour la gestion des chirurgies avec relations

// Récupérer les chirurgies par traitement avec leurs relations
  Future<List<Map<String, dynamic>>> getSurgeriesByTreatment(String treatmentId) async {
    Log.d("DatabaseHelper: Récupération des chirurgies pour le traitement $treatmentId");
    final db = await database;

    // Récupérer les chirurgies de base
    final List<Map<String, dynamic>> surgeries = await db.query(
        'surgeries',
        where: 'treatmentId = ?',
        whereArgs: [treatmentId],
        orderBy: 'date'
    );

    Log.d("DatabaseHelper: ${surgeries.length} chirurgies trouvées");
    List<Map<String, dynamic>> result = [];

    for (var surgery in surgeries) {
      // Créer une copie pour éviter de modifier l'original
      final Map<String, dynamic> completeSurgery = Map.from(surgery);

      // Ajouter l'établissement
      final establishmentId = surgery['establishmentId'];
      final List<Map<String, dynamic>> establishment = await db.query(
          'establishments',
          where: 'id = ?',
          whereArgs: [establishmentId]
      );

      if (establishment.isNotEmpty) {
        completeSurgery['establishment'] = establishment.first;
      }

      // Vérifier si la table surgery_doctors existe et si elle a une colonne 'role'
      final tablesSurgery = await db.rawQuery(
          "SELECT sql FROM sqlite_master WHERE type='table' AND name='surgery_doctors'"
      );

      if (tablesSurgery.isNotEmpty) {
        // Vérifier si la colonne 'role' existe
        bool hasRoleColumn = tablesSurgery.first['sql'].toString().contains('role');

        if (hasRoleColumn) {
          // Récupérer les chirurgiens en utilisant rawQuery pour la jointure
          final List<Map<String, dynamic>> surgeons = await db.rawQuery('''
          SELECT d.* 
          FROM doctors d
          INNER JOIN surgery_doctors sd ON d.id = sd.doctorId
          WHERE sd.surgeryId = ? AND sd.role = ?
        ''', [surgery['id'], 'surgeon']);

          completeSurgery['surgeons'] = surgeons;

          // Récupérer les anesthésistes en utilisant rawQuery pour la jointure
          final List<Map<String, dynamic>> anesthetists = await db.rawQuery('''
          SELECT d.* 
          FROM doctors d
          INNER JOIN surgery_doctors sd ON d.id = sd.doctorId
          WHERE sd.surgeryId = ? AND sd.role = ?
        ''', [surgery['id'], 'anesthetist']);

          completeSurgery['anesthetists'] = anesthetists;
        } else {
          // Si pas de colonne 'role', récupérer tous les médecins associés
          final List<Map<String, dynamic>> doctors = await db.rawQuery('''
          SELECT d.* 
          FROM doctors d
          INNER JOIN surgery_doctors sd ON d.id = sd.doctorId
          WHERE sd.surgeryId = ?
        ''', [surgery['id']]);

          completeSurgery['surgeons'] = doctors;
          completeSurgery['anesthetists'] = [];
        }
      } else {
        // Si la table n'existe pas, renvoyer des listes vides
        completeSurgery['surgeons'] = [];
        completeSurgery['anesthetists'] = [];
      }

      // Récupérer le rendez-vous pré-opératoire en utilisant rawQuery pour la jointure
      final List<Map<String, dynamic>> appointments = await db.rawQuery('''
      SELECT a.* 
      FROM appointments a
      INNER JOIN entity_documents ed ON a.id = ed.entityId
      WHERE ed.entityType = ? AND ed.documentId = ?
    ''', ['appointment', surgery['id']]);

      if (appointments.isNotEmpty) {
        completeSurgery['preOperationAppointment'] = appointments.first;
      }

      // Récupérer les documents en utilisant rawQuery pour la jointure
      final List<Map<String, dynamic>> documents = await db.rawQuery('''
      SELECT d.* 
      FROM documents d
      INNER JOIN entity_documents ed ON d.id = ed.documentId
      WHERE ed.entityId = ? AND ed.entityType = ?
    ''', [surgery['id'], 'surgery']);

      completeSurgery['documents'] = documents;

      result.add(completeSurgery);
    }

    return result;
  }


// Insérer une chirurgie avec ses relations
// Version corrigée pour insertSurgery - Les parties problématiques étaient les requêtes join
// Cette fonction ne nécessite pas de correction majeure car elle utilise des insertions directes
// sans jointures, mais je l'inclus pour référence

  Future<int> insertSurgery(Map<String, dynamic> surgery) async {
    Log.d("DatabaseHelper: Insertion d'une chirurgie");
    final db = await database;

    try {
      return await db.transaction((txn) async {
        // Insérer la chirurgie de base
        final surgeryData = {
          'id': surgery['id'],
          'treatmentId': surgery['treatmentId'],
          'title': surgery['title'],
          'date': surgery['date'],
          'establishmentId': surgery['establishmentId'],
          'description': surgery['operationReport'],
          'isCompleted': surgery['isCompleted'] ? 1 : 0,
        };

        await txn.insert('surgeries', surgeryData);
        Log.d("DatabaseHelper: Chirurgie de base insérée avec ID: ${surgery['id']}");

        // Vérifier si la table surgery_doctors existe et si elle a une colonne 'role'
        final tablesSurgery = await txn.rawQuery(
            "SELECT sql FROM sqlite_master WHERE type='table' AND name='surgery_doctors'"
        );

        if (tablesSurgery.isNotEmpty) {
          bool hasRoleColumn = tablesSurgery.first['sql'].toString().contains('role');

          // Insérer les chirurgiens
          if (hasRoleColumn && surgery['surgeonIds'] != null) {
            for (String doctorId in surgery['surgeonIds']) {
              await txn.insert('surgery_doctors', {
                'surgeryId': surgery['id'],
                'doctorId': doctorId,
                'role': 'surgeon',
              });
            }
            Log.d("DatabaseHelper: Relations chirurgiens ajoutées");
          }

          // Insérer les anesthésistes
          if (hasRoleColumn && surgery['anesthetistIds'] != null) {
            for (String doctorId in surgery['anesthetistIds']) {
              await txn.insert('surgery_doctors', {
                'surgeryId': surgery['id'],
                'doctorId': doctorId,
                'role': 'anesthetist',
              });
            }
            Log.d("DatabaseHelper: Relations anesthésistes ajoutées");
          }

          // Si pas de colonne 'role' mais qu'il y a des médecins
          if (!hasRoleColumn && surgery['surgeonIds'] != null) {
            for (String doctorId in surgery['surgeonIds']) {
              await txn.insert('surgery_doctors', {
                'surgeryId': surgery['id'],
                'doctorId': doctorId,
              });
            }
            Log.d("DatabaseHelper: Relations médecins ajoutées (sans rôle)");
          }
        }

        // Insérer le rendez-vous pré-opératoire s'il existe
        if (surgery['preOperationAppointment'] != null) {
          final appointment = surgery['preOperationAppointment'];
          final appointmentId = appointment['id'] ?? Uuid().v4();

          // Insérer le rendez-vous
          await txn.insert('appointments', {
            'id': appointmentId,
            'title': appointment['title'],
            'dateTime': appointment['dateTime'],
            'duration': appointment['duration'],
            'doctorId': appointment['doctorId'],
            'establishmentId': appointment['establishmentId'],
            'notes': appointment['notes'],
            'isCompleted': appointment['isCompleted'] ? 1 : 0,
          });

          // Lier le rendez-vous à la chirurgie
          await txn.insert('entity_documents', {
            'documentId': appointmentId,
            'entityType': 'appointment',
            'entityId': surgery['id'],
          });

          Log.d("DatabaseHelper: Rendez-vous pré-opératoire ajouté");
        }

        return 1; // Succès
      });
    } catch (e) {
      Log.d("DatabaseHelper: Erreur lors de l'insertion de la chirurgie: $e");
      return -1;
    }
  }


// Mettre à jour une chirurgie avec ses relations
  Future<int> updateSurgery(Map<String, dynamic> surgery) async {
    Log.d("DatabaseHelper: Mise à jour d'une chirurgie avec ID: ${surgery['id']}");
    final db = await database;

    try {
      return await db.transaction((txn) async {
        // Mettre à jour la chirurgie de base
        final surgeryData = {
          'title': surgery['title'],
          'date': surgery['date'],
          'establishmentId': surgery['establishmentId'],
          'description': surgery['operationReport'],
          'isCompleted': surgery['isCompleted'] ? 1 : 0,
        };

        await txn.update(
            'surgeries',
            surgeryData,
            where: 'id = ?',
            whereArgs: [surgery['id']]
        );

        // Vérifier si la table surgery_doctors existe et si elle a une colonne 'role'
        final tablesSurgery = await txn.rawQuery(
            "SELECT sql FROM sqlite_master WHERE type='table' AND name='surgery_doctors'"
        );

        if (tablesSurgery.isNotEmpty) {
          bool hasRoleColumn = tablesSurgery.first['sql'].toString().contains('role');

          // Supprimer toutes les associations existantes
          await txn.delete(
              'surgery_doctors',
              where: 'surgeryId = ?',
              whereArgs: [surgery['id']]
          );

          // Insérer les chirurgiens
          if (hasRoleColumn && surgery['surgeonIds'] != null) {
            for (String doctorId in surgery['surgeonIds']) {
              await txn.insert('surgery_doctors', {
                'surgeryId': surgery['id'],
                'doctorId': doctorId,
                'role': 'surgeon',
              });
            }
          }

          // Insérer les anesthésistes
          if (hasRoleColumn && surgery['anesthetistIds'] != null) {
            for (String doctorId in surgery['anesthetistIds']) {
              await txn.insert('surgery_doctors', {
                'surgeryId': surgery['id'],
                'doctorId': doctorId,
                'role': 'anesthetist',
              });
            }
          }

          // Si pas de colonne 'role' mais qu'il y a des médecins
          if (!hasRoleColumn && surgery['surgeonIds'] != null) {
            for (String doctorId in surgery['surgeonIds']) {
              await txn.insert('surgery_doctors', {
                'surgeryId': surgery['id'],
                'doctorId': doctorId,
              });
            }
          }
        }

        return 1; // Succès
      });
    } catch (e) {
      Log.d("DatabaseHelper: Erreur lors de la mise à jour de la chirurgie: $e");
      return -1;
    }
  }

// Supprimer une chirurgie (les relations seront supprimées en cascade)
  Future<int> deleteSurgery(String id) async {
    Log.d("DatabaseHelper: Suppression de la chirurgie avec ID: $id");
    final db = await database;

    try {
      final result = await db.delete(
          'surgeries',
          where: 'id = ?',
          whereArgs: [id]
      );

      Log.d("DatabaseHelper: Chirurgie supprimée avec succès, lignes affectées: $result");
      return result;
    } catch (e) {
      Log.d("DatabaseHelper: Erreur lors de la suppression de la chirurgie: $e");
      return -1;
    }
  }

  /// Récupère tous les médicaments disponibles
  Future<List<Map<String, dynamic>>> getMedications() async {
    final db = await database;
    try {
      final results = await db.query('medications', orderBy: 'name ASC');
      return results;
    } catch (e) {
      print("Erreur lors de la récupération des médicaments: $e");
      return [];
    }
  }

  Future<int> insertMedication(Map<String, dynamic> medication) async {
    final db = await database;
    try {
      final result = await db.insert('medications', medication, conflictAlgorithm: ConflictAlgorithm.replace);
      return result;
    } catch (e) {
      print("Erreur lors de l'insertion du médicament: $e");
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
      print("Erreur lors de la mise à jour du médicament: $e");
      return -1;
    }
  }

  /// Ajoute des médicaments à une nouvelle session
  Future<void> addSessionMedications(String sessionId, List<String> medicationIds, List<String> rinsingProductIds) async {
    Log.d("DatabaseHelper: Ajout de médicaments pour la session $sessionId");

    // Pour une nouvelle session, on peut réutiliser la même méthode
    return updateSessionMedications(sessionId, medicationIds, rinsingProductIds);
  }

  /// Met à jour les médicaments associés à une session
  Future<void> updateSessionMedications(String sessionId, List<String> medicationIds, List<String> rinsingProductIds) async {
    Log.d("DatabaseHelper: Mise à jour des médicaments pour la session $sessionId");
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

        Log.d("DatabaseHelper: ${medicationIds.length} médicaments standards ajoutés");

        // Ajouter les produits de rinçage
        for (final rinsingProductId in rinsingProductIds) {
          await txn.insert('session_medications', {
            'sessionId': sessionId,
            'medicationId': rinsingProductId,
          });
        }

        Log.d("DatabaseHelper: ${rinsingProductIds.length} produits de rinçage ajoutés");

        return;
      } catch (e) {
        Log.d("DatabaseHelper: Erreur lors de la mise à jour des médicaments: $e");
        throw e; // Propager l'erreur pour que la transaction échoue
      }
    });
  }

  /// Récupère les médicaments associés à une session spécifique
  Future<List<Map<String, dynamic>>> getSessionMedicationDetails(String sessionId) async {
    Log.d("DatabaseHelper: Récupération des médicaments détaillés pour la session $sessionId");
    final db = await database;

    try {
      // Récupérer tous les médicaments avec un flag pour indiquer s'il s'agit d'un produit de rinçage
      final List<Map<String, dynamic>> medications = await db.rawQuery('''
      SELECT m.*, sm.sessionId
      FROM medications m
      INNER JOIN session_medications sm ON m.id = sm.medicationId
      WHERE sm.sessionId = ?
    ''', [sessionId]);

      Log.d("DatabaseHelper: ${medications.length} médicaments récupérés pour la session");
      return medications;
    } catch (e) {
      Log.d("DatabaseHelper: Erreur lors de la récupération des médicaments de la session: $e");
      return [];
    }
  }

  /// Alternative plus détaillée pour récupérer les médicaments d'une session
  /// Cette version sépare directement les médicaments standards et les produits de rinçage
  Future<Map<String, List<Map<String, dynamic>>>> getSessionMedicationsByType(String sessionId) async {
    Log.d("DatabaseHelper: Récupération des médicaments par type pour la session $sessionId");
    final db = await database;

    try {
      // Récupérer les médicaments standards (non-rinçage)
      final List<Map<String, dynamic>> standardMeds = await db.rawQuery('''
      SELECT m.*
      FROM medications m
      INNER JOIN session_medications sm ON m.id = sm.medicationId
      WHERE sm.sessionId = ? AND m.isRinsing = 0
    ''', [sessionId]);

      // Récupérer les produits de rinçage
      final List<Map<String, dynamic>> rinsingMeds = await db.rawQuery('''
      SELECT m.*
      FROM medications m
      INNER JOIN session_medications sm ON m.id = sm.medicationId
      WHERE sm.sessionId = ? AND m.isRinsing = 1
    ''', [sessionId]);

      Log.d("DatabaseHelper: ${standardMeds.length} médicaments standards et ${rinsingMeds.length} produits de rinçage récupérés");

      return {
        'standard': standardMeds,
        'rinsing': rinsingMeds,
      };
    } catch (e) {
      Log.d("DatabaseHelper: Erreur lors de la récupération des médicaments par type: $e");
      return {
        'standard': [],
        'rinsing': [],
      };
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
        'doctorId': appointment['doctorId'],
        'establishmentId': appointment['establishmentId'],
        'notes': appointment['notes'],
        'isCompleted': appointment['isCompleted'] ?? 0,
        'type': appointment['type'],
      };

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
  Future<List<Map<String, dynamic>>> getAppointmentsByCycle(String cycleId) async {
    Log.d("DatabaseHelper: Récupération des rendez-vous pour le cycle $cycleId");
    final db = await database;

    try {
      final results = await db.rawQuery('''
      SELECT a.*, d.firstName, d.lastName, e.name as establishmentName 
      FROM appointments a
      LEFT JOIN doctors d ON a.doctorId = d.id
      LEFT JOIN establishments e ON a.establishmentId = e.id
      INNER JOIN cycle_appointments ca ON a.id = ca.appointmentId
      WHERE ca.cycleId = ?
      ORDER BY a.dateTime
    ''', [cycleId]);

      Log.d("DatabaseHelper: ${results.length} rendez-vous récupérés");
      return results;
    } catch (e) {
      Log.d("DatabaseHelper: Erreur lors de la récupération des rendez-vous: $e");
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

      Log.d("DatabaseHelper: Rendez-vous mis à jour avec succès, lignes affectées: $result");
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

      Log.d("DatabaseHelper: Rendez-vous supprimé avec succès, lignes affectées: $result");
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
  Future<List<Map<String, dynamic>>> getPrerequisitesBySession(String sessionId) async {
    Log.d("DatabaseHelper: Récupération des prérequis pour la session $sessionId");
    final db = await database;

    try {
      final results = await db.rawQuery('''
      SELECT p.*, a.title as appointmentTitle, a.dateTime as appointmentDateTime 
      FROM prerequisites p
      LEFT JOIN appointments a ON p.appointmentId = a.id
      WHERE p.sessionId = ?
      ORDER BY p.deadline
    ''', [sessionId]);

      Log.d("DatabaseHelper: ${results.length} prérequis récupérés");
      return results;
    } catch (e) {
      Log.d("DatabaseHelper: Erreur lors de la récupération des prérequis: $e");
      return [];
    }
  }

// Fonction pour mettre à jour uniquement la date/heure d'une session
  Future<int> updateSessionDateTime(String sessionId, DateTime dateTime) async {
    Log.d("DatabaseHelper: Mise à jour de la date/heure de la session $sessionId");
    final db = await database;

    try {
      final result = await db.update(
        'sessions',
        {'dateTime': dateTime.toIso8601String()},
        where: 'id = ?',
        whereArgs: [sessionId],
      );

      Log.d("DatabaseHelper: Date/heure de la session mise à jour avec succès, lignes affectées: $result");
      return result;
    } catch (e) {
      Log.d("DatabaseHelper: Erreur lors de la mise à jour de la date/heure de la session: $e");
      return -1;
    }
  }

// Fonction pour marquer une session comme terminée ou non
  Future<int> updateSessionCompletionStatus(String sessionId, bool isCompleted) async {
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
      print("Erreur lors de la mise à jour du statut de complétion de la session: $e");
      return -1;
    }
  }

// Fonction pour créer la structure de la table cycle_appointments si elle n'existe pas
  Future<void> ensureCycleAppointmentsTableExists() async {
    Log.d("DatabaseHelper: Vérification de l'existence de la table cycle_appointments");
    final db = await database;

    try {
      // Vérifier si la table existe
      final tables = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='cycle_appointments'"
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
      Log.d("DatabaseHelper: Erreur lors de la vérification/création de la table cycle_appointments: $e");
    }
  }

// Fonctions additionnelles à ajouter à votre classe DatabaseHelper

// Ajouter un chirurgien à une chirurgie
  Future<int> addSurgeonToSurgery(String surgeryId, String doctorId) async {
    Log.d("DatabaseHelper: Ajout du chirurgien $doctorId à la chirurgie $surgeryId");
    final db = await database;

    try {
      // Vérifier si la table surgery_doctors contient un champ 'role'
      final tableInfo = await db.rawQuery(
          "SELECT sql FROM sqlite_master WHERE type='table' AND name='surgery_doctors'"
      );

      if (tableInfo.isEmpty) {
        // La table n'existe pas encore, la créer avec le champ 'role'
        await db.execute('''
        CREATE TABLE surgery_doctors(
          surgeryId TEXT NOT NULL,
          doctorId TEXT NOT NULL,
          role TEXT NOT NULL,
          PRIMARY KEY (surgeryId, doctorId, role),
          FOREIGN KEY (surgeryId) REFERENCES surgeries (id) ON DELETE CASCADE,
          FOREIGN KEY (doctorId) REFERENCES doctors (id) ON DELETE CASCADE
        )
      ''');
        Log.d("DatabaseHelper: Table surgery_doctors créée avec un champ role");
      }

      // Vérifier si le champ 'role' est présent
      final hasRoleField = tableInfo.isNotEmpty &&
          tableInfo.first['sql'].toString().contains('role');

      if (hasRoleField) {
        final result = await db.insert('surgery_doctors', {
          'surgeryId': surgeryId,
          'doctorId': doctorId,
          'role': 'surgeon',
        });
        Log.d("DatabaseHelper: Chirurgien ajouté avec succès avec rôle");
        return result;
      } else {
        // Utiliser l'ancienne structure de table sans champ 'role'
        final result = await db.insert('surgery_doctors', {
          'surgeryId': surgeryId,
          'doctorId': doctorId,
        });
        Log.d("DatabaseHelper: Chirurgien ajouté avec succès sans rôle");
        return result;
      }
    } catch (e) {
      Log.d("DatabaseHelper: Erreur lors de l'ajout du chirurgien: $e");
      return -1;
    }
  }

// Ajouter un anesthésiste à une chirurgie
  Future<int> addAnesthetistToSurgery(String surgeryId, String doctorId) async {
    Log.d("DatabaseHelper: Ajout de l'anesthésiste $doctorId à la chirurgie $surgeryId");
    final db = await database;

    try {
      // Vérifier si la table surgery_doctors contient un champ 'role'
      final tableInfo = await db.rawQuery(
          "SELECT sql FROM sqlite_master WHERE type='table' AND name='surgery_doctors'"
      );

      // Vérifier si le champ 'role' est présent
      final hasRoleField = tableInfo.isNotEmpty &&
          tableInfo.first['sql'].toString().contains('role');

      if (hasRoleField) {
        final result = await db.insert('surgery_doctors', {
          'surgeryId': surgeryId,
          'doctorId': doctorId,
          'role': 'anesthetist',
        });
        Log.d("DatabaseHelper: Anesthésiste ajouté avec succès");
        return result;
      } else {
        // Sans le champ 'role', nous ne pouvons pas distinguer les anesthésistes
        Log.d("DatabaseHelper: La table surgery_doctors n'a pas de champ 'role', impossible d'ajouter un anesthésiste");
        return 0;
      }
    } catch (e) {
      Log.d("DatabaseHelper: Erreur lors de l'ajout de l'anesthésiste: $e");
      return -1;
    }
  }

// Ajouter un médecin à une radiothérapie
  Future<int> addDoctorToRadiotherapy(String radiotherapyId, String doctorId) async {
    Log.d("DatabaseHelper: Ajout du médecin $doctorId à la radiothérapie $radiotherapyId");
    final db = await database;

    try {
      // Vérifier si la table radiotherapy_doctors existe
      final tableExists = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='radiotherapy_doctors'"
      );

      if (tableExists.isEmpty) {
        // La table n'existe pas encore, la créer
        await db.execute('''
        CREATE TABLE radiotherapy_doctors(
          radiotherapyId TEXT NOT NULL,
          doctorId TEXT NOT NULL,
          PRIMARY KEY (radiotherapyId, doctorId),
          FOREIGN KEY (radiotherapyId) REFERENCES radiotherapies (id) ON DELETE CASCADE,
          FOREIGN KEY (doctorId) REFERENCES doctors (id) ON DELETE CASCADE
        )
      ''');
        Log.d("DatabaseHelper: Table radiotherapy_doctors créée");
      }

      final result = await db.insert('radiotherapy_doctors', {
        'radiotherapyId': radiotherapyId,
        'doctorId': doctorId,
      });

      Log.d("DatabaseHelper: Médecin ajouté à la radiothérapie avec succès");
      return result;
    } catch (e) {
      Log.d("DatabaseHelper: Erreur lors de l'ajout du médecin à la radiothérapie: $e");
      return -1;
    }
  }

// Récupérer les médecins d'une chirurgie par rôle
  Future<List<Map<String, dynamic>>> getDoctorsBySurgeryAndRole(String surgeryId, String role) async {
    Log.d("DatabaseHelper: Récupération des médecins de la chirurgie $surgeryId avec le rôle $role");
    final db = await database;

    try {
      // Vérifier si la table surgery_doctors contient un champ 'role'
      final tableInfo = await db.rawQuery(
          "SELECT sql FROM sqlite_master WHERE type='table' AND name='surgery_doctors'"
      );

      // Vérifier si le champ 'role' est présent
      final hasRoleField = tableInfo.isNotEmpty &&
          tableInfo.first['sql'].toString().contains('role');

      if (hasRoleField) {
        final results = await db.rawQuery('''
        SELECT d.* 
        FROM doctors d
        INNER JOIN surgery_doctors sd ON d.id = sd.doctorId
        WHERE sd.surgeryId = ? AND sd.role = ?
      ''', [surgeryId, role]);

        Log.d("DatabaseHelper: ${results.length} médecins récupérés avec le rôle $role");
        return results;
      } else {
        // Sans le champ 'role', on récupère tous les médecins (pour la rétrocompatibilité)
        final results = await db.rawQuery('''
        SELECT d.* 
        FROM doctors d
        INNER JOIN surgery_doctors sd ON d.id = sd.doctorId
        WHERE sd.surgeryId = ?
      ''', [surgeryId]);

        Log.d("DatabaseHelper: ${results.length} médecins récupérés (sans distinction de rôle)");
        return results;
      }
    } catch (e) {
      Log.d("DatabaseHelper: Erreur lors de la récupération des médecins: $e");
      return [];
    }
  }

// Récupérer les médecins d'une radiothérapie
  Future<List<Map<String, dynamic>>> getDoctorsByRadiotherapy(String radiotherapyId) async {
    Log.d("DatabaseHelper: Récupération des médecins de la radiothérapie $radiotherapyId");
    final db = await database;

    try {
      // Vérifier si la table radiotherapy_doctors existe
      final tableExists = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='radiotherapy_doctors'"
      );

      if (tableExists.isEmpty) {
        Log.d("DatabaseHelper: La table radiotherapy_doctors n'existe pas");
        return [];
      }

      final results = await db.rawQuery('''
      SELECT d.* 
      FROM doctors d
      INNER JOIN radiotherapy_doctors rd ON d.id = rd.doctorId
      WHERE rd.radiotherapyId = ?
    ''', [radiotherapyId]);

      Log.d("DatabaseHelper: ${results.length} médecins récupérés pour la radiothérapie");
      return results;
    } catch (e) {
      Log.d("DatabaseHelper: Erreur lors de la récupération des médecins de la radiothérapie: $e");
      return [];
    }
  }

// Mettre à jour les champs d'un cycle
  Future<int> updateCycleFields(Map<String, dynamic> cycleFields) async {
    Log.d("DatabaseHelper: Mise à jour des champs du cycle ${cycleFields['id']}");
    final db = await database;

    try {
      final result = await db.update(
        'cycles',
        cycleFields,
        where: 'id = ?',
        whereArgs: [cycleFields['id']],
      );

      Log.d("DatabaseHelper: Champs du cycle mis à jour avec succès, lignes affectées: $result");
      return result;
    } catch (e) {
      Log.d("DatabaseHelper: Erreur lors de la mise à jour des champs du cycle: $e");
      return -1;
    }
  }

// Mettre à jour les champs d'une chirurgie
  Future<int> updateSurgeryFields(Map<String, dynamic> surgeryFields) async {
    Log.d("DatabaseHelper: Mise à jour des champs de la chirurgie ${surgeryFields['id']}");
    final db = await database;

    try {
      final result = await db.update(
        'surgeries',
        surgeryFields,
        where: 'id = ?',
        whereArgs: [surgeryFields['id']],
      );

      Log.d("DatabaseHelper: Champs de la chirurgie mis à jour avec succès, lignes affectées: $result");
      return result;
    } catch (e) {
      Log.d("DatabaseHelper: Erreur lors de la mise à jour des champs de la chirurgie: $e");
      return -1;
    }
  }

// Mettre à jour les champs d'une radiothérapie
  Future<int> updateRadiotherapyFields(Map<String, dynamic> radiotherapyFields) async {
    Log.d("DatabaseHelper: Mise à jour des champs de la radiothérapie ${radiotherapyFields['id']}");
    final db = await database;

    try {
      final result = await db.update(
        'radiotherapies',
        radiotherapyFields,
        where: 'id = ?',
        whereArgs: [radiotherapyFields['id']],
      );

      Log.d("DatabaseHelper: Champs de la radiothérapie mis à jour avec succès, lignes affectées: $result");
      return result;
    } catch (e) {
      Log.d("DatabaseHelper: Erreur lors de la mise à jour des champs de la radiothérapie: $e");
      return -1;
    }
  }

// Créer des tables de relation si elles n'existent pas encore
  Future<void> ensureRelationTablesExist() async {
    Log.d("DatabaseHelper: Vérification de l'existence des tables de relation");
    final db = await database;

    try {
      // Vérifier et créer la table radiotherapy_doctors si nécessaire
      final radiotherapyDoctorsExists = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='radiotherapy_doctors'"
      );

      if (radiotherapyDoctorsExists.isEmpty) {
        Log.d("DatabaseHelper: Création de la table radiotherapy_doctors");
        await db.execute('''
        CREATE TABLE radiotherapy_doctors(
          radiotherapyId TEXT NOT NULL,
          doctorId TEXT NOT NULL,
          PRIMARY KEY (radiotherapyId, doctorId),
          FOREIGN KEY (radiotherapyId) REFERENCES radiotherapies (id) ON DELETE CASCADE,
          FOREIGN KEY (doctorId) REFERENCES doctors (id) ON DELETE CASCADE
        )
      ''');
      }

      // Vérifier si la table surgery_doctors existe et si elle a un champ 'role'
      final surgeryDoctorsInfo = await db.rawQuery(
          "SELECT sql FROM sqlite_master WHERE type='table' AND name='surgery_doctors'"
      );

      if (surgeryDoctorsInfo.isEmpty) {
        Log.d("DatabaseHelper: Création de la table surgery_doctors avec champ 'role'");
        await db.execute('''
        CREATE TABLE surgery_doctors(
          surgeryId TEXT NOT NULL,
          doctorId TEXT NOT NULL,
          role TEXT NOT NULL,
          PRIMARY KEY (surgeryId, doctorId, role),
          FOREIGN KEY (surgeryId) REFERENCES surgeries (id) ON DELETE CASCADE,
          FOREIGN KEY (doctorId) REFERENCES doctors (id) ON DELETE CASCADE
        )
      ''');
      } else {
        // Vérifier si le champ 'role' est présent
        final hasRoleField = surgeryDoctorsInfo.first['sql'].toString().contains('role');

        if (!hasRoleField) {
          Log.d("DatabaseHelper: Mise à jour de la table surgery_doctors pour ajouter le champ 'role'");

          // Renommer l'ancienne table
          await db.execute("ALTER TABLE surgery_doctors RENAME TO surgery_doctors_old");

          // Créer la nouvelle table avec le champ 'role'
          await db.execute('''
          CREATE TABLE surgery_doctors(
            surgeryId TEXT NOT NULL,
            doctorId TEXT NOT NULL,
            role TEXT NOT NULL,
            PRIMARY KEY (surgeryId, doctorId, role),
            FOREIGN KEY (surgeryId) REFERENCES surgeries (id) ON DELETE CASCADE,
            FOREIGN KEY (doctorId) REFERENCES doctors (id) ON DELETE CASCADE
          )
        ''');

          // Copier les données de l'ancienne table avec un rôle par défaut
          await db.execute('''
          INSERT INTO surgery_doctors (surgeryId, doctorId, role)
          SELECT surgeryId, doctorId, 'surgeon' FROM surgery_doctors_old
        ''');

          // Supprimer l'ancienne table
          await db.execute("DROP TABLE surgery_doctors_old");
        }
      }

      // Vérifier et créer la table cycle_appointments si nécessaire
      final cycleAppointmentsExists = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='cycle_appointments'"
      );

      if (cycleAppointmentsExists.isEmpty) {
        Log.d("DatabaseHelper: Création de la table cycle_appointments");
        await db.execute('''
        CREATE TABLE cycle_appointments(
          cycleId TEXT NOT NULL,
          appointmentId TEXT NOT NULL,
          PRIMARY KEY (cycleId, appointmentId),
          FOREIGN KEY (cycleId) REFERENCES cycles (id) ON DELETE CASCADE,
          FOREIGN KEY (appointmentId) REFERENCES appointments (id) ON DELETE CASCADE
        )
      ''');
      }

      Log.d("DatabaseHelper: Vérification des tables de relation terminée");
    } catch (e) {
      Log.d("DatabaseHelper: Erreur lors de la vérification/création des tables de relation: $e");
    }
  }

  Future<Map<String, dynamic>> getCompleteCycleData(String cycleId) async {
    Log.d("DatabaseHelper: Récupération complète des données du cycle $cycleId");
    final db = await database;

    // Récupérer les informations de base du cycle
    final cycleResults = await db.query(
      'cycles',
      where: 'id = ?',
      whereArgs: [cycleId],
    );

    if (cycleResults.isEmpty) {
      return {};
    }

    final cycleMap = cycleResults.first;

    // Récupérer l'établissement
    final establishmentId = cycleMap['establishmentId'];
    final establishmentResults = await db.query(
      'establishments',
      where: 'id = ?',
      whereArgs: [establishmentId],
    );

    Map<String, dynamic> establishmentMap = {};
    if (establishmentResults.isNotEmpty) {
      establishmentMap = establishmentResults.first;
    }

    // Récupérer les séances
    final sessionResults = await db.query(
      'sessions',
      where: 'cycleId = ?',
      whereArgs: [cycleId],
      orderBy: 'dateTime',
    );

    // Récupérer les médecins associés au cycle
    final doctorResults = await db.rawQuery('''
    SELECT d.* 
    FROM doctors d
    INNER JOIN cure_doctors cd ON d.id = cd.doctorId
    WHERE cd.cycleId = ?
  ''', [cycleId]);

    // Construire l'objet complet
    final completeData = {
      ...cycleMap,
      'establishment': establishmentMap,
      'sessions': sessionResults,
      'doctors': doctorResults,
    };

    return completeData;
  }

// Méthode pour récupérer les types principaux des traitements
  Future<Map<String, String>> getMainTreatmentTypes() async {
    Log.d("DatabaseHelper: Récupération des types principaux des traitements");
    final db = await database;

    // Récupérer tous les identifiants de traitement
    final treatmentResults = await db.query('treatments', columns: ['id']);

    Map<String, String> treatmentTypes = {};

    for (var treatment in treatmentResults) {
      final treatmentId = treatment['id'] as String;

      // Vérifier les cycles
      final cycleResults = await db.query(
        'cycles',
        where: 'treatmentId = ?',
        whereArgs: [treatmentId],
        limit: 1,
      );

      if (cycleResults.isNotEmpty) {
        final cycleType = cycleResults.first['type'];
        if (cycleType == 0) {
          treatmentTypes[treatmentId] = "Chimiothérapie";
        } else if (cycleType == 1) {
          treatmentTypes[treatmentId] = "Immunothérapie";
        } else if (cycleType == 2) {
          treatmentTypes[treatmentId] = "Hormonothérapie";
        } else if (cycleType == 3) {
          treatmentTypes[treatmentId] = "Traitement combiné";
        }
        continue;
      }

      // Vérifier les chirurgies
      final surgeryResults = await db.query(
        'surgeries',
        where: 'treatmentId = ?',
        whereArgs: [treatmentId],
        limit: 1,
      );

      if (surgeryResults.isNotEmpty) {
        treatmentTypes[treatmentId] = "Chirurgie";
        continue;
      }

      // Vérifier les radiothérapies
      final radiotherapyResults = await db.query(
        'radiotherapies',
        where: 'treatmentId = ?',
        whereArgs: [treatmentId],
        limit: 1,
      );

      if (radiotherapyResults.isNotEmpty) {
        treatmentTypes[treatmentId] = "Radiothérapie";
        continue;
      }

      // Par défaut
      treatmentTypes[treatmentId] = "Non spécifié";
    }

    return treatmentTypes;
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
    final establishmentResults = await this.getTreatmentEstablishments(treatmentId);

    // Récupérer les médecins associés
    final doctorResults = await this.getTreatmentDoctors(treatmentId);

    // Récupérer les cycles
    final cycleResults = await this.getCyclesByTreatment(treatmentId);

    // Récupérer les chirurgies
    final surgeryResults = await this.getSurgeriesByTreatment(treatmentId);

    // Récupérer les radiothérapies
    final radiotherapyResults = await this.getRadiotherapiesByTreatment(treatmentId);

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
      }
    } else if (surgeryResults.isNotEmpty) {
      mainType = "Chirurgie";
    } else if (radiotherapyResults.isNotEmpty) {
      mainType = "Radiothérapie";
    }

    // Construire l'objet complet
    final completeData = {
      ...treatmentMap,
      'mainType': mainType,
      'establishments': establishmentResults,
      'doctors': doctorResults,
      'cycles': cycleResults,
      'surgeries': surgeryResults,
      'radiotherapies': radiotherapyResults,
    };

    return completeData;
  }

// Méthode pour récupérer directement le premier cycle d'un traitement
  Future<Map<String, dynamic>?> getFirstCycleForTreatment(String treatmentId) async {
    Log.d("DatabaseHelper: Récupération du premier cycle pour le traitement $treatmentId");
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

// Méthode pour récupérer directement la première chirurgie d'un traitement
  Future<Map<String, dynamic>?> getFirstSurgeryForTreatment(String treatmentId) async {
    Log.d("DatabaseHelper: Récupération de la première chirurgie pour le traitement $treatmentId");
    final db = await database;

    // Récupérer la première chirurgie du traitement
    final surgeryResults = await db.query(
      'surgeries',
      where: 'treatmentId = ?',
      whereArgs: [treatmentId],
      orderBy: 'date',
      limit: 1,
    );

    if (surgeryResults.isEmpty) {
      return null;
    }

    return surgeryResults.first;
  }

// Méthode pour récupérer directement la première radiothérapie d'un traitement
  Future<Map<String, dynamic>?> getFirstRadiotherapyForTreatment(String treatmentId) async {
    Log.d("DatabaseHelper: Récupération de la première radiothérapie pour le traitement $treatmentId");
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
      final List<Map<String, dynamic>> examinationMaps = await db.rawQuery('''
      SELECT e.*, est.id as establishmentId, est.name as establishmentName, 
             est.address as establishmentAddress, est.phone as establishmentPhone, 
             d.id as doctorId, d.firstName as doctorFirstName, d.lastName as doctorLastName, 
             d.specialty as doctorSpecialty, d.phone as doctorPhone, d.email as doctorEmail
      FROM examinations e
      LEFT JOIN establishments est ON e.establishmentId = est.id
      LEFT JOIN doctors d ON e.doctorId = d.id
      WHERE e.id = ?
    ''', [examinationId]);

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
      final List<Map<String, dynamic>> documentMaps = await getDocumentsByEntity('examination', examinationId);
      result['documents'] = documentMaps;

      return result;
    } catch (e) {
      print("Erreur lors de la récupération de l'examen: $e");
      return null;
    }
  }

  // Méthode pour récupérer les examens associés à un cycle
  Future<List<Map<String, dynamic>>> getExaminationsByCycle(String cycleId) async {
    Log.d("DatabaseHelper: Récupération des examens pour le cycle $cycleId");
    final db = await database;

    try {
      print("Requête d'examens pour le cycle : $cycleId");
      // Vérifier d'abord si la table des examens existe
      final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='examinations'");

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
          orderBy: 'dateTime'
      );

      Log.d("DatabaseHelper: ${examinations.length} examens trouvés dans la base");

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
          Log.e("DatabaseHelper: Erreur lors de l'enrichissement de l'examen ${exam['id']}: $examError");
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
      final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='examinations'");

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

      final result = await db.insert('examinations', examination, conflictAlgorithm: ConflictAlgorithm.replace);
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
        Log.e("DatabaseHelper: Examen introuvable, impossible de mettre à jour");
        return 0;
      }

      // Mise à jour de l'examen
      final result = await db.update(
        'examinations',
        examination,
        where: 'id = ?',
        whereArgs: [examinationId],
      );

      Log.d("DatabaseHelper: Examen mis à jour avec succès, lignes affectées: $result");
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
      final documentData = await db.rawQuery('''
      SELECT d.*
      FROM documents d
      INNER JOIN entity_documents ed ON d.id = ed.documentId
      WHERE ed.entityId = ? AND ed.entityType = 'cycle'
      ORDER BY d.dateAdded DESC
    ''', [cycleId]);

      Log.d("DatabaseHelper: ${documentData.length} documents récupérés");
      return documentData;
    } catch (e) {
      Log.e("DatabaseHelper: Erreur lors de la récupération des documents: $e");
      return [];
    }
  }

  Future<int> insertDocument_ForAddDocumentScreen(Map<String, dynamic> document, [String? entityType, String? entityId]) async {
    final db = await database;
    try {
      Log.d("DatabaseHelper: Insertion d'un document: ${document['name']}");

      return await db.transaction((txn) async {
        // Insérer le document
        final result = await txn.insert('documents', document, conflictAlgorithm: ConflictAlgorithm.replace);

        // Si l'insertion a réussi et les paramètres entityType et entityId sont fournis,
        // créer également la liaison
        if (result > 0 && entityType != null && entityId != null) {
          final linkData = {
            'documentId': document['id'],
            'entityType': entityType,
            'entityId': entityId,
          };

          await txn.insert('entity_documents', linkData, conflictAlgorithm: ConflictAlgorithm.replace);
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
      final result = await db.insert('documents', document, conflictAlgorithm: ConflictAlgorithm.replace);
      Log.d("DatabaseHelper: Document inséré avec succès, résultat: $result");
      return result;
    } catch (e) {
      Log.e("DatabaseHelper: Erreur lors de l'insertion du document: $e");
      return -1;
    }
  }

// Lier un document à une entité (examen, séance, etc.)
  Future<int> linkDocumentToEntity(String entityType, String entityId, String documentId) async {
    final db = await database;
    try {
      Log.d("DatabaseHelper: Liaison du document $documentId à $entityType $entityId");

      // Vérifier si la table entity_documents existe
      final tableCheck = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='entity_documents'"
      );

      if (tableCheck.isEmpty) {
        Log.d("DatabaseHelper: La table entity_documents n'existe pas encore, création...");

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
        Log.d("DatabaseHelper: La liaison existe déjà, aucune action nécessaire");
        return 1; // Succès, liaison déjà existante
      }

      // Créer la liaison
      final linkData = {
        'documentId': documentId,
        'entityType': entityType,
        'entityId': entityId,
      };

      final result = await db.insert('entity_documents', linkData, conflictAlgorithm: ConflictAlgorithm.replace);
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
  Future<int> unlinkDocumentFromEntity(String entityType, String entityId, String documentId) async {
    final db = await database;
    try {
      Log.d("DatabaseHelper: Suppression de la liaison du document $documentId avec $entityType $entityId");

      final result = await db.delete(
        'entity_documents',
        where: 'documentId = ? AND entityType = ? AND entityId = ?',
        whereArgs: [documentId, entityType, entityId],
      );

      Log.d("DatabaseHelper: Liaison supprimée avec succès, lignes affectées: $result");
      return result;
    } catch (e) {
      Log.e("DatabaseHelper: Erreur lors de la suppression de la liaison: $e");
      return -1;
    }
  }


// Méthode pour mettre à jour le statut d'un examen
  Future<int> updateExaminationCompletionStatus(String examinationId, bool isCompleted) async {
    Log.d("DatabaseHelper: Mise à jour du statut de l'examen $examinationId");
    final db = await database;

    try {
      final result = await db.update(
        'examinations',
        {'isCompleted': isCompleted ? 1 : 0},
        where: 'id = ?',
        whereArgs: [examinationId],
      );

      Log.d("DatabaseHelper: Statut de l'examen mis à jour, lignes affectées: $result");
      return result;
    } catch (e) {
      Log.e("DatabaseHelper: Erreur lors de la mise à jour du statut de l'examen: $e");
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
        await txn.delete(
          'entity_documents',
          where: 'documentId = ?',
          whereArgs: [documentId],
        );

        // Puis supprimer le document lui-même
        final result = await txn.delete(
          'documents',
          where: 'id = ?',
          whereArgs: [documentId],
        );

        Log.d("DatabaseHelper: Document supprimé avec succès, lignes affectées: $result");
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
  Future<List<Map<String, dynamic>>> getDocumentsByEntity(String entityType, String entityId) async {
    final db = await database;
    try {
      Log.d("DatabaseHelper: Début de récupération des documents pour $entityType $entityId");

      // Vérifier si la table entity_documents existe
      final tableCheck = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='entity_documents'"
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

      Log.d("DatabaseHelper: ${linkedDocIds.length} liens trouvés pour $entityType $entityId");

      if (linkedDocIds.isEmpty) {
        return [];
      }

      // Extraire les IDs des documents
      final docIds = linkedDocIds.map((row) => row['documentId'] as String).toList();

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

      Log.d("DatabaseHelper: ${results.length} documents récupérés pour $entityType $entityId");

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
    final List<Map<String, dynamic>> result = await db.rawQuery('''
    SELECT doctorId FROM documents
    WHERE id = ?
  ''', [documentId]);

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

      Log.d("DatabaseHelper: Document mis à jour avec succès, lignes affectées: $result");
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
      await db.delete(
        'sessions',
        where: 'cycleId = ?',
        whereArgs: [cycleId],
      );

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

      Log.d("DatabaseHelper: Sessions générées avec succès pour le cycle $cycleId");
      return true;
    } catch (e) {
      Log.d("DatabaseHelper: Erreur lors de la génération des sessions: $e");
      return false;
    }
  }

// 4. Méthode pour générer les sessions de radiothérapie
  Future<bool> generateRadiotherapySessions(String radiotherapyId) async {
    Log.d("DatabaseHelper: Génération de sessions pour la radiothérapie $radiotherapyId");
    final db = await database;

    try {
      // Récupérer les informations de la radiothérapie
      final radiotherapyResults = await db.query(
        'radiotherapies',
        where: 'id = ?',
        whereArgs: [radiotherapyId],
      );

      if (radiotherapyResults.isEmpty) {
        Log.d("DatabaseHelper: Radiothérapie introuvable");
        return false;
      }

      final radiotherapy = radiotherapyResults.first;
      final sessionCount = radiotherapy['sessionCount'] as int;
      final startDate = DateTime.parse(radiotherapy['startDate'] as String);
      final endDate = DateTime.parse(radiotherapy['endDate'] as String);

      // Calculer l'intervalle entre les séances
      final totalDays = endDate.difference(startDate).inDays;
      final intervalDays = totalDays / (sessionCount - 1);

      // Supprimer les sessions existantes (si on regénère)
      await db.delete(
        'radiotherapy_sessions',
        where: 'radiotherapyId = ?',
        whereArgs: [radiotherapyId],
      );

      // Générer les nouvelles sessions
      for (int i = 0; i < sessionCount; i++) {
        final sessionId = Uuid().v4();
        final sessionDate = startDate.add(Duration(days: (i * intervalDays).round()));

        final sessionData = {
          'id': sessionId,
          'radiotherapyId': radiotherapyId,
          'dateTime': sessionDate.toIso8601String(),
          'isCompleted': 0,
        };

        await db.insert('radiotherapy_sessions', sessionData);
        Log.d("DatabaseHelper: Session de radiothérapie $i générée avec ID $sessionId");
      }

      Log.d("DatabaseHelper: Sessions générées avec succès pour la radiothérapie $radiotherapyId");
      return true;
    } catch (e) {
      Log.d("DatabaseHelper: Erreur lors de la génération des sessions de radiothérapie: $e");
      return false;
    }
  }

  /// Récupère tous les examens appartenant à un même groupe
  Future<List<Map<String, dynamic>>> getExaminationsByGroup(String groupId) async {
    Log.d("DatabaseHelper: Récupération des examens du groupe $groupId");
    final db = await database;

    try {
      // Récupérer les examens de base
      final examinations = await db.query(
          'examinations',
          where: 'examGroupId = ?',
          whereArgs: [groupId],
          orderBy: 'dateTime'
      );

      Log.d("DatabaseHelper: ${examinations.length} examens trouvés dans le groupe");

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
          Log.e("DatabaseHelper: Erreur lors de l'enrichissement de l'examen ${exam['id']}: $examError");
          // Ajouter quand même l'examen de base
          result.add(enrichedExam);
        }
      }

      Log.d("DatabaseHelper: ${result.length} examens enrichis");
      return result;
    } catch (e) {
      Log.e("DatabaseHelper: Erreur lors de la récupération des examens du groupe: $e");
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
          whereArgs: [entityType, entityId]
      );

      Log.d("Nombre de liens trouvés pour $entityType $entityId: ${links.length}");

      // Afficher les détails de chaque lien
      for (var link in links) {
        final docId = link['documentId'];

        // Récupérer les détails du document
        final docDetails = await db.query(
            'documents',
            where: 'id = ?',
            whereArgs: [docId]
        );

        if (docDetails.isNotEmpty) {
          Log.d("Document lié trouvé - ID: $docId, Nom: ${docDetails.first['name']}");
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
    Log.d("DatabaseHelper: Initialisation des catégories de professionnels de santé");

    final categories = [
      {
        'id': Uuid().v4(),
        'name': 'Médecin généraliste',
        'description': 'Médecin de premier recours assurant le suivi médical global',
        'isActive': 1
      },
      {
        'id': Uuid().v4(),
        'name': 'Pneumologue',
        'description': 'Spécialiste des maladies respiratoires',
        'isActive': 1
      },
      {
        'id': Uuid().v4(),
        'name': 'Cardiologue',
        'description': 'Spécialiste des maladies cardiovasculaires',
        'isActive': 1
      },
      {
        'id': Uuid().v4(),
        'name': 'ORL',
        'description': 'Spécialiste en oto-rhino-laryngologie',
        'isActive': 1
      },
      {
        'id': Uuid().v4(),
        'name': 'Chirurgien',
        'description': 'Médecin spécialisé dans les interventions chirurgicales',
        'isActive': 1
      },
      {
        'id': Uuid().v4(),
        'name': 'Anesthésiste',
        'description': 'Médecin spécialisé dans l\'anesthésie',
        'isActive': 1
      },
      {
        'id': Uuid().v4(),
        'name': 'Oncologue',
        'description': 'Spécialiste du traitement des cancers',
        'isActive': 1
      },
      {
        'id': Uuid().v4(),
        'name': 'Radiologue',
        'description': 'Spécialiste de l\'imagerie médicale',
        'isActive': 1
      },
      {
        'id': Uuid().v4(),
        'name': 'Infirmier',
        'description': 'Professionnel de santé assurant les soins infirmiers',
        'isActive': 1
      },
      {
        'id': Uuid().v4(),
        'name': 'Kinésithérapeute',
        'description': 'Spécialiste de la rééducation fonctionnelle',
        'isActive': 1
      },
      {
        'id': Uuid().v4(),
        'name': 'Sage-femme',
        'description': 'Professionnel de santé spécialisé dans le suivi de grossesse et l\'accouchement',
        'isActive': 1
      },
      {
        'id': Uuid().v4(),
        'name': 'Dentiste',
        'description': 'Spécialiste des soins dentaires',
        'isActive': 1
      },
      {
        'id': Uuid().v4(),
        'name': 'Pharmacien',
        'description': 'Spécialiste du médicament',
        'isActive': 1
      },
      {
        'id': Uuid().v4(),
        'name': 'Psychologue',
        'description': 'Spécialiste de la santé mentale',
        'isActive': 1
      },
      {
        'id': Uuid().v4(),
        'name': 'Diététicien',
        'description': 'Spécialiste de la nutrition',
        'isActive': 1
      },
      {
        'id': Uuid().v4(),
        'name': 'Ergothérapeute',
        'description': 'Spécialiste de la réadaptation',
        'isActive': 1
      },
      {
        'id': Uuid().v4(),
        'name': 'Orthophoniste',
        'description': 'Spécialiste des troubles de la communication',
        'isActive': 1
      },
      {
        'id': Uuid().v4(),
        'name': 'Podologue',
        'description': 'Spécialiste des affections du pied',
        'isActive': 1
      }
    ];

    // Insertion des catégories dans la base de données
    for (var category in categories) {
      await db.insert('health_professional_categories', category,
          conflictAlgorithm: ConflictAlgorithm.replace);
    }

    Log.d("DatabaseHelper: ${categories.length} catégories de professionnels de santé initialisées");
  }

  Future<List<Map<String, dynamic>>> getPS() async {
    Log.d("DatabaseHelper: Récupération des professionnels de santé");
    final db = await database;
    try {
      // Récupérer tous les professionnels de santé
      final List<Map<String, dynamic>> professionals = await db.query('health_professionals');
      Log.d("DatabaseHelper: ${professionals.length} professionnels récupérés");

      // Pour chaque professionnel, récupérer ses contacts, adresses et établissements
      List<Map<String, dynamic>> result = [];

      for (var professional in professionals) {
        // Créer une copie modifiable du professionnel
        final Map<String, dynamic> professionalCopy = Map<String, dynamic>.from(professional);

        // Récupérer les contacts
        final contacts = await db.query(
          'health_professional_contacts',
          where: 'healthProfessionalId = ?',
          whereArgs: [professional['id']],
        );
        Log.d('Récupération health_professional_contacts:[${contacts.toString()}]');

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
        Log.d('Récupération health_professional_addresses:[${addresses.toString()}]');

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
        Log.d('Récupération health_professional_establishments:[${establishmentLinks.toString()}]');

        List<Map<String, dynamic>> establishments = [];
        for (var link in establishmentLinks) {
          final establishmentResults = await db.query(
            'establishments',
            where: 'id = ?',
            whereArgs: [link['establishmentId']],
          );

          if (establishmentResults.isNotEmpty) {
            // Créer une copie modifiable de l'établissement
            final Map<String, dynamic> establishment = Map<String, dynamic>.from(establishmentResults.first);
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
          professionalCopy['category'] = Map<String, dynamic>.from(categoryResults.first);
        }

        result.add(professionalCopy);
      }

      return result;
    } catch (e) {
      Log.d("DatabaseHelper: Erreur lors de la récupération des professionnels de santé: $e");
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
          await txn.insert('health_professionals', professionalData,
              conflictAlgorithm: ConflictAlgorithm.replace);
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
              await txn.insert('health_professional_contacts', contactData,
                  conflictAlgorithm: ConflictAlgorithm.replace);
            } catch (e) {
              Log.d('Erreur lors de l insertion de health_professional_contacts $e');
            }
            Log.d('Insertion de health_professional_contacts id:[${contact['id']}] healthProfessionalId:[${professionalData['id']} type:[${contact['type']} value:[${contact['value']} label:[${contact['label']} isPrimary:[${contact['isPrimary']}] OK');
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
              await txn.insert('health_professional_addresses', addressData,
                  conflictAlgorithm: ConflictAlgorithm.replace);
            } catch (e) {
              Log.d('Erreur lors de l nsertion de health_professional_addresses $e');
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
              await txn.insert('health_professional_establishments', linkData,
                  conflictAlgorithm: ConflictAlgorithm.replace);
            }catch (e) {
              Log.d('Erreur lors de l nsertion de health_professional_establishments $e');
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

      Log.d("DatabaseHelper: Professionnel supprimé avec succès, lignes affectées: $result");
      return result;
    } catch (e) {
      Log.e("DatabaseHelper: Erreur lors de la suppression du professionnel de santé: $e");
      return -1;
    }
  }

  Future<bool> updatePS(Map<String, dynamic> healthProfessional) async {
    Log.d("DatabaseHelper: Mise à jour du professionnel de santé ${healthProfessional['id']}");
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

        await txn.update('health_professionals', professionalData,
            where: 'id = ?', whereArgs: [healthProfessional['id']]);

        // Supprimer les contacts existants
        await txn.delete('health_professional_contacts',
            where: 'healthProfessionalId = ?', whereArgs: [healthProfessional['id']]);

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
            await txn.insert('health_professional_contacts', contactData,
                conflictAlgorithm: ConflictAlgorithm.replace);
          }
        }

        // Supprimer les adresses existantes
        await txn.delete('health_professional_addresses',
            where: 'healthProfessionalId = ?', whereArgs: [healthProfessional['id']]);

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
            await txn.insert('health_professional_addresses', addressData,
                conflictAlgorithm: ConflictAlgorithm.replace);
          }
        }

        // Supprimer les liens avec les établissements existants
        await txn.delete('health_professional_establishments',
            where: 'healthProfessionalId = ?', whereArgs: [healthProfessional['id']]);

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
            await txn.insert('health_professional_establishments', linkData,
                conflictAlgorithm: ConflictAlgorithm.replace);
          }
        } else {
          Log.d("Pad d'établissment pour le PS");
        }

        return true; // Succès
      });
    } catch (e) {
      Log.e("DatabaseHelper: Erreur lors de la mise à jour du professionnel de santé: $e");
      return false;
    }
  }


  Future<List<Map<String, dynamic>>> getPSContacts(String healthProfessionalId) async {
    final db = await database;
    return await db.query(
      'health_professional_contacts',
      where: 'healthProfessionalId = ?',
      whereArgs: [healthProfessionalId],
    );
  }

  Future<List<Map<String, dynamic>>> getPSAddresses(String healthProfessionalId) async {
    final db = await database;
    return await db.query(
      'health_professional_addresses',
      where: 'healthProfessionalId = ?',
      whereArgs: [healthProfessionalId],
    );
  }

  Future<List<Map<String, dynamic>>> getPSEstablishments(String healthProfessionalId) async {
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
    Log.d("DatabaseHelper: Récupération du professionnel de santé avec ID: $id");
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
      final List<Map<String, dynamic>> establishments = await db.rawQuery('''
      SELECT e.*, hpe.role
      FROM establishments e
      INNER JOIN health_professional_establishments hpe ON e.id = hpe.establishmentId
      WHERE hpe.healthProfessionalId = ?
    ''', [id]);
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
      Log.e("DatabaseHelper: Erreur lors de la récupération du professionnel de santé: $e");
      return null;
    }
  }

  // Insérer une catégorie
  Future<int> insertHealthProfessionalCategory(Map<String, dynamic> category) async {
    Log.d("DatabaseHelper: Insertion d'une catégorie de professionnel de santé");
    final db = await database;

    try {
      final categoryData = {
        'id': category['id'] ?? Uuid().v4(),
        'name': category['name'],
        'description': category['description'],
        'isActive': category['isActive'],
      };

      final result = await db.insert('health_professional_categories', categoryData,
          conflictAlgorithm: ConflictAlgorithm.replace);

      Log.d("DatabaseHelper: Catégorie insérée avec succès, résultat: $result");
      return result;
    } catch (e) {
      Log.e("DatabaseHelper: Erreur lors de l'insertion de la catégorie: $e");
      return -1;
    }
  }

  // Récupérer toutes les catégories
  Future<List<Map<String, dynamic>>> getHealthProfessionalCategories() async {
    Log.d("DatabaseHelper: Récupération des catégories de professionnels de santé");
    final db = await database;

    try {
      final categories = await db.query(
        'health_professional_categories',
        orderBy: 'name',
      );

      Log.d("DatabaseHelper: ${categories.length} catégories récupérées");
      return categories;
    } catch (e) {
      Log.e("DatabaseHelper: Erreur lors de la récupération des catégories: $e");
      return [];
    }
  }


  // Insérer une prise de médicament
  Future<int> insertMedicationIntake(Map<String, dynamic> intake) async {
    Log.d("DatabaseHelper: Insertion d'une prise de médicament");
    final db = await database;
    try {
      final result = await db.insert('medication_intakes', intake, conflictAlgorithm: ConflictAlgorithm.replace);
      Log.d("DatabaseHelper: Prise de médicament insérée avec succès, résultat: $result");
      return result;
    } catch (e) {
      Log.d("DatabaseHelper: Erreur lors de l'insertion de la prise de médicament: $e");
      return -1;
    }
  }

  // Récupérer les prises de médicaments pour un cycle
  Future<List<Map<String, dynamic>>> getMedicationIntakesByCycle(String cycleId) async {
    Log.d("DatabaseHelper: Récupération des prises de médicaments pour le cycle $cycleId");
    final db = await database;
    try {
      final results = await db.query(
          'medication_intakes',
          where: 'cycleId = ?',
          whereArgs: [cycleId],
          orderBy: 'dateTime DESC'
      );
      Log.d("DatabaseHelper: ${results.length} prises de médicaments récupérées");
      return results;
    } catch (e) {
      Log.d("DatabaseHelper: Erreur lors de la récupération des prises de médicaments: $e");
      return [];
    }
  }

  // Mettre à jour une prise de médicament
  Future<int> updateMedicationIntake(Map<String, dynamic> intake) async {
    Log.d("DatabaseHelper: Mise à jour de la prise de médicament avec ID ${intake['id']}");
    final db = await database;
    try {
      final result = await db.update(
          'medication_intakes',
          intake,
          where: 'id = ?',
          whereArgs: [intake['id']]
      );
      Log.d("DatabaseHelper: Prise de médicament mise à jour avec succès, lignes affectées: $result");
      return result;
    } catch (e) {
      Log.d("DatabaseHelper: Erreur lors de la mise à jour de la prise de médicament: $e");
      return -1;
    }
  }

  // Supprimer une prise de médicament
  Future<int> deleteMedicationIntake(String id) async {
    Log.d("DatabaseHelper: Suppression de la prise de médicament avec ID $id");
    final db = await database;
    try {
      final result = await db.delete(
          'medication_intakes',
          where: 'id = ?',
          whereArgs: [id]
      );
      Log.d("DatabaseHelper: Prise de médicament supprimée avec succès, lignes affectées: $result");
      return result;
    } catch (e) {
      Log.d("DatabaseHelper: Erreur lors de la suppression de la prise de médicament: $e");
      return -1;
    }
  }

  // Mettre à jour le statut d'une prise de médicament (pris/non pris)
  Future<int> updateMedicationIntakeCompletionStatus(String id, bool isCompleted) async {
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
      print("Erreur lors de la mise à jour du statut de la prise de médicament: $e");
      return -1;
    }
  }
}
