import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:card_quest/models/user_profile_model.dart';
import 'package:card_quest/models/score_model.dart';

/// Servicio encargado del progreso del usuario y el ranking global
/// estructurado exactamente con los nombres de campos de la Sección 10.
class ProgressRankingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String usersCollection = 'users';
  static const String scoresCollection = 'scores';

  /// Inicializa el perfil del usuario al registrarse (Sección 10)
  Future<void> initializeUserProfile({
    required String uid,
    required String displayName,
    String? email,
  }) async {
    final docRef = _firestore.collection(usersCollection).doc(uid);
    final docSnap = await docRef.get();

    if (!docSnap.exists) {
      final initialProfile = UserProfileModel(
        uid: uid,
        displayName: displayName,
        highestUnlockedLevel: 1, // El nivel 1 inicia desbloqueado (RF-05)
        wins: 0,
        bestScoresByLevel: {},
        totalScore: 0,
      );
      await docRef.set(initialProfile.toMap());
    }
  }

  /// Escucha el perfil del usuario en tiempo real con StreamBuilder
  Stream<UserProfileModel?> streamUserProfile(String uid) {
    return _firestore
        .collection(usersCollection)
        .doc(uid)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return null;
      return UserProfileModel.fromFirestore(snapshot);
    });
  }

  /// Registra el resultado de victoria atómicamente:
  /// - Incrementa victorias (wins)
  /// - Desbloquea el siguiente nivel si completó su nivel máximo (RF-05)
  /// - Actualiza la mejor puntuación del nivel y recalcula totalScore como la suma
  ///   de los mejores puntajes de los 5 niveles (Sección 6)
  Future<void> recordVictory({
    required String uid,
    required int completedLevel,
    required int matchScore,
  }) async {
    final docRef = _firestore.collection(usersCollection).doc(uid);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;

      final profile = UserProfileModel.fromFirestore(snapshot);

      // Calcular nuevo nivel desbloqueado (máximo 5 niveles)
      final newLevel = (completedLevel >= profile.highestUnlockedLevel && profile.highestUnlockedLevel < 5)
          ? completedLevel + 1
          : profile.highestUnlockedLevel;

      // Actualizar el mapa de mejores puntajes por nivel
      final levelKey = 'level_$completedLevel';
      final currentLevelBest = profile.bestScoresByLevel[levelKey] ?? 0;
      final updatedScoresByLevel = Map<String, int>.from(profile.bestScoresByLevel);

      if (matchScore > currentLevelBest) {
        updatedScoresByLevel[levelKey] = matchScore;
      }

      // El puntaje total del ranking es la suma de los mejores puntajes de los cinco niveles (Sección 6)
      final newTotalScore = updatedScoresByLevel.values.fold(0, (total, score) => total + score);

      transaction.update(docRef, {
        'wins': FieldValue.increment(1),
        'highestUnlockedLevel': newLevel,
        'bestScoresByLevel': updatedScoresByLevel,
        'totalScore': newTotalScore,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Añadir la entrada al ranking global de scores
      await addScore(
        userId: uid,
        playerName: profile.displayName,
        points: newTotalScore,
        levelReached: newLevel,
      );
    });
  }

  /// Añade una puntuación a la colección global 'scores'
  Future<void> addScore({
    required String userId,
    required String playerName,
    required int points,
    required int levelReached,
  }) async {
    final score = ScoreModel(
      id: '',
      userId: userId,
      playerName: playerName,
      points: points,
      levelReached: levelReached,
    );

    await _firestore.collection(scoresCollection).add(score.toMap());
  }

  /// Retorna las mejores 20 puntuaciones en tiempo real (RF-12)
  Stream<List<ScoreModel>> streamTopScores({int limit = 20}) {
    return _firestore
        .collection(scoresCollection)
        .orderBy('points', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ScoreModel.fromFirestore(doc))
          .toList();
    });
  }
}
