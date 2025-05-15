// lib/features/treatment/widgets/document_card.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:suivi_cancer/features/treatment/models/document.dart';
import 'package:suivi_cancer/features/treatment/utils/event_formatter.dart';

class DocumentCard extends StatelessWidget {
  final Document document;
  final Function(Document) onTap;
  final String locale;

  const DocumentCard({
    Key? key,
    required this.document,
    required this.onTap,
    required this.locale,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Color color = EventFormatter.getDocumentTypeColor(document.type);
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      elevation: 1,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: BorderSide(color: Colors.grey[200]!, width: 1),
      ),
      child: InkWell(
        onTap: () => onTap(document),
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date
              Container(
                width: 50,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      DateFormat('dd', locale).format(document.dateAdded),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    Text(
                      DateFormat('MMM', locale).format(document.dateAdded).toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('HH:mm', locale).format(document.dateAdded),
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              // Séparateur vertical
              Container(
                height: 60,
                width: 1,
                color: Colors.grey.withOpacity(0.2),
                margin: const EdgeInsets.symmetric(horizontal: 4),
              ),
              // Icône
              Container(
                margin: const EdgeInsets.only(right: 8, top: 2),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  EventFormatter.getDocumentTypeIcon(document.type),
                  size: 14,
                  color: color,
                ),
              ),
              // Contenu
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            document.name,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Document',
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.grey[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    // Détails du document
                    _buildDocumentDetails(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDocumentDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              EventFormatter.getDocumentDetailsIcon(document.type),
              size: 10,
              color: EventFormatter.getDocumentTypeColor(document.type),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                document.name,
                style: const TextStyle(fontSize: 10),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        Row(
          children: [
            Icon(Icons.folder, size: 10, color: Colors.grey[600]),
            const SizedBox(width: 4),
            Text(
              EventFormatter.getDocumentTypeLabel(document.type),
              style: const TextStyle(fontSize: 10),
            ),
            if (document.size != null) ...[
              Text(
                ' • ${EventFormatter.formatFileSize(document.size!)}',
                style: TextStyle(fontSize: 10, color: Colors.grey[600]),
              ),
            ],
          ],
        ),
        if (document.description != null && document.description!.isNotEmpty)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.description, size: 10, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  document.description!,
                  style: const TextStyle(fontSize: 10, fontStyle: FontStyle.italic),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

