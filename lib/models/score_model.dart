import 'package:cloud_firestore/cloud_firestore.dart';

/// Modelo de datos que representa una entrada en el ranking global de puntuaciones
class ScoreModel {
  /// Identificador único del documento de puntuación
  final String id;

  /// Identificador del usuario dueño de la puntuación
  final String userId;

  /// Nombre del jugador mostrado en el ranking
  final String playerName;

  /// Puntos conseguidos en la partida
  final int points;

  /// Nivel alcanzado en dicha puntuación
  final int levelReached;

  /// Fecha en la que se registró la puntuación
  final DateTime? timestamp;

  const ScoreModel({
    required this.id,
    required this.userId,
    required this.playerName,
    required this.points,
    required this.levelReached,
    this.timestamp,
  });

  /// Factory para construir el modelo a partir de un DocumentSnapshot de Firestore
  factory ScoreModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return ScoreModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      playerName: data['playerName'] ?? 'Anónimo',
      points: (data['points'] as num?)?.toInt() ?? 0,
      levelReached: (data['levelReached'] as num?)?.toInt() ?? 1,
      timestamp: (data['timestamp'] as Timestamp?)?.toDate(),
    );
  }

  /// Convierte la instancia en un Map para persistir en la colección 'scores'
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'playerName': playerName,
      'points': points,
      'levelReached': levelReached,
      'timestamp': FieldValue.serverTimestamp(),
    };
  }
}
