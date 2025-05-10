// lib/core/storage/document_storage.dart
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class DocumentStorage {
  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<File> _localFile(String fileName) async {
    final path = await _localPath;
    return File('$path/$fileName');
  }

  Future<void> saveDocument(String fileName, List<int> bytes) async {
    final file = await _localFile(fileName);
    await file.writeAsBytes(bytes);
  }

  Future<File?> getDocument(String fileName) async {
    try {
      final file = await _localFile(fileName);
      return file;
    } catch (e) {
      return null;
    }
  }

  Future<void> saveText(String fileName, String content) async {
    final file = await _localFile(fileName);
    await file.writeAsString(content);
  }

  Future<String?> readText(String fileName) async {
    try {
      final file = await _localFile(fileName);
      return await file.readAsString();
    } catch (e) {
      return null;
    }
  }
}
