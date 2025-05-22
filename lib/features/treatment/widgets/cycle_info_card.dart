// lib/features/treatment/widgets/cycle_info_card.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:suivi_cancer/features/treatment/models/cycle.dart';
import 'package:suivi_cancer/features/treatment/utils/event_formatter.dart';

class CycleInfoCard extends StatelessWidget {
  final Cycle cycle;

  const CycleInfoCard({super.key, required this.cycle});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Cycle de ${EventFormatter.getCycleTypeLabel(cycle.type)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color:
                        cycle.isCompleted
                            ? Colors.green.withOpacity(0.1)
                            : Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color:
                          cycle.isCompleted
                              ? Colors.green.withOpacity(0.5)
                              : Colors.blue.withOpacity(0.5),
                    ),
                  ),
                  child: Text(
                    cycle.isCompleted ? 'Terminé' : 'En cours',
                    style: TextStyle(
                      color: cycle.isCompleted ? Colors.green : Colors.blue,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildInfoRow(
              Icons.calendar_today,
              'Début: ${DateFormat('dd/MM/yyyy').format(cycle.startDate)}',
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              Icons.calendar_today,
              'Fin: ${DateFormat('dd/MM/yyyy').format(cycle.endDate)}',
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              Icons.medical_services,
              'Séances prévues: ${cycle.sessionCount}',
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              Icons.timer,
              'Intervalle: ${cycle.sessionInterval.inDays} jours',
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              Icons.business,
              'Établissement: ${cycle.establishment.name}',
            ),
            if (cycle.conclusion != null && cycle.conclusion!.isNotEmpty) ...[
              const Divider(height: 24),
              const Text(
                'Conclusion du cycle:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Text(
                cycle.conclusion!,
                style: const TextStyle(
                  fontStyle: FontStyle.italic,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey[700]),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
      ],
    );
  }
}
