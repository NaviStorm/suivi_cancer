// lib/features/treatment/screens/add_examination_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:collection/collection.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:suivi_cancer/features/treatment/models/session.dart';
import 'package:suivi_cancer/features/treatment/models/document.dart';
import 'package:suivi_cancer/features/treatment/models/examination.dart';
import 'package:suivi_cancer/features/treatment/models/establishment.dart';
import 'package:suivi_cancer/features/treatment/models/doctor.dart';
import 'package:suivi_cancer/core/storage/database_helper.dart';
import 'package:suivi_cancer/common/widgets/custom_text_field.dart';
import 'package:suivi_cancer/features/treatment/screens/doctor/add_doctor_screen.dart';
import 'package:suivi_cancer/features/treatment/screens/establishment/add_establishment_screen.dart';
import 'package:suivi_cancer/utils/logger.dart';

// Enum pour le type de lien
enum ExaminationLinkType {
  Cycle,
  SingleSession,
  AllSessions
}

// Enum pour la relation temporelle avec la séance
enum SessionTimeRelation {
  Before,  // Avant la séance
  Same,    // Le jour même
  After    // Après la séance
}

class AddExaminationScreen extends StatefulWidget {
  final String cycleId;
  final String? sessionId; // ID de la séance spécifique (si applicable)
  final Examination? examination; // Pour l'édition
  final bool forAllSessions; // Pour créer des examens pour toutes les séances
  final bool detachFromGroup; // Nouveau paramètre pour détacher un examen de son groupe

  const AddExaminationScreen({
    Key? key,
    required this.cycleId,
    this.sessionId,
    this.examination,
    this.forAllSessions = false,
    this.detachFromGroup = false, // Valeur par défaut
  }) : super(key: key);

  @override
  _AddExaminationScreenState createState() => _AddExaminationScreenState();
}

class SaveExaminationResult {
  final bool success;
  final String examinationId;

  SaveExaminationResult(this.success, this.examinationId);
}

