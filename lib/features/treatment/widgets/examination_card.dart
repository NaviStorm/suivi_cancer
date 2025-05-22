// lib/features/treatment/widgets/examination_card.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:suivi_cancer/features/treatment/models/examination.dart';
import 'package:suivi_cancer/features/treatment/utils/event_formatter.dart';

class ExaminationCard extends StatelessWidget {
  final Examination examination;
  final Function(Examination) onToggleCompleted;
  final Function(Examination) onTap;
  final String locale;
  final String? sessionRelationLabel;

  const ExaminationCard({
    super.key,
    required this.examination,
    required this.onToggleCompleted,
    required this.onTap,
    required this.locale,
    this.sessionRelationLabel,
  });

  @override
  Widget build(BuildContext context) {
    final bool isPast = examination.dateTime.isBefore(DateTime.now());
    final bool isCompleted = examination.isCompleted;

    // Déterminer la couleur de fond et la bordure
    Color backgroundColor;
    BorderSide? border;

    if (examination.type == ExaminationType.PriseDeSang) {
      backgroundColor = const Color(0xFFFFF9C4); // Jaune très pâle
      border = BorderSide(color: Colors.amber[300]!, width: 1);
    } else if (examination.type == ExaminationType.Injection) {
      backgroundColor = Colors.lightGreen.shade50; // Vert très pâle
      border = BorderSide(color: Colors.amber[300]!, width: 1);
    } else if (isCompleted) {
      backgroundColor = Colors.grey.withAlpha(13);
      border = BorderSide(color: Colors.grey[300]!, width: 1);
    } else if (isPast) {
      backgroundColor = Colors.amber.withAlpha(13);
      border = BorderSide(color: Colors.amber[300]!, width: 1);
    } else {
      backgroundColor = Colors.white;
      border = BorderSide(color: Colors.red[200]!, width: 1);
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      elevation: 1,
      color: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: border,
      ),
      child: InkWell(
        onTap: () => onTap(examination),
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(8),
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
                      DateFormat('dd', locale).format(examination.dateTime),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                    Text(
                      DateFormat(
                        'MMM',
                        locale,
                      ).format(examination.dateTime).toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('HH:mm', locale).format(examination.dateTime),
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
                margin: const EdgeInsets.symmetric(horizontal: 4),
              ),
              // Icône
              Container(
                margin: const EdgeInsets.only(right: 8, top: 2),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  EventFormatter.getExaminationIcon(examination.type),
                  size: 14,
                  color: Colors.red,
                ),
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
                            EventFormatter.getExaminationTypeLabel(
                              examination.type,
                            ),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Icône de case à cocher
                        GestureDetector(
                          onTap: () => onToggleCompleted(examination),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
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
                          padding: const EdgeInsets.symmetric(
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
                    const SizedBox(height: 2),
                    // Détails de l'examen
                    _buildExaminationDetails(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExaminationDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.business, size: 10, color: Colors.grey[600]),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                examination.establishment.name,
                style: const TextStyle(fontSize: 10),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        if (examination.prescripteur != null)
          Row(
            children: [
              const Icon(Icons.person, size: 10, color: Colors.indigo),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  examination.prescripteur!.fullName,
                  style: const TextStyle(fontSize: 10),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        if (sessionRelationLabel != null)
          Row(
            children: [
              const Icon(Icons.event_available, size: 10, color: Colors.purple),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  sessionRelationLabel!,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        if (examination.notes != null && examination.notes!.isNotEmpty)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.notes, size: 10, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  examination.notes!,
                  style: const TextStyle(
                    fontSize: 10,
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
      ],
    );
  }
}
