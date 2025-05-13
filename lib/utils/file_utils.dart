// lib/utils/file_utils.dart
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:suivi_cancer/utils/logger.dart';

class FileUtils {
  /// Copie un fichier vers le répertoire de stockage de l'application
  /// et renvoie le chemin du fichier copié
  static Future<String> copyFileToAppStorage(String sourceFilePath, String destinationRelativePath) async {
    try {
      // Récupérer le répertoire de stockage de l'application
      final appDir = await getApplicationDocumentsDirectory();
      final String destinationDirPath = path.join(appDir.path, path.dirname(destinationRelativePath));

      // Créer le répertoire de destination s'il n'existe pas
      final Directory destinationDir = Directory(destinationDirPath);
      if (!await destinationDir.exists()) {
        await destinationDir.create(recursive: true);
      }

      // Chemin complet du fichier de destination
      final String destinationPath = path.join(appDir.path, destinationRelativePath);

      // Copier le fichier
      final File sourceFile = File(sourceFilePath);
      final File destinationFile = await sourceFile.copy(destinationPath);

      Log.d("Fichier copié vers: ${destinationFile.path}");
      return destinationFile.path;
    } catch (e) {
      Log.e("Erreur lors de la copie du fichier: $e");
      rethrow;
    }
  }

  /// Supprime un fichier du stockage de l'application
  static Future<bool> deleteFileFromAppStorage(String filePath) async {
    try {
      final File file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        Log.d("Fichier supprimé: $filePath");
        return true;
      }
      return false;
    } catch (e) {
      Log.e("Erreur lors de la suppression du fichier: $e");
      return false;
    }
  }

  /// Vérifie si un fichier existe
  static Future<bool> fileExists(String filePath) async {
    try {
      final File file = File(filePath);
      return await file.exists();
    } catch (e) {
      Log.e("Erreur lors de la vérification de l'existence du fichier: $e");
      return false;
    }
  }

  /// Obtient la taille d'un fichier en octets
  static Future<int> getFileSize(String filePath) async {
    try {
      final File file = File(filePath);
      if (await file.exists()) {
        return await file.length();
      }
      return 0;
    } catch (e) {
      Log.e("Erreur lors de la récupération de la taille du fichier: $e");
      return 0;
    }
  }

  /// Convertit la taille en octets en une chaîne lisible
  static String getReadableFileSize(int size) {
    const suffixes = ['o', 'Ko', 'Mo', 'Go', 'To'];
    var i = 0;
    double s = size.toDouble();

    while (s >= 1024 && i < suffixes.length - 1) {
      s /= 1024;
      i++;
    }

    return '${s.toStringAsFixed(1)} ${suffixes[i]}';
  }
}