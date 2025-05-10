// lib/features/treatment/models/doctor.dart
import 'package:flutter/foundation.dart';
import 'package:suivi_cancer/features/treatment/models/establishment.dart';

enum DoctorSpecialty {
  Generaliste,
  Pneumologue,
  ORL,
  Cardiologue,
  Oncologue,
  Chirurgien,
  Anesthesiste,
  Radiologue,
  Radiotherapeute,
  Autre
}

class Doctor {
  final String id;
  final String firstName;
  final String lastName;
  final DoctorSpecialty? specialty;
  final String? otherSpecialty; // Si specialty est Autre
  final List<ContactInfo> contactInfos;
  final Establishment? establishment;
  final String? notes;

  Doctor({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.specialty,
    this.otherSpecialty,
    this.contactInfos = const [],
    this.establishment,
    this.notes,
  });
  
  String get fullName => '$firstName $lastName';
  
  Doctor copyWith({
    String? id,
    String? firstName,
    String? lastName,
    DoctorSpecialty? specialty,
    String? otherSpecialty,
    List<ContactInfo>? contactInfos,
    Establishment? establishment,
    String? notes,
  }) {
    return Doctor(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      specialty: specialty ?? this.specialty,
      otherSpecialty: otherSpecialty ?? this.otherSpecialty,
      contactInfos: contactInfos ?? this.contactInfos,
      establishment: establishment ?? this.establishment,
      notes: notes ?? this.notes,
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'firstName': firstName,
      'lastName': lastName,
      'specialty': specialty?.index,
      'otherSpecialty': otherSpecialty,
      'contactInfos': contactInfos.map((x) => x.toMap()).toList(),
      'establishment': establishment?.toMap(),
      'notes': notes,
    };
  }

  factory Doctor.fromMap(Map<String, dynamic> map) {
    return Doctor(
      id: map['id'],
      firstName: map['firstName'],
      lastName: map['lastName'],
      specialty: map['specialty'] != null
          ? DoctorSpecialty.values[map['specialty']]
          : null,
      otherSpecialty: map['otherSpecialty'],
      contactInfos: map['contactInfos'] != null
          ? (map['contactInfos'] as List)
          .map((contactMap) => ContactInfo.fromMap(contactMap as Map<String, dynamic>))
          .toList()
          : [],
    );
  }
}

enum ContactType {
  Phone,
  Email,
  Address
}

enum ContactCategory {
  Cabinet,
  Hopital,
  Personnel,
  Autre
}

class ContactInfo {
  final String id;
  final ContactType type;
  final ContactCategory category;
  final String value;
  
  ContactInfo({
    required this.id,
    required this.type,
    required this.category,
    required this.value,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.index,
      'category': category.index,
      'value': value,
    };
  }

  factory ContactInfo.fromMap(Map<String, dynamic> map) {
    return ContactInfo(
      id: map['id'],
      type: ContactType.values[map['type']],
      category: ContactCategory.values[map['category']],
      value: map['value'],
    );
  }
}

