// lib/widgets/establishment_list_widget.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:suivi_cancer/core/storage/database_helper.dart';
import 'package:suivi_cancer/features/treatment/models/establishment.dart';
import 'package:suivi_cancer/features/treatment/services/treatment_service.dart';
import 'package:suivi_cancer/features/treatment/screens/establishment/edit_establishment_screen.dart';
import 'package:suivi_cancer/utils/logger.dart';


class EstablishmentListWidget extends StatefulWidget {
  const EstablishmentListWidget({super.key}); // <-- ici on accepte une key

  @override
  EstablishmentListWidgetState createState() => EstablishmentListWidgetState();
}

class EstablishmentListWidgetState extends State<EstablishmentListWidget> {
  List<Establishment> _establishments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    loadEstablishments();
  }

  Future<void> loadEstablishments() async {
    Log.d('_load');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _isLoading = true;
      });
    });

    try {
      final establishments = await TreatmentService.getAllEstablishments();
      setState(() {
        _establishments = establishments;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    // Code existant pour le widget...

    return ListView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: _establishments.length,
      itemBuilder: (context, index) {
        final establishment = _establishments[index];
        final hasPhone = establishment.phone != null && establishment.phone!.isNotEmpty;
        final hasEmail = establishment.email != null && establishment.email!.isNotEmpty;

        return Card(
          margin: EdgeInsets.only(bottom: 8),
          child: ListTile(
            title: Text(establishment.name),
            subtitle: Text(
              [
                establishment.address,
                establishment.postalCode,
                establishment.city
              ].where((s) => s != null && s.isNotEmpty).join(', '),
            ),
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
                      ? () => _makePhoneCall(establishment.phone!)
                      : null,
                ),
                // Icône d'email
                IconButton(
                  icon: Icon(
                    Icons.email,
                    color: hasEmail ? Colors.blue : Colors.grey,
                  ),
                  onPressed: hasEmail
                      ? () => _sendEmail(establishment.email!)
                      : null,
                ),
                // Icône de modification
                IconButton(
                  icon: Icon(Icons.edit, color: Colors.blue),
                  onPressed: () => _editEstablishment(establishment),
                ),
                // Icône de suppression
                IconButton(
                  icon: Icon(Icons.delete, color: Colors.red),
                  onPressed: () {
                    _confirmDelete(context, establishment);
                  },
                ),
              ],
            ),
            onTap: () {
              // Navigation vers les détails de l'établissement si nécessaire
            },
          ),
        );
      },
    );
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

  // Méthode pour naviguer vers l'écran de modification
  void _editEstablishment(Establishment Establishment) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditEstablishmentScreen(establishment: Establishment),
      ),
    );

    if (result == true) {
      // Rafraîchir la liste des établissements
      loadEstablishments();
    }
  }

  void _confirmDelete(BuildContext context, Establishment Establishment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Supprimer ce cette établissement?'),
        content: Text(
            "Êtes-vous sûr de vouloir supprimer l'établissement ${Establishment.name} ? Cette action est irréversible."
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
              await _deleteEstablishment(Establishment.id);
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

  Future<void> _deleteEstablishment(String id) async {
    try {
      final dbHelper = DatabaseHelper();
      await dbHelper.deleteEstablishment(id);

      // Rafraîchir la liste après suppression
      loadEstablishments();

      // Afficher un message de confirmation
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Établissement supprimé avec succès')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la suppression: $e')),
      );
    }
  }
}

