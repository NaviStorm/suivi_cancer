// lib/features/treatment/widgets/session_card.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:suivi_cancer/features/treatment/models/session.dart';

class SessionCard extends StatelessWidget {
  final Session session;
  final Function(Session) onToggleCompleted;
  final Function(Session) onTap;
  final String locale;
  final String sessionNumber;

  const SessionCard({
    Key? key,
    required this.session,
    required this.onToggleCompleted,
    required this.onTap,
    required this.locale,
    required this.sessionNumber,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool isPast = session.dateTime.isBefore(DateTime.now());
    final bool isCompleted = session.isCompleted;
    
    // Déterminer la couleur de fond et la bordure
    Color backgroundColor;
    BorderSide? border;

    if (isCompleted) {
      backgroundColor = Colors.grey[100]!;
      border = BorderSide(color: Colors.grey[300]!, width: 1);
    } else if (isPast) {
      backgroundColor = Colors.grey[300]!;
      border = BorderSide(color: Colors.amber[300]!, width: 1);
    } else {
      backgroundColor = Colors.white;
      border = BorderSide(color: Colors.black, width: 1);
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
        onTap: () => onTap(session),
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date
              Container(
                width: 50,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      DateFormat('dd', locale).format(session.dateTime),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    Text(
                      DateFormat('MMM', locale).format(session.dateTime).toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('HH:mm', locale).format(session.dateTime),
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[600],
                      ),
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
                  color: Colors.blue.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.medical_services, size: 14, color: Colors.blue),
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
                            'Séance $sessionNumber',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Icône de case à cocher
                        GestureDetector(
                          onTap: () => onToggleCompleted(session),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                            decoration: BoxDecoration(
                              color: isCompleted ? Colors.green.withAlpha(20) : Colors.grey.withAlpha(10),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Icon(
                              isCompleted ? Icons.check_circle : Icons.check_circle_outline,
                              size: 16,
                              color: isCompleted ? Colors.green : Colors.grey,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: isCompleted
                                ? Colors.green.withOpacity(0.1)
                                : Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isCompleted ? 'Terminé' : (isPast ? 'En retard' : 'À venir'),
                            style: TextStyle(
                              fontSize: 9,
                              color: isCompleted ? Colors.green : (isPast ? Colors.amber.shade900 : Colors.grey[700]),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    // Détails de la session
                    _buildSessionDetails(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSessionDetails() {
    // Récupérer les médicaments groupés par type
    final List standardMeds = session.medications.where((m) => !m.isRinsing).toList();
    final List rinsingMeds = session.medications.where((m) => m.isRinsing).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.business, size: 10, color: Colors.grey[600]),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                session.establishment.name,
                style: const TextStyle(fontSize: 10),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        if (standardMeds.isNotEmpty)
          Row(
            children: [
              Icon(Icons.medication, size: 10, color: Colors.blue[700]),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Médic: ${standardMeds.map((m) => m.name).join(", ")}',
                  style: const TextStyle(fontSize: 10),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        if (rinsingMeds.isNotEmpty)
          Row(
            children: [
              const Icon(Icons.sanitizer, size: 10, color: Colors.teal),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Rinçage: ${rinsingMeds.map((m) => m.name).join(", ")}',
                  style: const TextStyle(fontSize: 10),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        if (session.notes != null && session.notes!.isNotEmpty)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.notes, size: 10, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  session.notes!,
                  style: const TextStyle(fontSize: 10, fontStyle: FontStyle.italic),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

