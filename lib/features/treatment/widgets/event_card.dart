// lib/features/treatment/widgets/event_card.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:suivi_cancer/features/treatment/models/session.dart';
import 'package:suivi_cancer/features/treatment/models/examination.dart';
import 'package:suivi_cancer/features/treatment/models/document.dart';
import 'package:suivi_cancer/features/treatment/models/medication_intake.dart';
import 'package:suivi_cancer/features/treatment/widgets/medication_intake_card.dart';
import 'package:suivi_cancer/utils/logger.dart';

class EventCard extends StatelessWidget {
  final Map<String, dynamic> event;
  final Function(dynamic) onToggleCompleted;
  final Function(Map<String, dynamic>) onTap;
  final Function(Map<String, dynamic>) onLongPress;
  final String locale;

  const EventCard({
    super.key,
    required this.event,
    required this.onToggleCompleted,
    required this.onTap,
    required this.onLongPress,
    required this.locale,
  });

  @override
  Widget build(BuildContext context) {
    final bool isPast = event['isPast'] as bool;
    final bool isCompleted = event['isCompleted'] as bool;
    final DateTime date = event['date'] as DateTime;
    final String title = event['title'] as String;
    final IconData icon = event['icon'] as IconData;
    final BorderSide border = event['border'] as BorderSide;
    final Color color = event['color'] as Color;
    final Color backgroundColor = event['backgroundColor'] as Color;
    final String type = event['type'] as String;

    Log.d('event:[${event.toString()}]');
    // Cas spécial pour les prises de médicament
    if (type == 'medication_intake') {
      return MedicationIntakeCard(
        intake: event['object'] as MedicationIntake,
        onToggleCompleted: () => onToggleCompleted(event['object']),
        onTap: () => onTap(event),
        onLongPress: () => onLongPress(event),
        locale: locale,
      );
    }

    // Contenu spécifique au type d'événement
    Widget eventContent;
    if (type == 'session') {
      eventContent = _buildSessionPreview(event['object'] as Session);
    } else if (type == 'examination') {
      eventContent = _buildExaminationPreview(event['object'] as Examination);
    } else if (type == 'document') {
      eventContent = _buildDocumentPreview(event['object'] as Document);
    } else {
      eventContent = Container(); // Ne devrait jamais arriver
    }

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      elevation: 1,
      color: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: border ?? BorderSide.none,
      ),
      child: InkWell(
        onTap: () => onTap(event),
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: EdgeInsets.all(8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date
              SizedBox(
                width: 50,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      DateFormat('dd', locale).format(date),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    Text(
                      DateFormat('MMM', locale).format(date).toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[600],
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      DateFormat('HH:mm', locale).format(date),
                      style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              // Séparateur vertical
              Container(
                height: 60,
                width: 1,
                color: Colors.grey.withOpacity(0.2),
                margin: EdgeInsets.symmetric(horizontal: 4),
              ),
              // Icône
              Container(
                margin: EdgeInsets.only(right: 8, top: 2),
                padding: EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 14, color: color),
              ),
              // Contenu
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Icône de case à cocher pour les séances et examens
                        if (type == 'session' || type == 'examination')
                          GestureDetector(
                            onTap: () => onToggleCompleted(event['object']),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    isCompleted
                                        ? Colors.green.withAlpha(20)
                                        : Colors.grey.withAlpha(10),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Icon(
                                isCompleted
                                    ? Icons.check_circle
                                    : Icons.check_circle_outline,
                                size: 16,
                                color: isCompleted ? Colors.green : Colors.grey,
                              ),
                            ),
                          ),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color:
                                isCompleted
                                    ? Colors.green.withOpacity(0.1)
                                    : Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isCompleted
                                ? 'Terminé'
                                : (isPast ? 'En retard' : 'À venir'),
                            style: TextStyle(
                              fontSize: 9,
                              color:
                                  isCompleted
                                      ? Colors.green
                                      : (isPast
                                          ? Colors.amber.shade900
                                          : Colors.grey[700]),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 2),
                    // Détails spécifiques au type d'événement
                    eventContent,
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSessionPreview(Session session) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.business, size: 10, color: Colors.grey[600]),
            SizedBox(width: 4),
            Expanded(
              child: Text(
                session.establishment.name,
                style: TextStyle(fontSize: 10),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        if (session.medications.isNotEmpty)
          Row(
            children: [
              Icon(Icons.medication, size: 10, color: Colors.blue[700]),
              SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Médic: ${session.medications.where((m) => !m.isRinsing).map((m) => m.name).join(", ")}',
                  style: TextStyle(fontSize: 10),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        // Ajoutez d'autres détails selon vos besoins
      ],
    );
  }

  Widget _buildExaminationPreview(Examination examination) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.business, size: 10, color: Colors.grey[600]),
            SizedBox(width: 4),
            Expanded(
              child: Text(
                examination.establishment.name,
                style: TextStyle(fontSize: 10),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        // Ajoutez d'autres détails selon vos besoins
      ],
    );
  }

  Widget _buildDocumentPreview(Document document) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.description, size: 10, color: Colors.grey[600]),
            SizedBox(width: 4),
            Expanded(
              child: Text(
                document.name,
                style: TextStyle(fontSize: 10),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        // Ajoutez d'autres détails selon vos besoins
      ],
    );
  }
}
