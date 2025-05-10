// lib/widgets/doctor_list_widget.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:suivi_cancer/features/treatment/models/doctor.dart';
import 'package:suivi_cancer/core/storage/database_helper.dart';
import 'package:suivi_cancer/features/treatment/screens/doctor/edit_doctor_screen.dart';


class DoctorListWidget extends StatefulWidget {
  const DoctorListWidget({Key? key}) : super(key: key);

  @override
  State<DoctorListWidget> createState() => _DoctorListWidgetState();
}

class _DoctorListWidgetState extends State<DoctorListWidget> {
  List<Doctor> _doctors = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDoctors();
  }

  Future<void> _loadDoctors() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final dbHelper = DatabaseHelper();
      final doctorMaps = await dbHelper.getDoctors();

      if (!mounted) return;

      setState(() {
        _doctors = doctorMaps.map((map) => Doctor.fromMap(map)).toList();
        _isLoading = false;
      });

      // Débogage
      for (var doctor in _doctors) {
        print("Médecin: ${doctor.fullName}");
        print("Contacts: ${doctor.contactInfos.length}");
        for (var contact in doctor.contactInfos) {
          print(" - ${contact.type}: ${contact.value}");
        }
      }
    } catch (e) {
      print('Erreur lors du chargement des médecins: $e');

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _doctors = [];
      });
    }
  }

  void _editDoctor(Doctor doctor) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditDoctorScreen(doctor: doctor),
      ),
    );

    if (result == true) {
      _loadDoctors();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (_doctors.isEmpty) {
      return Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(
            child: Text(
              'Aucun médecin ajouté',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: _doctors.length,
      itemBuilder: (context, index) {
        final doctor = _doctors[index];

        // Trouver les contacts de téléphone et email
        final phoneContacts = doctor.contactInfos
            .where((contact) => contact.type == ContactType.Phone)
            .toList();

        final emailContacts = doctor.contactInfos
            .where((contact) => contact.type == ContactType.Email)
            .toList();

        final bool hasPhone = phoneContacts.isNotEmpty;
        final bool hasEmail = emailContacts.isNotEmpty;

        return Card(
          margin: EdgeInsets.only(bottom: 8),
          child: ListTile(
            title: Text(doctor.fullName),
            subtitle: Text(doctor.specialty?.toString() ?? 'Non spécifiée'),
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
                      ? () => _showContactOptions(context, phoneContacts, ContactType.Phone)
                      : null,
                ),
                // Icône d'email
                IconButton(
                  icon: Icon(
                    Icons.email,
                    color: hasEmail ? Colors.blue : Colors.grey,
                  ),
                  onPressed: hasEmail
                      ? () => _showContactOptions(context, emailContacts, ContactType.Email)
                      : null,
                ),
                // Icône de modification
                IconButton(
                  icon: Icon(Icons.edit, color: Colors.blue),
                  onPressed: () => _editDoctor(doctor),
                ),
                // Icône de suppression
                IconButton(
                  icon: Icon(Icons.delete, color: Colors.red),
                  onPressed: () {
                    _confirmDelete(context, doctor);
                  },
                ),
              ],
            ),
            onTap: () {
              // Navigation vers les détails du médecin
            },
          ),
        );
      },
    );
  }

  // Afficher une liste d'options si plusieurs contacts sont disponibles
  void _showContactOptions(BuildContext context, List<ContactInfo> contacts, ContactType type) {
    if (contacts.isEmpty) return;

    if (contacts.length == 1) {
      // S'il n'y a qu'un seul contact, l'utiliser directement
      if (type == ContactType.Phone) {
        _makePhoneCall(contacts[0].value);
      } else if (type == ContactType.Email) {
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
                type == ContactType.Phone ? 'Choisir un numéro de téléphone' : 'Choisir un email',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Divider(),
            ...contacts.map((contact) => ListTile(
              leading: Icon(
                type == ContactType.Phone ? Icons.phone : Icons.email,
                color: Colors.blue,
              ),
              title: Text(contact.value),
              subtitle: Text(_getCategoryText(contact.category)),
              onTap: () {
                Navigator.pop(context);
                if (type == ContactType.Phone) {
                  _makePhoneCall(contact.value);
                } else if (type == ContactType.Email) {
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

  void _confirmDelete(BuildContext context, Doctor doctor) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Supprimer ce médecin?'),
        content: Text(
            'Êtes-vous sûr de vouloir supprimer le Dr. ${doctor.firstName} ${doctor.lastName}? Cette action est irréversible.'
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
              await _deleteDoctor(doctor.id);
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

  Future<void> _deleteDoctor(String id) async {
    try {
      final dbHelper = DatabaseHelper();
      await dbHelper.deleteDoctor(id);

      // Rafraîchir la liste après suppression
      _loadDoctors();

      // Afficher un message de confirmation
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Médecin supprimé avec succès')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la suppression: $e')),
      );
    }
  }
}



