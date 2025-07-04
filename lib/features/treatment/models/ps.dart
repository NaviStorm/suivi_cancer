class HealthProfessionalCategory {
  final String id;
  final String name;
  final String? description;
  final bool isActive;

  HealthProfessionalCategory({
    required this.id,
    required this.name,
    this.description,
    this.isActive = true,
  });

  factory HealthProfessionalCategory.fromMap(Map<String, dynamic> map) {
    return HealthProfessionalCategory(
      id: map['id'],
      name: map['name'],
      description: map['description'],
      isActive: map['isActive'] == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'isActive': isActive ? 1 : 0,
    };
  }
}

class HealthProfessionalContact {
  final String id;
  final String healthProfessionalId;
  final int type; // 0: téléphone, 1: email, 2: fax, etc.
  final String value;
  final String? label;
  final int isPrimary;

  HealthProfessionalContact({
    required this.id,
    required this.healthProfessionalId,
    required this.type,
    required this.value,
    this.label,
    this.isPrimary = 0,
  });

  factory HealthProfessionalContact.fromMap(Map<String, dynamic> map) {
    return HealthProfessionalContact(
      id: map['id'],
      healthProfessionalId: map['healthProfessionalId'],
      type: map['type'],
      value: map['value'],
      label: map['label'],
      isPrimary: map['isPrimary'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'healthProfessionalId': healthProfessionalId,
      'type': type,
      'value': value,
      'label': label,
      'isPrimary': isPrimary,
    };
  }
}


class HealthProfessionalAddress {
  final String id;
  final String healthProfessionalId;
  final String? street;
  final String city;
  final String? postalCode;
  final String country;
  final String? label;
  final int isPrimary;

  HealthProfessionalAddress({
    required this.id,
    required this.healthProfessionalId,
    this.street,
    required this.city,
    this.postalCode,
    this.country = 'France',
    this.label,
    this.isPrimary = 0,
  });

  factory HealthProfessionalAddress.fromMap(Map<String, dynamic> map) {
    return HealthProfessionalAddress(
      id: map['id'],
      healthProfessionalId: map['healthProfessionalId'],
      street: map['street'],
      city: map['city'],
      postalCode: map['postalCode'],
      country: map['country'] ?? 'France',
      label: map['label'],
      isPrimary: map['isPrimary'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'healthProfessionalId': healthProfessionalId,
      'street': street,
      'city': city,
      'postalCode': postalCode,
      'country': country,
      'label': label,
      'isPrimary': isPrimary,
    };
  }
}


class HealthProfessionalEstablishment {
  final String healthProfessionalId;
  final String establishmentId;
  final String? role;

  HealthProfessionalEstablishment({
    required this.healthProfessionalId,
    required this.establishmentId,
    this.role,
  });

  factory HealthProfessionalEstablishment.fromMap(Map<String, dynamic> map) {
    return HealthProfessionalEstablishment(
      healthProfessionalId: map['healthProfessionalId'],
      establishmentId: map['establishmentId'],
      role: map['role'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'healthProfessionalId': healthProfessionalId,
      'establishmentId': establishmentId,
      'role': role,
    };
  }
}

class HealthProfessional {
  final String id;
  final String firstName;
  final String lastName;
  final String categoryId;
  final String? specialtyDetails;
  final String? notes;
  final List<HealthProfessionalContact>? contacts;
  final List<HealthProfessionalAddress>? addresses;
  final List<Map<String, dynamic>>? establishments;
  final Map<String, dynamic>? category;

  HealthProfessional({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.categoryId,
    this.specialtyDetails,
    this.notes,
    this.contacts,
    this.addresses,
    this.establishments,
    this.category,
  });

  factory HealthProfessional.fromMap(Map<String, dynamic> map) {
    return HealthProfessional(
      id: map['id'],
      firstName: map['firstName'],
      lastName: map['lastName'],
      categoryId: map['categoryId'],
      specialtyDetails: map['specialtyDetails'],
      notes: map['notes'],
      contacts: map['contacts'] != null
          ? List<HealthProfessionalContact>.from(
              map['contacts'].map((x) => HealthProfessionalContact.fromMap(x)))
          : null,
      addresses: map['addresses'] != null
          ? List<HealthProfessionalAddress>.from(
              map['addresses'].map((x) => HealthProfessionalAddress.fromMap(x)))
          : null,
      establishments: map['establishments'],
      category: map['category'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'firstName': firstName,
      'lastName': lastName,
      'categoryId': categoryId,
      'specialtyDetails': specialtyDetails,
      'notes': notes,
    };
  }

  String get fullName => '$firstName $lastName';
}



