import 'dart:convert';
import 'package:flutter/material.dart';

class PhotoProject {
  final String id;
  final String originalImportedPath; // Asla silinmeyecek orijinal galeri yolu
  final List<String> capturedPaths;   // Uygulama içinden çekilenler (silinebilir)
  final DateTime createdAt;

  PhotoProject({
    required this.id,
    required this.originalImportedPath,
    required this.capturedPaths,
    required this.createdAt,
  });

  List<String> get allPhotos => [originalImportedPath, ...capturedPaths];
  int get totalCount => allPhotos.length;

  Color get statusColor {
    if (totalCount == 1) return Colors.amber.shade600; // Sarı: Tek foto
    if (totalCount == 2) return Colors.green.shade600; // Yeşil: Eşli/Çift
    return Colors.purple.shade600;                     // Mor: 3+ foto
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'originalImportedPath': originalImportedPath,
        'capturedPaths': capturedPaths,
        'createdAt': createdAt.toIso8601String(),
      };

  factory PhotoProject.fromMap(Map<String, dynamic> map) => PhotoProject(
        id: map['id'],
        originalImportedPath: map['originalImportedPath'],
        capturedPaths: List<String>.from(map['capturedPaths'] ?? []),
        createdAt: DateTime.parse(map['createdAt']),
      );

  String toJson() => json.encode(toMap());
  factory PhotoProject.fromJson(String source) =>
      PhotoProject.fromMap(json.decode(source));
}