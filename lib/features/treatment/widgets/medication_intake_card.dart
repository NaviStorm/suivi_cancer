// lib/features/treatment/widgets/medication_intake_card.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:suivi_cancer/features/treatment/models/medication_intake.dart';

class MedicationIntakeCard extends StatelessWidget {
  final MedicationIntake intake;
  final Function() onToggleCompleted;
  final Function() onTap;
  final Function()? onLongPress;
  final String locale;

  const MedicationIntakeCard({
    super.key,
    required this.intake,
    required this.onToggleCompleted,
    required this.onTap,
    this.onLongPress,
    required this.locale,
  });

  @override
  Widget build(BuildContext context) {
    final bool isPast = intake.dateTime.isBefore(DateTime.now());
    final bool isCompleted = intake.isCompleted;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      elevation: 1,
      color: const Color(0xFFE3F2FD), // Bleu très pâle
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: BorderSide(color: Colors.blue[100]!, width: 1),
      ),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              // Date et heure
              Text(
                DateFormat('dd/MM HH:mm', locale).format(intake.dateTime),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(width: 8),
              // Icône médicament
              const Icon(Icons.medication, size: 16, color: Colors.blue),
              const SizedBox(width: 8),
              // Nom des médicaments avec quantités
              Expanded(
                child: Text(
                  _getFormattedLabel(),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Icône de validation et statut
              InkWell(
                onTap: onToggleCompleted,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isCompleted ? Icons.check_circle : Icons.circle_outlined,
                      color: isCompleted ? Colors.green : Colors.grey,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isCompleted
                          ? 'Terminé'
                          : (isPast ? 'En retard' : 'À venir'),
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            isCompleted
                                ? Colors.green
                                : (isPast ? Colors.red : Colors.grey[700]),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getFormattedLabel() {
    if (intake.medications.isEmpty) {
      return "Aucun médicament";
    }

    String medicationsLabel = intake.medications
        .map((med) => "${med.quantity}x${med.medicationName}")
        .join(", ");

    // Tronquer si trop long
    if (medicationsLabel.length > 25) {
      medicationsLabel = "${medicationsLabel.substring(0, 22)}...";
    }

    return medicationsLabel;
  }
}
