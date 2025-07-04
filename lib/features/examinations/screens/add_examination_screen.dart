// lib/features/treatment/screens/add_examination_screen.dart
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:collection/collection.dart';
import 'package:suivi_cancer/features/treatment/models/session.dart';
// import 'package:suivi_cancer/core/widgets/common/universal_snack_bar.dart'; // Remplacé par CupertinoAlertDialog
import 'package:suivi_cancer/features/treatment/models/ps.dart';
import 'package:suivi_cancer/features/treatment/models/examination.dart';
import 'package:suivi_cancer/features/treatment/models/establishment.dart';
import 'package:suivi_cancer/core/storage/database_helper.dart';
import 'package:suivi_cancer/features/ps/screens/edit_ps_creen.dart';
import 'package:suivi_cancer/features/establishment/screens/add_establishment_screen.dart';
import 'package:suivi_cancer/features/treatment/models/document.dart';
import 'package:suivi_cancer/utils/logger.dart';
import 'package:suivi_cancer/services/document_import_service.dart';

// Enum pour le type de lien
enum ExaminationLinkType { cycle, singleSession, allSessions }

// Enum pour la relation temporelle avec la séance
enum SessionTimeRelation {
  before, // Avant la séance
  same, // Le jour même
  after, // Après la séance
}

class AddExaminationScreen extends StatefulWidget {
  final String cycleId;
  final String? sessionId; // ID de la séance spécifique (si applicable)
  final Examination? examination; // Pour l'édition
  final bool forAllSessions; // Pour créer des examens pour toutes les séances
  final bool
  detachFromGroup; // Nouveau paramètre pour détacher un examen de son groupe

  const AddExaminationScreen({
    super.key,
    required this.cycleId,
    this.sessionId,
    this.examination,
    this.forAllSessions = false,
    this.detachFromGroup = false, // Valeur par défaut
  });

  @override
  State<AddExaminationScreen> createState() => _AddExaminationScreenState();
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

  final DocumentImportService _documentService = DocumentImportService();

  DateTime _selectedDate = DateTime.now();
  DateTime _selectedTime = DateTime.now();
  ExaminationType _selectedType = ExaminationType.PriseDeSang;

  Establishment? _selectedEstablishment;
  List<Establishment> _establishments = [];
  HealthProfessional? _selectedPrescripteur;
  HealthProfessional? _selectedExecutant; // Pour le médecin qui fera l'examen
  List<HealthProfessional> _healthProfessionals = [];

  // Variables pour les sessions et le type de lien
  String? _selectedSessionId;
  List<Session> _sessions = [];
  ExaminationLinkType _linkType = ExaminationLinkType.cycle;
  String? _examGroupId; // ID commun pour les examens liés à toutes les séances

  // Variables pour la relation temporelle avec la séance
  SessionTimeRelation _timeRelation = SessionTimeRelation.before;
  int _timeOffset = 0; // Offset en heures

  // Liste des documents joints
  List<DocumentAttachment> _attachedDocuments = [];

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    Log.d('Ecran d\'ajout d\'un examen : [${widget.examination?.toMap()}]');
    super.initState();

    // Initialiser le type de lien en fonction des paramètres
    if (widget.sessionId != null) {
      _linkType = ExaminationLinkType.singleSession;
      _selectedSessionId = widget.sessionId;
    } else if (widget.forAllSessions) {
      _linkType = ExaminationLinkType.allSessions;
      _examGroupId = Uuid().v4(); // Générer un ID de groupe
    } else {
      _linkType = ExaminationLinkType.cycle;
    }

