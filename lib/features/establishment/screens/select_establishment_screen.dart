// lib/features/treatment/screens/select_establishment_screen.dart
import 'package:flutter/material.dart';
import 'package:suivi_cancer/features/treatment/models/establishment.dart';
import 'package:suivi_cancer/utils/logger.dart';
import 'package:suivi_cancer/features/treatment/services/treatment_service.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class SelectEstablishmentScreen extends StatefulWidget {
  const SelectEstablishmentScreen({super.key});

  @override
  _SelectEstablishmentScreenState createState() =>
      _SelectEstablishmentScreenState();
}

class _SelectEstablishmentScreenState extends State<SelectEstablishmentScreen> {
  List<Establishment> _establishments = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadEstablishments();
  }

  Future<void> _loadEstablishments() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final establishments = await TreatmentService.getAllEstablishments();
      setState(() {
        _establishments = establishments;
        _isLoading = false;
      });
    } catch (e) {
      Log.d(
        "SelectEstablishmentScreen: Erreur lors du chargement des établissements: $e",
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<Establishment> get _filteredEstablishments {
    if (_searchQuery.isEmpty) {
      return _establishments;
    }

    final query = _searchQuery.toLowerCase();
    return _establishments.where((establishment) {
      return establishment.name.toLowerCase().contains(query) ||
          (establishment.city != null &&
              establishment.city!.toLowerCase().contains(query));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Sélectionner un établissement')),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                labelText: 'Rechercher un établissement',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          Expanded(
            child:
                _isLoading
                    ? Center(child: CircularProgressIndicator())
                    : _filteredEstablishments.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                      itemCount: _filteredEstablishments.length,
                      itemBuilder: (context, index) {
                        final establishment = _filteredEstablishments[index];
                        return ListTile(
                          leading: Icon(Icons.business),
                          title: Text(establishment.name),
                          subtitle: Text(
                            [
                                  establishment.address,
                                  establishment.postalCode,
                                  establishment.city,
                                ]
                                .where((s) => s != null && s.isNotEmpty)
                                .join(', '),
                          ),
                          onTap: () {
                            Navigator.pop(context, establishment);
                          },
                        );
                      },
                    ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNewEstablishment,
        tooltip: 'Ajouter un nouvel établissement',
        child: Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FaIcon(
            FontAwesomeIcons.buildingUser, // Icône d'établissement
            size: 80,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            'Aucun établissement trouvé',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'Ajoutez un nouvel établissement en cliquant sur le bouton +',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Future<void> _addNewEstablishment() async {
    final establishment = await TreatmentService.addEstablishment(context);
    if (establishment != null) {
      _loadEstablishments();
    }
  }
}
