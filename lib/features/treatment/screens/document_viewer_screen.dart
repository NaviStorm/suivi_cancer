// lib/features/treatment/screens/document_viewer_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:suivi_cancer/features/treatment/models/document.dart';
import 'package:suivi_cancer/features/treatment/models/doctor.dart';
import 'package:suivi_cancer/core/storage/database_helper.dart';
import 'package:suivi_cancer/utils/logger.dart';

class DocumentViewerScreen extends StatefulWidget {
  final Document document;

  const DocumentViewerScreen({
    Key? key,
    required this.document,
  }) : super(key: key);

  @override
  _DocumentViewerScreenState createState() => _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends State<DocumentViewerScreen> {
  bool _isLoading = true;
  Doctor? _doctor;
  int _totalPages = 0;
  int _currentPage = 0;
  bool _fileExists = false;

  @override
  void initState() {
    super.initState();
    _checkFileExists();
    _loadDocumentDoctor();
  }

  Future<void> _checkFileExists() async {
    try {
      final file = File(widget.document.path);
      final exists = await file.exists();

      setState(() {
        _fileExists = exists;
        _isLoading = false;
      });
    } catch (e) {
      Log.e("Erreur lors de la vérification du fichier: $e");
      setState(() {
        _fileExists = false;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadDocumentDoctor() async {
    try {
      final dbHelper = DatabaseHelper();
      final doctorId = await dbHelper.getDocumentDoctor(widget.document.id);

      if (doctorId != null) {
        final doctorMap = await dbHelper.getDoctor(doctorId);

        if (doctorMap != null) {
          setState(() {
            _doctor = Doctor.fromMap(doctorMap);
          });
        }
      }
    } catch (e) {
      Log.e("Erreur lors du chargement du médecin associé au document: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.document.name),
        actions: [
          IconButton(
            icon: Icon(Icons.share),
            onPressed: _shareDocument,
          ),
          IconButton(
            icon: Icon(Icons.download),
            onPressed: _downloadDocument,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
        children: [
          // Informations sur le document
          Container(
            padding: EdgeInsets.all(16),
            color: Colors.grey.shade100,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _getDocumentTypeIcon(widget.document.type),
                      color: _getDocumentTypeColor(widget.document.type),
                      size: 24,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.document.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                    SizedBox(width: 8),
                    Text(
                      'Date: ${DateFormat('dd/MM/yyyy').format(widget.document.dateAdded)}',
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
                if (_doctor != null) ...[
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.person, size: 16, color: Colors.grey),
                      SizedBox(width: 8),
                      Text(
                        'Médecin: ${_doctor!.fullName}',
                        style: TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ],
                if (widget.document.description != null) ...[
                  SizedBox(height: 8),
                  Text(
                    widget.document.description!,
                    style: TextStyle(
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Visionneuse de document
          Expanded(
            child: _fileExists
                ? _buildDocumentViewer()
                : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: Colors.red.shade300,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Le fichier est introuvable',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Le fichier a peut-être été déplacé ou supprimé',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ),

          // Barre de navigation pour les PDF
          if (_fileExists && widget.document.type == DocumentType.PDF && _totalPages > 0)
            Container(
              padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: Colors.grey.shade200,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back_ios),
                    onPressed: _currentPage > 0
                        ? () => _changePage(_currentPage - 1)
                        : null,
                  ),
                  Text(
                    'Page ${_currentPage + 1} / $_totalPages',
                    style: TextStyle(fontSize: 14),
                  ),
                  IconButton(
                    icon: Icon(Icons.arrow_forward_ios),
                    onPressed: _currentPage < _totalPages - 1
                        ? () => _changePage(_currentPage + 1)
                        : null,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDocumentViewer() {
    switch (widget.document.type) {
      case DocumentType.PDF:
        return PDFView(
          filePath: widget.document.path,
          onRender: (pages) {
            setState(() {
              _totalPages = pages!;
            });
          },
          onPageChanged: (page, total) {
            setState(() {
              _currentPage = page!;
              _totalPages = total!;
            });
          },
          onError: (error) {
            Log.e("Erreur lors de l'affichage du PDF: $error");
          },
        );

      case DocumentType.Image:
        return InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Center(
            child: Image.file(
              File(widget.document.path),
              fit: BoxFit.contain,
            ),
          ),
        );

      case DocumentType.Text:
      case DocumentType.Word:
      case DocumentType.Other:
      default:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _getDocumentTypeIcon(widget.document.type),
                size: 48,
                color: _getDocumentTypeColor(widget.document.type),
              ),
              SizedBox(height: 16),
              Text(
                'Aperçu non disponible',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Ce type de document ne peut pas être visualisé directement',
                style: TextStyle(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _downloadDocument,
                icon: Icon(Icons.download),
                label: Text('Télécharger'),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(200, 44),
                ),
              ),
            ],
          ),
        );
    }
  }

  void _changePage(int page) {
    // Cette méthode sera implémentée par le contrôleur PDF
  }

  void _shareDocument() {
    // TODO: Implémenter le partage de document
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Fonctionnalité de partage à venir')),
    );
  }

  void _downloadDocument() {
    // TODO: Implémenter le téléchargement de document
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Fonctionnalité de téléchargement à venir')),
    );
  }

  IconData _getDocumentTypeIcon(DocumentType type) {
    switch (type) {
      case DocumentType.PDF:
        return Icons.picture_as_pdf;
      case DocumentType.Image:
        return Icons.image;
      case DocumentType.Text:
        return Icons.article;
      case DocumentType.Word:
        return Icons.description;
      case DocumentType.Other:
        return Icons.insert_drive_file;
    }
  }

  Color _getDocumentTypeColor(DocumentType type) {
    switch (type) {
      case DocumentType.PDF:
        return Colors.red;
      case DocumentType.Image:
        return Colors.blue;
      case DocumentType.Text:
        return Colors.green;
      case DocumentType.Word:
        return Colors.indigo;
      case DocumentType.Other:
        return Colors.grey;
    }
  }
}

