import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:suivi_cancer/features/treatment/screens/ps/edit_ps_creen.dart';
import 'package:suivi_cancer/features/treatment/screens/ps/detail_health_ps.dart';
import 'package:suivi_cancer/core/storage/database_helper.dart';


class HealthProfessionalsListScreen extends StatefulWidget {
  @override
  _HealthProfessionalsListScreenState createState() => _HealthProfessionalsListScreenState();
}

class _HealthProfessionalsListScreenState extends State<HealthProfessionalsListScreen> {
  List<Map<String, dynamic>> _professionals = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfessionals();
  }

  Future<void> _loadProfessionals() async {
    setState(() {
      _isLoading = true;
    });
    
    final professionals = await DatabaseHelper().getPS();
    
    setState(() {
      _professionals = professionals;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50], // Fond clair style iOS
      appBar: AppBar(
        title: Text('Professionnels de santé', 
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: IconThemeData(color: Colors.blue),
        actions: [
          IconButton(
            icon: Icon(Icons.add, color: Colors.blue),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditPSScreen(),
                ),
              );
              
              if (result == true) {
                _loadProfessionals();
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _professionals.isEmpty
              ? Center(
                  child: Text(
                    'Aucun professionnel de santé',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                )
              : ListView.separated(
                  itemCount: _professionals.length,
                  separatorBuilder: (context, index) => Divider(height: 1),
                  itemBuilder: (context, index) {
                    final professional = _professionals[index];
                    final category = professional['category'] != null
                        ? professional['category']['name']
                        : 'Catégorie inconnue';
                    
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue[100],
                        child: Text(
                          '${professional['firstName'][0]}${professional['lastName'][0]}',
                          style: TextStyle(color: Colors.blue[800]),
                        ),
                      ),
                      title: Text(
                        '${professional['firstName']} ${professional['lastName']}',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: Text(category),
                      trailing: Icon(Icons.chevron_right, color: Colors.grey),
                      onTap: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => HealthProfessionalDetailScreen(
                              professionalId: professional['id'],
                            ),
                          ),
                        );
                        
                        if (result == true) {
                          _loadProfessionals();
                        }
                      },
                    );
                  },
                ),
    );
  }
}

