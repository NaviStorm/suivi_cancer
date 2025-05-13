// lib/widgets/doctor_list_widget.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:suivi_cancer/features/treatment/models/doctor.dart';
import 'package:suivi_cancer/features/treatment/models/ps.dart'; // Nouveau modèle
import 'package:suivi_cancer/core/storage/database_helper.dart';
import 'package:suivi_cancer/features/treatment/screens/doctor/edit_doctor_screen.dart';
import 'package:suivi_cancer/features/treatment/screens/ps/edit_ps_creen.dart';


class DoctorListWidget extends StatefulWidget {
  const DoctorListWidget({Key? key}) : super(key: key);

  @override
  State<DoctorListWidget> createState() => DoctorListWidgetState();
}

class DoctorListWidgetState extends State<DoctorListWidget> {
  List<PS> _professionals = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    loadPS();
  }

  Future<void> loadPS() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final dbHelper = DatabaseHelper();
      final psMaps = await dbHelper.getPS();

      if (!mounted) return;
      setState(() {
        _professionals = psMaps.map((map) => PS.fromMap(map)).toList();
        _isLoading = false;
      });

      // Débogage
      for (var professional in _professionals) {
        print("Professionnel: ${professional.fullName}");
        print("Contacts: ${professional.contacts?.length ?? 0}");
        if (professional.contacts != null) {
          for (var contact in professional.contacts!) {
            print(" - ${contact.type}: ${contact.value}");
          }
        }
      }
    } catch (e) {
      print('Erreur lors du chargement des professionnels: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _professionals = [];
      });
    }
  }

  void _editPS(PS professional) async {
    final psMap = professional.toMap();

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditPSScreen(ps: psMap),
      ),
    );

    if (result == true) {
      loadPS();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (_professionals.isEmpty) {
      return Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(
            child: Text(
              'Aucun professionnel de santé ajouté',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: _professionals.length,
      itemBuilder: (context, index) {
        final professional = _professionals[index];

        // Trouver les contacts de téléphone et email
        final phoneContacts = professional.contacts
            ?.where((contact) => contact.type == 0) // Type téléphone
            .toList() ?? [];
        final emailContacts = professional.contacts
            ?.where((contact) => contact.type == 1) // Type email
            .toList() ?? [];

        final bool hasPhone = phoneContacts.isNotEmpty;
        final bool hasEmail = emailContacts.isNotEmpty;

        return Card(
          margin: EdgeInsets.only(bottom: 8),
          child: ListTile(
            title: Text(professional.fullName),
            subtitle: Text(professional.category?['name'] ?? 'Catégorie non spécifiée'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icône de téléphone
                IconButton(
                  icon: Icon(
                    Icons.phone,
                    color: hasPhone ? Colors.blue : Colors.grey,
                  ),
                  onPressed: hasPhone
                      ? () => _showContactOptions(context, phoneContacts, 0)
                      : null,
                ),
                // Icône d'email
                IconButton(
                  icon: Icon(
                    Icons.email,
                    color: hasEmail ? Colors.blue : Colors.grey,
                  ),
                  onPressed: hasEmail
                      ? () => _showContactOptions(context, emailContacts, 1)
                      : null,
                ),
                // Icône de modification
                IconButton(
                  icon: Icon(Icons.edit, color: Colors.blue),
                  onPressed: () => _editPS(professional),
                ),
                // Icône de suppression
                IconButton(
                  icon: Icon(Icons.delete, color: Colors.red),
                  onPressed: () {
                    _confirmDelete(context, professional);
                  },
                ),
              ],
            ),
            onTap: () {
              // Navigation vers les détails du professionnel
            },
          ),
        );
      },
    );
  }


  // Afficher une liste d'options si plusieurs contacts sont disponibles
  void _showContactOptions(BuildContext context, List<HealthProfessionalContact> contacts, int type) {
    if (contacts.isEmpty) return;

    if (contacts.length == 1) {
      // S'il n'y a qu'un seul contact, l'utiliser directement
      if (type == 0) { // Téléphone
        _makePhoneCall(contacts[0].value);
      } else if (type == 1) { // Email
        _sendEmail(contacts[0].value);
      }
      return;
    }

    // S'il y a plusieurs contacts, afficher une liste d'options
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                type == 0 ? 'Choisir un numéro de téléphone' : 'Choisir un email',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Divider(),
            ...contacts.map((contact) => ListTile(
              leading: Icon(
                type == 0 ? Icons.phone : Icons.email,
                color: Colors.blue,
              ),
              title: Text(contact.value),
              subtitle: Text(contact.label ?? 'Non spécifié'),
              onTap: () {
                Navigator.pop(context);
                if (type == 0) {
                  _makePhoneCall(contact.value);
                } else if (type == 1) {
                  _sendEmail(contact.value);
                }
              },
            )),
          ],
        ),
      ),
    );
  }

  // Fonction pour obtenir le texte correspondant à la catégorie
  String _getCategoryText(ContactCategory category) {
    switch (category) {
      case ContactCategory.Cabinet:
        return 'Cabinet';
      case ContactCategory.Hopital:
        return 'Hôpital';
      case ContactCategory.Personnel:
        return 'Personnel';
      case ContactCategory.Autre:
        return 'Autre';
      default:
        return 'Non spécifié';
    }
  }

  // Fonction pour passer un appel téléphonique
  void _makePhoneCall(String phoneNumber) async {
    final Uri uri = Uri.parse('tel:$phoneNumber');
    try {
      await launchUrl(uri);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible de passer un appel au $phoneNumber')),
      );
    }
  }

  // Fonction pour envoyer un email
  void _sendEmail(String email) async {
    final Uri uri = Uri.parse('mailto:$email');
    try {
      await launchUrl(uri);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible d\'envoyer un email à $email')),
      );
    }
  }

  void _confirmDelete(BuildContext context, PS professional) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Supprimer ce professionnel?'),
        content: Text(
            'Êtes-vous sûr de vouloir supprimer ${professional.firstName} ${professional.lastName}? Cette action est irréversible.'
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text('Annuler'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deletePS(professional.id);
            },
            child: Text('Supprimer'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
          ),
        ],
      ),
    );
  }


  Future<void> _deletePS(String id) async {
    try {
      final dbHelper = DatabaseHelper();
      await dbHelper.deleteHealthProfessional(id);
      // Rafraîchir la liste après suppression
      loadPS();
      // Afficher un message de confirmation
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Professionnel supprimé avec succès')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la suppression: $e')),
      );
    }
  }
}