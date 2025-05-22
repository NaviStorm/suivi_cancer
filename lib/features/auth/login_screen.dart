// lib/features/auth/login_screen.dart
import 'package:flutter/material.dart';
import 'package:suivi_cancer/features/home/home_screen.dart';
import 'package:suivi_cancer/utils/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:suivi_cancer/core/encryption/encryption_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _passwordController = TextEditingController();
  final EncryptionService _encryptionService = EncryptionService();
  int _failedAttempts = 0;
  DateTime? _lockoutTime;

  @override
  void initState() {
    super.initState();
    Log.d('Appel _checkLockout');
    _checkLockout();
    Log.d('Retour _checkLockout et appel _checkPasswordExists');
    _checkPasswordExists();
    Log.d('Retour _checkPasswordExists');
  }

  Future<void> _checkLockout() async {
    Log.d('Instantiasion de SharedPreferences');
    final prefs = await SharedPreferences.getInstance();
    _failedAttempts = prefs.getInt('failed_attempts') ?? 0;
    final lockoutTimeString = prefs.getString('lockout_time');

    if (lockoutTimeString != null) {
      _lockoutTime = DateTime.parse(lockoutTimeString);
      if (DateTime.now().isAfter(_lockoutTime!)) {
        // Réinitialiser le verrouillage si le temps est écoulé
        await prefs.remove('lockout_time');
        _lockoutTime = null;
      }
    }
  }

  Future<void> _checkPasswordExists() async {
    Log.d('Verification si le mot de passe existe');
    final storedPassword = _encryptionService.getPassword();
    try {
      String? pwd = await _encryptionService.getPassword();
    } catch (e) {
      print("Erreur sur l'apple de : getPassword $e");
    }
    Log.d("Le mot de passe existe : storedPassword:[$storedPassword]");
  }

  Future<void> _verifyPassword() async {
    final prefs = await SharedPreferences.getInstance();
    final storedPassword = await _encryptionService.getPassword();

    if (storedPassword == _passwordController.text) {
      await prefs.setInt('failed_attempts', 0);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomeScreen()),
      );
    } else {
      _failedAttempts++;
      await prefs.setInt('failed_attempts', _failedAttempts);

      if (_failedAttempts >= 10) {
        // Supprimer toutes les données
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Trop de tentatives. Toutes les données ont été supprimées.',
            ),
          ),
        );
      } else if (_failedAttempts >= 8) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Attention! Après 10 tentatives échouées, toutes les données seront supprimées.',
            ),
          ),
        );
        _setLockout();
      } else if (_failedAttempts >= 3) {
        _setLockout();
      }
    }
  }

  Future<void> _setLockout() async {
    final prefs = await SharedPreferences.getInstance();
    _lockoutTime = DateTime.now().add(Duration(hours: 1));
    await prefs.setString('lockout_time', _lockoutTime!.toIso8601String());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Suivi Cancer',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            Text(
              'Cette application contient des données sensibles concernant votre santé. Un mot de passe est requis pour protéger vos informations.',
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 30),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Mot de passe',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed:
                  _lockoutTime != null && DateTime.now().isBefore(_lockoutTime!)
                      ? null
                      : _verifyPassword,
              child: Text('Se connecter'),
            ),
          ],
        ),
      ),
    );
  }
}
