// lib/features/treatment/screens/session_details_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:suivi_cancer/features/treatment/models/session.dart';
import 'package:suivi_cancer/features/treatment/models/cycle.dart';
import 'package:suivi_cancer/core/storage/database_helper.dart';
import 'package:suivi_cancer/common/widgets/confirmation_dialog_new.dart';
import 'package:suivi_cancer/features/treatment/screens/add_side_effect_screen.dart';

class SessionDetailsScreen extends StatefulWidget {
  final Session session;
  final Cycle cycle; // Ajout du paramètre cycle

  const SessionDetailsScreen({
    Key? key,
    required this.session,
    required this.cycle,
  }) : super(key: key);

  @override
  _SessionDetailsScreenState createState() => _SessionDetailsScreenState();
}

class _SessionDetailsScreenState extends State<SessionDetailsScreen> {
  bool _isLoading = false;
  late Session _session;
  late Cycle _cycle;

  @override
  void initState() {
    super.initState();
    _session = widget.session;
    _cycle = widget.cycle;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Détails de la séance'),
        actions: [
          IconButton(
            icon: Icon(Icons.edit),
            onPressed: () {
              // Navigation vers l'écran de modification de la séance
              // À implémenter selon vos besoins
            },
          ),
          IconButton(
            icon: Icon(Icons.delete),
            onPressed: _confirmDeleteSession,
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
                  SizedBox(height: 24),
                  _buildMedicationsSection(),
                  SizedBox(height: 24),
                  _buildPrerequisitesSection(),
                  SizedBox(height: 24),
                  _buildSideEffectsSection(),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddSideEffectScreen(
                entityType: 'session',
                entityId: _session.id,
                entityName: 'Séance du ${DateFormat('dd/MM/yyyy').format(_session.dateTime)}',
              ),
            ),
          );
        },
        child: Icon(Icons.add),
        tooltip: 'Ajouter un effet secondaire',
      ),
    );
  }

  Widget _buildSessionInfoCard() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Informations de la séance',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                _buildStatusChip(
                  _session.isCompleted ? 'Terminé' : 'Planifié',
                  _session.isCompleted ? Colors.green : Colors.orange,
                ),
              ],
            ),
            SizedBox(height: 16),
            _buildInfoRow('Cycle', _getCycleTypeLabel(_cycle.type)),
            _buildInfoRow('Date et heure', DateFormat('dd/MM/yyyy à HH:mm').format(_session.dateTime)),
            _buildInfoRow('Établissement', _session.establishment.name),
            if (_session.notes != null && _session.notes!.isNotEmpty)
              _buildInfoRow('Notes', _session.notes!),
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
            width: 120,
            child: Text(
              '$label:',
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

  Widget _buildMedicationsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Médicaments',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 8),
        _session.medications.isEmpty
            ? Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: Text(
                      'Aucun médicament enregistré',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                ),
              )
            : ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: _session.medications.length,
                itemBuilder: (context, index) {
                  final medication = _session.medications[index];
                  return Card(
                    margin: EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(medication.name),
                      subtitle: medication.quantity != null
                          ? Text('Dosage: ${medication.quantity}')
                          : null,
                    ),
                  );
                },
              ),
      ],
    );
  }

  Widget _buildPrerequisitesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Prérequis',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 8),
        _session.prerequisites.isEmpty
            ? Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: Text(
                      'Aucun prérequis enregistré',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                ),
              )
            : ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: _session.prerequisites.length,
                itemBuilder: (context, index) {
                  final prerequisite = _session.prerequisites[index];
                  return Card(
                    margin: EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(prerequisite.description),
                      subtitle: Text('Échéance: ${DateFormat('dd/MM/yyyy').format(prerequisite.deadline)}'),
                      trailing: prerequisite.appointment != null
                          ? Icon(Icons.event, color: Colors.blue)
                          : null,
                      onTap: prerequisite.appointment != null
                          ? () {
                              // Afficher les détails du rendez-vous
                            }
                          : null,
                    ),
                  );
                },
              ),
      ],
    );
  }

  Widget _buildSideEffectsSection() {
    // À implémenter: affichage des effets secondaires liés à la séance
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Effets secondaires',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 8),
        // Placeholder pour les effets secondaires (à remplacer par votre implémentation)
        Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: Text(
                'Aucun effet secondaire enregistré',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDeleteSession() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => ConfirmationDialog(
        title: 'Supprimer la séance',
        content: 'Êtes-vous sûr de vouloir supprimer cette séance ? Cette action est irréversible.',
        confirmText: 'Supprimer',
        cancelText: 'Annuler',
        isDestructive: true,
      ),
    );

    if (confirmed == true) {
      try {
        final dbHelper = DatabaseHelper();
        await dbHelper.deleteSession(_session.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Séance supprimée avec succès')),
        );
        Navigator.pop(context, true);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la suppression: $e')),
        );
      }
    }
  }

  Widget _buildStatusChip(String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  String _getCycleTypeLabel(CureType type) {
    switch (type) {
      case CureType.Chemotherapy:
        return 'Chimiothérapie';
      case CureType.Immunotherapy:
        return 'Immunothérapie';
      case CureType.Hormonotherapy:
        return 'Hormonothérapie';
      case CureType.Combined:
        return 'Traitement combiné';
    }
  }
}
