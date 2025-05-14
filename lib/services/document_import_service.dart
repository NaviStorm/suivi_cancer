// lib/services/document_import_service.dart

import 'dart:io';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:share_plus/share_plus.dart';
import 'package:suivi_cancer/features/treatment/models/document.dart';
import 'package:suivi_cancer/utils/logger.dart';

class DocumentImportService {
  // Singleton pattern
  static final DocumentImportService _instance = DocumentImportService._internal();
  factory DocumentImportService() => _instance;
  DocumentImportService._internal();

  // Méthode pour obtenir le chemin de base des documents
  Future<String> getBaseDocumentsPath() async {
    final appDir = await getApplicationDocumentsDirectory();
    final documentsDir = Directory('${appDir.path}/documents');
    if (!await documentsDir.exists()) {
      await documentsDir.create(recursive: true);
    }
    return documentsDir.path;
  }

  // Méthode pour convertir un chemin relatif en chemin absolu
  Future<String> getAbsolutePath(String relativePath) async {
    final appDir = await getApplicationDocumentsDirectory();
    return '${appDir.path}/$relativePath';
  }

  // Méthodes pour afficher les dialogues d'ajout de document
  Future<String?> showAddDocumentDialog(BuildContext context) async {
    return showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('Ajouter un document'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'camera'),
            child: ListTile(
              leading: Icon(Icons.camera_alt, color: Colors.blue),
              title: Text('Prendre une photo'),
              dense: true,
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'gallery'),
            child: ListTile(
              leading: Icon(Icons.photo_library, color: Colors.green),
              title: Text('Choisir une image'),
              dense: true,
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'file'),
            child: ListTile(
              leading: Icon(Icons.upload_file, color: Colors.orange),
              title: Text('Sélectionner un fichier'),
              dense: true,
            ),
          ),
        ],
      ),
    );
  }

  // Prendre une photo avec la caméra
  Future<Document?> takePicture(BuildContext context) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );

      if (image != null) {
        return await processImage(context, image);
      }
      return null;
    } catch (e) {
      Log.e("Erreur lors de la prise de photo: $e");
      _showErrorMessage(context, "Impossible de prendre une photo");
      return null;
    }
  }

  // Sélectionner une image depuis la galerie
  Future<Document?> pickImage(BuildContext context) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (image != null) {
        return await processImage(context, image);
      }
      return null;
    } catch (e) {
      Log.e("Erreur lors de la sélection d'image: $e");
      _showErrorMessage(context, "Impossible de sélectionner une image");
      return null;
    }
  }

  // Sélectionner un fichier
  Future<Document?> pickFile(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx', 'txt'],
      );

      if (result != null && result.files.isNotEmpty) {
        final filePath = result.files.first.path!;
        final fileName = result.files.first.name;
        final fileExtension = fileName.split('.').last.toLowerCase();

        // Déterminer le type de document
        DocumentType docType = DocumentType.Other;
        switch (fileExtension) {
          case 'pdf':
            docType = DocumentType.PDF;
            // Vérifier si le PDF est protégé par mot de passe
            if (await isPdfPasswordProtected(filePath)) {
              return await handlePasswordProtectedPdf(context, filePath, fileName);
            }
            break;
          case 'jpg':
          case 'jpeg':
          case 'png':
            docType = DocumentType.Image;
            break;
          case 'doc':
          case 'docx':
            docType = DocumentType.Word;
            break;
          case 'txt':
            docType = DocumentType.Text;
            break;
        }

        return await processDocument(context, filePath, fileName, docType);
      }
      return null;
    } catch (e) {
      Log.e("Erreur lors de la sélection du fichier: $e");
      _showErrorMessage(context, "Impossible de sélectionner le fichier");
      return null;
    }
  }

  // Traitement des images
  Future<Document?> processImage(BuildContext context, XFile image) async {
    return processDocument(context, image.path, image.name, DocumentType.Image);
  }

  // Traitement général des documents
  Future<Document?> processDocument(
      BuildContext context,
      String sourcePath,
      String fileName,
      DocumentType docType
      ) async {
    try {
      // Obtenir un nom pour le document
      final docName = await getDocumentName(context, docType.toString(), fileName);
      if (docName == null) return null; // L'utilisateur a annulé

      // Obtenir une description pour le document
      final docDescription = await getDocumentDescription(context);

      // Créer un dossier dans l'application pour stocker les fichiers
      final baseDir = await getBaseDocumentsPath();

      // Générer un nom de fichier unique
      final uniqueId = Uuid().v4();
      final fileExtension = fileName.split('.').last.toLowerCase();
      final newFileName = '$uniqueId.$fileExtension';
      final relativePath = 'documents/$newFileName';
      final absolutePath = '${await getApplicationDocumentsDirectory().then((dir) => dir.path)}/$relativePath';

      // Copier le fichier dans le dossier de l'application
      final sourceFile = File(sourcePath);
      await sourceFile.copy(absolutePath);

      // Créer et retourner le document
      final document = Document(
        id: uniqueId,
        name: docName,
        path: relativePath, // Stocker le chemin relatif
        dateAdded: DateTime.now(),
        type: docType,
        description: docDescription,
        size: await sourceFile.length(),
      );

      _showMessage(context, 'Document ajouté avec succès');
      return document;
    } catch (e) {
      Log.e("Erreur lors du traitement du document: $e");
      _showErrorMessage(context, "Impossible de traiter le document");
      return null;
    }
  }

  // Vérification si un PDF est protégé par mot de passe
  Future<bool> isPdfPasswordProtected(String filePath) async {
    try {
      final bytes = await File(filePath).readAsBytes();
      try {
        final document = PdfDocument(inputBytes: bytes);
        document.dispose();
        return false; // Le document s'est ouvert sans mot de passe
      } catch (e) {
        return true; // Le document est probablement protégé
      }
    } catch (e) {
      Log.e("Erreur lors de la vérification de la protection du PDF: $e");
      return false;
    }
  }

  // Gestion des PDF protégés par mot de passe
  Future<Document?> handlePasswordProtectedPdf(
      BuildContext context,
      String filePath,
      String fileName
      ) async {
    final choice = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Document protégé par mot de passe'),
        content: Text('Ce document PDF est protégé par un mot de passe. Souhaitez-vous supprimer cette protection ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Conserver la protection'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Supprimer la protection'),
          ),
        ],
      ),
    );

    if (choice == true) {
      final password = await askForPdfPassword(context);
      if (password != null && password.isNotEmpty) {
        final decryptedFilePath = await decryptPdf(context, filePath, fileName, password);
        if (decryptedFilePath != null) {
          return await processDocument(context, decryptedFilePath, fileName, DocumentType.PDF);
        }
      }
    } else if (choice == false) {
      return await processDocument(context, filePath, fileName, DocumentType.PDF);
    }
    return null;
  }

  // Demander le mot de passe d'un PDF
  Future<String?> askForPdfPassword(BuildContext context) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Saisir le mot de passe'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: 'Mot de passe',
            hintText: 'Entrez le mot de passe du document',
          ),
          obscureText: true,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text('Valider'),
          ),
        ],
      ),
    );
  }

  // Décrypter un PDF protégé par mot de passe
  Future<String?> decryptPdf(
      BuildContext context,
      String filePath,
      String fileName,
      String password
      ) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final tempDir = Directory('${appDir.path}/temp');
      if (!await tempDir.exists()) {
        await tempDir.create(recursive: true);
      }

      final uniqueId = Uuid().v4();
      final decryptedFilePath = '${tempDir.path}/$uniqueId.pdf';

      final bytes = await File(filePath).readAsBytes();
      try {
        final document = PdfDocument(
          inputBytes: bytes,
          password: password,
        );

        final security = document.security;
        security.userPassword = '';
        security.ownerPassword = '';
        security.permissions.clear();

        final decryptedBytes = await document.save();
        document.dispose();

        await File(decryptedFilePath).writeAsBytes(decryptedBytes);
        _showMessage(context, 'Protection par mot de passe supprimée avec succès');
        return decryptedFilePath;
      } catch (e) {
        Log.e("Erreur lors du décryptage du PDF: $e");
        _showErrorMessage(context, "Mot de passe incorrect ou document non déchiffrable");
        return null;
      }
    } catch (e) {
      Log.e("Erreur lors du traitement du PDF protégé: $e");
      _showErrorMessage(context, "Impossible de traiter le document protégé");
      return null;
    }
  }

  // Obtenir un nom pour le document
  Future<String?> getDocumentName(BuildContext context, String type, String defaultName) async {
    final controller = TextEditingController(text: defaultName);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Nom du document'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: 'Nom',
            hintText: 'Entrez un nom pour ce document',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(context, controller.text.trim());
              }
            },
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  // Obtenir une description pour le document
  Future<String?> getDocumentDescription(BuildContext context) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Description (optionnelle)'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: 'Description',
            hintText: 'Entrez une description pour ce document',
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, ''),
            child: Text('Ignorer'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  // Visualisation des documents
  Future<void> viewDocument(BuildContext context, Document document) async {
    Log.d('Chemin relatif vers le document : [${document.path}]');
    try {
      final absolutePath = await getAbsolutePath(document.path);
      Log.d('Chemin absolu vers le document : [$absolutePath]');

      final file = File(absolutePath);
      if (!(await file.exists())) {
        _showErrorMessage(context, "Le fichier est introuvable");
        return;
      }

      switch (document.type) {
        case DocumentType.Image:
          viewImageDocument(context, document);
          break;
        case DocumentType.PDF:
          viewPdfDocument(context, document);
          break;
        case DocumentType.Word:
        case DocumentType.Text:
        case DocumentType.Other:
        default:
          openWithDefaultApp(context, document);
          break;
      }
    } catch (e) {
      Log.e("Erreur lors de l'ouverture du document: $e");
      _showErrorMessage(context, "Impossible d'ouvrir le document");
    }
  }

  // Visualisation des images
  Future<void> viewImageDocument(BuildContext context, Document document) async {
    final absolutePath = await getAbsolutePath(document.path);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text(document.name),
            actions: [
              IconButton(
                icon: Icon(Icons.ios_share),
                onPressed: () => shareDocument(context, document),
                tooltip: 'Partager',
              ),
            ],
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.file(
                File(absolutePath),
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Visualisation des PDF
  Future<void> viewPdfDocument(BuildContext context, Document document) async {
    try {
      final absolutePath = await getAbsolutePath(document.path);
      final file = File(absolutePath);
      if (await file.exists()) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => Scaffold(
              appBar: AppBar(
                title: Text(document.name),
                actions: [
                  IconButton(
                    icon: Icon(Icons.ios_share),
                    onPressed: () => shareDocument(context, document),
                    tooltip: 'Partager',
                  ),
                ],
              ),
              body: PDFView(
                filePath: absolutePath,
                enableSwipe: true,
                swipeHorizontal: true,
                autoSpacing: false,
                pageFling: true,
                pageSnap: true,
                defaultPage: 0,
                fitPolicy: FitPolicy.BOTH,
                preventLinkNavigation: false,
                onRender: (_pages) {
                  // PDF est chargé
                },
                onError: (error) {
                  _showErrorMessage(context, "Erreur lors du chargement du PDF: $error");
                },
                onPageError: (page, error) {
                  _showErrorMessage(context, "Erreur lors du chargement de la page $page: $error");
                },
              ),
            ),
          ),
        );
      } else {
        _showErrorMessage(context, "Le fichier PDF est introuvable");
      }
    } catch (e) {
      Log.e("Erreur lors de l'ouverture du PDF: $e");
      _showErrorMessage(context, "Impossible d'ouvrir le document PDF");
    }
  }

  // Ouverture avec l'application par défaut
  Future<void> openWithDefaultApp(BuildContext context, Document document) async {
    try {
      final absolutePath = await getAbsolutePath(document.path);
      final file = File(absolutePath);
      if (await file.exists()) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Ouvrir le document'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _getDocumentTypeIcon(document.type),
                  size: 60,
                  color: _getDocumentTypeColor(document.type),
                ),
                SizedBox(height: 16),
                Text(document.name, style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text(
                  'Ce type de document ne peut pas être ouvert directement dans l\'application.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  shareDocument(context, document);
                },
                child: Text('Partager'),
              ),
            ],
          ),
        );
      } else {
        _showErrorMessage(context, "Le fichier est introuvable");
      }
    } catch (e) {
      Log.e("Erreur lors de l'ouverture du document: $e");
      _showErrorMessage(context, "Impossible d'ouvrir le document");
    }
  }

  // Partage de documents
  Future<void> shareDocument(BuildContext context, Document document) async {
    try {
      final absolutePath = await getAbsolutePath(document.path);
      final file = File(absolutePath);
      if (await file.exists()) {
        String shareMessage;
        switch (document.type) {
          case DocumentType.PDF:
            shareMessage = "Document PDF: ${document.name}";
            break;
          case DocumentType.Image:
            shareMessage = "Image: ${document.name}";
            break;
          case DocumentType.Word:
            shareMessage = "Document Word: ${document.name}";
            break;
          case DocumentType.Text:
            shareMessage = "Document texte: ${document.name}";
            break;
          default:
            shareMessage = "Document: ${document.name}";
        }

        if (document.description != null && document.description!.isNotEmpty) {
          shareMessage += "\n${document.description}";
        }

        await Share.shareXFiles(
          [XFile(absolutePath)],
          text: shareMessage,
          subject: document.name,
        );
      } else {
        _showErrorMessage(context, "Le fichier est introuvable");
      }
    } catch (e) {
      Log.e("Erreur lors du partage du document: $e");
      _showErrorMessage(context, "Impossible de partager le document");
    }
  }

  // Nettoyage des fichiers temporaires
  Future<void> cleanupTempFiles() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final tempDir = Directory('${appDir.path}/temp');
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    } catch (e) {
      Log.e("Erreur lors du nettoyage des fichiers temporaires: $e");
    }
  }

  // Utilitaires pour les icônes et couleurs
  IconData _getDocumentTypeIcon(DocumentType type) {
    switch (type) {
      case DocumentType.PDF:
        return Icons.picture_as_pdf;
      case DocumentType.Image:
        return Icons.image;
      case DocumentType.Word:
        return Icons.article;
      case DocumentType.Text:
        return Icons.description;
      case DocumentType.Other:
      default:
        return Icons.insert_drive_file;
    }
  }

  Color _getDocumentTypeColor(DocumentType type) {
    switch (type) {
      case DocumentType.PDF:
        return Colors.red;
      case DocumentType.Image:
        return Colors.blue;
      case DocumentType.Word:
        return Colors.indigo;
      case DocumentType.Text:
        return Colors.green;
      case DocumentType.Other:
      default:
        return Colors.grey;
    }
  }

  // Affichage des messages
  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showErrorMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
}