class _AddExaminationScreenState extends State<AddExaminationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  ExaminationType _selectedType = ExaminationType.PriseDeSang;

  Establishment? _selectedEstablishment;
  Doctor? _selectedDoctor;

  // Variables pour les sessions et le type de lien
  String? _selectedSessionId;
  List<Session> _sessions = [];
  ExaminationLinkType _linkType = ExaminationLinkType.Cycle;
  String? _examGroupId; // ID commun pour les examens liés à toutes les séances

  // Variables pour la relation temporelle avec la séance
  SessionTimeRelation _timeRelation = SessionTimeRelation.Before;
  int _timeOffset = 0; // Offset en heures

  List<Establishment> _establishments = [];
  List<Doctor> _doctors = [];

  // Liste des documents joints
  List<DocumentAttachment> _attachedDocuments = [];

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    // Initialiser le type de lien en fonction des paramètres
    if (widget.sessionId != null) {
      _linkType = ExaminationLinkType.SingleSession;
      _selectedSessionId = widget.sessionId;
    } else if (widget.forAllSessions) {
      _linkType = ExaminationLinkType.AllSessions;
      _examGroupId = Uuid().v4(); // Générer un ID de groupe
    } else {
      _linkType = ExaminationLinkType.Cycle;
    }

    // Si on est en mode édition
    if (widget.examination != null) {
      _titleController.text = widget.examination!.title ?? '';
      _notesController.text = widget.examination!.notes ?? '';
      _selectedDate = widget.examination!.dateTime;
      _selectedTime = TimeOfDay.fromDateTime(widget.examination!.dateTime);
      _selectedType = widget.examination!.type;
      _selectedSessionId = widget.examination!.prereqForSessionId;
      _examGroupId = widget.examination!.examGroupId;

      if (_selectedSessionId != null) {
        _linkType = ExaminationLinkType.SingleSession;
      } else if (_examGroupId != null) {
        _linkType = ExaminationLinkType.AllSessions;
      }

      // Charger les documents de l'examen
      _loadDocuments();
    }

    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final dbHelper = DatabaseHelper();

      // Charger les établissements
      final establishmentMaps = await dbHelper.getEstablishments();
      _establishments = establishmentMaps.map((map) => Establishment.fromMap(map)).toList();

      // Charger les médecins
      final doctorMaps = await dbHelper.getDoctors();
      _doctors = doctorMaps.map((map) => Doctor.fromMap(map)).toList();

      // Charger les séances du cycle
      if (_linkType == ExaminationLinkType.SingleSession || _linkType == ExaminationLinkType.AllSessions) {
        final sessionMaps = await dbHelper.getSessionsByCycle(widget.cycleId);
        _sessions = sessionMaps.map((map) => Session.fromMap(map)).toList();

        // Trier les séances par date
        _sessions.sort((a, b) => a.dateTime.compareTo(b.dateTime));

        // Sélectionner la première séance si aucune n'est sélectionnée
        if (_selectedSessionId == null && _sessions.isNotEmpty && _linkType == ExaminationLinkType.SingleSession) {
          _selectedSessionId = _sessions.first.id;
        }
      }

      // Si on est en mode édition, sélectionner l'établissement et le médecin
      if (widget.examination != null) {
        _selectedEstablishment = _establishments.firstWhereOrNull(
              (e) => e.id == widget.examination!.establishment.id,
        );

        if (_selectedEstablishment == null && _establishments.isNotEmpty) {
          _selectedEstablishment = _establishments.first;
        }

        if (widget.examination!.doctor != null) {
          _selectedDoctor = _doctors.firstWhereOrNull(
                  (d) => d.id == widget.examination!.doctor!.id
          );
        }
      } else if (_establishments.isNotEmpty) {
        _selectedEstablishment = _establishments.first;
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      Log.e("Erreur lors du chargement des données: $e");
      setState(() {
        _isLoading = false;
      });
      _showErrorMessage("Impossible de charger les données");
    }
  }

  Future<void> _loadDocuments() async {
    if (widget.examination == null) return;

    try {
      final dbHelper = DatabaseHelper();
      final documentMaps = await dbHelper.getDocumentsByEntity('examination', widget.examination!.id);

      setState(() {
        _attachedDocuments = documentMaps.map((map) {
          return DocumentAttachment(
            document: Document.fromMap(map),
            isNew: false,
          );
        }).toList();
      });
    } catch (e) {
      Log.e("Erreur lors du chargement des documents: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.examination != null ? 'Modifier l\'examen' : 'Ajouter un examen'),
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
              _buildExaminationTypeSelector(),
              SizedBox(height: 16),

              CustomTextField(
                label: 'Titre',
                controller: _titleController,
                placeholder: 'ex: Bilan sanguin',
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Veuillez saisir un titre';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),

              // Uniquement visible en mode édition ou si l'examen est lié au cycle
              if (_linkType == ExaminationLinkType.Cycle || widget.examination != null)
                _buildDateTimePicker(),

              // Configuration spécifique pour les examens liés aux séances
              if (_linkType != ExaminationLinkType.Cycle && widget.examination == null)
                _buildSessionTimingConfig(),

              SizedBox(height: 16),

              _buildLinkTypeSelector(),
              SizedBox(height: 16),

              // Si le type est Session unique, ajouter un sélecteur de séance
              if (_linkType == ExaminationLinkType.SingleSession)
                _buildSessionSelector(),

              SizedBox(height: 16),

              _buildEstablishmentSelector(),
              SizedBox(height: 16),

              _buildDoctorSelector(),
              SizedBox(height: 16),

              _buildDocumentsSection(),
              SizedBox(height: 16),

              CustomTextField(
                label: 'Notes (optionnel)',
                controller: _notesController,
                placeholder: 'ex: À jeun depuis la veille',
                maxLines: 3,
              ),
              SizedBox(height: 32),

              ElevatedButton(
                onPressed: _isSaving ? null : _saveExamination,
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 50),
                ),
                child: _isSaving
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text(widget.examination != null ? 'Mettre à jour' : 'Enregistrer'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExaminationTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Type d\'examen',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildTypeChip(ExaminationType.PriseDeSang, 'Prise de sang', Icons.bloodtype),
            _buildTypeChip(ExaminationType.Injection, 'Injection,',  Icons.vaccines),
            _buildTypeChip(ExaminationType.Scanner, 'Scanner', Icons.panorama_horizontal),
            _buildTypeChip(ExaminationType.IRM, 'IRM', Icons.medical_information),
            _buildTypeChip(ExaminationType.PETScan, 'PET-Scan', Icons.biotech),
            _buildTypeChip(ExaminationType.Radio, 'Radio', Icons.photo),
            _buildTypeChip(ExaminationType.Echographie, 'Échographie', Icons.waves),
            _buildTypeChip(ExaminationType.EpreuveEffort, 'Épreuve d\'effort', Icons.directions_run),
            _buildTypeChip(ExaminationType.EFR, 'EFR', Icons.air),
            _buildTypeChip(ExaminationType.Autre, 'Autre', Icons.science),
          ],
        ),
      ],
    );
  }

  Widget _buildTypeChip(ExaminationType type, String label, IconData icon) {
    final isSelected = _selectedType == type;
    final color = Colors.blue;

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
          Text(label, style: TextStyle(fontSize: 12)),
        ],
      ),
      selected: isSelected,
      onSelected: (_) {
        setState(() {
          _selectedType = type;
        });
      },
      backgroundColor: Colors.blue.withAlpha(20),
      selectedColor: color,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : color,
        fontSize: 12,
      ),
      showCheckmark: false,
    );
  }

  Widget _buildDateTimePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Date et heure',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: InkWell(
                onTap: _selectDate,
                child: InputDecorator(
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    suffixIcon: Icon(Icons.calendar_today, size: 18),
                  ),
                  child: Text(
                    DateFormat('dd/MM/yyyy').format(_selectedDate),
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: InkWell(
                onTap: _selectTime,
                child: InputDecorator(
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    suffixIcon: Icon(Icons.access_time, size: 18),
                  ),
                  child: Text(
                    _selectedTime.format(context),
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSessionTimingConfig() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Planification par rapport à la séance',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<SessionTimeRelation>(
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                value: _timeRelation,
                onChanged: (SessionTimeRelation? value) {
                  if (value != null) {
                    setState(() {
                      _timeRelation = value;
                    });
                  }
                },
                items: [
                  DropdownMenuItem(
                    value: SessionTimeRelation.Before,
                    child: Text('Avant', style: TextStyle(fontSize: 14)),
                  ),
                  DropdownMenuItem(
                    value: SessionTimeRelation.Same,
                    child: Text('Le jour même', style: TextStyle(fontSize: 14)),
                  ),
                  DropdownMenuItem(
                    value: SessionTimeRelation.After,
                    child: Text('Après', style: TextStyle(fontSize: 14)),
                  ),
                ],
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  if (_timeRelation != SessionTimeRelation.Same)
                    Expanded(
                      child: TextFormField(
                        decoration: InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          labelText: 'Heures',
                        ),
                        keyboardType: TextInputType.number,
                        initialValue: _timeOffset.toString(),
                        validator: _timeRelation != SessionTimeRelation.Same
                            ? (value) {
                          if (value == null || value.isEmpty) {
                            return 'Obligatoire';
                          }
                          final number = int.tryParse(value);
                          if (number == null || number < 0) {
                            return 'Invalide';
                          }
                          return null;
                        }
                            : null,
                        onChanged: (value) {
                          final parsed = int.tryParse(value);
                          if (parsed != null) {
                            setState(() {
                              _timeOffset = parsed;
                            });
                          }
                        },
                      ),
                    ),
                  if (_timeRelation == SessionTimeRelation.Same)
                    Expanded(
                      child: Text(
                        'Planifier le jour de la séance',
                        style: TextStyle(fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: 4),
        Text(
          _getTimingDescription(),
          style: TextStyle(
            fontSize: 12,
            fontStyle: FontStyle.italic,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  String _getTimingDescription() {
    switch (_timeRelation) {
      case SessionTimeRelation.Before:
        return 'L\'examen sera planifié $_timeOffset heures avant chaque séance';
      case SessionTimeRelation.Same:
        return 'L\'examen sera planifié le jour même de chaque séance';
      case SessionTimeRelation.After:
        return 'L\'examen sera planifié $_timeOffset heures après chaque séance';
    }
  }

  Widget _buildLinkTypeSelector() {
    // En mode édition, on ne peut pas changer le type de lien
    if (widget.examination != null) {
      return SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Lier cet examen à :',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: RadioListTile<ExaminationLinkType>(
                title: Text('Cycle', style: TextStyle(fontSize: 13)),
                value: ExaminationLinkType.Cycle,
                groupValue: _linkType,
                dense: true,
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _linkType = value;
                      _selectedSessionId = null;
                    });
                  }
                },
              ),
            ),
            Expanded(
              child: RadioListTile<ExaminationLinkType>(
                title: Text('Une séance', style: TextStyle(fontSize: 13)),
                value: ExaminationLinkType.SingleSession,
                groupValue: _linkType,
                dense: true,
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _linkType = value;
                      if (_sessions.isNotEmpty) {
                        _selectedSessionId = _sessions.first.id;
                      }
                    });
                  }
                },
              ),
            ),
            Expanded(
              child: RadioListTile<ExaminationLinkType>(
                title: Text('Toutes', style: TextStyle(fontSize: 13)),
                value: ExaminationLinkType.AllSessions,
                groupValue: _linkType,
                dense: true,
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _linkType = value;
                      _selectedSessionId = null;
                      if (_examGroupId == null) {
                        _examGroupId = Uuid().v4();
                      }
                    });
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSessionSelector() {
    if (_sessions.isEmpty) {
      return Text('Aucune séance disponible', style: TextStyle(color: Colors.red));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Séance',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 8),
        DropdownButtonFormField<String>(
          decoration: InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          value: _selectedSessionId,
          hint: Text('Sélectionner une séance'),
          onChanged: (String? value) {
            setState(() {
              _selectedSessionId = value;
            });
          },
          items: _sessions.map((session) {
            // Trouver le numéro de la séance dans le cycle
            final sessionNumber = _sessions.indexOf(session) + 1;
            final sessionDate = DateFormat('dd/MM/yyyy').format(session.dateTime);
            final sessionTime = DateFormat('HH:mm').format(session.dateTime);

            return DropdownMenuItem<String>(
              value: session.id,
              child: Text(
                'Séance $sessionNumber - $sessionDate à $sessionTime',
                style: TextStyle(fontSize: 13),
              ),
            );
          }).toList(),
          validator: (value) {
            if (_linkType == ExaminationLinkType.SingleSession && value == null) {
              return 'Veuillez sélectionner une séance';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildEstablishmentSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Établissement',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            TextButton.icon(
              icon: Icon(Icons.add, size: 16),
              label: Text('Nouveau', style: TextStyle(fontSize: 12)),
              onPressed: _addNewEstablishment,
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        DropdownButtonFormField<Establishment>(
          decoration: InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          value: _selectedEstablishment,
          hint: Text('Sélectionner un établissement'),
          onChanged: (Establishment? value) {
            setState(() {
              _selectedEstablishment = value;
            });
          },
          items: _establishments.map((establishment) => DropdownMenuItem(
            value: establishment,
            child: Text(establishment.name, style: TextStyle(fontSize: 14)),
          )).toList(),
          validator: (value) {
            if (value == null) {
              return 'Veuillez sélectionner un établissement';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildDoctorSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Médecin (optionnel)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            TextButton.icon(
              icon: Icon(Icons.add, size: 16),
              label: Text('Nouveau', style: TextStyle(fontSize: 12)),
              onPressed: _addNewDoctor,
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        DropdownButtonFormField<Doctor?>(
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
            DropdownMenuItem<Doctor?>(
              value: null,
              child: Text('Aucun', style: TextStyle(fontSize: 14)),
            ),
            ..._doctors.map((doctor) => DropdownMenuItem(
              value: doctor,
              child: Text(doctor.fullName, style: TextStyle(fontSize: 14)),
            )).toList(),
          ],
        ),
      ],
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
              'Documents (optionnel)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            TextButton.icon(
              icon: Icon(Icons.add, size: 16),
              label: Text('Ajouter', style: TextStyle(fontSize: 12)),
              onPressed: _showAddDocumentDialog,
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        if (_attachedDocuments.isEmpty)
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Center(
              child: Text(
                'Aucun document attaché',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: _attachedDocuments.length,
            itemBuilder: (context, index) {
              final attachment = _attachedDocuments[index];
              final document = attachment.document;

              IconData documentIcon;
              switch (document.type) {
                case DocumentType.PDF:
                  documentIcon = Icons.picture_as_pdf;
                  break;
                case DocumentType.Image:
                  documentIcon = Icons.image;
                  break;
                case DocumentType.Text:
                  documentIcon = Icons.description;
                  break;
                case DocumentType.Word:
                  documentIcon = Icons.article;
                  break;
                case DocumentType.Other:
                default:
                  documentIcon = Icons.insert_drive_file;
                  break;
              }

              return Card(
                margin: EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withAlpha(20),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(documentIcon, size: 20, color: Colors.blue),
                  ),
                  title: Text(
                    document.name,
                    style: TextStyle(fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    document.description ?? 'Pas de description',
                    style: TextStyle(fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (attachment.isNew && document.type == DocumentType.Image)
                        IconButton(
                          icon: Icon(Icons.visibility, size: 20),
                          onPressed: () => _previewImageDocument(attachment),
                          tooltip: 'Aperçu',
                        ),
                      IconButton(
                        icon: Icon(Icons.delete, size: 20, color: Colors.red),
                        onPressed: () => _removeDocument(index),
                        tooltip: 'Supprimer',
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  void _previewImageDocument(DocumentAttachment attachment) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: Text(attachment.document.name),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Flexible(
              child: Image.file(
                File(attachment.document.path),
                fit: BoxFit.contain,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _removeDocument(int index) {
    setState(() {
      _attachedDocuments.removeAt(index);
    });
  }

  Future<void> _showAddDocumentDialog() async {
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
      _showMessage('Fonctionnalité à venir');
      // TODO: Implémenter la sélection de fichier
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
        await _processCapturedImage(image);
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
        await _processCapturedImage(image);
      }
    } catch (e) {
      Log.e("Erreur lors de la sélection d'image: $e");
      _showErrorMessage("Impossible de sélectionner une image");
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx', 'txt'],
      );

      if (result != null && result.files.isNotEmpty) {
        final file = File(result.files.first.path!);
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

        // Obtenir un nom pour le document
        final docName = await _getDocumentName('Document', fileName);
        if (docName == null) return; // L'utilisateur a annulé

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
        final newFileName = '$uniqueId.$fileExtension';
        final filePath = '${documentsDir.path}/$newFileName';

        // Copier le fichier dans le dossier de l'application
        await file.copy(filePath);

        // Créer le document
        final document = Document(
          id: uniqueId,
          name: docName,
          path: filePath,
          dateAdded: DateTime.now(),
          type: docType,
          description: docDescription,
          size: await file.length(),
        );

        // Ajouter le document à la liste des documents attachés
        setState(() {
          _attachedDocuments.add(DocumentAttachment(
            document: document,
            isNew: true,
          ));
        });

        _showMessage('Document ajouté avec succès');
      }
    } catch (e) {
      Log.e("Erreur lors de la sélection du fichier: $e");
      _showErrorMessage("Impossible de sélectionner le fichier");
    }
  }


  Future<void> _processCapturedImage(XFile image) async {
    try {
      // Obtenir un nom pour le document
      final docName = await _getDocumentName('Image', image.name);
      if (docName == null) return;  // L'utilisateur a annulé

      // Obtenir une description pour le document
      final docDescription = await _getDocumentDescription();

      // Créer un dossier dans l'application pour stocker les images
      final appDir = await getApplicationDocumentsDirectory();
      final documentsDir = Directory('${appDir.path}/documents');
      if (!await documentsDir.exists()) {
        await documentsDir.create(recursive: true);
      }

      // Générer un nom de fichier unique
      final uniqueId = Uuid().v4();
      final fileName = '$uniqueId.jpg';
      final filePath = '${documentsDir.path}/$fileName';

      // Copier l'image dans le dossier de l'application
      final imageFile = File(image.path);
      await imageFile.copy(filePath);

      // Créer le document
      final document = Document(
        id: uniqueId,
        name: docName,
        path: filePath,
        dateAdded: DateTime.now(),
        type: DocumentType.Image,
        description: docDescription,
        size: await imageFile.length(),
      );

      // Ajouter le document à la liste des documents attachés
      setState(() {
        _attachedDocuments.add(DocumentAttachment(
          document: document,
          isNew: true,
        ));
      });

      _showMessage('Image ajoutée avec succès');
    } catch (e) {
      Log.e("Erreur lors du traitement de l'image: $e");
      _showErrorMessage("Impossible de traiter l'image");
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

  Future<void> _addNewEstablishment() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddEstablishmentScreen()),
    );

    if (result == true) {
      // Recharger les établissements
      final dbHelper = DatabaseHelper();
      final establishmentMaps = await dbHelper.getEstablishments();

      setState(() {
        _establishments = establishmentMaps.map((map) => Establishment.fromMap(map)).toList();

        // Sélectionner automatiquement le nouvel établissement (dernier de la liste)
        if (_establishments.isNotEmpty) {
          _selectedEstablishment = _establishments.last;
        }
      });
    }
  }

  Future<void> _addNewDoctor() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddDoctorScreen()),
    );

    if (result != null && result is Doctor) {
      // Le médecin a été ajouté, on le charge dans la liste
      setState(() {
        _doctors.add(result);
        _selectedDoctor = result;
      });
    } else if (result == true) {
      // Recharger les médecins
      final dbHelper = DatabaseHelper();
      final doctorMaps = await dbHelper.getDoctors();

      setState(() {
        _doctors = doctorMaps.map((map) => Doctor.fromMap(map)).toList();

        // Sélectionner automatiquement le nouveau médecin (dernier de la liste)
        if (_doctors.isNotEmpty) {
          _selectedDoctor = _doctors.last;
        }
      });
    }
  }

  Future<void> _selectDate() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(Duration(days: 365)),
      lastDate: DateTime.now().add(Duration(days: 365)),
    );

    if (pickedDate != null && pickedDate != _selectedDate) {
      setState(() {
        _selectedDate = pickedDate;
      });
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );

    if (pickedTime != null && pickedTime != _selectedTime) {
      setState(() {
        _selectedTime = pickedTime;
      });
    }
  }

  Future<void> _saveExamination() async {
    if (_formKey.currentState!.validate() && _selectedEstablishment != null) {
      // Vérifier que si le type est SingleSession, une séance est sélectionnée
      if (_linkType == ExaminationLinkType.SingleSession && _selectedSessionId == null) {
        _showErrorMessage('Veuillez sélectionner une séance');
        return;
      }

      setState(() {
        _isSaving = true;
      });

      try {
        final dbHelper = DatabaseHelper();

        // Combiner date et heure pour la date de l'examen
        DateTime dateTime;

        if (_linkType == ExaminationLinkType.Cycle || widget.examination != null) {
          // Si l'examen est pour le cycle entier ou en mode édition, utiliser la date sélectionnée
          dateTime = DateTime(
            _selectedDate.year,
            _selectedDate.month,
            _selectedDate.day,
            _selectedTime.hour,
            _selectedTime.minute,
          );
        } else {
          // Pour les examens liés aux séances, calculer la date en fonction de la séance
          dateTime = calculateDateTimeFromSession();
        }

        // Sauvegarder d'abord tous les nouveaux documents
        List<Document> savedDocuments = [];
        for (var attachment in _attachedDocuments.where((a) => a.isNew)) {
          final document = attachment.document;
          Log.d("Insertion du nouveau document: ${document.name}");

          // Ajouter le document à la base de données
          final docResult = await dbHelper.insertDocument(document.toMap());
          Log.d("Résultat de l'insertion du document: $docResult");

          if (docResult > 0) {
            savedDocuments.add(document);
          } else {
            Log.e("Échec de l'insertion du document: ${document.name}");
          }
        }

        String examinationId = "";
        bool updateResult = false;

        // Cas spécial: détacher un examen de son groupe
        if (widget.examination != null && widget.detachFromGroup) {
          // On va conserver l'ID de l'examen mais supprimer son groupId
          updateResult = await _createOrUpdateDetachedExamination(dateTime);
          examinationId = widget.examination!.id;
        }
        // En mode édition pour un examen qui fait partie d'un groupe
        else if (widget.examination != null && widget.examination!.examGroupId != null && widget.forAllSessions) {
          // Mettre à jour tous les examens du groupe
          updateResult = await _updateAllExaminationsInGroup(dateTime);
          examinationId = widget.examination!.id;
        } else if (_linkType == ExaminationLinkType.AllSessions) {
          // Créer un examen pour chaque séance
          updateResult = await _createExaminationsForAllSessions(dateTime, savedDocuments);
        } else {
          // Créer ou mettre à jour un seul examen (pour le cycle ou pour une séance)
          final result = await _createOrUpdateSingleExamination(dateTime);
          updateResult = result.success;
          examinationId = result.examinationId;
        }

        if (updateResult && examinationId.isNotEmpty) {
          // Maintenant, lier tous les nouveaux documents à l'examen créé ou mis à jour
          for (var document in savedDocuments) {
            Log.d("Liaison du document ${document.id} à l'examen $examinationId");
            final linkResult = await dbHelper.linkDocumentToEntity('examination', examinationId, document.id);
            Log.d("Résultat de la liaison: $linkResult");

            if (linkResult <= 0) {
              Log.e("Erreur lors de la liaison du document ${document.id} à l'examen $examinationId");
            }
          }

          // Vérifier les liaisons finales
          await dbHelper.verifyDocumentLinks('examination', examinationId);
        }

        _showMessage(widget.examination != null
            ? 'Examen mis à jour avec succès'
            : 'Examen ajouté avec succès');

        Navigator.pop(context, true);
      } catch (e) {
        Log.e("Erreur lors de l'enregistrement de l'examen: $e");
        _showErrorMessage('Erreur lors de l\'enregistrement');
        setState(() {
          _isSaving = false;
        });
      }
    }
  }


  Future<bool> _createOrUpdateDetachedExamination(DateTime dateTime) async {
    final dbHelper = DatabaseHelper();
    final examinationId = widget.examination!.id;

    Log.d("Détachement de l'examen $examinationId de son groupe");

    // Vérifier l'état des documents avant la mise à jour
    await dbHelper.verifyDocumentLinks('examination', examinationId);

    final examinationData = {
      'id': examinationId,
      'cycleId': widget.cycleId,
      'title': _titleController.text.trim(),
      'type': _selectedType.index,
      'otherType': _selectedType == ExaminationType.Autre ? _titleController.text.trim() : null,
      'dateTime': dateTime.toIso8601String(),
      'establishmentId': _selectedEstablishment!.id,
      'doctorId': _selectedDoctor?.id,
      'notes': _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
      'isCompleted': widget.examination?.isCompleted == 1 ? 1 : 0,
      'prereqForSessionId': _linkType == ExaminationLinkType.SingleSession ?
      _selectedSessionId : widget.examination?.prereqForSessionId,
      'examGroupId': null, // Important: mettre à null pour détacher du groupe
    };

    Log.d("Mise à jour de l'examen avec les données: $examinationData");

    try {
      // Mettre à jour l'examen dans la base de données
      int result = await dbHelper.updateExamination(examinationData);
      Log.d("Résultat de la mise à jour de l'examen: $result");

      if (result <= 0) {
        Log.e("Échec de la mise à jour de l'examen: $examinationId");
        return false;
      }

      // Gérer les documents existants
      final existingDocIds = _attachedDocuments
          .where((a) => !a.isNew)
          .map((a) => a.document.id)
          .toSet();

      Log.d("Documents existants à conserver: $existingDocIds");

      // Récupérer tous les documents actuellement liés
      final linkedDocs = await dbHelper.getDocumentsByEntity('examination', examinationId);
      Log.d("Documents actuellement liés: ${linkedDocs.length}");

      for (var docMap in linkedDocs) {
        final docId = docMap['id'] as String;
        Log.d("Vérification du document lié: $docId");

        // Si le document n'est plus dans la liste, supprimer le lien
        if (!existingDocIds.contains(docId)) {
          Log.d("Suppression du lien pour le document: $docId");
          await dbHelper.unlinkDocumentFromEntity('examination', examinationId, docId);
        } else {
          Log.d("Conservation du lien pour le document: $docId");
        }
      }

      return true;
    } catch (e) {
      Log.e("Exception lors de la mise à jour de l'examen détaché: $e");
      return false;
    }
  }

  Future<bool> _updateAllExaminationsInGroup(DateTime baseDateTime) async {
    final dbHelper = DatabaseHelper();
    final String groupId = widget.examination!.examGroupId!;

    try {
      // Récupérer tous les examens du groupe
      final examinationMaps = await dbHelper.getExaminationsByGroup(groupId);

      Log.d("Mise à jour de ${examinationMaps.length} examens du groupe $groupId");

      if (examinationMaps.isEmpty) {
        Log.e("Aucun examen trouvé dans le groupe $groupId");
        return false;
      }

      // Préparer les données de base pour la mise à jour
      final baseExamData = {
        'type': _selectedType.index,
        'otherType': _selectedType == ExaminationType.Autre ? _titleController.text.trim() : null,
        'title': _titleController.text.trim(),
        'establishmentId': _selectedEstablishment!.id,
        'doctorId': _selectedDoctor?.id,
        'notes': _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
      };

      // Pour chaque examen du groupe, mettre à jour ses propriétés
      for (var examinationMap in examinationMaps) {
        final examinationId = examinationMap['id'] as String;

        // Si l'examen fait partie d'un groupe, sa date est calculée par rapport à sa séance
        String? prereqSessionId = examinationMap['prereqForSessionId'] as String?;
        DateTime examDateTime = baseDateTime;

        if (prereqSessionId != null) {
          // Trouver la séance correspondante
          final sessionResult = await dbHelper.getSessionById(prereqSessionId);

          if (sessionResult != null) {
            final sessionDateTime = DateTime.parse(sessionResult['dateTime'] as String);

            // Calculer la nouvelle date en fonction de la relation temporelle
            switch (_timeRelation) {
              case SessionTimeRelation.Before:
                examDateTime = sessionDateTime.subtract(Duration(hours: _timeOffset));
                break;
              case SessionTimeRelation.Same:
                examDateTime = DateTime(
                  sessionDateTime.year,
                  sessionDateTime.month,
                  sessionDateTime.day,
                  _selectedTime.hour,
                  _selectedTime.minute,
                );
                break;
              case SessionTimeRelation.After:
                examDateTime = sessionDateTime.add(Duration(hours: _timeOffset));
                break;
            }
          }
        }

        // Créer la map complète pour cet examen
        final Map<String, dynamic> examinationData = {
          ...baseExamData,
          'id': examinationId,
          'cycleId': widget.cycleId,
          'dateTime': examDateTime.toIso8601String(),
          'isCompleted': examinationMap['isCompleted'], // Garder l'état de complétion d'origine
          'prereqForSessionId': prereqSessionId,
          'examGroupId': groupId, // Conserver le groupId
        };

        // Mettre à jour cet examen
        Log.d("Mise à jour de l'examen $examinationId du groupe");
        int updateResult = await dbHelper.updateExamination(examinationData);

        if (updateResult <= 0) {
          Log.e("Échec de la mise à jour de l'examen $examinationId du groupe");
          continue; // Continuer avec le prochain examen même en cas d'échec
        }

        // Gérer les documents pour chaque examen
        // Les documents existants (non-nouveaux) sont supposés être déjà liés aux examens
        Log.d("Gestion des documents existants pour l'examen $examinationId");

        // Récupérer tous les documents actuellement liés
        final linkedDocs = await dbHelper.getDocumentsByEntity('examination', examinationId);
        final existingDocIds = _attachedDocuments
            .where((a) => !a.isNew)
            .map((a) => a.document.id)
            .toSet();

        // Supprimer les liens des documents qui ont été retirés
        for (var docMap in linkedDocs) {
          final docId = docMap['id'] as String;

          if (!existingDocIds.contains(docId)) {
            Log.d("Suppression du lien pour le document $docId de l'examen $examinationId");
            await dbHelper.unlinkDocumentFromEntity('examination', examinationId, docId);
          }
        }

        // Ajouter des liens pour les documents existants qui ne sont pas encore liés
        for (var docId in existingDocIds) {
          bool isLinked = linkedDocs.any((docMap) => docMap['id'] == docId);

          if (!isLinked) {
            Log.d("Ajout de lien pour le document $docId à l'examen $examinationId");
            await dbHelper.linkDocumentToEntity('examination', examinationId, docId);
          }
        }
      }

      Log.d("Tous les examens du groupe ont été mis à jour avec succès");
      return true;
    } catch (e) {
      Log.e("Erreur lors de la mise à jour des examens du groupe: $e");
      return false;
    }
  }

  DateTime calculateDateTimeFromSession() {
    // Trouver la séance cible
    final Session targetSession = _linkType == ExaminationLinkType.SingleSession
        ? _sessions.firstWhere((s) => s.id == _selectedSessionId)
        : _sessions.first;  // Pour AllSessions, on se base sur la première séance pour l'exemple

    final DateTime sessionDateTime = targetSession.dateTime;

    // Calculer la date en fonction de la relation temporelle
    switch (_timeRelation) {
      case SessionTimeRelation.Before:
        return sessionDateTime.subtract(Duration(hours: _timeOffset));
      case SessionTimeRelation.Same:
      // Même jour que la séance, mais à l'heure spécifiée
        return DateTime(
          sessionDateTime.year,
          sessionDateTime.month,
          sessionDateTime.day,
          _selectedTime.hour,
          _selectedTime.minute,
        );
      case SessionTimeRelation.After:
        return sessionDateTime.add(Duration(hours: _timeOffset));
    }
  }

  Future<bool> _createExaminationsForAllSessions(DateTime dateTime, List<Document> savedDocuments) async {
    final dbHelper = DatabaseHelper();
    int successCount = 0;

    for (var session in _sessions) {
      final examinationId = Uuid().v4();

      // Calculer la date pour cette séance spécifique
      DateTime examDateTime;
      switch (_timeRelation) {
        case SessionTimeRelation.Before:
          examDateTime = session.dateTime.subtract(Duration(hours: _timeOffset));
          break;
        case SessionTimeRelation.Same:
          examDateTime = DateTime(
            session.dateTime.year,
            session.dateTime.month,
            session.dateTime.day,
            _selectedTime.hour,
            _selectedTime.minute,
          );
          break;
        case SessionTimeRelation.After:
          examDateTime = session.dateTime.add(Duration(hours: _timeOffset));
          break;
      }

      final examinationData = {
        'id': examinationId,
        'cycleId': widget.cycleId,
        'title': _titleController.text.trim(),
        'type': _selectedType.index,
        'otherType': _selectedType == ExaminationType.Autre ? _titleController.text.trim() : null,
        'dateTime': examDateTime.toIso8601String(),
        'establishmentId': _selectedEstablishment!.id,
        'doctorId': _selectedDoctor?.id,
        'notes': _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
        'isCompleted': 0,
        'prereqForSessionId': session.id,
        'examGroupId': _examGroupId,
      };

      final result = await dbHelper.insertExamination(examinationData);
      if (result > 0) {
        successCount++;

        // Lier les documents existants à cet examen
        for (var doc in _attachedDocuments.where((a) => !a.isNew)) {
          await dbHelper.linkDocumentToEntity('examination', examinationId, doc.document.id);
        }

        // Lier les nouveaux documents à cet examen
        for (var doc in savedDocuments) {
          await dbHelper.linkDocumentToEntity('examination', examinationId, doc.id);
        }
      }
    }

    if (successCount != _sessions.length) {
      _showErrorMessage('Certains examens n\'ont pas pu être ajoutés');
      return false;
    }

    return true;
  }


  Future<SaveExaminationResult> _createOrUpdateSingleExamination(DateTime dateTime) async {
    final dbHelper = DatabaseHelper();
    final examinationId = widget.examination?.id ?? Uuid().v4();

    final examinationData = {
      'id': examinationId,
      'cycleId': widget.cycleId,
      'title': _titleController.text.trim(),
      'type': _selectedType.index,
      'otherType': _selectedType == ExaminationType.Autre ? _titleController.text.trim() : null,
      'dateTime': dateTime.toIso8601String(),
      'establishmentId': _selectedEstablishment!.id,
      'doctorId': _selectedDoctor?.id,
      'notes': _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
      'isCompleted': widget.examination?.isCompleted == 1 ? 1 : 0,
      'prereqForSessionId': _linkType == ExaminationLinkType.SingleSession ? _selectedSessionId : null,
      'examGroupId': null,
    };

    int result;
    if (widget.examination != null) {
      result = await dbHelper.updateExamination(examinationData);
    } else {
      result = await dbHelper.insertExamination(examinationData);
    }

    if (result > 0) {
      // Gérer les documents existants
      final existingDocIds = _attachedDocuments
          .where((a) => !a.isNew)
          .map((a) => a.document.id)
          .toSet();

      Log.d("Documents existants à conserver: $existingDocIds");

      // Récupérer tous les documents actuellement liés
      final linkedDocs = await dbHelper.getDocumentsByEntity('examination', examinationId);
      Log.d("Documents actuellement liés: ${linkedDocs.length}");

      for (var docMap in linkedDocs) {
        final docId = docMap['id'] as String;
        Log.d("Vérification du document lié: $docId");

        // Si le document n'est plus dans la liste, supprimer le lien
        if (!existingDocIds.contains(docId)) {
          Log.d("Suppression du lien pour le document: $docId");
          await dbHelper.unlinkDocumentFromEntity('examination', examinationId, docId);
        } else {
          Log.d("Conservation du lien pour le document: $docId");
        }
      }
    }

    return SaveExaminationResult(result > 0, examinationId);
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

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }
}

// Classe utilitaire pour gérer les documents attachés
class DocumentAttachment {
  final Document document;
  final bool isNew;  // Si le document est nouvellement créé (pas encore dans la base de données)

  DocumentAttachment({
    required this.document,
    required this.isNew,
  });
}
