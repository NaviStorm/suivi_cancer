// lib/features/treatment/widgets/add_event_bottom_sheet.dart
import 'package:flutter/material.dart';

class AddEventBottomSheet extends StatelessWidget {
  final Function() onAddSession;
  final Function() onAddExamination;
  final Function() onAddDocument;
  final Function() onAddMedicationIntake;
  final Function() onAddAppointment;

  const AddEventBottomSheet({
    super.key,
    required this.onAddSession,
    required this.onAddExamination,
    required this.onAddDocument,
    required this.onAddMedicationIntake,
    required this.onAddAppointment,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ajouter un événement',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.event_note, color: Colors.blue),
            title: const Text(
              'Nouvelle séance',
              style: TextStyle(fontSize: 14),
            ),
            subtitle: const Text(
              'Planifier une séance de traitement',
              style: TextStyle(fontSize: 12),
            ),
            onTap: () {
              Navigator.pop(context);
              onAddSession();
            },
          ),
          ListTile(
            leading: const Icon(Icons.monitor_heart, color: Colors.red),
            title: const Text('Nouvel examen', style: TextStyle(fontSize: 14)),
            subtitle: const Text(
              'Prise de sang, scanner, IRM...',
              style: TextStyle(fontSize: 12),
            ),
            onTap: () {
              Navigator.pop(context);
              onAddExamination();
            },
          ),
          ListTile(
            leading: Icon(Icons.calendar_today, color: Colors.orange),
            title: Text('Ajouter un rendez-vous'),
            subtitle: Text('Consultation médicale'),
            onTap: () {
              Navigator.pop(context);
              onAddAppointment();
            },
          ),
          ListTile(
            leading: const Icon(Icons.description, color: Colors.green),
            title: const Text(
              'Nouveau document',
              style: TextStyle(fontSize: 14),
            ),
            subtitle: const Text(
              'Ordonnance, résultat, compte-rendu...',
              style: TextStyle(fontSize: 12),
            ),
            onTap: () {
              Navigator.pop(context);
              onAddDocument();
            },
          ),
          ListTile(
            leading: const Icon(Icons.medication, color: Colors.lightBlue),
            title: const Text(
              'Nouvelle prise de médicament',
              style: TextStyle(fontSize: 14),
            ),
            subtitle: const Text(
              'Enregistrer une prise de médicament',
              style: TextStyle(fontSize: 12),
            ),
            onTap: () {
              Navigator.pop(context);
              onAddMedicationIntake();
            },
          ),
        ],
      ),
    );
  }
}
