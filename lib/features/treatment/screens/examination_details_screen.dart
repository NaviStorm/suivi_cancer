import 'dart:io';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:share_plus/share_plus.dart';
import 'package:suivi_cancer/features/treatment/models/examination.dart';
import 'package:suivi_cancer/features/treatment/models/document.dart';
import 'package:suivi_cancer/features/treatment/models/session.dart';
import 'package:suivi_cancer/core/storage/database_helper.dart';
import 'package:suivi_cancer/common/widgets/confirmation_dialog_new.dart';
import 'package:suivi_cancer/features/treatment/screens/add_examination_screen.dart';
import 'package:suivi_cancer/utils/logger.dart';

class ExaminationDetailsScreen extends StatefulWidget {
  final Examination examination;
  final String cycleId;
  final List<Session> sessions;

  const ExaminationDetailsScreen({
    Key? key,
    required this.examination,
    required this.cycleId,
    required this.sessions,
  }) : super(key: key);

  @override
  _ExaminationDetailsScreenState createState() => _ExaminationDetailsScreenState();
}

class _ExaminationDetailsScreenState extends State<ExaminationDetailsScreen> {
  bool _isLoading = false;
  bool _isDeleting = false;
  late Examination _examination;
  List<Document> _documents = [];
  Session? _relatedSession;

  final DatabaseHelper _dbHelper = DatabaseHelper();

