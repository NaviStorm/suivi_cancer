import 'package:uuid/uuid.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:suivi_cancer/core/storage/database_helper.dart';
import 'package:suivi_cancer/features/treatment/screens/ps/edit_ps_creen.dart';
import 'package:suivi_cancer/utils/logger.dart';



class HealthProfessionalDetailScreen extends StatefulWidget {
  final String professionalId;
  
  HealthProfessionalDetailScreen({required this.professionalId});
  
  @override
  _HealthProfessionalDetailScreenState createState() => _HealthProfessionalDetailScreenState();
}

class _HealthProfessionalDetailScreenState extends State<HealthProfessionalDetailScreen> {
  Map<String, dynamic>? _professional;
  bool _isLoading = true;
  
  @override
  void initState() {
    Log.d('Début');
    super.initState();
    _loadProfessional();
  }
  
  Future<void> _loadProfessional() async {
    setState(() {
      _isLoading = true;
    });
    
    final professional = await DatabaseHelper().getHealthProfessional(widget.professionalId);
    
    setState(() {
      _professional = professional;
      _isLoading = false;
    });
  }
  
  Future<void> _deleteProfessional() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirmer la suppression'),
        content: Text('Voulez-vous vraiment supprimer ce professionnel de santé ? Cette action est irréversible.'),
        actions: [
          TextButton(
            child: Text('Annuler'),
            onPressed: () => Navigator.pop(context, false),
          ),
          TextButton(
            child: Text('Supprimer', style: TextStyle(color: Colors.red)),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      final result = await DatabaseHelper().deleteHealthProfessional(widget.professionalId);
      
      if (result > 0) {
        Navigator.pop(context, true); // Retourner à l'écran précédent avec résultat
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la suppression')),
        );
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          _isLoading ? 'Chargement...' : '${_professional!['firstName']} ${_professional!['lastName']}',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: IconThemeData(color: Colors.blue),
        actions: [
          IconButton(
            icon: Icon(Icons.edit, color: Colors.blue),
            onPressed: _isLoading
                ? null
                : () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EditPSScreen(
                          ps: _professional,
                        ),
                      ),
                    );
                    
                    if (result == true) {
                      _loadProfessional();
                    }
                  },
          ),
          IconButton(
            icon: Icon(Icons.delete, color: Colors.red),
            onPressed: _isLoading ? null : _deleteProfessional,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // En-tête avec informations principales
                  Container(
                    padding: EdgeInsets.all(16),
                    color: Colors.white,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 30,
                              backgroundColor: Colors.blue[100],
                              child: Text(
                                '${_professional!['firstName'][0]}${_professional!['lastName'][0]}',
                                style: TextStyle(fontSize: 24, color: Colors.blue[800]),
                              ),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${_professional!['firstName']} ${_professional!['lastName']}',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    _professional!['category'] != null
                                        ? _professional!['category']['name']
                                        : 'Catégorie inconnue',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (_professional!['specialtyDetails'] != null &&
                            _professional!['specialtyDetails'].toString().isNotEmpty)
                          Padding(
                            padding: EdgeInsets.only(top: 16),
                            child: Text(
                              _professional!['specialtyDetails'],
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                      ],
                    ),
                  ),
                  
                  SizedBox(height: 16),
                  
                  // Section Contacts
                  if (_professional!['contacts'] != null &&
                      (_professional!['contacts'] as List).isNotEmpty)
                    _buildSection(
                      title: 'Contacts',
                      children: (_professional!['contacts'] as List).map((contact) {
                        IconData icon;
                        String label = contact['label'] ?? '';
                        
                        switch (contact['type']) {
                          case 0:
                            icon = Icons.phone;
                            break;
                          case 1:
                            icon = Icons.email;
                            break;
                          case 2:
                            icon = Icons.print;
                            break;
                          default:
                            icon = Icons.contact_phone;
                        }
                        
                        return ListTile(
                          leading: Icon(icon, color: Colors.blue),
                          title: Text(contact['value']),
                          subtitle: label.isNotEmpty ? Text(label) : null,
                          trailing: contact['isPrimary'] == 1
                              ? Chip(
                                  label: Text('Principal'),
                                  backgroundColor: Colors.blue[50],
                                  labelStyle: TextStyle(fontSize: 12, color: Colors.blue),
                                )
                              : null,
                        );
                      }).toList(),
                    ),
                  
                  SizedBox(height: 16),
                  
                  // Section Adresses
                  if (_professional!['addresses'] != null &&
                      (_professional!['addresses'] as List).isNotEmpty)
                    _buildSection(
                      title: 'Adresses',
                      children: (_professional!['addresses'] as List).map((address) {
                        String formattedAddress = [
                          address['street'],
                          '${address['postalCode']} ${address['city']}',
                          address['country'],
                        ].where((s) => s != null && s.toString().isNotEmpty).join('\n');
                        
                        return ListTile(
                          leading: Icon(Icons.location_on, color: Colors.blue),
                          title: Text(formattedAddress),
                          subtitle: address['label'] != null ? Text(address['label']) : null,
                          trailing: address['isPrimary'] == 1
                              ? Chip(
                                  label: Text('Principal'),
                                  backgroundColor: Colors.blue[50],
                                  labelStyle: TextStyle(fontSize: 12, color: Colors.blue),
                                )
                              : null,
                        );
                      }).toList(),
                    ),
                  
                  SizedBox(height: 16),
                  
                  // Section Établissements
                  if (_professional!['establishments'] != null &&
                      (_professional!['establishments'] as List).isNotEmpty)
                    _buildSection(
                      title: 'Établissements',
                      children: (_professional!['establishments'] as List).map((establishment) {
                        return ListTile(
                          leading: Icon(Icons.business, color: Colors.blue),
                          title: Text(establishment['name']),
                          subtitle: establishment['role'] != null
                              ? Text(establishment['role'])
                              : null,
                        );
                      }).toList(),
                    ),
                  
                  SizedBox(height: 16),
                  
                  // Section Notes
                  if (_professional!['notes'] != null &&
                      _professional!['notes'].toString().isNotEmpty)
                    _buildSection(
                      title: 'Notes',
                      children: [
                        Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(_professional!['notes']),
                        ),
                      ],
                    ),
                  
                  SizedBox(height: 32),
                ],
              ),
            ),
    );
  }
  
  Widget _buildSection({required String title, required List<Widget> children}) {
    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
          ),
          Divider(height: 1),
          ...children,
        ],
      ),
    );
  }
}

