// fctDate.dart

import 'dart:ui' as ui;
import 'package:suivi_cancer/utils/logger.dart';

String getFmtDate() {
  final locale = ui.PlatformDispatcher.instance.locale.toString();
  Log.d('locale:[$locale]');

  switch (locale) {
    case 'fr_FR':
      return 'dd/MM/yyyy';
    case 'en_US':
      return 'MM/dd/yyyy';
    case 'en_GB':
      return 'dd/MM/yyyy';
    case 'de_DE':
      return 'dd.MM.yyyy';
    case 'ja_JP':
      return 'yyyy/MM/dd';
    default:
      return 'yyyy-MM-dd'; // Fallback format
  }
}


String getFmtDateTime() {
  final locale = ui.PlatformDispatcher.instance.locale.toString();
  Log.d('locale:[$locale]');

  switch (locale) {
    case 'fr_FR':
      return 'dd/MM/yyyy HH:mm';
    case 'en_US':
      return 'MM/dd/yyyy hh:mm a'; // 12h avec AM/PM
    case 'en_GB':
      return 'dd/MM/yyyy HH:mm';
    case 'de_DE':
      return 'dd.MM.yyyy HH:mm';
    case 'ja_JP':
      return 'yyyy/MM/dd HH:mm';
    default:
      return 'yyyy-MM-dd HH:mm'; // format par défaut (ISO-like)
  }
}

int getFirstWeekday(String locale) {
  switch (locale) {
    case 'fr_FR':
    case 'de_DE':
    case 'en_GB':
      return DateTime.monday; // 1
    case 'en_US':
    case 'ja_JP':
      return DateTime.sunday; // 7
    default:
      return DateTime.monday; // Fallback ISO
  }
}