  @override
  void initState() {
    super.initState();
    _examination = widget.examination;
    _loadData();
    
    // Trouver la séance associée si cet examen est lié à une séance
    if (_examination.prereqForSessionId != null) {
      _relatedSession = widget.sessions.where(
        (s) => s.id == _examination.prereqForSessionId
      ).firstOrNull;
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Charger les documents de l'examen
      final documentMaps = await _dbHelper.getDocumentsByEntity('examination', _examination.id);
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
      body: _isLoading
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
                  if (_relatedSession != null)
                    _buildRelatedSessionSection(),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.add),
        tooltip: 'Ajouter un document',
        onPressed: _showAddDocumentDialog,
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
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _examination.isCompleted 
                              ? Colors.green.withOpacity(0.1) 
                              : Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _examination.isCompleted 
                                ? Colors.green.withOpacity(0.5) 
                                : Colors.blue.withOpacity(0.5),
                          ),
                        ),
                        child: Text(
                          _examination.isCompleted ? 'Terminé' : 'À venir',
                          style: TextStyle(
                            color: _examination.isCompleted ? Colors.green : Colors.blue,
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
              'Date: ${DateFormat('dd/MM/yyyy').format(_examination.dateTime)}',
            ),
            SizedBox(height: 8),
            _buildInfoRow(
              Icons.access_time,
              'Heure: ${DateFormat('HH:mm').format(_examination.dateTime)}',
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
            if (_examination.notes != null && _examination.notes!.isNotEmpty) ...[
              Divider(height: 32),
              Text(
                'Notes:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 8),
              Text(
                _examination.notes!,
                style: TextStyle(
                  fontSize: 14,
                ),
              ),
            ],
            Divider(height: 32),
            Center(
              child: OutlinedButton.icon(
                icon: Icon(
                  _examination.isCompleted ? Icons.close : Icons.check,
                  size: 18,
                ),
                label: Text(
                  _examination.isCompleted ? 'Marquer comme non terminé' : 'Marquer comme terminé',
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
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
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
    
    final sessionDate = DateFormat('dd/MM/yyyy').format(_relatedSession!.dateTime);
    final sessionTime = DateFormat('HH:mm').format(_relatedSession!.dateTime);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Séance associée',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: Icon(Icons.event, color: Colors.blue),
            title: Text('Séance du $sessionDate'),
            subtitle: Text('à $sessionTime - ${_relatedSession!.establishment.name}'),
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
          document.name,
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ajouté le ${DateFormat('dd/MM/yyyy').format(document.dateAdded)}',
              style: TextStyle(fontSize: 12),
            ),
            if (document.description != null && document.description!.isNotEmpty)
              Text(
                document.description!,
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
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 14),
          ),
        ),
      ],
    );
  }

  String _getSessionTimeRelationLabel() {
    if (_examination.prereqForSessionId != null && _relatedSession != null) {
      if (_examination.dateTime.isBefore(_relatedSession!.dateTime)) {
        return 'Prérequis pour la séance du ${DateFormat('dd/MM/yyyy').format(_relatedSession!.dateTime)}';
      } else {
        return 'Suivi de la séance du ${DateFormat('dd/MM/yyyy').format(_relatedSession!.dateTime)}';
      }
    }
    return 'Associé à une séance';
  }

  IconData _getExaminationIcon(ExaminationType type) {
    switch (type) {
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
        builder: (context) => AlertDialog(
          title: Text('Modifier l\'examen'),
          content: Text(
              'Cet examen fait partie d\'un groupe d\'examens liés à toutes les séances du cycle. '
                  'Souhaitez-vous modifier uniquement cet examen ou tous les examens similaires ?'
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
            builder: (context) => AddExaminationScreen(
              cycleId: widget.cycleId,
              examination: _examination,
              detachFromGroup: true, // Nouveau flag pour indiquer qu'on détache du groupe
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
            builder: (context) => AddExaminationScreen(
              cycleId: widget.cycleId,
              examination: _examination,
              forAllSessions: true,  // Indiquer que c'est pour tous les examens du groupe
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
          builder: (context) => AddExaminationScreen(
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
      final documentMaps = await dbHelper.getDocumentsByEntity('examination', _examination.id);
      Log.d("Nombre de documents trouvés: ${documentMaps.length}");

      setState(() {
        _documents = documentMaps.map((map) => Document.fromMap(map)).toList();
      });

      // Si l'examen est associé à une séance, recharger la séance également
      if (_examination.prereqForSessionId != null) {
        _relatedSession = widget.sessions.where(
                (s) => s.id == _examination.prereqForSessionId
        ).firstOrNull;
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
      await _dbHelper.updateExaminationCompletionStatus(_examination.id, newCompletionState);

      // Mettre à jour l'UI
      setState(() {
        _examination = _examination.copyWith(isCompleted: newCompletionState);
      });

      // Afficher un message de confirmation
      _showMessage(
        newCompletionState
            ? 'Examen marqué comme terminé'
            : 'Examen marqué comme non terminé'
      );
    } catch (e) {
      Log.e("Erreur lors de la mise à jour de l'état de l'examen: $e");
      _showErrorMessage("Une erreur est survenue lors de la mise à jour");
    }
  }

  Future<void> _confirmDeleteExamination() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => ConfirmationDialog(
        title: 'Supprimer l\'examen',
        content: 'Êtes-vous sûr de vouloir supprimer cet examen et tous les documents associés ? Cette action est irréversible.',
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
        Navigator.pop(context, true); // Retourner true pour indiquer que l'examen a été supprimé
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
    final action = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('Ajouter un document'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'camera'),
            child: ListTile(
              leading: Icon(Icons.camera_alt, color: Colors.blue),
              title: Text('Prendre une photo'),
              dense: true,
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'gallery'),
            child: ListTile(
              leading: Icon(Icons.photo_library, color: Colors.green),
              title: Text('Choisir une image'),
              dense: true,
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'file'),
            child: ListTile(
              leading: Icon(Icons.upload_file, color: Colors.orange),
              title: Text('Sélectionner un fichier'),
              dense: true,
            ),
          ),
        ],
      ),
    );

    if (action == null) return;

    if (action == 'camera') {
      await _takePicture();
    } else if (action == 'gallery') {
      await _pickImage();
    } else if (action == 'file') {
      await _pickFile();
    }
  }


  Future<void> _takePicture() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );

      if (image != null) {
        await _processDocument(image.path, image.name, DocumentType.Image);
      }
    } catch (e) {
      Log.e("Erreur lors de la prise de photo: $e");
      _showErrorMessage("Impossible de prendre une photo");
    }
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (image != null) {
        await _processDocument(image.path, image.name, DocumentType.Image);
      }
    } catch (e) {
      Log.e("Erreur lors de la sélection d'image: $e");
      _showErrorMessage("Impossible de sélectionner une image");
    }
  }

  Future<void> _pickFile() async {
    Log.d('_pickFile');
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx', 'txt'],
      );

      if (result != null && result.files.isNotEmpty) {
        final filePath = result.files.first.path!;
        final fileName = result.files.first.name;
        final fileExtension = fileName.split('.').last.toLowerCase();

        // Déterminer le type de document
        DocumentType docType;
        switch (fileExtension) {
          case 'pdf':
            docType = DocumentType.PDF;
            break;
          case 'jpg':
          case 'jpeg':
          case 'png':
            docType = DocumentType.Image;
            break;
          case 'doc':
          case 'docx':
            docType = DocumentType.Word;
            break;
          case 'txt':
            docType = DocumentType.Text;
            break;
          default:
            docType = DocumentType.Other;
        }

        await _processDocument(filePath, fileName, docType);
      }
    } catch (e) {
      Log.e("Erreur lors de la sélection du fichier: $e");
      _showErrorMessage("Impossible de sélectionner le fichier");
    }
  }

  Future<void> _processDocument(String sourcePath, String fileName, DocumentType docType) async {
    try {
      // Obtenir un nom pour le document
      final docName = await _getDocumentName(docType.toString(), fileName);
      if (docName == null) return;  // L'utilisateur a annulé

      // Obtenir une description pour le document
      final docDescription = await _getDocumentDescription();

      // Créer un dossier dans l'application pour stocker les fichiers
      final appDir = await getApplicationDocumentsDirectory();
      final documentsDir = Directory('${appDir.path}/documents');
      if (!await documentsDir.exists()) {
        await documentsDir.create(recursive: true);
      }

      // Générer un nom de fichier unique
      final uniqueId = Uuid().v4();
      final fileExtension = fileName.split('.').last.toLowerCase();
      final newFileName = '$uniqueId.$fileExtension';
      final filePath = '${documentsDir.path}/$newFileName';

      // Copier le fichier dans le dossier de l'application
      final sourceFile = File(sourcePath);
      await sourceFile.copy(filePath);

      // Créer le document
      final document = Document(
        id: uniqueId,
        name: docName,
        path: filePath,
        dateAdded: DateTime.now(),
        type: docType,
        description: docDescription,
        size: await sourceFile.length(),
      );

      // Ajouter le document à la base de données
      final dbHelper = DatabaseHelper();
      final docResult = await dbHelper.insertDocument(document.toMap());

      if (docResult > 0) {
        // Lier le document à l'examen
        final linkResult = await dbHelper.linkDocumentToEntity('examination', _examination.id, document.id);
        if (linkResult > 0) {
          // Recharger les documents
          await _loadData();
          _showMessage('Document ajouté avec succès');
        } else {
          _showErrorMessage("Erreur lors de la liaison du document à l'examen");
        }
      } else {
        _showErrorMessage("Erreur lors de l'enregistrement du document");
      }
    } catch (e) {
      Log.e("Erreur lors du traitement du document: $e");
      _showErrorMessage("Impossible de traiter le document");
    }
  }

  Future<String?> _getDocumentName(String type, String defaultName) async {
    final controller = TextEditingController(text: defaultName);

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Nom du document'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: 'Nom',
            hintText: 'Entrez un nom pour ce document',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(context, controller.text.trim());
              }
            },
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<String?> _getDocumentDescription() async {
    final controller = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Description (optionnelle)'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: 'Description',
            hintText: 'Entrez une description pour ce document',
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, ''),
            child: Text('Ignorer'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  void _viewDocument(Document document) async {
    try {
      final path = document.path;
      final file = File(path);

      if (!(await file.exists())) {
        _showErrorMessage("Le fichier est introuvable");
        return;
      }

      switch (document.type) {
        case DocumentType.Image:
          _viewImageDocument(document);
          break;
        case DocumentType.PDF:
          _viewPdfDocument(document);
          break;
        case DocumentType.Word:
        case DocumentType.Text:
        case DocumentType.Other:
        default:
          _openWithDefaultApp(document);
          break;
      }
    } catch (e) {
      Log.e("Erreur lors de l'ouverture du document: $e");
      _showErrorMessage("Impossible d'ouvrir le document");
    }
  }


  void _viewImageDocument(Document document) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text(document.name),
            actions: [
              IconButton(
                icon: Icon(Icons.ios_share), // Icône de partage style iOS
                onPressed: () => _shareDocument(document),
                tooltip: 'Partager',
              ),
            ],
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.file(
                File(document.path),
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }


  void _viewPdfDocument(Document document) async {
    try {
      // Vérifier si le fichier PDF existe
      final file = File(document.path);
      if (await file.exists()) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => Scaffold(
              appBar: AppBar(
                title: Text(document.name),
                actions: [
                  IconButton(
                    icon: Icon(Icons.ios_share), // Icône de partage style iOS
                    onPressed: () => _shareDocument(document),
                    tooltip: 'Partager',
                  ),
                ],
              ),
              body: PDFView(
                filePath: document.path,
                enableSwipe: true,
                swipeHorizontal: true,
                autoSpacing: false,
                pageFling: true,
                pageSnap: true,
                defaultPage: 0,
                fitPolicy: FitPolicy.BOTH,
                preventLinkNavigation: false,
                onRender: (_pages) {
                  // PDF est chargé
                },
                onError: (error) {
                  _showErrorMessage("Erreur lors du chargement du PDF: $error");
                },
                onViewCreated: (PDFViewController pdfViewController) {
                  // PDFView créé
                },
                onPageChanged: (int? page, int? total) {
                  // Page changée
                },
                onPageError: (page, error) {
                  _showErrorMessage("Erreur lors du chargement de la page $page: $error");
                },
              ),
            ),
          ),
        );
      } else {
        _showErrorMessage("Le fichier PDF est introuvable");
      }
    } catch (e) {
      Log.e("Erreur lors de l'ouverture du PDF: $e");
      _showErrorMessage("Impossible d'ouvrir le document PDF");
    }
  }


  void _shareDocument(Document document) async {
    try {
      final file = File(document.path);
      if (await file.exists()) {
        // Déterminer le message de partage en fonction du type de document
        String shareMessage;
        switch (document.type) {
          case DocumentType.PDF:
            shareMessage = "Document PDF: ${document.name}";
            break;
          case DocumentType.Image:
            shareMessage = "Image: ${document.name}";
            break;
          case DocumentType.Word:
            shareMessage = "Document Word: ${document.name}";
            break;
          case DocumentType.Text:
            shareMessage = "Document texte: ${document.name}";
            break;
          default:
            shareMessage = "Document: ${document.name}";
        }

        // Ajouter la description si disponible
        if (document.description != null && document.description!.isNotEmpty) {
          shareMessage += "\n${document.description}";
        }

        // Partager le document
        await Share.shareXFiles(
          [XFile(document.path)],
          text: shareMessage,
          subject: document.name,
        );
      } else {
        _showErrorMessage("Le fichier est introuvable");
      }
    } catch (e) {
      Log.e("Erreur lors du partage du document: $e");
      _showErrorMessage("Impossible de partager le document");
    }
  }

  Future<void> _openWithDefaultApp(Document document) async {
    try {
      final file = File(document.path);
      if (await file.exists()) {
        // Proposer à l'utilisateur de partager ou d'essayer d'ouvrir le fichier
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Ouvrir le document'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _getDocumentTypeIcon(document.type),
                  size: 60,
                  color: _getDocumentTypeColor(document.type),
                ),
                SizedBox(height: 16),
                Text(document.name, style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text(
                  'Ce type de document ne peut pas être ouvert directement dans l\'application.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _shareDocument(document);
                },
                child: Text('Partager'),
              ),
            ],
          ),
        );
      } else {
        _showErrorMessage("Le fichier est introuvable");
      }
    } catch (e) {
      Log.e("Erreur lors de l'ouverture du document: $e");
      _showErrorMessage("Impossible d'ouvrir le document");
    }
  }

