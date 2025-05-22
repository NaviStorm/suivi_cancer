// lib/screens/health_professionals_screen.dart
import 'package:flutter/material.dart';
import 'package:suivi_cancer/features/treatment/screens/establishment/add_establishment_screen.dart';
import 'package:suivi_cancer/features/treatment/widgets/establishment/establishment_list_widget.dart';
import 'package:suivi_cancer/features/ps/widgets/ps_list_widget.dart';
import 'package:suivi_cancer/features/ps/screens/edit_ps_creen.dart';
import 'package:suivi_cancer/utils/logger.dart';

class HealthProfessionalsScreen extends StatefulWidget {
  const HealthProfessionalsScreen({super.key});

  @override
  _HealthProfessionalsScreenState createState() =>
      _HealthProfessionalsScreenState();
}

class _HealthProfessionalsScreenState extends State<HealthProfessionalsScreen> {
  // Variable pour forcer la reconstruction
  int _refreshCounter = 0;
  final GlobalKey<EstablishmentListWidgetState> listKey =
      GlobalKey<EstablishmentListWidgetState>();
  final GlobalKey<PSListWidgetState> listKeyPS = GlobalKey<PSListWidgetState>();

  @override
  Widget build(BuildContext context) {
    Log.d('Debut');
    return Scaffold(
      appBar: AppBar(title: Text('Professionnels de Santé')),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Médecins',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              PSListWidget(key: listKeyPS),
              SizedBox(height: 24),
              Text(
                'Établissements',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              EstablishmentListWidget(key: listKey),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showAddOptions(context);
        },
        tooltip: 'Ajouter',
        child: Icon(Icons.add),
      ),
    );
  }

  void _showAddOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder:
          (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(Icons.person_add),
                  title: Text('Ajouter un médecin'),
                  onTap: () async {
                    Navigator.pop(context); // Fermer la bottom sheet
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => AddPSScreen()),
                    );

                    // Rafraîchir l'écran si un médecin a été ajouté
                    if (result == true) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        setState(() {
                          listKeyPS.currentState?.loadPS();
                          // En incrémentant cette variable, nous forçons un rebuild de tout l'écran
                          _refreshCounter++;
                        });
                      });
                    }
                  },
                ),
                ListTile(
                  leading: Icon(Icons.business_center),
                  title: Text('Ajouter un établissement'),
                  onTap: () async {
                    Navigator.pop(context); // Fermer la bottom sheet
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AddEstablishmentScreen(),
                      ),
                    );

                    Log.d('Retour AddEstablishmentScreen result:[$result]');
                    // Rafraîchir l'écran si un établissement a été ajouté
                    if (result == true) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        setState(() {
                          listKey.currentState?.loadEstablishments();
                          _refreshCounter++;
                        });
                      });
                    }
                  },
                ),
              ],
            ),
          ),
    );
  }
}
