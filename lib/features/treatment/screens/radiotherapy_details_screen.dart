// lib/features/treatment/screens/radiotherapy_details_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:suivi_cancer/features/treatment/models/radiotherapy.dart';
import 'package:suivi_cancer/core/storage/database_helper.dart';
import 'package:suivi_cancer/common/widgets/confirmation_dialog_new.dart';
import 'package:suivi_cancer/features/sideeffect/add_side_effect_screen.dart';

class RadiotherapyDetailsScreen extends StatefulWidget {
  final Radiotherapy radiotherapy;

  const RadiotherapyDetailsScreen({super.key, required this.radiotherapy});

  @override
  _RadiotherapyDetailsScreenState createState() =>
      _RadiotherapyDetailsScreenState();
}

class _RadiotherapyDetailsScreenState extends State<RadiotherapyDetailsScreen> {
  final bool _isLoading = false;
  late Radiotherapy _radiotherapy;

  @override
  void initState() {
    super.initState();
    _radiotherapy = widget.radiotherapy;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Détails de la radiothérapie'),
        actions: [
          IconButton(
            icon: Icon(Icons.edit),
            onPressed: () {
              // Navigation vers l'écran de modification de la radiothérapie
              // À implémenter selon vos besoins
            },
          ),
          IconButton(
            icon: Icon(Icons.delete),
            onPressed: _confirmDeleteRadiotherapy,
          ),
        ],
      ),
      body:
          _isLoading
              ? Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildRadiotherapyInfoCard(),
                    SizedBox(height: 24),
                    _buildSessionsSection(),
                    SizedBox(height: 24),
                    _buildDocumentationSection(),
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
              builder:
                  (context) => AddSideEffectScreen(
                    entityType: 'radiotherapy',
                    entityId: _radiotherapy.id,
                    entityName: _radiotherapy.title,
                  ),
            ),
          );
        },
        tooltip: 'Ajouter un effet secondaire',
        child: Icon(Icons.add),
      ),
    );
  }

  Widget _buildRadiotherapyInfoCard() {
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
                  'Informations de la radiothérapie',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                _buildStatusChip(
                  _radiotherapy.isCompleted ? 'Terminé' : 'En cours',
                  _radiotherapy.isCompleted ? Colors.green : Colors.purple,
                ),
              ],
            ),
            SizedBox(height: 16),
            _buildInfoRow('Titre', _radiotherapy.title),
            _buildInfoRow(
              'Début',
              DateFormat('dd/MM/yyyy').format(_radiotherapy.startDate),
            ),
            _buildInfoRow(
              'Fin',
              DateFormat('dd/MM/yyyy').format(_radiotherapy.endDate),
            ),
            _buildInfoRow(
              'Nombre de séances',
              _radiotherapy.sessionCount.toString(),
            ),
            _buildInfoRow('Établissement', _radiotherapy.establishment.name),
            if (_radiotherapy.ps.isNotEmpty)
              _buildInfoRow(
                'Médecins',
                _radiotherapy.ps.map((doc) => doc.fullName).join(', '),
              ),
            if (_radiotherapy.notes != null && _radiotherapy.notes!.isNotEmpty)
              _buildInfoRow('Notes', _radiotherapy.notes!),
            if (_radiotherapy.conclusion != null &&
                _radiotherapy.conclusion!.isNotEmpty)
              _buildInfoRow('Conclusion', _radiotherapy.conclusion!),
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
            width: 140,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: TextStyle(fontWeight: FontWeight.w400)),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Calendrier des séances',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8),
        _radiotherapy.sessions.isEmpty
            ? Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: Text(
                    'Aucune séance programmée',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
              ),
            )
            : ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: _radiotherapy.sessions.length,
              itemBuilder: (context, index) {
                final session = _radiotherapy.sessions[index];
                return Card(
                  margin: EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text('Séance ${index + 1}'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat(
                            'dd/MM/yyyy HH:mm',
                          ).format(session.dateTime),
                        ),
                        if (session.area != null) Text('Zone: ${session.area}'),
                        if (session.dose != null) Text('Dose: ${session.dose}'),
                      ],
                    ),
                    trailing: Icon(
                      session.isCompleted ? Icons.check_circle : Icons.schedule,
                      color: session.isCompleted ? Colors.green : Colors.orange,
                    ),
                    onTap: () {
                      // Afficher les détails de la séance
                    },
                  ),
                );
              },
            ),
      ],
    );
  }

  Widget _buildDocumentationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Documents',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8),
        _radiotherapy.documents.isEmpty
            ? Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: Text(
                    'Aucun document disponible',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
              ),
            )
            : ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: _radiotherapy.documents.length,
              itemBuilder: (context, index) {
                final document = _radiotherapy.documents[index];
                return Card(
                  margin: EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Icon(Icons.description),
                    title: Text(document.name),
                    subtitle: Text(
                      DateFormat('dd/MM/yyyy').format(document.dateAdded),
                    ),
                    onTap: () {
                      // Ouvrir le document
                    },
                  ),
                );
              },
            ),
      ],
    );
  }

  Widget _buildSideEffectsSection() {
    // À implémenter: affichage des effets secondaires liés à la radiothérapie
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Effets secondaires',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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

  Future<void> _confirmDeleteRadiotherapy() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => ConfirmationDialog(
            title: 'Supprimer la radiothérapie',
            content:
                'Êtes-vous sûr de vouloir supprimer cette radiothérapie ? Cette action est irréversible.',
            confirmText: 'Supprimer',
            cancelText: 'Annuler',
            isDestructive: true,
          ),
    );

    if (confirmed == true) {
      try {
        final dbHelper = DatabaseHelper();
        await dbHelper.deleteRadiotherapy(_radiotherapy.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Radiothérapie supprimée avec succès')),
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
}
