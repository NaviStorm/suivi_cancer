// lib/features/treatment/screens/session_details_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:suivi_cancer/features/treatment/models/establishment.dart';
import 'package:suivi_cancer/features/treatment/models/medication.dart';
import 'package:suivi_cancer/features/treatment/models/cycle.dart';
import 'package:suivi_cancer/features/treatment/models/session.dart';
import 'package:suivi_cancer/features/treatment/models/treatment.dart';
import 'package:suivi_cancer/features/treatment/models/radiotherapy.dart';
import 'package:suivi_cancer/features/treatment/services/treatment_service.dart';
import 'package:suivi_cancer/core/storage/database_helper.dart';
import 'package:suivi_cancer/utils/logger.dart';

class SessionDetailsScreen extends StatefulWidget {
  final Session session;
  final Cycle cycle;

  const SessionDetailsScreen({
    Key? key,
    required this.session,
    required this.cycle,
  }) : super(key: key);

  @override
  _SessionDetailsScreenState createState() => _SessionDetailsScreenState();
}

class _SessionDetailsScreenState extends State<SessionDetailsScreen> {
  bool _isLoading = true;
  Establishment? _establishment;
  List<Medication> _medications = [];

  @override
  void initState() {
    super.initState();
    _loadSessionDetails();
  }

  Future<void> _loadSessionDetails() async {
    setState(() {
      _isLoading = true;
    });

    try {
      Log.d("SessionDetailsScreen: Chargement des détails de la session ${widget.session.id}");
      final dbHelper = DatabaseHelper();
      
      // Charger l'établissement
      final establishmentMap = await dbHelper.getEstablishment(widget.session.establishmentId);
      if (establishmentMap != null) {
        _establishment = Establishment.fromMap(establishmentMap);
      }
      
      // Charger les médicaments
      final medicationMaps = await dbHelper.getSessionMedications(widget.session.id);
      _medications = medicationMaps.map((m) => Medication.fromMap(m)).toList();
      
      setState(() {
        _isLoading = false;
      });
      
      Log.d("SessionDetailsScreen: Détails chargés avec succès");
    } catch (e) {
      Log.d("SessionDetailsScreen: Erreur lors du chargement des détails: $e");
      setState(() {
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors du chargement des détails')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Détails de la session'),
        actions: [
          IconButton(
            icon: Icon(Icons.edit),
            onPressed: _editSession,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSessionInfoCard(),
                  SizedBox(height: 16),
                  if (_establishment != null) _buildEstablishmentCard(),
                  SizedBox(height: 16),
                  _buildMedicationsCard(),
                  SizedBox(height: 24),
                  if (!widget.session.isCompleted)
                    ElevatedButton(
                      onPressed: _markAsCompleted,
                      child: Text('Marquer comme terminée'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: Size(double.infinity, 50),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildSessionInfoCard() {
    final isPast = widget.session.dateTime.isBefore(DateTime.now());
    
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Informations de la session',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (widget.session.isCompleted)
                  Chip(
                    label: Text('Terminée'),
                    backgroundColor: Colors.green[100],
                    labelStyle: TextStyle(color: Colors.green[800]),
                  )
                else if (isPast)
                  Chip(
                    label: Text('Manquée'),
                    backgroundColor: Colors.red[100],
                    labelStyle: TextStyle(color: Colors.red[800]),
                  )
                else
                  Chip(
                    label: Text('À venir'),
                    backgroundColor: Colors.blue[100],
                    labelStyle: TextStyle(color: Colors.blue[800]),
                  ),
              ],
            ),
            SizedBox(height: 16),
            _buildInfoRow(
              'Date',
              DateFormat('EEEE dd MMMM yyyy', 'fr_FR').format(widget.session.dateTime),
            ),
            _buildInfoRow(
              'Heure',
              DateFormat('HH:mm', 'fr_FR').format(widget.session.dateTime),
            ),
            if (widget.session.notes != null && widget.session.notes!.isNotEmpty) ...[
              SizedBox(height: 16),
              Text(
                'Notes:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                widget.session.notes!,
                style: TextStyle(
                  color: Colors.grey[700],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEstablishmentCard() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Établissement',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            ListTile(
              leading: Icon(Icons.business),
              title: Text(_establishment!.name),
              subtitle: Text(
                [
                  _establishment!.address,
                  _establishment!.postalCode,
                  _establishment!.city
                ].where((s) => s != null && s.isNotEmpty).join(', '),
              ),
            ),
            if (_establishment!.phone != null && _establishment!.phone!.isNotEmpty)
              ListTile(
                leading: Icon(Icons.phone),
                title: Text(_establishment!.phone!),
                onTap: () => _makePhoneCall(_establishment!.phone!),
              ),
            if (_establishment!.email != null && _establishment!.email!.isNotEmpty)
              ListTile(
                leading: Icon(Icons.email),
                title: Text(_establishment!.email!),
                onTap: () => _sendEmail(_establishment!.email!),
              ),
            if (_establishment!.website != null && _establishment!.website!.isNotEmpty)
              ListTile(
                leading: Icon(Icons.language),
                title: Text(_establishment!.website!),
                onTap: () => _openWebsite(_establishment!.website!),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicationsCard() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Médicaments',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            _medications.isEmpty
                ? Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Aucun médicament associé à cette session',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    itemCount: _medications.length,
                    itemBuilder: (context, index) {
                      final medication = _medications[index];
                      return ListTile(
                        leading: Icon(
                          medication.isRinsing
                              ? Icons.water_drop
                              : Icons.medication,
                          color: medication.isRinsing ? Colors.blue : Colors.orange,
                        ),
                        title: Text(medication.name),
                        subtitle: medication.quantity != null
                            ? Text('${medication.quantity} ${medication.unit ?? ''}')
                            : null,
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri uri = Uri.parse('tel:$phoneNumber');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _sendEmail(String email) async {
    final Uri uri = Uri.parse('mailto:$email');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openWebsite(String website) async {
    String url = website;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }
    
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _editSession() async {
    Log.d("SessionDetailsScreen: Navigation vers l'écran de modification de la session");
    
    // Ici, vous naviguerez vers un écran d'édition de session
    // Pour l'instant, nous allons simplement afficher un message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Fonctionnalité d\'édition à implémenter')),
    );
  }

  void _markAsCompleted() async {
    Log.d("SessionDetailsScreen: Marquage de la session comme terminée");
    
    try {
      final dbHelper = DatabaseHelper();
      await dbHelper.updateSession({
        'id': widget.session.id,
        'isCompleted': 1,
      });
      
      setState(() {
        final updatedSession = Session(
          id: widget.session.id,
          cycleId: widget.session.cycleId,
          dateTime: widget.session.dateTime,
          establishmentId: widget.session.establishmentId,
          notes: widget.session.notes,
          establishment: widget.session.establishment,
          medications: widget.session.medications,
        );
        
        // Mettre à jour la session dans le widget
        widget.session.isCompleted = true;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Session marquée comme terminée')),
      );
      
      // Indiquer à l'écran précédent que des modifications ont été apportées
      Navigator.pop(context, true);
    } catch (e) {
      Log.d("SessionDetailsScreen: Erreur lors du marquage de la session: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la mise à jour de la session')),
      );
    }
  }
}

