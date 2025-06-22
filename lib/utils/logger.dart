// lib/utils/logger.dart

import 'package:flutter/foundation.dart';

/// Utilitaire de logging qui détecte automatiquement le contexte d'appel
/// (fichier, classe, et méthode) à partir de la stack trace.
class Log {
  static bool _enableStackTraceDetection = true;

  /// Active ou désactive la détection automatique de la stack trace.
  /// Si désactivée, seul le message sera affiché.
  static set enableStackTraceDetection(bool value) {
    _enableStackTraceDetection = value;
  }

  /// Journalise un message de debug avec détection automatique du contexte.
  static void d(String message) {
    if (!kReleaseMode) {
      print(message);
    }
    _log('🔍 DEBUG', message);
  }

  /// Journalise un message d'information avec détection automatique du contexte.
  static void i(String message) {
    if (!kReleaseMode) {
      print(message);
    }
    _log('📘 INFO', message);
  }

  /// Journalise un avertissement avec détection automatique du contexte.
  static void w(String message) {
    if (!kReleaseMode) {
      print(message);
    }
    _log('⚠️ WARN', message);
  }

  /// Journalise une erreur avec détection automatique du contexte.
  static void e(String message, {Object? error, StackTrace? stackTrace}) {
    _log('❌ ERROR', message);

    if (error != null) {
      debugPrint('Exception: $error');
    }

    if (stackTrace != null) {
      debugPrint('Stack trace: $stackTrace');
    }
  }

  /// Méthode interne qui gère le logging avec détection du contexte.
  static void _log(String level, String message) {
    if (!kDebugMode) return;

    if (_enableStackTraceDetection) {
      // Récupérer la stack trace actuelle
      final stackTrace = StackTrace.current;

      // Convertir la stack trace en chaîne de caractères et la diviser en lignes
      final stackTraceString = stackTrace.toString();
      final stackTraceLines = stackTraceString.split('\n');

      // La première ligne est cette méthode _log, la deuxième est la méthode d/i/w/e
      // Donc nous voulons la troisième ligne qui est l'appelant réel
      if (stackTraceLines.length > 2) {
        final callerLine = stackTraceLines[2];

        // Analyser la ligne pour extraire les informations
        final callerInfo = _parseStackTraceLine(callerLine);

        if (callerInfo != null) {
          final fileName = callerInfo['file'];
          final numLine = callerInfo['line'];
          final className = callerInfo['class'];
          final methodName = callerInfo['method'];

          // Construire le préfixe avec les informations disponibles
          var context = '';

          if (fileName != null) {
            context += '[$fileName] ';
          }

          if (className != null) {
            context += className;

            if (methodName != null) {
              numLine != null
                  ? context += '.$methodName($numLine)'
                  : context += '.$methodName()';
            }

            if (numLine != null) {
              context += ':';
              context += numLine;
            }
            context += ': ';
          }

          debugPrint('$level $context$message');
          return;
        }
      }
    }

    // Fallback simple si la détection ne fonctionne pas
    debugPrint('$level $message');
  }

  /// Analyse une ligne de stack trace pour extraire le fichier, la classe et la méthode.
  static Map<String, String?>? _parseStackTraceLine(String line) {
    // Format typique de stack trace Flutter/Dart:
    // #2      Logger._log (package:myapp/utils/logger.dart:45:7)

    try {
      final RegExp numeroLineRegex = RegExp(r':(\d+):\d+\)');
      final Match? numeroLineMatch = numeroLineRegex.firstMatch(line);
      String? lineNumber = numeroLineMatch?.group(1);

      // Extraire le chemin du fichier
      final filePathRegex = RegExp(r'\((.+?)(:\d+:\d+)?\)');
      final filePathMatch = filePathRegex.firstMatch(line);
      String? filePath = filePathMatch?.group(1);

      // Si on a un chemin, extraire juste le nom du fichier
      String? fileName;
      if (filePath != null) {
        final fileNameRegex = RegExp(r'[^/\\]+\.dart');
        final fileNameMatch = fileNameRegex.firstMatch(filePath);
        fileName = fileNameMatch?.group(0);
      }

      // Extraire la classe et la méthode
      // Format: #2      ClassName.methodName
      final methodRegex = RegExp(r'#\d+\s+([^(]+)');
      final methodMatch = methodRegex.firstMatch(line);
      String? methodFull = methodMatch?.group(1)?.trim();

      String? className;
      String? methodName;

      if (methodFull != null) {
        final parts = methodFull.split('.');

        if (parts.length > 1) {
          // Si on a un format Classe.méthode
          className = parts[0];
          methodName = parts.sublist(1).join('.');
        } else {
          // Si c'est juste une fonction sans classe
          methodName = methodFull;
        }
      }

      return {
        'file': fileName,
        'line': lineNumber,
        'class': className,
        'method': methodName,
      };
    } catch (e) {
      debugPrint('Erreur lors de l\'analyse de la stack trace: $e');
      return null;
    }
  }
}

// Pas d'extension ni d'alias global qui pourrait être confondu avec un Type
