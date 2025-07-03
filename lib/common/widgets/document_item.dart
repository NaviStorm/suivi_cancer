import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../features/treatment/models/document.dart';

class DocumentItem extends StatelessWidget {
  final Document document;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const DocumentItem({
    super.key,
    required this.document,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 4, horizontal: 0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              _buildDocumentIcon(),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      document.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Ajouté le ${DateFormat('dd/MM/yyyy').format(document.dateAdded)}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                    if (document.description != null &&
                        document.description!.isNotEmpty) ...[
                      SizedBox(height: 4),
                      Text(
                        document.description!,
                        style: TextStyle(fontSize: 14),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (onDelete != null)
                IconButton(
                  icon: Icon(Icons.delete_outline, color: Colors.red[700]),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder:
                          (context) => AlertDialog(
                            title: Text('Supprimer le document'),
                            content: Text(
                              'Êtes-vous sûr de vouloir supprimer ce document ?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: Text('ANNULER'),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  onDelete!();
                                },
                                child: Text(
                                  'SUPPRIMER',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDocumentIcon() {
    IconData iconData;
    Color iconColor;

    switch (document.type) {
      case DocumentType.PDF:
        iconData = Icons.picture_as_pdf;
        iconColor = Colors.red;
        break;
      case DocumentType.Image:
        iconData = Icons.image;
        iconColor = Colors.blue;
        break;
      case DocumentType.Text:
        iconData = Icons.description;
        iconColor = Colors.amber;
        break;
      case DocumentType.Word:
        iconData = Icons.article;
        iconColor = Colors.indigo;
        break;
      case DocumentType.Other:
        iconData = Icons.insert_drive_file;
        iconColor = Colors.grey;
        break;
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(iconData, color: iconColor, size: 24),
    );
  }
}
