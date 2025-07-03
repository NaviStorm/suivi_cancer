import 'dart:io';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:suivi_cancer/core/widgets/common/universal_snack_bar.dart';
import 'package:suivi_cancer/features/treatment/models/examination.dart';
import 'package:suivi_cancer/features/treatment/models/document.dart';
import 'package:suivi_cancer/features/treatment/models/session.dart';
import 'package:suivi_cancer/core/storage/database_helper.dart';
import 'package:suivi_cancer/common/widgets/confirmation_dialog_new.dart';
import 'package:suivi_cancer/features/examinations/screens/add_examination_screen.dart';
import 'package:suivi_cancer/utils/logger.dart';
import 'package:suivi_cancer/utils/fctDate.dart';
import 'package:suivi_cancer/services/document_import_service.dart';

class ExaminationDetailsScreen extends StatefulWidget {
  final Examination examination;
  final String cycleId;
  final List<Session> sessions;

  const ExaminationDetailsScreen({
    super.key,
    required this.examination,
    required this.cycleId,
    required this.sessions,
  });

  @override
  State<ExaminationDetailsScreen> createState() =>
      _ExaminationDetailsScreenState();
}

class _ExaminationDetailsScreenState extends State<ExaminationDetailsScreen> {
  bool _isLoading = false;
  bool _isDeleting = false;
  late Examination _examination;
  List<Document> _documents = [];
  Session? _relatedSession;

  final DatabaseHelper _dbHelper = DatabaseHelper();
  final DocumentImportService _documentService = DocumentImportService();

