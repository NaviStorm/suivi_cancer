// lib/features/treatment/models/document.dart
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

enum DocumentType {
  PDF,
  Image,
  Text,
  Word,
  Other
}

class Document {
  final String id;
  final String name;
  final String path;
  final DateTime dateAdded;
  final DocumentType type;
  final String? description;
  final int? size;  // Taille du fichier en octets (optionnel)

  Document({
    required this.id,
    required this.name,
    required this.path,
    required this.dateAdded,
    required this.type,
    this.description,
    this.size,
  });

  Document copyWith({
    String? id,
    String? name,
    String? path,
    DateTime? dateAdded,
    DocumentType? type,
    String? description,
    int? size,
  }) {
    return Document(
      id: id ?? this.id,
      name: name ?? this.name,
      path: path ?? this.path,
      dateAdded: dateAdded ?? this.dateAdded,
      type: type ?? this.type,
      description: description ?? this.description,
      size: size ?? this.size,
    );
  }

  // Ajouter une méthode pour obtenir le chemin absolu
  Future<String> getAbsolutePath() async {
    final appDir = await getApplicationDocumentsDirectory();
    return '${appDir.path}/$path';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'path': path,
      'dateAdded': dateAdded.toIso8601String(),
      'type': type.index,
      'description': description,
      'size': size,
    };
  }

  factory Document.fromMap(Map<String, dynamic> map) {
    return Document(
      id: map['id'],
      name: map['name'],
      path: map['path'],
      dateAdded: DateTime.parse(map['dateAdded']),
      type: DocumentType.values[map['type']],
      description: map['description'],
      size: map['size'],
    );
  }

  String get extension {
    switch (type) {
      case DocumentType.PDF:
        return 'pdf';
      case DocumentType.Image:
        return 'jpg';
      case DocumentType.Text:
        return 'txt';
      case DocumentType.Word:
        return 'docx';
      case DocumentType.Other:
        return '';
    }
  }
  
  String get iconName {
    switch (type) {
      case DocumentType.PDF:
        return 'pdf_icon';
      case DocumentType.Image:
        return 'image_icon';
      case DocumentType.Text:
        return 'text_icon';
      case DocumentType.Word:
        return 'word_icon';
      case DocumentType.Other:
        return 'file_icon';
    }
  }
}

