// fctDate.dart

import 'dart:ui' as ui;
import 'package:intl/intl.dart';
import 'package:suivi_cancer/utils/logger.dart';

String getFmtDate() {
  final locale = ui.PlatformDispatcher.instance.locale.toString();
//  Log.d('locale:[$locale]');

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
//  Log.d('locale:[$locale]');

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

String getFmtTime() {
  final locale = ui.PlatformDispatcher.instance.locale.toString();
//  Log.d('locale:[$locale]');

  switch (locale) {
    case 'en_US':
      return 'hh:mm a'; // 12h avec AM/PM
    default:
      return 'HH:mm'; // format par défaut (ISO-like)
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

String getLocalizedDateTimeFormat(DateTime dateTime) {
  // Initialiser les données de formatage pour cette locale
  final locale = ui.PlatformDispatcher.instance.locale.toString();

  // Créer un format adapté à la locale
  switch (locale) {
    case 'fr_FR':
      return DateFormat("dd/MM/yyyy 'à' HH:mm", locale).format(dateTime);
    case 'en_US':
      return DateFormat("MM/dd/yyyy 'at' h:mm a", locale).format(dateTime);
    case 'en_GB':
      return DateFormat("dd/MM/yyyy 'at' HH:mm", locale).format(dateTime);
    case 'de_DE':
      return DateFormat("dd.MM.yyyy 'um' HH:mm", locale).format(dateTime);
    case 'es_ES':
      return DateFormat("dd/MM/yyyy 'a las' HH:mm", locale).format(dateTime);
    case 'it_IT':
      return DateFormat("dd/MM/yyyy 'alle ore' HH:mm", locale).format(dateTime);
    case 'ja_JP':
      return DateFormat("yyyy年MM月dd日 HH時mm分", locale).format(dateTime);
    case 'zh_CN':
      return DateFormat("yyyy年MM月dd日 HH:mm", locale).format(dateTime);
    default:
    // Format par défaut international
      return DateFormat('yyyy-MM-dd HH:mm', locale).format(dateTime);
  }
}