// Fonction auxiliaire pour obtenir l'icône correspondant au type de document
  IconData _getDocumentTypeIcon(DocumentType type) {
    switch (type) {
      case DocumentType.PDF:
        return Icons.picture_as_pdf;
      case DocumentType.Image:
        return Icons.image;
      case DocumentType.Word:
        return Icons.article;
      case DocumentType.Text:
        return Icons.description;
      case DocumentType.Other:
      default:
        return Icons.insert_drive_file;
    }
  }

// Fonction auxiliaire pour obtenir la couleur correspondant au type de document
  Color _getDocumentTypeColor(DocumentType type) {
    switch (type) {
      case DocumentType.PDF:
        return Colors.red;
      case DocumentType.Image:
        return Colors.blue;
      case DocumentType.Word:
        return Colors.indigo;
      case DocumentType.Text:
        return Colors.green;
      case DocumentType.Other:
      default:
        return Colors.grey;
    }
  }

// Ensuite, modifiez la méthode _viewDocument pour utiliser cette nouvelle fonction :

  Future<void> _confirmRemoveDocument(Document document) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => ConfirmationDialog(
        title: 'Supprimer le document',
        content: 'Êtes-vous sûr de vouloir supprimer ce document de l\'examen ?',
        confirmText: 'Supprimer',
        cancelText: 'Annuler',
        isDestructive: true,
      ),
    );

    if (confirmed == true) {
      try {
        // Supprimer le lien entre le document et l'examen
        await _dbHelper.unlinkDocumentFromEntity('examination', _examination.id, document.id);
        
        // Recharger les documents
        await _loadData();
        
        _showMessage('Document supprimé avec succès');
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
}