  @override
  void initState() {
    Log.d('Ecran d\'examen détails initialisé');
    super.initState();
    Log.d('widget.examination n est pas null : [${widget.examination?.toMap()}]');
    _examination = widget.examination;
    _loadData();

    // Trouver la séance associée si cet examen est lié à une séance
    if (_examination.prereqForSessionId != null) {
      _relatedSession =
          widget.sessions
              .where((s) => s.id == _examination.prereqForSessionId)
              .firstOrNull;
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Charger les documents de l'examen
      final documentMaps = await _dbHelper.getDocumentsByEntity(
        'examination',
        _examination.id,
      );
      _documents = documentMaps.map((map) => Document.fromMap(map)).toList();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      Log.e("Erreur lors du chargement des documents: $e");
      _showErrorMessage("Impossible de charger les documents");
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Détails de l\'examen'),
        actions: [
          IconButton(
            icon: Icon(Icons.edit),
            onPressed: _navigateToEditExamination,
          ),
          IconButton(
            icon: Icon(Icons.delete),
            onPressed: _confirmDeleteExamination,
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
                    _buildExaminationCard(),
                    SizedBox(height: 24),
                    _buildDocumentsSection(),
                    SizedBox(height: 16),
                    if (_relatedSession != null) _buildRelatedSessionSection(),
                  ],
                ),
              ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Ajouter un document',
        onPressed: _showAddDocumentDialog,
        child: Icon(Icons.add),
      ),
    );
  }

  Widget _buildExaminationCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getExaminationIcon(_examination.type),
                    color: Colors.red,
                    size: 32,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _examination.title ?? _examination.typeLabel,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color:
                              _examination.isCompleted
                                  ? Colors.green.withOpacity(0.1)
                                  : Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color:
                                _examination.isCompleted
                                    ? Colors.green.withOpacity(0.5)
                                    : Colors.blue.withOpacity(0.5),
                          ),
                        ),
                        child: Text(
                          _examination.isCompleted ? 'Terminé' : 'À venir',
                          style: TextStyle(
                            color:
                                _examination.isCompleted
                                    ? Colors.green
                                    : Colors.blue,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Divider(height: 32),
            _buildInfoRow(
              Icons.calendar_today,
              'Date: ${DateFormat(getFmtDate()).format(_examination.dateTime)}',
            ),
            SizedBox(height: 8),
            _buildInfoRow(
              Icons.access_time,
              'Heure: ${DateFormat(getFmtTime()).format(_examination.dateTime)}',
            ),
            SizedBox(height: 8),
            _buildInfoRow(
              Icons.business,
              'Établissement: ${_examination.establishment.name}',
            ),
            if (_examination.prescripteur != null) ...[
              SizedBox(height: 8),
              _buildInfoRow(
                Icons.person,
                'Médecin: ${_examination.prescripteur!.fullName}',
              ),
            ],
            if (_examination.prereqForSessionId != null) ...[
              SizedBox(height: 8),
              _buildInfoRow(
                Icons.event_available,
                _getSessionTimeRelationLabel(),
              ),
            ],
            if (_examination.notes != null &&
                _examination.notes!.isNotEmpty) ...[
              Divider(height: 32),
              Text(
                'Notes:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              SizedBox(height: 8),
              Text(_examination.notes!, style: TextStyle(fontSize: 14)),
            ],
            Divider(height: 32),
            Center(
              child: OutlinedButton.icon(
                icon: Icon(
                  _examination.isCompleted ? Icons.close : Icons.check,
                  size: 18,
                ),
                label: Text(
                  _examination.isCompleted
                      ? 'Marquer comme non terminé'
                      : 'Marquer comme terminé',
                ),
                onPressed: _toggleExaminationCompleted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Documents',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            TextButton.icon(
              icon: Icon(Icons.add, size: 16),
              label: Text('Ajouter', style: TextStyle(fontSize: 12)),
              onPressed: _showAddDocumentDialog,
            ),
          ],
        ),
        SizedBox(height: 8),
        if (_documents.isEmpty)
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.folder_open, color: Colors.grey[400], size: 48),
                    SizedBox(height: 16),
                    Text(
                      'Aucun document attaché',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Ajoutez des documents à cet examen pour les retrouver facilement',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: _documents.length,
            itemBuilder: (context, index) {
              final document = _documents[index];
              return _buildDocumentCard(document);
            },
          ),
      ],
    );
  }

  Widget _buildRelatedSessionSection() {
    if (_relatedSession == null) return SizedBox.shrink();

    final sessionDate = DateFormat(
      getFmtDate(),
    ).format(_relatedSession!.dateTime);
    final sessionTime = DateFormat(
      getFmtTime(),
    ).format(_relatedSession!.dateTime);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Séance associée',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: Icon(Icons.event, color: Colors.blue),
            title: Text('Séance du $sessionDate'),
            subtitle: Text(
              'à $sessionTime - ${_relatedSession!.establishment.name}',
            ),
            trailing: Icon(Icons.chevron_right),
            onTap: () => _navigateToSessionDetails(_relatedSession!),
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentCard(Document document) {
    IconData documentIcon;
    Color iconColor;

    switch (document.type) {
      case DocumentType.PDF:
        documentIcon = Icons.picture_as_pdf;
        iconColor = Colors.red;
        break;
      case DocumentType.Image:
        documentIcon = Icons.image;
        iconColor = Colors.blue;
        break;
      case DocumentType.Text:
        documentIcon = Icons.description;
        iconColor = Colors.green;
        break;
      case DocumentType.Word:
        documentIcon = Icons.article;
        iconColor = Colors.indigo;
        break;
      case DocumentType.Other:
      default:
        documentIcon = Icons.insert_drive_file;
        iconColor = Colors.grey;
        break;
    }

    return Card(
      margin: EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(documentIcon, size: 24, color: iconColor),
        ),
        title: Text(
          (document.description != null && document.description!.trim().isNotEmpty ) ? document.description! : document.name,
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ajouté le ${DateFormat(getFmtDate()).format(document.dateAdded)}',
              style: TextStyle(fontSize: 12),
            ),
            if (document.description != null &&
                document.description!.isNotEmpty)
              Text(
                document.name,
                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.visibility, size: 20),
              onPressed: () => _viewDocument(document),
              tooltip: 'Voir',
            ),
            IconButton(
              icon: Icon(Icons.delete, size: 20, color: Colors.red),
              onPressed: () => _confirmRemoveDocument(document),
              tooltip: 'Supprimer',
            ),
          ],
        ),
        onTap: () => _viewDocument(document),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey[700]),
        SizedBox(width: 12),
        Expanded(child: Text(text, style: TextStyle(fontSize: 14))),
      ],
    );
  }

  String _getSessionTimeRelationLabel() {
    if (_examination.prereqForSessionId != null && _relatedSession != null) {
      if (_examination.dateTime.isBefore(_relatedSession!.dateTime)) {
        return 'Prérequis pour la séance du ${DateFormat(getFmtDate()).format(_relatedSession!.dateTime)}';
      } else {
        return 'Suivi de la séance du ${DateFormat(getFmtDate()).format(_relatedSession!.dateTime)}';
      }
    }
    return 'Associé à une séance';
  }

  IconData _getExaminationIcon(ExaminationType type) {
    switch (type) {
      case ExaminationType.Consult:
        return Icons.medical_services;
      case ExaminationType.IRM:
        return Icons.medical_information;
      case ExaminationType.PETScan:
        return Icons.biotech;
      case ExaminationType.Scanner:
        return Icons.panorama_horizontal;
      case ExaminationType.Radio:
        return Icons.photo;
      case ExaminationType.Injection:
        return Icons.vaccines;
      case ExaminationType.PriseDeSang:
        return Icons.bloodtype;
      case ExaminationType.Echographie:
        return Icons.waves;
      case ExaminationType.EpreuveEffort:
        return Icons.directions_run;
      case ExaminationType.EFR:
        return Icons.air;
      case ExaminationType.Soin:
        return Icons.health_and_safety;
      case ExaminationType.Autre:
        return Icons.science;
    }
  }

  void _navigateToEditExamination() async {
    // Vérifier si l'examen fait partie d'un groupe (lié à toutes les séances)
    if (_examination.examGroupId != null) {
      // Afficher un dialogue pour demander si la modification concerne toutes les occurrences
      final choice = await showDialog<String>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: Text('Modifier l\'examen'),
              content: Text(
                'Cet examen fait partie d\'un groupe d\'examens liés à toutes les séances du cycle. '
                'Souhaitez-vous modifier uniquement cet examen ou tous les examens similaires ?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, 'single'),
                  child: Text('Cet examen uniquement'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, 'all'),
                  child: Text('Tous les examens'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Annuler'),
                ),
              ],
            ),
      );

      if (choice == null) {
        // L'utilisateur a annulé
        return;
      }

      if (choice == 'single') {
        // Pour un examen unique, on ne change pas l'ID mais on supprime juste le groupId
        // pour le détacher du groupe
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => AddExaminationScreen(
                  cycleId: widget.cycleId,
                  examination: _examination,
                  detachFromGroup:
                      true, // Nouveau flag pour indiquer qu'on détache du groupe
                ),
          ),
        );

        if (result == true) {
          // Rechargement des données
          _reloadExamination();
        }
      } else {
        // Pour tous les examens du groupe
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => AddExaminationScreen(
                  cycleId: widget.cycleId,
                  examination: _examination,
                  forAllSessions:
                      true, // Indiquer que c'est pour tous les examens du groupe
                ),
          ),
        );

        if (result == true) {
          // Rechargement des données et retour à l'écran précédent
          // car l'examen actuel pourrait avoir été modifié en profondeur
          Navigator.pop(context, true);
        }
      }
    } else {
      // Examen normal (non groupé) - cas simple
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => AddExaminationScreen(
                cycleId: widget.cycleId,
                examination: _examination,
              ),
        ),
      );

      if (result == true) {
        // Rechargement des données
        _reloadExamination();
      }
    }
  }

  Future<void> _reloadExamination() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Recharger l'examen depuis la base de données
      final dbHelper = DatabaseHelper();

      // Ajouter des logs pour déboguer
      Log.d("Rechargement de l'examen avec ID: ${_examination.id}");

      final examinationMap = await dbHelper.getExamination(_examination.id);
      if (examinationMap != null) {
        setState(() {
          _examination = Examination.fromMap(examinationMap);
        });

        Log.d("Examen rechargé avec succès: ${_examination.id}");
      } else {
        Log.e("Impossible de trouver l'examen avec ID: ${_examination.id}");
        _showErrorMessage("Impossible de trouver l'examen");
      }

      // Recharger les documents explicitement
      Log.d("Chargement des documents pour l'examen: ${_examination.id}");
      final documentMaps = await dbHelper.getDocumentsByEntity(
        'examination',
        _examination.id,
      );
      Log.d("Nombre de documents trouvés: ${documentMaps.length}");

      setState(() {
        _documents = documentMaps.map((map) => Document.fromMap(map)).toList();
      });

      // Si l'examen est associé à une séance, recharger la séance également
      if (_examination.prereqForSessionId != null) {
        _relatedSession =
            widget.sessions
                .where((s) => s.id == _examination.prereqForSessionId)
                .firstOrNull;
      }
    } catch (e) {
      Log.e("Erreur lors du rechargement de l'examen: $e");
      _showErrorMessage("Impossible de recharger les données");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleExaminationCompleted() async {
    try {
      // Inverser l'état de complétion
      final bool newCompletionState = !_examination.isCompleted;

      // Mettre à jour dans la base de données
      await _dbHelper.updateExaminationCompletionStatus(
        _examination.id,
        newCompletionState,
      );

      // Mettre à jour l'UI
      setState(() {
        _examination = _examination.copyWith(isCompleted: newCompletionState);
      });

      // Afficher un message de confirmation
      _showMessage(
        newCompletionState
            ? 'Examen marqué comme terminé'
            : 'Examen marqué comme non terminé',
      );
    } catch (e) {
      Log.e("Erreur lors de la mise à jour de l'état de l'examen: $e");
      _showErrorMessage("Une erreur est survenue lors de la mise à jour");
    }
  }

  Future<void> _confirmDeleteExamination() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => ConfirmationDialog(
            title: 'Supprimer l\'examen',
            content:
                'Êtes-vous sûr de vouloir supprimer cet examen et tous les documents associés ? Cette action est irréversible.',
            confirmText: 'Supprimer',
            cancelText: 'Annuler',
            isDestructive: true,
          ),
    );

    if (confirmed == true) {
      setState(() {
        _isDeleting = true;
      });

      try {
        await _dbHelper.deleteExamination(_examination.id);
        _showMessage('Examen supprimé avec succès');
        Navigator.pop(
          context,
          true,
        ); // Retourner true pour indiquer que l'examen a été supprimé
      } catch (e) {
        Log.e("Erreur lors de la suppression de l'examen: $e");
        _showErrorMessage("Impossible de supprimer l'examen");
      } finally {
        setState(() {
          _isDeleting = false;
        });
      }
    }
  }

  void _showAddDocumentDialog() async {
    final action = await _documentService.showAddDocumentDialog(context);

    if (action == null) return;

    Document? document;
    if (action == 'camera') {
      document = await _documentService.takePicture(context);
    } else if (action == 'gallery') {
      document = await _documentService.pickImage(context);
    } else if (action == 'file') {
      document = await _documentService.pickFile(context);
    }

    if (document != null) {
      Log.d('document:[${document.path}]');
      // Lier le document à l'examen
      final dbHelper = DatabaseHelper();
      final docResult = await dbHelper.insertDocument(document.toMap());
      if (docResult > 0) {
        final linkResult = await dbHelper.linkDocumentToEntity(
          'examination',
          _examination.id,
          document.id,
        );
        if (linkResult > 0) {
          await _loadData(); // Recharger les documents
        }
      }
    }
  }

  void _viewDocument(Document document) {
    _documentService.viewDocument(context, document);
  }

  Future<void> _confirmRemoveDocument(Document document) async {
    final confirmed = await showDialog(
      context: context,
      builder:
          (context) => ConfirmationDialog(
            title: 'Supprimer le document',
            content:
                'Êtes-vous sûr de vouloir supprimer ce document de l\'examen ? Cette action est irréversible.',
            confirmText: 'Supprimer',
            cancelText: 'Annuler',
            isDestructive: true,
          ),
    );

    if (confirmed == true) {
      try {
        // 1. Supprimer le lien entre le document et l'examen
        await _dbHelper.unlinkDocumentFromEntity(
          'examination',
          _examination.id,
          document.id,
        );

        // 2. Vérifier si le document est lié à d'autres entités
        final linkedEntities = await _dbHelper.getEntitiesLinkedToDocument(
          document.id,
        );

        // Si le document n'est lié à aucune autre entité, le supprimer complètement
        if (linkedEntities.isEmpty) {
          // 3. Supprimer le fichier du disque
          final absolutePath = await _documentService.getAbsolutePath(
            document.path,
          );
          final file = File(absolutePath);
          if (await file.exists()) {
            await file.delete();
          }

          // 4. Supprimer l'entrée du document dans la base de données
          await _dbHelper.deleteDocument(document.id);

          _showMessage('Document supprimé définitivement');
        } else {
          _showMessage('Document détaché de cet examen');
        }

        // 5. Recharger les documents
        await _loadData();
      } catch (e) {
        Log.e("Erreur lors de la suppression du document: $e");
        _showErrorMessage("Impossible de supprimer le document");
      }
    }
  }

  void _navigateToSessionDetails(Session session) {
    // TODO: Implémentation de la navigation vers les détails de la séance
    _showMessage("Cette fonctionnalité sera disponible prochainement");
  }

  void _showMessage(String message) {
    UniversalSnackBar.show(context, title: message);
  }

  void _showErrorMessage(String message) {
    UniversalSnackBar.show(context, title: 'Erreur', message: message);
  }
}
