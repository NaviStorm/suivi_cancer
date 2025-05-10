class AppConstants {
  // Nom de l'application
  static const String appName = "Suivi Cancer";
  
  // Identifiants de bundle
  static const String iOSBundleId = "com.tandreuperouges.suivicancer.andreu";
  static const String androidBundleId = "com.tandreuperouges.suivicancer";
  
  // Clés de stockage
  static const String userPasswordKey = "user_password";
  static const String failedAttemptsKey = "failed_attempts";
  static const String lockoutTimeKey = "lockout_time";
  
  // Délais de sécurité
  static const int maxFailedAttempts = 10;
  static const int warningAttempts = 8;
  static const int lockoutAttempts = 3;
  static const int lockoutDurationHours = 1;
  
  // Canaux de notification
  static const String treatmentChannelId = "treatment_channel";
  static const String treatmentChannelName = "Traitement";
  static const String treatmentChannelDescription = "Notifications pour les traitements et rendez-vous";
  
  // Messages
  static const String securityMessage = "Cette application contient des données sensibles concernant votre santé. Un mot de passe est requis pour protéger vos informations.";
  static const String deleteWarningMessage = "Attention! Après 10 tentatives échouées, toutes les données seront supprimées.";
}

