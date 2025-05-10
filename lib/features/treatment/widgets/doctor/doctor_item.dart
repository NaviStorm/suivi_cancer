// lib/features/treatment/widgets/doctor_item.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:suivi_cancer/features/treatment/models/doctor.dart';

class DoctorItem extends StatelessWidget {
  final Doctor doctor;
  final VoidCallback? onDelete;

  const DoctorItem({
    Key? key,
    required this.doctor,
    this.onDelete,
    this.onEdit,  // Add this parameter
  }) : super(key: key);

// Add the property declaration
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    // Trouver les contacts de téléphone et d'email
    final phoneContact = doctor.contactInfos.firstWhere(
      (contact) => contact.type == ContactType.Phone,
      orElse: () => ContactInfo(
        id: '',
        type: ContactType.Phone,
        category: ContactCategory.Cabinet,
        value: '',
      ),
    );
    
    final emailContact = doctor.contactInfos.firstWhere(
      (contact) => contact.type == ContactType.Email,
      orElse: () => ContactInfo(
        id: '',
        type: ContactType.Email,
        category: ContactCategory.Cabinet,
        value: '',
      ),
    );
    
    final hasPhone = phoneContact.value.isNotEmpty;
    final hasEmail = emailContact.value.isNotEmpty;
    
    return Card(
      margin: EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              child: Text(
                doctor.firstName[0] + doctor.lastName[0],
                style: TextStyle(color: Colors.white),
              ),
              backgroundColor: Theme.of(context).primaryColor,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    doctor.fullName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  if (doctor.specialty != null)
                    Text(
                      _getSpecialtyText(doctor.specialty!),
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                ],
              ),
            ),
            if (onDelete != null)
              IconButton(
                icon: Icon(Icons.delete_outline, color: Colors.red),
                onPressed: onDelete,
                tooltip: 'Supprimer',
              ),
            IconButton(
              icon: Icon(
                Icons.phone,
                color: hasPhone ? Colors.green : Colors.grey[400],
              ),
              onPressed: hasPhone ? () => _makePhoneCall(phoneContact.value) : null,
              tooltip: hasPhone ? 'Appeler' : 'Aucun numéro',
            ),
            IconButton(
              icon: Icon(
                Icons.email,
                color: hasEmail ? Colors.blue : Colors.grey[400],
              ),
              onPressed: hasEmail ? () => _sendEmail(emailContact.value) : null,
              tooltip: hasEmail ? 'Envoyer un email' : 'Aucun email',
            ),
          ],
        ),
      ),
    );
  }
  
  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri uri = Uri.parse('tel:$phoneNumber');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
  
  Future<void> _sendEmail(String email) async {
    final Uri uri = Uri.parse('mailto:$email');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
  
  String _getSpecialtyText(DoctorSpecialty specialty) {
    switch (specialty) {
      case DoctorSpecialty.Generaliste:
        return 'Généraliste';
      case DoctorSpecialty.Pneumologue:
        return 'Pneumologue';
      case DoctorSpecialty.ORL:
        return 'ORL';
      case DoctorSpecialty.Cardiologue:
        return 'Cardiologue';
      case DoctorSpecialty.Oncologue:
        return 'Oncologue';
      case DoctorSpecialty.Chirurgien:
        return 'Chirurgien';
      case DoctorSpecialty.Anesthesiste:
        return 'Anesthésiste';
      case DoctorSpecialty.Radiologue:
        return 'Radiologue';
      case DoctorSpecialty.Autre:
        return doctor.otherSpecialty ?? 'Autre';
      default:
        return 'Non spécifié';
    }
  }
}

