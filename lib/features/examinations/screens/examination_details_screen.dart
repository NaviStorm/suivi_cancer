import 'dart:io';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';
import 'package:flutter/cupertino.dart';
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
    _examination = widget.examination;
    _loadDocuments();

    if (_examination.prereqForSessionId != null) {
      _relatedSession = widget.sessions
          .firstWhereOrNull((s) => s.id == _examination.prereqForSessionId);
    }
  }

  Future<void> _loadDocuments() async {
    setState(() => _isLoading = true);
    try {
      final documentMaps =
      await _dbHelper.getDocumentsByEntity('examination', _examination.id);
      if (mounted) {
        setState(() {
          _documents =
              documentMaps.map((map) => Document.fromMap(map)).toList();
        });
      }
    } catch (e) {
      Log.e("Erreur lors du chargement des documents: $e");
      _showErrorMessage("Impossible de charger les documents");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text('Détails de l\'examen'),
        trailing: _isDeleting
            ? CupertinoActivityIndicator()
            : Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              child: Icon(CupertinoIcons.pencil),
              onPressed: _navigateToEditExamination,
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              child: Icon(CupertinoIcons.trash,
                  color: CupertinoColors.destructiveRed),
              onPressed: _confirmDeleteExamination,
            ),
          ],
        ),
      ),
      child: SafeArea(
        child: _isLoading
            ? Center(child: CupertinoActivityIndicator())
            : ListView(
          padding: EdgeInsets.symmetric(vertical: 8),
          children: [
            _buildExaminationCard(),
            if (_documents.isNotEmpty) ...[
              SizedBox(height: 8),
              _buildDocumentsSection(),
            ],
            if (_documents.isEmpty) ...[
              SizedBox(height: 8),
              _buildEmptyDocumentsSection(),
            ],
            if (_relatedSession != null) ...[
              SizedBox(height: 8),
              _buildRelatedSessionSection(),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildExaminationCard() {
    return CupertinoListSection.insetGrouped(
      header: Text(
        _examination.title ?? _examination.typeLabel,
        style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: CupertinoColors.label.resolveFrom(context)),
      ),
      children: [
        CupertinoListTile(
          title: Text('Statut'),
          trailing: Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _examination.isCompleted
                  ? CupertinoColors.systemGreen.withOpacity(0.2)
                  : CupertinoColors.systemBlue.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _examination.isCompleted ? 'Terminé' : 'À venir',
              style: TextStyle(
                color: _examination.isCompleted
                    ? CupertinoColors.systemGreen
                    : CupertinoColors.systemBlue,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          leading: Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: CupertinoColors.systemRed.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getExaminationIcon(_examination.type),
              color: CupertinoColors.systemRed,
            ),
          ),
        ),
        _buildInfoTile(CupertinoIcons.calendar,
            'Date: ${DateFormat(getFmtDate()).format(_examination.dateTime)}'),
        _buildInfoTile(CupertinoIcons.clock,
            'Heure: ${DateFormat(getFmtTime()).format(_examination.dateTime)}'),
        _buildInfoTile(CupertinoIcons.building_2_fill,
            'Établissement: ${_examination.establishment.name}'),
        if (_examination.prescripteur != null)
          _buildInfoTile(CupertinoIcons.person_fill,
              'Médecin: ${_examination.prescripteur!.fullName}'),
        if (_examination.prereqForSessionId != null)
          _buildInfoTile(
              CupertinoIcons.checkmark_seal, _getSessionTimeRelationLabel()),
        if (_examination.notes != null && _examination.notes!.isNotEmpty)
          CupertinoListTile(
            title: Text("Notes"),
            subtitle: Text(_examination.notes!),
          ),
        CupertinoListTile(
          title: Center(
            child: CupertinoButton(
              onPressed: _toggleExaminationCompleted,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _examination.isCompleted
                        ? CupertinoIcons.xmark_circle
                        : CupertinoIcons.check_mark_circled,
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Text(_examination.isCompleted
                      ? 'Marquer non terminé'
                      : 'Marquer comme terminé'),
                ],
              ),
            ),
          ),
        )
      ],
    );
  }

  Widget _buildDocumentsSection() {
    return CupertinoListSection.insetGrouped(
      header: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Documents'),
          CupertinoButton(
            padding: EdgeInsets.zero,
            child: Row(
              children: [
                Icon(CupertinoIcons.add, size: 16),
                SizedBox(width: 4),
                Text('Ajouter', style: TextStyle(fontSize: 12)),
              ],
            ),
            onPressed: _showAddDocumentDialog,
          ),
        ],
      ),
      children: _documents.map((doc) => _buildDocumentTile(doc)).toList(),
    );
  }

  Widget _buildEmptyDocumentsSection() {
    return CupertinoListSection.insetGrouped(
      header: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Documents'),
          CupertinoButton(
            padding: EdgeInsets.zero,
            child: Row(
              children: [
                Icon(CupertinoIcons.add, size: 16),
                SizedBox(width: 4),
                Text('Ajouter', style: TextStyle(fontSize: 12)),
              ],
            ),
            onPressed: _showAddDocumentDialog,
          ),
        ],
      ),
      children: [
        Container(
          padding: EdgeInsets.all(16),
          child: Center(
            child: Column(
              children: [
                Icon(CupertinoIcons.folder_open,
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                    size: 48),
                SizedBox(height: 16),
                Text(
                  'Aucun document attaché',
                  style: TextStyle(
                      color:
                      CupertinoColors.secondaryLabel.resolveFrom(context)),
                ),
                SizedBox(height: 8),
                Text(
                  'Ajoutez des documents à cet examen pour les retrouver facilement',
                  style: TextStyle(
                      color:
                      CupertinoColors.secondaryLabel.resolveFrom(context),
                      fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRelatedSessionSection() {
    if (_relatedSession == null) return SizedBox.shrink();

    final sessionDate = DateFormat(getFmtDate()).format(_relatedSession!.dateTime);
    final sessionTime = DateFormat(getFmtTime()).format(_relatedSession!.dateTime);

    return CupertinoListSection.insetGrouped(
      header: Text('Séance associée'),
      children: [
        CupertinoListTile(
          leading: Icon(CupertinoIcons.calendar_today, color: CupertinoColors.systemBlue),
          title: Text('Séance du $sessionDate'),
          subtitle:
          Text('à $sessionTime - ${_relatedSession!.establishment.name}'),
          trailing: Icon(CupertinoIcons.right_chevron),
          onTap: () => _navigateToSessionDetails(_relatedSession!),
        ),
      ],
    );
  }

  CupertinoListTile _buildDocumentTile(Document document) {
    IconData documentIcon;
    Color iconColor;

    switch (document.type) {
      case DocumentType.PDF:
        documentIcon = CupertinoIcons.doc_chart;
        iconColor = CupertinoColors.systemRed;
        break;
      case DocumentType.Image:
        documentIcon = CupertinoIcons.photo;
        iconColor = CupertinoColors.systemBlue;
        break;
      case DocumentType.Text:
        documentIcon = CupertinoIcons.doc_text;
        iconColor = CupertinoColors.systemGreen;
        break;
      case DocumentType.Word:
        documentIcon = CupertinoIcons.doc_richtext;
        iconColor = CupertinoColors.systemIndigo;
        break;
      default:
        documentIcon = CupertinoIcons.doc;
        iconColor = CupertinoColors.secondaryLabel;
        break;
    }

    bool hasDescription = document.description != null && document.description!.trim().isNotEmpty;

    return CupertinoListTile.notched(
      onTap: () => _viewDocument(document),
      leading: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(documentIcon, size: 24, color: iconColor),
      ),
      title: Text(
        hasDescription ? document.description! : document.name,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ajouté le ${DateFormat(getFmtDate()).format(document.dateAdded)}',
            style: TextStyle(fontSize: 12, color: CupertinoColors.secondaryLabel),
          ),
          if (hasDescription)
            Padding(
              padding: const EdgeInsets.only(top: 2.0),
              child: Text(
                document.name, // Nom du fichier
                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: CupertinoColors.secondaryLabel),
              ),
            ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CupertinoButton(
            padding: EdgeInsets.all(4),
            child: Icon(CupertinoIcons.pencil, size: 20),
            onPressed: () => _showEditDocumentDescriptionDialog(document),
          ),
          CupertinoButton(
            padding: EdgeInsets.all(4),
            child: Icon(CupertinoIcons.trash,
                size: 20, color: CupertinoColors.destructiveRed),
            onPressed: () => _confirmRemoveDocument(document),
          ),
        ],
      ),
    );
  }

  CupertinoListTile _buildInfoTile(IconData icon, String text) {
    return CupertinoListTile(
      leading: Icon(icon, color: CupertinoColors.secondaryLabel),
      title: Text(text, style: TextStyle(fontSize: 14)),
    );
  }

  String _getSessionTimeRelationLabel() {
    if (_relatedSession != null) {
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
      case ExaminationType.Consult: return CupertinoIcons.person_2_fill;
      case ExaminationType.IRM: return CupertinoIcons.doc_text_search;
      case ExaminationType.PETScan: return CupertinoIcons.dot_radiowaves_left_right;
      case ExaminationType.Scanner: return CupertinoIcons.pano;
      case ExaminationType.Radio: return CupertinoIcons.photo_camera;
      case ExaminationType.Injection: return CupertinoIcons.lab_flask;
      case ExaminationType.PriseDeSang: return CupertinoIcons.drop;
      case ExaminationType.Echographie: return CupertinoIcons.waveform;
      case ExaminationType.EpreuveEffort: return CupertinoIcons.heart_fill;
      case ExaminationType.EFR: return CupertinoIcons.wind;
      case ExaminationType.Soin: return CupertinoIcons.bandage_fill;
      case ExaminationType.Autre: return CupertinoIcons.question_circle;
    }
  }

  void _navigateToEditExamination() async {
    if (_examination.examGroupId != null) {
      final choice = await showCupertinoDialog<String>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: Text('Modifier l\'examen'),
          content: Text(
              'Cet examen est lié à plusieurs séances. Voulez-vous modifier uniquement cet examen ou tous les examens similaires ?'),
          actions: [
            CupertinoDialogAction(
              child: Text('Cet examen seulement'),
              onPressed: () => Navigator.pop(context, 'single'),
            ),
            CupertinoDialogAction(
              child: Text('Tous les examens'),
              onPressed: () => Navigator.pop(context, 'all'),
            ),
            CupertinoDialogAction(
              child: Text('Annuler'),
              isDefaultAction: true,
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );

      if (choice == null) return;

      bool detach = (choice == 'single');
      final result = await Navigator.push(
        context,
        CupertinoPageRoute(
          builder: (context) => AddExaminationScreen(
            cycleId: widget.cycleId,
            examination: _examination,
            detachFromGroup: detach,
            forAllSessions: !detach,
          ),
        ),
      );

      if (result == true) {
        if(choice == 'single') {
          _reloadExamination();
        } else {
          Navigator.pop(context, true);
        }
      }
    } else {
      final result = await Navigator.push(
        context,
        CupertinoPageRoute(
          builder: (context) => AddExaminationScreen(
            cycleId: widget.cycleId,
            examination: _examination,
          ),
        ),
      );

      if (result == true) {
        _reloadExamination();
      }
    }
  }

  Future<void> _reloadExamination() async {
    setState(() => _isLoading = true);
    try {
      Log.d("Rechargement de l'examen avec ID: ${_examination.id}");

      // 1. Récupérer la ligne brute de l'examen
      final rawExamMap = await _dbHelper.getRawDataById('examinations', _examination.id);
      if (rawExamMap == null) {
        throw Exception("Examen non trouvé");
      }

      // 2. Récupérer les objets liés
      final establishmentMap = await _dbHelper.getRawDataById('establishments', rawExamMap['establishmentId']);
      final prescripteurMap = rawExamMap['prescripteurId'] != null ? await _dbHelper.getRawDataById('health_professionals', rawExamMap['prescripteurId']) : null;
      final executantMap = rawExamMap['executantId'] != null ? await _dbHelper.getRawDataById('health_professionals', rawExamMap['executantId']) : null;

      // 3. Construire la carte imbriquée attendue par le factory
      final completeExamMap = Map<String, dynamic>.from(rawExamMap);
      completeExamMap['establishment'] = establishmentMap;
      completeExamMap['prescripteur'] = prescripteurMap;
      completeExamMap['executant'] = executantMap;

      if (mounted) {
        setState(() {
          // 4. Créer l'objet Examination complet
          _examination = Examination.fromMap(completeExamMap);
        });
        Log.d("Examen rechargé avec succès: ${_examination.id}");
        await _loadDocuments(); // Recharger aussi les documents
      }
    } catch (e) {
      Log.e("Erreur lors du rechargement de l'examen: $e");
      if(mounted) _showErrorMessage("Impossible de recharger les données");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleExaminationCompleted() async {
    try {
      final newCompletionState = !_examination.isCompleted;
      await _dbHelper.updateExaminationCompletionStatus(_examination.id, newCompletionState);
      if (mounted) {
        setState(() => _examination = _examination.copyWith(isCompleted: newCompletionState));
        _showMessage(newCompletionState ? 'Examen marqué comme terminé' : 'Examen marqué comme non terminé');
      }
    } catch (e) {
      Log.e("Erreur lors de la mise à jour de l'état de l'examen: $e");
      _showErrorMessage("Une erreur est survenue lors de la mise à jour");
    }
  }

  Future<void> _confirmDeleteExamination() async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('Supprimer l\'examen'),
        content: Text('Êtes-vous sûr de vouloir supprimer cet examen et ses documents ? Cette action est irréversible.'),
        actions: [
          CupertinoDialogAction(
            child: Text('Annuler'),
            onPressed: () => Navigator.pop(context, false),
          ),
          CupertinoDialogAction(
            child: Text('Supprimer'),
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isDeleting = true);
      try {
        await _dbHelper.deleteExamination(_examination.id);
        if (mounted) {
          _showMessage('Examen supprimé avec succès');
          Navigator.pop(context, true);
        }
      } catch (e) {
        Log.e("Erreur lors de la suppression de l'examen: $e");
        if(mounted) _showErrorMessage("Impossible de supprimer l'examen");
      } finally {
        if (mounted) setState(() => _isDeleting = false);
      }
    }
  }

  void _showAddDocumentDialog() async {
    final action = await showCupertinoModalPopup<String>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Ajouter un document'),
        actions: <CupertinoActionSheetAction>[
          CupertinoActionSheetAction(
            child: const Text('Prendre une photo'),
            onPressed: () => Navigator.pop(context, 'camera'),
          ),
          CupertinoActionSheetAction(
            child: const Text('Choisir une image'),
            onPressed: () => Navigator.pop(context, 'gallery'),
          ),
          CupertinoActionSheetAction(
            child: const Text('Choisir un fichier'),
            onPressed: () => Navigator.pop(context, 'file'),
          )
        ],
        cancelButton: CupertinoActionSheetAction(
          child: const Text('Annuler'),
          isDefaultAction: true,
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );

    if (action == null || !mounted) return;

    Document? document;
    if (action == 'camera') {
      document = await _documentService.takePicture(context);
    } else if (action == 'gallery') {
      document = await _documentService.pickImage(context);
    } else if (action == 'file') {
      document = await _documentService.pickFile(context);
    }

    if (document != null) {
      final docResult = await _dbHelper.insertDocument(document.toMap());
      if (docResult > 0) {
        final linkResult = await _dbHelper.linkDocumentToEntity('examination', _examination.id, document.id);
        if (linkResult > 0) {
          await _loadDocuments();
        }
      }
    }
  }

  void _viewDocument(Document document) {
    _documentService.viewDocument(context, document);
  }

  Future<void> _showEditDocumentDescriptionDialog(Document document) async {
    final controller = TextEditingController(text: document.description);
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('Modifier la description'),
        content: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: CupertinoTextField(
            controller: controller,
            placeholder: 'Description du document',
            autofocus: true,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: Text('Annuler'),
            onPressed: () => Navigator.pop(context, false),
          ),
          CupertinoDialogAction(
            child: Text('Enregistrer'),
            isDefaultAction: true,
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _dbHelper.updateDocumentDescription(document.id, controller.text.trim());
        _showMessage('Description mise à jour');
        await _loadDocuments();
      } catch (e) {
        Log.e("Erreur lors de la mise à jour de la description: $e");
        _showErrorMessage("Impossible de mettre à jour la description");
      }
    }
  }

  Future<void> _confirmRemoveDocument(Document document) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('Supprimer le document'),
        content: Text('Voulez-vous supprimer ce document de l\'examen ?'),
        actions: [
          CupertinoDialogAction(child: Text('Annuler'), onPressed: () => Navigator.pop(context, false)),
          CupertinoDialogAction(child: Text('Supprimer'), isDestructiveAction: true, onPressed: () => Navigator.pop(context, true)),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _dbHelper.unlinkDocumentFromEntity('examination', _examination.id, document.id);
        final linkedEntities = await _dbHelper.getEntitiesLinkedToDocument(document.id);

        if (linkedEntities.isEmpty) {
          final absolutePath = await _documentService.getAbsolutePath(document.path);
          final file = File(absolutePath);
          if (await file.exists()) {
            await file.delete();
          }
          await _dbHelper.deleteDocument(document.id);
          _showMessage('Document supprimé définitivement');
        } else {
          _showMessage('Document détaché de cet examen');
        }
        await _loadDocuments();
      } catch (e) {
        Log.e("Erreur lors de la suppression du document: $e");
        _showErrorMessage("Impossible de supprimer le document");
      }
    }
  }

  void _navigateToSessionDetails(Session session) {
    _showMessage("Cette fonctionnalité sera disponible prochainement");
  }

  void _showCupertinoAlert(String title, {String? content}) {
    if (!mounted) return;
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(title),
        content: content != null ? Text(content) : null,
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            isDefaultAction: true,
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  void _showMessage(String message) {
    UniversalSnackBar.show(context, title: message);
  }

  void _showErrorMessage(String message) {
    UniversalSnackBar.show(context, title: message);
  }
}
