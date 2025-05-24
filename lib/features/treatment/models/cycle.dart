import 'package:suivi_cancer/features/treatment/models/establishment.dart';
import 'package:suivi_cancer/features/treatment/models/examination.dart';
import 'package:suivi_cancer/features/treatment/models/reminder.dart';
import 'package:suivi_cancer/features/treatment/models/session.dart';

enum CureType {
  Chemotherapy,
  Immunotherapy,
  Hormonotherapy,
  Combined,
  Surgery,
  Radiotherapy
}

class Cycle {
  final String id;
  final CureType type;
  final DateTime startDate;
  final DateTime endDate;
  final Establishment establishment;
  final int sessionCount;
  final Duration sessionInterval;
  final List<Session> sessions;
  final List<Examination> examinations;
  final List<Reminder> reminders;
  String? conclusion;
  bool isCompleted;

  Cycle({
    required this.id,
    required this.type,
    required this.startDate,
    required this.endDate,
    required this.establishment,
    required this.sessionCount,
    required this.sessionInterval,
    this.sessions = const [],
    this.examinations = const [],
    this.reminders = const [],
    this.conclusion,
    this.isCompleted = false,
  });
}
