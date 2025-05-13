import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/material.dart';

import 'package:suivi_cancer/features/treatment/models/ps.dart';
import 'package:suivi_cancer/features/treatment/screens/ps/contact.dart';
import 'package:suivi_cancer/features/treatment/screens/ps/list_health_ps.dart';
import 'package:suivi_cancer/features/treatment/screens/ps/list_establishment_selection_dialog.dart';
import 'package:suivi_cancer/core/storage/database_helper.dart';
import 'package:suivi_cancer/common/widgets/custom_text_field.dart';
import 'package:suivi_cancer/common/widgets/date_time_picker.dart';


class EstablishmentSelectionDialog extends StatefulWidget {
  final List<Map<String, dynamic>> allEstablishments;
  final List<Map<String, dynamic>> selectedEstablishments;

  EstablishmentSelectionDialog({
    required this.allEstablishments,
    required this.selectedEstablishments,
  });

  @override
  _EstablishmentSelectionDialogState createState() => _EstablishmentSelectionDialogState();
}

class _EstablishmentSelectionDialogState extends State<EstablishmentSelectionDialog> {
  late List<Map<String, dynamic>> _selectedEstablishments;

  @override
  void initState() {
    super.initState();
    // Créer une copie profonde des établissements sélectionnés
    _selectedEstablishments = List.from(widget.selectedEstablishments);
  }

  bool _isSelected(String establishmentId) {
    return _selectedEstablishments.any((e) => e['id'] == establishmentId);
  }

  void _toggleEstablishment(Map<String, dynamic> establishment) {
    setState(() {
      if (_isSelected(establishment['id'])) {
        _selectedEstablishments.removeWhere((e) => e['id'] == establishment['id']);
      } else {
        // Ajouter avec un rôle vide par défaut
        final Map<String, dynamic> establishmentWithRole = Map.from(establishment);
        establishmentWithRole['role'] = '';
        _selectedEstablishments.add(establishmentWithRole);
      }
    });
  }

  void _updateRole(String establishmentId, String role) {
    setState(() {
      final index = _selectedEstablishments.indexWhere((e) => e['id'] == establishmentId);
      if (index != -1) {
        _selectedEstablishments[index]['role'] = role;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Sélectionner des établissements'),
      content: Container(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.allEstablishments.length,
                itemBuilder: (context, index) {
                  final establishment = widget.allEstablishments[index];
                  final isSelected = _isSelected(establishment['id']);

                  return Column(
                    children: [
                      ListTile(
                        title: Text(establishment['name']),
                        subtitle: establishment['address'] != null
                            ? Text(establishment['address'])
                            : null,
                        leading: Checkbox(
                          value: isSelected,
                          onChanged: (value) {
                            _toggleEstablishment(establishment);
                          },
                        ),
                        onTap: () {
                          _toggleEstablishment(establishment);
                        },
                      ),
                      if (isSelected)
                        Padding(
                          padding: EdgeInsets.only(left: 16, right: 16, bottom: 8),
                          child: TextField(
                            decoration: InputDecoration(
                              labelText: 'Rôle dans cet établissement',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            controller: TextEditingController(
                                text: _selectedEstablishments
                                    .firstWhere((e) => e['id'] == establishment['id'])['role'] ?? ''
                            ),
                            onChanged: (value) {
                              _updateRole(establishment['id'], value);
                            },
                          ),
                        ),
                      Divider(height: 1),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          child: Text('Annuler'),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        ElevatedButton(
          child: Text('Confirmer'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
          onPressed: () {
            Navigator.of(context).pop(_selectedEstablishments);
          },
        ),
      ],
    );
  }
}

