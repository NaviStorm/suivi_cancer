// lib/features/treatment/screens/add_document_screen.dart
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:file_picker/file_picker.dart';
import 'package:suivi_cancer/common/widgets/custom_text_field.dart';
import 'package:suivi_cancer/features/treatment/models/document.dart';
import 'package:suivi_cancer/features/treatment/models/doctor.dart';
import 'package:suivi_cancer/core/storage/database_helper.dart';
import 'package:suivi_cancer/utils/file_utils.dart';
import 'package:suivi_cancer/utils/logger.dart';

class AddDocumentScreen extends StatefulWidget {
  final String entityType; // 'cycle', 'session', 'examination', etc.
  final String entityId;
  final String? entityName; // Nom optionnel pour l'affichage
  final Document? document; // Null en cas de création, non-null en cas d'édition

  const AddDocumentScreen({
    Key? key,
    required this.entityType,
    required this.entityId,
    this.entityName,
    this.document,
  }) : super(key: key);

  @override
  _AddDocumentScreenState createState() => _AddDocumentScreenState();
}

class _AddDocumentScreenState extends State<AddDocumentScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  DocumentType _selectedType = DocumentType.PDF;
  Doctor? _selectedDoctor;
  DateTime _addedDate = DateTime.now();
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isEdit = false;
  String? _selectedFilePath;
  String? _selectedFileName;
  List<Doctor> _doctors = [];

  @override
  void initState() {
    super.initState();
    _isEdit = widget.document != null;

    if (_isEdit) {
      // En mode édition, initialiser les contrôleurs avec les valeurs existantes
      final doc = widget.document!;
      _nameController.text = doc.name;
      _descriptionController.text = doc.description ?? '';
      _selectedType = doc.type;
      _addedDate = doc.dateAdded;
      // Le chemin du fichier et le médecin doivent être récupérés séparément
    }

    _loadDoctors();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadDoctors() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final dbHelper = DatabaseHelper();
      final doctorMaps = await dbHelper.getDoctors();

      setState(() {
        _doctors = doctorMaps.map((map) => Doctor.fromMap(map)).toList();
        _isLoading = false;
      });

      // En mode édition, essayer de trouver le médecin associé
      if (_isEdit) {
        _loadDocumentDoctor();
      }
    } catch (e) {
      Log.e("Erreur lors du chargement des médecins: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadDocumentDoctor() async {
    try {
      if (widget.document == null) return;

      final dbHelper = DatabaseHelper();
      final doctorId = await dbHelper.getDocumentDoctor(widget.document!.id);

      if (doctorId != null) {
        setState(() {
          _selectedDoctor = _doctors.firstWhere(
                (d) => d.id == doctorId,
            orElse: () => _doctors.first,
          );
        });
      }
    } catch (e) {
      Log.e("Erreur lors du chargement du médecin associé au document: $e");
    }
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: _getFileType(),
        allowMultiple: false,
      );

      if (result != null) {
        setState(() {
          _selectedFilePath = result.files.single.path;
          _selectedFileName = result.files.single.name;

          // Auto-remplir le nom s'il est vide
          if (_nameController.text.isEmpty) {
            _nameController.text = path.basenameWithoutExtension(result.files.single.name);
          }

          // Déterminer automatiquement le type de document en fonction de l'extension
          final extension = path.extension(result.files.single.name).toLowerCase();
          if (extension == '.pdf') {
            _selectedType = DocumentType.PDF;
          } else if (['.jpg', '.jpeg', '.png', '.gif'].contains(extension)) {
            _selectedType = DocumentType.Image;
          } else if (extension == '.txt') {
            _selectedType = DocumentType.Text;
          } else if (['.doc', '.docx'].contains(extension)) {
            _selectedType = DocumentType.Word;
          } else {
            _selectedType = DocumentType.Other;
          }
        });
      }
    } catch (e) {
      Log.e("Erreur lors de la sélection du fichier: $e");
      _showErrorMessage("Erreur lors de la sélection du fichier");
    }
  }

  FileType _getFileType() {
    switch (_selectedType) {
      case DocumentType.PDF:
        return FileType.custom;
      case DocumentType.Image:
        return FileType.image;
      case DocumentType.Text:
        return FileType.any;
      case DocumentType.Word:
        return FileType.custom;
      case DocumentType.Other:
        return FileType.any;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Modifier le document' : 'Ajouter un document'),
        actions: [
          if (_isEdit)
            IconButton(
              icon: Icon(Icons.delete),
              onPressed: _confirmDeleteDocument,
            ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.entityName != null) ...[
                Text(
                  'Document pour : ${widget.entityName}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800,
                  ),
                ),
                SizedBox(height: 16),
              ],

              // Type de document
              Text(
                'Type de document',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 8),
              _buildDocumentTypeSelector(),
              SizedBox(height: 16),

              // Sélection de fichier
              if (!_isEdit) ...[
                OutlinedButton.icon(
                  onPressed: _pickFile,
                  icon: Icon(Icons.attach_file),
                  label: Text(_selectedFileName != null
                      ? 'Fichier sélectionné: $_selectedFileName'
                      : 'Sélectionner un fichier'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: Size(double.infinity, 50),
                  ),
                ),
                if (_selectedFileName == null)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      'Veuillez sélectionner un fichier',
                      style: TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
                SizedBox(height: 16),
              ],

              // Nom du document
              CustomTextField(
                label: 'Nom du document',
                controller: _nameController,
                placeholder: 'ex: Ordonnance 01/01/2023',
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Veuillez saisir un nom';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),

              // Description
              CustomTextField(
                label: 'Description (optionnelle)',
                controller: _descriptionController,
                placeholder: 'ex: Ordonnance pour prise de sang',
                maxLines: 2,
              ),
              SizedBox(height: 16),

              // Médecin prescripteur
              Text(
                'Médecin prescripteur (optionnel)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 8),
              _buildDoctorDropdown(),
              SizedBox(height: 16),

              // Date d'ajout
              Text(
                'Date du document',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 8),
              InkWell(
                onTap: _selectDate,
                child: InputDecorator(
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(
                    DateFormat('dd/MM/yyyy').format(_addedDate),
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ),
              SizedBox(height: 32),

              // Bouton d'enregistrement
              ElevatedButton(
                onPressed: _isSaving || (_selectedFileName == null && !_isEdit)
                    ? null
                    : _saveDocument,
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 50),
                ),
                child: _isSaving
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text(_isEdit ? 'Mettre à jour' : 'Enregistrer'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDocumentTypeSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildTypeChip(DocumentType.PDF, 'PDF', Icons.picture_as_pdf),
        _buildTypeChip(DocumentType.Image, 'Image', Icons.image),
        _buildTypeChip(DocumentType.Text, 'Texte', Icons.article),
        _buildTypeChip(DocumentType.Word, 'Word', Icons.description),
        _buildTypeChip(DocumentType.Other, 'Autre', Icons.insert_drive_file),
      ],
    );
  }

  Widget _buildTypeChip(DocumentType type, String label, IconData icon) {
    final isSelected = _selectedType == type;
    final color = _getDocumentTypeColor(type);

    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: isSelected ? Colors.white : color,
          ),
          SizedBox(width: 4),
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: (_) {
        setState(() {
          _selectedType = type;
        });

        // Si on est en mode création, proposer de sélectionner à nouveau un fichier
        if (!_isEdit && _selectedFileName != null) {
          _pickFile();
        }
      },
      backgroundColor: color.withOpacity(0.1),
      selectedColor: color,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : color,
      ),
      showCheckmark: false,
    );
  }

  Widget _buildDoctorDropdown() {
    return DropdownButtonFormField<Doctor>(
      decoration: InputDecoration(
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      value: _selectedDoctor,
      hint: Text('Sélectionner un médecin'),
      onChanged: (Doctor? value) {
        setState(() {
          _selectedDoctor = value;
        });
      },
      items: [
        DropdownMenuItem<Doctor>(
          value: null,
          child: Text('Aucun'),
        ),
        ..._doctors.map((doctor) => DropdownMenuItem<Doctor>(
          value: doctor,
          child: Text(doctor.fullName),
        )).toList(),
      ],
    );
  }

  Future<void> _selectDate() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _addedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );

    if (pickedDate != null && pickedDate != _addedDate) {
      setState(() {
        _addedDate = pickedDate;
      });
    }
  }

  Future<void> _saveDocument() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSaving = true;
      });

      try {
        final dbHelper = DatabaseHelper();
        final String documentId = _isEdit ? widget.document!.id : Uuid().v4();
        String filePath = '';

        // En cas de création, copier le fichier vers le stockage de l'application
        if (!_isEdit && _selectedFilePath != null) {
          filePath = await FileUtils.copyFileToAppStorage(
            _selectedFilePath!,
            'documents/$documentId${path.extension(_selectedFilePath!)}',
          );
        } else if (_isEdit) {
          // En cas d'édition, utiliser le chemin existant
          filePath = widget.document!.path;
        }

        final documentData = {
          'id': documentId,
          'name': _nameController.text.trim(),
          'path': filePath,
          'type': _selectedType.index,
          'dateAdded': _addedDate.toIso8601String(),
          'description': _descriptionController.text.trim().isNotEmpty
              ? _descriptionController.text.trim()
              : null,
        };

        int result;
        if (_isEdit) {
          result = await dbHelper.updateDocument(documentData);
        } else {
          result = await dbHelper.insertDocument_ForAddDocumentScreen(documentData, widget.entityType, widget.entityId);
        }

        // Associer le médecin si sélectionné
        if (_selectedDoctor != null) {
          await dbHelper.linkDocumentDoctor(documentId, _selectedDoctor!.id);
        } else {
          // Si aucun médecin n'est sélectionné, supprimer toute association existante
          await dbHelper.unlinkDocumentDoctor(documentId);
        }

        if (result > 0) {
          _showMessage(_isEdit ? 'Document mis à jour avec succès' : 'Document ajouté avec succès');
          Navigator.pop(context, true);
        } else {
          _showErrorMessage('Erreur lors de l\'enregistrement');
          setState(() {
            _isSaving = false;
          });
        }
      } catch (e) {
        Log.e("Erreur lors de l'enregistrement du document: $e");
        _showErrorMessage('Erreur lors de l\'enregistrement: $e');
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _confirmDeleteDocument() async {
    if (!_isEdit) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Supprimer le document'),
        content: Text('Êtes-vous sûr de vouloir supprimer ce document ? Cette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        setState(() {
          _isSaving = true;
        });

        final dbHelper = DatabaseHelper();
        final result = await dbHelper.deleteDocument(widget.document!.id);

        if (result > 0) {
          _showMessage('Document supprimé avec succès');
          Navigator.pop(context, true);
        } else {
          _showErrorMessage('Erreur lors de la suppression');
          setState(() {
            _isSaving = false;
          });
        }
      } catch (e) {
        Log.e("Erreur lors de la suppression du document: $e");
        _showErrorMessage('Erreur lors de la suppression: $e');
        setState(() {
          _isSaving = false;
        });
      }
    }
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

  Color _getDocumentTypeColor(DocumentType type) {
    switch (type) {
      case DocumentType.PDF:
        return Colors.red;
      case DocumentType.Image:
        return Colors.blue;
      case DocumentType.Text:
        return Colors.green;
      case DocumentType.Word:
        return Colors.indigo;
      case DocumentType.Other:
        return Colors.grey;
    }
  }
}

