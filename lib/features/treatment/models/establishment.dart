// lib/features/treatment/models/establishment.dart
import 'package:flutter/foundation.dart';

class Establishment {
  final String id;
  final String name;
  final String? address;
  final String? city;
  final String? postalCode;
  final String? phone;
  final String? email;
  final String? website;
  final String? notes;

  Establishment({
    required this.id,
    required this.name,
    this.address,
    this.city,
    this.postalCode,
    this.phone,
    this.email,
    this.website,
    this.notes,
  });
  
  Establishment copyWith({
    String? id,
    String? name,
    String? address,
    String? city,
    String? postalCode,
    String? phone,
    String? email,
    String? website,
    String? notes,
  }) {
    return Establishment(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      city: city ?? this.city,
      postalCode: postalCode ?? this.postalCode,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      website: website ?? this.website,
      notes: notes ?? this.notes,
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'city': city,
      'postalCode': postalCode,
      'phone': phone,
      'email': email,
      'website': website,
      'notes': notes,
    };
  }
  
  factory Establishment.fromMap(Map<String, dynamic> map) {
    return Establishment(
      id: map['id'],
      name: map['name'],
      address: map['address'],
      city: map['city'],
      postalCode: map['postalCode'],
      phone: map['phone'],
      email: map['email'],
      website: map['website'],
      notes: map['notes'],
    );
  }
}

