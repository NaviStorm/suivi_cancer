// lib/screens/health_professionals_screen.dart
import 'package:flutter/material.dart';
import 'package:suivi_cancer/features/treatment/screens/doctor/add_doctor_screen.dart';
import 'package:suivi_cancer/features/treatment/screens/establishment/add_establishment_screen.dart';
import 'package:suivi_cancer/features/treatment/widgets/doctor/doctor_list_widget.dart';
import 'package:suivi_cancer/features/treatment/widgets/establishment/establishment_list_widget.dart';

class HealthProfessionalsScreen extends StatefulWidget {
  @override
  _HealthProfessionalsScreenState createState() => _HealthProfessionalsScreenState();
}

class _HealthProfessionalsScreenState extends State<HealthProfessionalsScreen> {
  // Variable pour forcer la reconstruction
  int _refreshCounter = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Professionnels de Santé'),
      ),
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
              DoctorListWidget(),
              SizedBox(height: 24),
              Text(
                'Établissements',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              EstablishmentListWidget(),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showAddOptions(context);
        },
        child: Icon(Icons.add),
        tooltip: 'Ajouter',
      ),
    );
  }

  void _showAddOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
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
                  MaterialPageRoute(builder: (context) => AddDoctorScreen()),
                );

                // Rafraîchir l'écran si un médecin a été ajouté
                if (result == true) {
                  setState(() {
                    // En incrémentant cette variable, nous forçons un rebuild de tout l'écran
                    _refreshCounter++;
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
                  MaterialPageRoute(builder: (context) => AddEstablishmentScreen()),
                );

                // Rafraîchir l'écran si un établissement a été ajouté
                if (result == true) {
                  setState(() {
                    _refreshCounter++;
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



