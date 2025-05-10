// lib/features/treatment/screens/surgery_details_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:suivi_cancer/features/treatment/models/surgery.dart';
import 'package:suivi_cancer/features/treatment/models/document.dart';
import 'package:suivi_cancer/core/storage/database_helper.dart';
import 'package:suivi_cancer/common/widgets/confirmation_dialog_new.dart';
import 'package:suivi_cancer/features/treatment/screens/add_side_effect_screen.dart';

class SurgeryDetailsScreen extends StatefulWidget {
  final Surgery surgery;

  const SurgeryDetailsScreen({Key? key, required this.surgery}) : super(key: key);

  @override
  _SurgeryDetailsScreenState createState() => _SurgeryDetailsScreenState();
}

class _SurgeryDetailsScreenState extends State<SurgeryDetailsScreen> {
  bool _isLoading = false;
  late Surgery _surgery;

  @override
  void initState() {
    super.initState();
    _surgery = widget.surgery;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Détails de l\'opération'),
        actions: [
          IconButton(
            icon: Icon(Icons.edit),
            onPressed: () {
              // Navigation vers l'écran de modification de la chirurgie
              // À implémenter selon vos besoins
            },
          ),
          IconButton(
            icon: Icon(Icons.delete),
            onPressed: _confirmDeleteSurgery,
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
            _buildSurgeryInfoCard(),
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
              builder: (context) => AddSideEffectScreen(
                entityType: 'surgery',
                entityId: _surgery.id,
                entityName: _surgery.title, // Utiliser title au lieu de type
              ),
            ),
          );
        },
        child: Icon(Icons.add),
        tooltip: 'Ajouter un effet secondaire',
      ),
    );
  }

  Widget _buildSurgeryInfoCard() {
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
                  'Informations de l\'opération',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                _buildStatusChip(
                  _surgery.isCompleted ? 'Terminé' : 'Planifié',
                  _surgery.isCompleted ? Colors.green : Colors.orange,
                ),
              ],
            ),
            SizedBox(height: 16),
            _buildInfoRow('Type d\'opération', _surgery.title), // Utiliser title au lieu de type
            _buildInfoRow('Date', DateFormat('dd/MM/yyyy').format(_surgery.date)),
            _buildInfoRow('Établissement', _surgery.establishment.name),
            if (_surgery.surgeons.isNotEmpty)
              _buildInfoRow('Chirurgien(s)', _surgery.surgeons.map((doc) => doc.fullName).join(', ')),
            if (_surgery.anesthetists.isNotEmpty)
              _buildInfoRow('Anesthésiste(s)', _surgery.anesthetists.map((doc) => doc.fullName).join(', ')),
            if (_surgery.operationReport != null && _surgery.operationReport!.isNotEmpty)
              _buildInfoRow('Rapport d\'opération', _surgery.operationReport!),
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

  Widget _buildDocumentationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Documents',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 8),
        _surgery.documents.isEmpty
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
          itemCount: _surgery.documents.length,
          itemBuilder: (context, index) {
            final document = _surgery.documents[index];
            return Card(
              margin: EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(Icons.description),
                title: Text(document.name),
                subtitle: Text(DateFormat('dd/MM/yyyy').format(document.dateAdded)),
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
    // À implémenter: affichage des effets secondaires liés à la chirurgie
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

  Future<void> _confirmDeleteSurgery() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => ConfirmationDialog(
        title: 'Supprimer l\'opération',
        content: 'Êtes-vous sûr de vouloir supprimer cette opération ? Cette action est irréversible.',
        confirmText: 'Supprimer',
        cancelText: 'Annuler',
        isDestructive: true,
      ),
    );

    if (confirmed == true) {
      try {
        final dbHelper = DatabaseHelper();
        await dbHelper.deleteSurgery(_surgery.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Opération supprimée avec succès')),
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
