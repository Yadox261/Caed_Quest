import 'package:cloud_firestore/cloud_firestore.dart';

/// Modelo de perfil y progreso según la Sección 10 del documento de requerimientos:
/// users/{uid}: displayName, avatarPath, avatarUrl, highestUnlockedLevel, wins,
/// bestScoresByLevel, totalScore, createdAt, updatedAt
class UserProfileModel {
  final String uid;
  final String displayName;
  final String? avatarPath;
  final String? avatarUrl;
  final int highestUnlockedLevel;
  final int wins;
  final Map<String, int> bestScoresByLevel;
  final int totalScore;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const UserProfileModel({
    required this.uid,
    required this.displayName,
    this.avatarPath,
    this.avatarUrl,
    required this.highestUnlockedLevel,
    required this.wins,
    required this.bestScoresByLevel,
    required this.totalScore,
    this.createdAt,
    this.updatedAt,
  });

  /// Factory para mapear desde DocumentSnapshot de Firestore
  factory UserProfileModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    // Mapear el mapa de mejores puntuaciones por nivel
    final rawScores = data['bestScoresByLevel'] as Map<String, dynamic>? ?? {};
    final scoresMap = rawScores.map((key, value) => MapEntry(key, (value as num).toInt()));

    return UserProfileModel(
      uid: doc.id,
      displayName: data['displayName'] ?? data['name'] ?? 'Samurai',
      avatarPath: data['avatarPath'],
      avatarUrl: data['avatarUrl'],
      highestUnlockedLevel: (data['highestUnlockedLevel'] as num?)?.toInt() ?? 1,
      wins: (data['wins'] as num?)?.toInt() ?? (data['totalVictories'] as num?)?.toInt() ?? 0,
      bestScoresByLevel: scoresMap,
      totalScore: (data['totalScore'] as num?)?.toInt() ?? (data['highScore'] as num?)?.toInt() ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Convierte a Map para guardar en Firestore cumpliendo el esquema oficial (Sección 10)
  Map<String, dynamic> toMap() {
    return {
      'displayName': displayName,
      'avatarPath': avatarPath,
      'avatarUrl': avatarUrl,
      'highestUnlockedLevel': highestUnlockedLevel,
      'wins': wins,
      'bestScoresByLevel': bestScoresByLevel,
      'totalScore': totalScore,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
