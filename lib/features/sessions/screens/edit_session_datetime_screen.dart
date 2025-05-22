// lib/features/treatment/screens/edit_session_datetime_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:suivi_cancer/utils/logger.dart';
import 'package:suivi_cancer/features/treatment/models/session.dart';
import 'package:suivi_cancer/core/storage/database_helper.dart';
import 'package:suivi_cancer/common/widgets/date_time_picker.dart';

class EditSessionDateTimeScreen extends StatefulWidget {
  final Session session;

  const EditSessionDateTimeScreen({super.key, required this.session});

  @override
  _EditSessionDateTimeScreenState createState() =>
      _EditSessionDateTimeScreenState();
}

class _EditSessionDateTimeScreenState extends State<EditSessionDateTimeScreen> {
  DateTime _dateTime = DateTime.now();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _dateTime = widget.session.dateTime;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Modifier la date et l\'heure')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Information sur la séance',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Vous pouvez modifier uniquement la date et l\'heure de cette séance. Les médicaments et autres paramètres sont définis par le protocole du cycle et ne peuvent pas être modifiés individuellement.',
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Date actuelle: ${DateFormat('dd/MM/yyyy HH:mm').format(widget.session.dateTime)}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 24),
            DateTimePicker(
              label: 'Nouvelle date et heure',
              initialValue: _dateTime,
              showTime: true,
              onDateTimeSelected: (dateTime) {
                setState(() {
                  _dateTime = dateTime;
                });
              },
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isSaving ? null : _saveDateTime,
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 16),
                minimumSize: Size(double.infinity, 50),
              ),
              child:
                  _isSaving
                      ? CircularProgressIndicator(color: Colors.white)
                      : Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveDateTime() async {
    setState(() {
      _isSaving = true;
    });

    try {
      final dbHelper = DatabaseHelper();

      // Mettre à jour uniquement la date et l'heure
      final sessionData = {
        'id': widget.session.id,
        'dateTime': _dateTime.toIso8601String(),
      };

      await dbHelper.updateSession(sessionData);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Date et heure modifiées avec succès')),
      );

      Navigator.pop(context, true);
    } catch (e) {
      Log.d('Erreur lors de la modification de la date: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la modification: $e')),
      );
      setState(() {
        _isSaving = false;
      });
    }
  }
}