    // Si on est en mode édition
    if (widget.examination != null) {
      Log.d(
          'widget.examination n\'est pas null : [${widget.examination?.toMap()}]');
      _titleController.text = widget.examination!.title ?? '';
      _notesController.text = widget.examination!.notes ?? '';
      _selectedDate = widget.examination!.dateTime;
      _selectedTime = widget.examination!.dateTime;
      _selectedType = widget.examination!.type;
      _selectedSessionId = widget.examination!.prereqForSessionId;
      _examGroupId = widget.examination!.examGroupId;

      if (_selectedSessionId != null) {
        _linkType = ExaminationLinkType.singleSession;
      } else if (_examGroupId != null) {
        _linkType = ExaminationLinkType.allSessions;
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
      _establishments =
          establishmentMaps.map((map) => Establishment.fromMap(map)).toList();

      // Charger les médecins
      final psMaps = await dbHelper.getPS();
      _healthProfessionals = psMaps.map((map) => HealthProfessional.fromMap(map)).toList();

      // Charger les séances du cycle
      if (_linkType == ExaminationLinkType.singleSession ||
          _linkType == ExaminationLinkType.allSessions) {
        final sessionMaps = await dbHelper.getSessionsByCycle(widget.cycleId);
        _sessions = sessionMaps.map((map) => Session.fromMap(map)).toList();

        // Trier les séances par date
        _sessions.sort((a, b) => a.dateTime.compareTo(b.dateTime));

        // Sélectionner la première séance si aucune n'est sélectionnée
        if (_selectedSessionId == null &&
            _sessions.isNotEmpty &&
            _linkType == ExaminationLinkType.singleSession) {
          _selectedSessionId = _sessions.first.id;
        }
      }

      // Si on est en mode édition, sélectionner l'établissement et le médecin
      if (widget.examination != null) {
        Log.d('widget.examination non NULL');
        _selectedEstablishment = _establishments.firstWhereOrNull(
              (e) => e.id == widget.examination!.establishment.id,
        );

        if (_selectedEstablishment == null && _establishments.isNotEmpty) {
          _selectedEstablishment = _establishments.first;
        }

        if (widget.examination!.prescripteur != null) {
          Log.d('_healthProfessionals:[${_healthProfessionals.toList()}]');
          _selectedPrescripteur = _healthProfessionals.firstWhereOrNull(
                (d) => d.id == widget.examination!.prescripteur!.id,
          );
        } else {
          Log.d(
              'widget.examination.prescripteur est NULL : [${widget.examination?.toMap()}]');
        }

        // Sélectionner l'autre médecin si présent
        if (widget.examination!.executant != null) {
          _selectedExecutant = _healthProfessionals.firstWhereOrNull(
                (ps) => ps.id == widget.examination!.executant!.id,
          );
        }
      } else if (_establishments.isNotEmpty) {
        Log.d('widget.examination est NULL');
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
      final documentMaps = await dbHelper.getDocumentsByEntity(
        'examination',
        widget.examination!.id,
      );

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

  Widget _buildSaveButton() {
    if (_isSaving) {
      return const CupertinoActivityIndicator();
    }
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: _saveExamination,
      child: Text(
        widget.examination != null ? 'Mettre à jour' : 'Enregistrer',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          widget.examination != null
              ? 'Modifier l\'examen'
              : 'Ajouter un examen',
        ),
        trailing: _buildSaveButton(),
      ),
      child: SafeArea(
        child: _isLoading
            ? Center(child: CupertinoActivityIndicator())
            : Form(
          key: _formKey,
          child: ListView(
            padding: EdgeInsets.all(16),
            children: [
              _buildExaminationTypeSelector(),
              SizedBox(height: 16),
              FormField<String>(
                initialValue: _titleController.text,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Veuillez saisir un titre';
                  }
                  return null;
                },
                builder: (field) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Titre',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                      SizedBox(height: 8),
                      CupertinoTextField(
                        controller: _titleController,
                        placeholder: 'ex: Bilan sanguin',
                        onChanged: (value) => field.didChange(value),
                      ),
                      if (field.hasError)
                        Padding(
                          padding: const EdgeInsets.only(top: 5.0),
                          child: Text(
                            field.errorText!,
                            style: TextStyle(
                                color: CupertinoColors.destructiveRed,
                                fontSize: 12),
                          ),
                        )
                    ],
                  );
                },
              ),
              SizedBox(height: 16),
              if (_linkType == ExaminationLinkType.cycle ||
                  widget.examination != null)
                _buildDateTimePicker(),
              if (_linkType != ExaminationLinkType.cycle &&
                  widget.examination == null)
                _buildSessionTimingConfig(),
              SizedBox(height: 16),
              _buildLinkTypeSelector(),
              if (_linkType == ExaminationLinkType.singleSession) ...[
                SizedBox(height: 16),
                _buildSessionSelector(),
                SizedBox(height: 16),
              ],
              _buildEstablishmentSelector(),
              SizedBox(height: 16),
              _buildPrescripteurSelector(),
              SizedBox(height: 16),
              _buildExecutantSelector(),
              SizedBox(height: 16),
              _buildDocumentsSection(),
              SizedBox(height: 16),
              Text(
                'Notes (optionnel)',
                style:
                TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              SizedBox(height: 16),
              CupertinoTextField(
                controller: _notesController,
                placeholder: 'ex: À jeun depuis la veille',
                maxLines: 5,
                minLines: 3,
              ),
              SizedBox(height: 32),
              // Le bouton a été déplacé dans la barre de navigation
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
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildTypeChip(
                ExaminationType.Consult, 'Consul', CupertinoIcons.person_2),
            _buildTypeChip(ExaminationType.PriseDeSang, 'Prise de sang',
                CupertinoIcons.drop),
            _buildTypeChip(
                ExaminationType.Injection, 'Injection', CupertinoIcons.lab_flask),
            _buildTypeChip(
                ExaminationType.Scanner, 'Scanner', CupertinoIcons.pano),
            _buildTypeChip(ExaminationType.IRM, 'IRM', CupertinoIcons.doc_text),
            _buildTypeChip(
                ExaminationType.PETScan, 'PET-Scan', CupertinoIcons.dot_radiowaves_left_right),
            _buildTypeChip(ExaminationType.Radio, 'Radio', CupertinoIcons.photo_camera),
            _buildTypeChip(
                ExaminationType.Echographie, 'Échographie', CupertinoIcons.waveform),
            _buildTypeChip(ExaminationType.EpreuveEffort, 'Épreuve d\'effort',
                CupertinoIcons.heart_fill),
            _buildTypeChip(ExaminationType.EFR, 'EFR', CupertinoIcons.wind),
            _buildTypeChip(
                ExaminationType.Soin, 'Soin', CupertinoIcons.heart_circle),
            _buildTypeChip(
                ExaminationType.Autre, 'Autre', CupertinoIcons.question_circle),
          ],
        ),
      ],
    );
  }

  Widget _buildTypeChip(ExaminationType type, String label, IconData icon) {
    final isSelected = _selectedType == type;

    return CupertinoButton(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: isSelected
          ? CupertinoColors.activeBlue
          : CupertinoColors.tertiarySystemFill,
      onPressed: () {
        setState(() {
          _selectedType = type;
        });
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 16,
              color: isSelected
                  ? CupertinoColors.white
                  : CupertinoColors.activeBlue),
          SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isSelected ? CupertinoColors.white : CupertinoColors.label,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateTimePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Date et heure',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _selectDate,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: CupertinoColors.separator.resolveFrom(context)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        DateFormat('dd/MM/yyyy').format(_selectedDate),
                        style: TextStyle(
                            fontSize: 14, color: CupertinoColors.label),
                      ),
                      Icon(CupertinoIcons.calendar,
                          size: 18,
                          color: CupertinoColors.secondaryLabel
                              .resolveFrom(context)),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _selectTime,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: CupertinoColors.separator.resolveFrom(context)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        DateFormat.Hm().format(_selectedTime),
                        style: TextStyle(
                            fontSize: 14, color: CupertinoColors.label),
                      ),
                      Icon(CupertinoIcons.clock,
                          size: 18,
                          color: CupertinoColors.secondaryLabel
                              .resolveFrom(context)),
                    ],
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
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: FormField<SessionTimeRelation>(
                initialValue: _timeRelation,
                builder: (field) => _buildPickerButton<SessionTimeRelation>(
                  value: _timeRelation,
                  items: SessionTimeRelation.values,
                  itemTextBuilder: (val) {
                    switch (val) {
                      case SessionTimeRelation.before:
                        return 'Avant';
                      case SessionTimeRelation.same:
                        return 'Le jour même';
                      case SessionTimeRelation.after:
                        return 'Après';
                      default:
                        return '';
                    }
                  },
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _timeRelation = value;
                      });
                      field.didChange(value);
                    }
                  },
                ),
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  if (_timeRelation != SessionTimeRelation.same)
                    Expanded(
                      child: FormField<String>(
                        initialValue: _timeOffset.toString(),
                        validator: _timeRelation != SessionTimeRelation.same
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
                        builder: (field) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CupertinoTextField(
                              placeholder: 'Heures',
                              controller:
                              TextEditingController(text: field.value),
                              keyboardType: TextInputType.number,
                              onChanged: (value) {
                                final parsed = int.tryParse(value);
                                if (parsed != null) {
                                  setState(() {
                                    _timeOffset = parsed;
                                  });
                                }
                                field.didChange(value);
                              },
                            ),
                            if (field.hasError)
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text(
                                  field.errorText!,
                                  style: TextStyle(
                                      color: CupertinoColors.destructiveRed,
                                      fontSize: 12),
                                ),
                              )
                          ],
                        ),
                      ),
                    ),
                  if (_timeRelation == SessionTimeRelation.same)
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
            color: CupertinoColors.secondaryLabel.resolveFrom(context),
          ),
        ),
      ],
    );
  }

  String _getTimingDescription() {
    switch (_timeRelation) {
      case SessionTimeRelation.before:
        return 'L\'examen sera planifié $_timeOffset heures avant chaque séance';
      case SessionTimeRelation.same:
        return 'L\'examen sera planifié le jour même de chaque séance';
      case SessionTimeRelation.after:
        return 'L\'examen sera planifié $_timeOffset heures après chaque séance';
    }
  }

  Widget _buildLinkTypeSelector() {
    if (widget.examination != null) {
      return SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Lier cet examen à :',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: CupertinoSegmentedControl<ExaminationLinkType>(
            groupValue: _linkType,
            children: const <ExaminationLinkType, Widget>{
              ExaminationLinkType.cycle: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('Cycle')),
              ExaminationLinkType.singleSession: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('Une séance')),
              ExaminationLinkType.allSessions: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('Toutes')),
            },
            onValueChanged: (value) {
              setState(() {
                _linkType = value;
                if (value == ExaminationLinkType.singleSession) {
                  if (_sessions.isNotEmpty) {
                    _selectedSessionId = _sessions.first.id;
                  }
                } else {
                  _selectedSessionId = null;
                }
                if (value == ExaminationLinkType.allSessions) {
                  _examGroupId ??= Uuid().v4();
                }
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSessionSelector() {
    if (_sessions.isEmpty) {
      return Text(
        'Aucune séance disponible',
        style: TextStyle(color: CupertinoColors.destructiveRed),
      );
    }
    return FormField<String>(
      initialValue: _selectedSessionId,
      validator: (value) {
        if (_linkType == ExaminationLinkType.singleSession && value == null) {
          return 'Veuillez sélectionner une séance';
        }
        return null;
      },
      builder: (field) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Séance',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          SizedBox(height: 8),
          _buildPickerButton<String?>(
            value: _selectedSessionId,
            items: _sessions.map((s) => s.id).toList(),
            itemTextBuilder: (sessionId) {
              if (sessionId == null) return 'Sélectionner une séance';
              final session = _sessions.firstWhere((s) => s.id == sessionId);
              final sessionNumber = _sessions.indexOf(session) + 1;
              final sessionDate =
              DateFormat('dd/MM/yyyy').format(session.dateTime);
              final sessionTime =
              DateFormat('HH:mm').format(session.dateTime);
              return 'Séance $sessionNumber - $sessionDate à $sessionTime';
            },
            onChanged: (value) {
              setState(() {
                _selectedSessionId = value;
              });
              field.didChange(value);
            },
          ),
          if (field.hasError)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                field.errorText!,
                style: TextStyle(
                    color: CupertinoColors.destructiveRed, fontSize: 12),
              ),
            )
        ],
      ),
    );
  }

  Widget _buildEstablishmentSelector() {
    return FormField<Establishment>(
        initialValue: _selectedEstablishment,
        validator: (value) {
          if (value == null) {
            return 'Veuillez sélectionner un établissement';
          }
          return null;
        },
        builder: (field) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Établissement',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _addNewEstablishment,
                    child: Row(
                      children: [
                        Icon(CupertinoIcons.add, size: 16),
                        SizedBox(width: 4),
                        Text('Nouveau', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              _buildPickerButton<Establishment?>(
                value: _selectedEstablishment,
                items: _establishments,
                itemTextBuilder: (est) => est?.name ?? 'Sélectionner...',
                onChanged: (value) {
                  setState(() => _selectedEstablishment = value);
                  field.didChange(value);
                },
              ),
              if (field.hasError)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    field.errorText!,
                    style: TextStyle(
                        color: CupertinoColors.destructiveRed, fontSize: 12),
                  ),
                )
            ],
          );
        });
  }

  Widget _buildPrescripteurSelector() {
    return FormField<HealthProfessional>(
        initialValue: _selectedPrescripteur,
        validator: (value) {
          if (value == null) {
            return 'Veuillez sélectionner un professionnel de santé';
          }
          return null;
        },
        builder: (field) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Professionnel de santé (obligatoire)',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _addNewPS,
                    child: Row(
                      children: [
                        Icon(CupertinoIcons.add, size: 16),
                        SizedBox(width: 4),
                        Text('Nouveau', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              _buildPickerButton<HealthProfessional?>(
                value: _selectedPrescripteur,
                items: _healthProfessionals,
                itemTextBuilder: (ps) => ps?.fullName ?? 'Sélectionner...',
                onChanged: (value) {
                  setState(() => _selectedPrescripteur = value);
                  field.didChange(value);
                },
              ),
              if (field.hasError)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    field.errorText!,
                    style: TextStyle(
                        color: CupertinoColors.destructiveRed, fontSize: 12),
                  ),
                )
            ],
          );
        });
  }

  Widget _buildExecutantSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Médecin réalisant l\'examen (optionnel)',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        SizedBox(height: 8),
        _buildPickerButton<HealthProfessional?>(
          value: _selectedExecutant,
          items: [null, ..._healthProfessionals], // Add null for "Aucun"
          itemTextBuilder: (ps) => ps?.fullName ?? 'Aucun',
          onChanged: (value) {
            setState(() {
              _selectedExecutant = value;
            });
          },
        ),
      ],
    );
  }

  Widget _buildPickerButton<T>({
    required T value,
    required List<T> items,
    required String Function(T) itemTextBuilder,
    required ValueChanged<T?> onChanged,
  }) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () {
        showCupertinoModalPopup(
          context: context,
          builder: (context) => CupertinoActionSheet(
            actions: items
                .map((item) => CupertinoActionSheetAction(
              child: Text(itemTextBuilder(item)),
              onPressed: () {
                onChanged(item);
                Navigator.pop(context);
              },
            ))
                .toList(),
            cancelButton: CupertinoActionSheetAction(
              child: const Text('Annuler'),
              isDefaultAction: true,
              onPressed: () => Navigator.pop(context),
            ),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border:
          Border.all(color: CupertinoColors.separator.resolveFrom(context)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              itemTextBuilder(value),
              style: TextStyle(
                  fontSize: 14,
                  color: value == null
                      ? CupertinoColors.placeholderText
                      : CupertinoColors.label),
            ),
            Icon(CupertinoIcons.chevron_up_chevron_down,
                size: 16,
                color: CupertinoColors.secondaryLabel.resolveFrom(context)),
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
              'Documents (optionnel)',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _showAddDocumentDialog,
              child: Row(
                children: [
                  Icon(CupertinoIcons.add, size: 16),
                  SizedBox(width: 4),
                  Text('Ajouter', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        if (_attachedDocuments.isEmpty)
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(
                  color: CupertinoColors.separator.resolveFrom(context)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                'Aucun document attaché',
                style: TextStyle(
                    fontSize: 14,
                    color: CupertinoColors.secondaryLabel.resolveFrom(context)),
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
                  documentIcon = CupertinoIcons.doc_chart;
                  break;
                case DocumentType.Image:
                  documentIcon = CupertinoIcons.photo;
                  break;
                case DocumentType.Text:
                  documentIcon = CupertinoIcons.doc_text;
                  break;
                case DocumentType.Word:
                  documentIcon = CupertinoIcons.doc_richtext;
                  break;
                case DocumentType.Other:
                  documentIcon = CupertinoIcons.doc;
                  break;
              }

              return Container(
                margin: EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: CupertinoColors.tertiarySystemGroupedBackground
                      .resolveFrom(context),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: CupertinoListTile(
                  leading: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: CupertinoColors.activeBlue.withAlpha(40),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(documentIcon,
                        size: 20, color: CupertinoColors.activeBlue),
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
                      if (attachment.isNew &&
                          document.type == DocumentType.Image)
                        CupertinoButton(
                          padding: EdgeInsets.all(4),
                          child: Icon(CupertinoIcons.eye, size: 20),
                          onPressed: () => _previewImageDocument(attachment),
                        ),
                      CupertinoButton(
                        padding: EdgeInsets.all(4),
                        child: Icon(CupertinoIcons.delete,
                            size: 20, color: CupertinoColors.destructiveRed),
                        onPressed: () => _removeDocument(index),
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
    _documentService.viewImageDocument(context, attachment.document);
  }

  void _removeDocument(int index) {
    setState(() {
      _attachedDocuments.removeAt(index);
    });
  }

  Future _showAddDocumentDialog() async {
    final action = await showCupertinoModalPopup<String>(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        title: const Text('Ajouter un document'),
        message: const Text('Choisir la source du document'),
        actions: <CupertinoActionSheetAction>[
          CupertinoActionSheetAction(
            child: const Text('Prendre une photo'),
            onPressed: () {
              Navigator.pop(context, 'camera');
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('Choisir une image'),
            onPressed: () {
              Navigator.pop(context, 'gallery');
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('Choisir un fichier'),
            onPressed: () {
              Navigator.pop(context, 'file');
            },
          )
        ],
        cancelButton: CupertinoActionSheetAction(
          child: const Text('Annuler'),
          isDefaultAction: true,
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
    );

    if (!mounted) return;
    if (action == null) return;

    Document? document;
    if (action == 'camera') {
      document = await _documentService.takePicture(context);
    } else if (action == 'gallery') {
      document = await _documentService.pickImage(context);
    } else if (action == 'file') {
      document = await _documentService.pickFile(context);
    }

    if (!mounted) return;
    if (document != null) {
      setState(() {
        _attachedDocuments.add(
          DocumentAttachment(document: document!, isNew: true),
        );
      });
    }
  }

  Future<void> _addNewEstablishment() async {
    final result = await Navigator.push(
      context,
      CupertinoPageRoute(builder: (context) => AddEstablishmentScreen()),
    );

    if (result == true) {
      final dbHelper = DatabaseHelper();
      final establishmentMaps = await dbHelper.getEstablishments();

      setState(() {
        _establishments =
            establishmentMaps.map((map) => Establishment.fromMap(map)).toList();
        if (_establishments.isNotEmpty) {
          _selectedEstablishment = _establishments.last;
        }
      });
    }
  }

  Future<void> _addNewPS() async {
    final result = await Navigator.push(
      context,
      CupertinoPageRoute(builder: (context) => AddPSScreen()),
    );
    if (result != null && result is HealthProfessional) {
      setState(() {
        _healthProfessionals.add(result);
        _selectedPrescripteur = result;
      });
    } else if (result == true) {
      final dbHelper = DatabaseHelper();
      final psMaps = await dbHelper.getPS();
      setState(() {
        _healthProfessionals = psMaps.map((map) => HealthProfessional.fromMap(map)).toList();
        if (_healthProfessionals.isNotEmpty) {
          _selectedPrescripteur = _healthProfessionals.last;
        }
      });
    }
  }

  Future<void> _selectDate() async {
    DateTime tempPickedDate = _selectedDate;
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) => Container(
        height: 250,
        padding: const EdgeInsets.only(top: 6.0),
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CupertinoButton(
                  child: const Text('Annuler'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                CupertinoButton(
                  child: const Text('Valider'),
                  onPressed: () {
                    setState(() {
                      _selectedDate = tempPickedDate;
                    });
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: _selectedDate,
                onDateTimeChanged: (DateTime newDate) {
                  tempPickedDate = newDate;
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectTime() async {
    DateTime tempPickedTime = _selectedTime;
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) => Container(
        height: 250,
        padding: const EdgeInsets.only(top: 6.0),
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CupertinoButton(
                  child: const Text('Annuler'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                CupertinoButton(
                  child: const Text('Valider'),
                  onPressed: () {
                    setState(() {
                      _selectedTime = tempPickedTime;
                    });
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.time,
                use24hFormat: true,
                initialDateTime: _selectedTime,
                onDateTimeChanged: (DateTime newDate) {
                  tempPickedTime = newDate;
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveExamination() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSaving = true;
      });

      try {
        final dbHelper = DatabaseHelper();

        // Combiner date et heure pour la date de l'examen
        DateTime dateTime;

        if (_linkType == ExaminationLinkType.cycle ||
            widget.examination != null) {
          dateTime = DateTime(
            _selectedDate.year,
            _selectedDate.month,
            _selectedDate.day,
            _selectedTime.hour,
            _selectedTime.minute,
          );
        } else {
          dateTime = calculateDateTimeFromSession();
        }

        // Sauvegarder d'abord tous les nouveaux documents
        List<Document> savedDocuments = [];
        for (var attachment in _attachedDocuments.where((a) => a.isNew)) {
          final document = attachment.document;
          Log.d("Insertion du nouveau document: ${document.name}");

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

        if (widget.examination != null && widget.detachFromGroup) {
          updateResult = await _createOrUpdateDetachedExamination(dateTime);
          examinationId = widget.examination!.id;
        } else if (widget.examination != null &&
            widget.examination!.examGroupId != null &&
            widget.forAllSessions) {
          updateResult = await _updateAllExaminationsInGroup(dateTime);
          examinationId = widget.examination!.id;
        } else if (_linkType == ExaminationLinkType.allSessions) {
          updateResult = await _createExaminationsForAllSessions(
            dateTime,
            savedDocuments,
          );
        } else {
          final result = await _createOrUpdateSingleExamination(dateTime);
          updateResult = result.success;
          examinationId = result.examinationId;
        }

        if (updateResult && examinationId.isNotEmpty) {
          for (var document in savedDocuments) {
            Log.d(
              "Liaison du document ${document.id} à l'examen $examinationId",
            );
            final linkResult = await dbHelper.linkDocumentToEntity(
              'examination',
              examinationId,
              document.id,
            );
            Log.d("Résultat de la liaison: $linkResult");

            if (linkResult <= 0) {
              Log.e(
                "Erreur lors de la liaison du document ${document.id} à l'examen $examinationId",
              );
            }
          }
          await dbHelper.verifyDocumentLinks('examination', examinationId);
        }

        // La sauvegarde est terminée, on retourne à l'écran précédent avec un succès.
        if (mounted) {
          Navigator.pop(context, true);
        }

      } catch (e) {
        Log.e("Erreur lors de l'enregistrement de l'examen: $e");
        if (mounted) {
          setState(() {
            _isSaving = false;
          });
          _showErrorMessage('Erreur lors de l\'enregistrement');
        }
      }
    }
  }

  Future<bool> _createOrUpdateDetachedExamination(DateTime dateTime) async {
    final dbHelper = DatabaseHelper();
    final examinationId = widget.examination!.id;

    Log.d("Détachement de l'examen $examinationId de son groupe");

    await dbHelper.verifyDocumentLinks('examination', examinationId);

    final examinationData = {
      'id': examinationId,
      'cycleId': widget.cycleId,
      'title': _titleController.text.trim(),
      'type': _selectedType.index,
      'otherType': _selectedType == ExaminationType.Autre
          ? _titleController.text.trim()
          : null,
      'dateTime': dateTime.toIso8601String(),
      'establishmentId': _selectedEstablishment!.id,
      'prescripteurId': _selectedPrescripteur?.id,
      'executantId': _selectedExecutant?.id,
      'notes': _notesController.text.trim().isNotEmpty
          ? _notesController.text.trim()
          : null,
      'isCompleted': widget.examination?.isCompleted == 1 ? 1 : 0,
      'prereqForSessionId': _linkType == ExaminationLinkType.singleSession
          ? _selectedSessionId
          : widget.examination?.prereqForSessionId,
      'examGroupId': null,
    };

    Log.d("Mise à jour de l'examen avec les données: $examinationData");

    try {
      int result = await dbHelper.updateExamination(examinationData);
      Log.d("Résultat de la mise à jour de l'examen: $result");

      if (result <= 0) {
        Log.e("Échec de la mise à jour de l'examen: $examinationId");
        return false;
      }

      final existingDocIds = _attachedDocuments
          .where((a) => !a.isNew)
          .map((a) => a.document.id)
          .toSet();

      Log.d("Documents existants à conserver: $existingDocIds");

      final linkedDocs = await dbHelper.getDocumentsByEntity(
        'examination',
        examinationId,
      );
      Log.d("Documents actuellement liés: ${linkedDocs.length}");

      for (var docMap in linkedDocs) {
        final docId = docMap['id'] as String;
        Log.d("Vérification du document lié: $docId");

        if (!existingDocIds.contains(docId)) {
          Log.d("Suppression du lien pour le document: $docId");
          await dbHelper.unlinkDocumentFromEntity(
            'examination',
            examinationId,
            docId,
          );
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
      final examinationMaps = await dbHelper.getExaminationsByGroup(groupId);

      Log.d(
        "Mise à jour de ${examinationMaps.length} examens du groupe $groupId",
      );

      if (examinationMaps.isEmpty) {
        Log.e("Aucun examen trouvé dans le groupe $groupId");
        return false;
      }

      final baseExamData = {
        'type': _selectedType.index,
        'otherType': _selectedType == ExaminationType.Autre
            ? _titleController.text.trim()
            : null,
        'title': _titleController.text.trim(),
        'establishmentId': _selectedEstablishment!.id,
        'prescripteurId': _selectedPrescripteur?.id,
        'executantId': _selectedExecutant?.id,
        'notes': _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
      };

      for (var examinationMap in examinationMaps) {
        final examinationId = examinationMap['id'] as String;

        String? prereqSessionId =
        examinationMap['prereqForSessionId'] as String?;
        DateTime examDateTime = baseDateTime;

        if (prereqSessionId != null) {
          final sessionResult = await dbHelper.getSessionById(prereqSessionId);

          if (sessionResult != null) {
            final sessionDateTime = DateTime.parse(
              sessionResult['dateTime'] as String,
            );

            switch (_timeRelation) {
              case SessionTimeRelation.before:
                examDateTime = sessionDateTime.subtract(
                  Duration(hours: _timeOffset),
                );
                break;
              case SessionTimeRelation.same:
                examDateTime = DateTime(
                  sessionDateTime.year,
                  sessionDateTime.month,
                  sessionDateTime.day,
                  _selectedTime.hour,
                  _selectedTime.minute,
                );
                break;
              case SessionTimeRelation.after:
                examDateTime = sessionDateTime.add(
                  Duration(hours: _timeOffset),
                );
                break;
            }
          }
        }

        final Map<String, dynamic> examinationData = {
          ...baseExamData,
          'id': examinationId,
          'cycleId': widget.cycleId,
          'dateTime': examDateTime.toIso8601String(),
          'isCompleted': examinationMap[
          'isCompleted'],
          'prereqForSessionId': prereqSessionId,
          'examGroupId': groupId,
        };

        Log.d("Mise à jour de l'examen $examinationId du groupe");
        int updateResult = await dbHelper.updateExamination(examinationData);

        if (updateResult <= 0) {
          Log.e("Échec de la mise à jour de l'examen $examinationId du groupe");
          continue;
        }

        Log.d("Gestion des documents existants pour l'examen $examinationId");

        final linkedDocs = await dbHelper.getDocumentsByEntity(
          'examination',
          examinationId,
        );
        final existingDocIds = _attachedDocuments
            .where((a) => !a.isNew)
            .map((a) => a.document.id)
            .toSet();

        for (var docMap in linkedDocs) {
          final docId = docMap['id'] as String;

          if (!existingDocIds.contains(docId)) {
            Log.d(
              "Suppression du lien pour le document $docId de l'examen $examinationId",
            );
            await dbHelper.unlinkDocumentFromEntity(
              'examination',
              examinationId,
              docId,
            );
          }
        }

        for (var docId in existingDocIds) {
          bool isLinked = linkedDocs.any((docMap) => docMap['id'] == docId);

          if (!isLinked) {
            Log.d(
              "Ajout de lien pour le document $docId à l'examen $examinationId",
            );
            await dbHelper.linkDocumentToEntity(
              'examination',
              examinationId,
              docId,
            );
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
    final Session targetSession =
    _linkType == ExaminationLinkType.singleSession
        ? _sessions.firstWhere((s) => s.id == _selectedSessionId)
        : _sessions
        .first;

    final DateTime sessionDateTime = targetSession.dateTime;

    switch (_timeRelation) {
      case SessionTimeRelation.before:
        return sessionDateTime.subtract(Duration(hours: _timeOffset));
      case SessionTimeRelation.same:
        return DateTime(
          sessionDateTime.year,
          sessionDateTime.month,
          sessionDateTime.day,
          _selectedTime.hour,
          _selectedTime.minute,
        );
      case SessionTimeRelation.after:
        return sessionDateTime.add(Duration(hours: _timeOffset));
    }
  }

  Future<bool> _createExaminationsForAllSessions(
      DateTime dateTime,
      List<Document> savedDocuments,
      ) async {
    final dbHelper = DatabaseHelper();
    int successCount = 0;

    for (var session in _sessions) {
      final examinationId = Uuid().v4();

      DateTime examDateTime;
      switch (_timeRelation) {
        case SessionTimeRelation.before:
          examDateTime = session.dateTime.subtract(
            Duration(hours: _timeOffset),
          );
          break;
        case SessionTimeRelation.same:
          examDateTime = DateTime(
            session.dateTime.year,
            session.dateTime.month,
            session.dateTime.day,
            _selectedTime.hour,
            _selectedTime.minute,
          );
          break;
        case SessionTimeRelation.after:
          examDateTime = session.dateTime.add(Duration(hours: _timeOffset));
          break;
      }

      final examinationData = {
        'id': examinationId,
        'cycleId': widget.cycleId,
        'title': _titleController.text.trim(),
        'type': _selectedType.index,
        'otherType': _selectedType == ExaminationType.Autre
            ? _titleController.text.trim()
            : null,
        'dateTime': examDateTime.toIso8601String(),
        'establishmentId': _selectedEstablishment!.id,
        'prescripteurId': _selectedPrescripteur?.id,
        'executantId': _selectedExecutant?.id,
        'notes': _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
        'isCompleted': 0,
        'prereqForSessionId': session.id,
        'examGroupId': _examGroupId,
      };

      final result = await dbHelper.insertExamination(examinationData);
      if (result > 0) {
        successCount++;

        for (var doc in _attachedDocuments.where((a) => !a.isNew)) {
          await dbHelper.linkDocumentToEntity(
            'examination',
            examinationId,
            doc.document.id,
          );
        }

        for (var doc in savedDocuments) {
          await dbHelper.linkDocumentToEntity(
            'examination',
            examinationId,
            doc.id,
          );
        }
      }
    }

    if (successCount != _sessions.length) {
      _showErrorMessage('Certains examens n\'ont pas pu être ajoutés');
      return false;
    }

    return true;
  }

  Future<SaveExaminationResult> _createOrUpdateSingleExamination(
      DateTime dateTime,
      ) async {
    final dbHelper = DatabaseHelper();
    final examinationId = widget.examination?.id ?? Uuid().v4();

    final examinationData = {
      'id': examinationId,
      'cycleId': widget.cycleId,
      'title': _titleController.text.trim(),
      'type': _selectedType.index,
      'otherType': _selectedType == ExaminationType.Autre
          ? _titleController.text.trim()
          : null,
      'dateTime': dateTime.toIso8601String(),
      'establishmentId': _selectedEstablishment!.id,
      'prescripteurId': _selectedPrescripteur?.id,
      'executantId': _selectedExecutant?.id,
      'notes': _notesController.text.trim().isNotEmpty
          ? _notesController.text.trim()
          : null,
      'isCompleted': widget.examination?.isCompleted == 1 ? 1 : 0,
      'prereqForSessionId': _linkType == ExaminationLinkType.singleSession
          ? _selectedSessionId
          : null,
      'examGroupId': null,
    };

    int result;
    if (widget.examination != null) {
      result = await dbHelper.updateExamination(examinationData);
    } else {
      result = await dbHelper.insertExamination(examinationData);
    }

    if (result > 0) {
      final existingDocIds = _attachedDocuments
          .where((a) => !a.isNew)
          .map((a) => a.document.id)
          .toSet();

      Log.d("Documents existants à conserver: $existingDocIds");

      final linkedDocs = await dbHelper.getDocumentsByEntity(
        'examination',
        examinationId,
      );
      Log.d("Documents actuellement liés: ${linkedDocs.length}");

      for (var docMap in linkedDocs) {
        final docId = docMap['id'] as String;
        Log.d("Vérification du document lié: $docId");

        if (!existingDocIds.contains(docId)) {
          Log.d("Suppression du lien pour le document: $docId");
          await dbHelper.unlinkDocumentFromEntity(
            'examination',
            examinationId,
            docId,
          );
        } else {
          Log.d("Conservation du lien pour le document: $docId");
        }
      }
    }

    return SaveExaminationResult(result > 0, examinationId);
  }

  void _showCupertinoAlert(String title, {String? content}) {
    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) => CupertinoAlertDialog(
        title: Text(title),
        content: content != null ? Text(content) : null,
        actions: <CupertinoDialogAction>[
          CupertinoDialogAction(
            child: const Text('OK'),
            isDefaultAction: true,
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  void _showErrorMessage(String message) {
    _showCupertinoAlert('Erreur', content: message);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }
}

class DocumentAttachment {
  final Document document;
  final bool
  isNew;

  DocumentAttachment({required this.document, required this.isNew});
}