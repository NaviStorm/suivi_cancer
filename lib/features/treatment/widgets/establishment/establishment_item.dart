// lib/features/treatment/widgets/establishment_item.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:suivi_cancer/features/treatment/models/establishment.dart';

class EstablishmentItem extends StatelessWidget {
  final Establishment establishment;
  final VoidCallback? onDelete;

  const EstablishmentItem({
    Key? key,
    required this.establishment,
    this.onDelete,
    this.onEdit,  // Add this parameter
  }) : super(key: key);

// Add the property declaration
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final hasPhone = establishment.phone != null && establishment.phone!.isNotEmpty;
    final hasEmail = establishment.email != null && establishment.email!.isNotEmpty;
    
    return Card(
      margin: EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.business,
                color: Theme.of(context).primaryColor,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    establishment.name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  if (establishment.address != null || establishment.city != null)
                    Text(
                      [
                        establishment.address,
                        establishment.postalCode,
                        establishment.city
                      ].where((s) => s != null && s.isNotEmpty).join(', '),
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
              onPressed: hasPhone ? () => _makePhoneCall(establishment.phone!) : null,
              tooltip: hasPhone ? 'Appeler' : 'Aucun numéro',
            ),
            IconButton(
              icon: Icon(
                Icons.email,
                color: hasEmail ? Colors.blue : Colors.grey[400],
              ),
              onPressed: hasEmail ? () => _sendEmail(establishment.email!) : null,
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
}

