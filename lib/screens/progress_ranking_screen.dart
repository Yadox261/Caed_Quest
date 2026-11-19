import 'package:flutter/material.dart';
import 'package:card_quest/services/progress_ranking_service.dart';
import 'package:card_quest/models/user_profile_model.dart';
import 'package:card_quest/models/score_model.dart';

/// Pantalla interactiva que demuestra el progreso del jugador y el ranking global
/// utilizando StreamBuilder para reaccionar a cambios en tiempo real de Firestore.
class ProgressRankingScreen extends StatelessWidget {
  final String currentUserId;
  final ProgressRankingService _service = ProgressRankingService();

  ProgressRankingScreen({super.key, required this.currentUserId});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F0E17),
        appBar: AppBar(
          title: const Text('Progreso y Ranking', style: TextStyle(color: Colors.white)),
          backgroundColor: const Color(0xFF1E1B2E),
          bottom: const TabBar(
            indicatorColor: Color(0xFFD210EB),
            labelColor: Color(0xFFD210EB),
            unselectedLabelColor: Colors.white60,
            tabs: [
              Tab(icon: Icon(Icons.person), text: 'Mi Progreso'),
              Tab(icon: Icon(Icons.leaderboard), text: 'Ranking Global'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildUserProgressTab(),
            _buildGlobalRankingTab(),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // PESTAÑA 1: PROGRESO DEL USUARIO CON STREAMBUILDER
  // ============================================================
  Widget _buildUserProgressTab() {
    return StreamBuilder<UserProfileModel?>(
      stream: _service.streamUserProfile(currentUserId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFFD210EB)),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error al cargar progreso: ${snapshot.error}',
              style: const TextStyle(color: Colors.redAccent),
            ),
          );
        }

        final profile = snapshot.data;

        if (profile == null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'No se encontró progreso registrado',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD210EB)),
                  onPressed: () {
                    _service.initializeUserProfile(
                      uid: currentUserId,
                      displayName: 'Samurai Novato',
                    );
                  },
                  child: const Text('Inicializar Progreso', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1B2E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFD210EB), width: 1.5),
              ),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 36,
                    backgroundColor: Color(0xFFD210EB),
                    child: Icon(Icons.shield, size: 40, color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    profile.displayName,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            Row(
              children: [
                _buildStatCard('Nivel Desbloqueado', 'Nvl. ${profile.highestUnlockedLevel} / 5', Icons.military_tech),
                const SizedBox(width: 12),
                _buildStatCard('Victorias', '${profile.wins}', Icons.emoji_events),
              ],
            ),
            const SizedBox(height: 12),
            _buildStatCard('Puntuación Total (Ranking)', '${profile.totalScore} pts', Icons.star),

            const SizedBox(height: 30),

            // Simulación de victoria usando la fórmula del documento (Sección 6)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD210EB),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                // Simula victoria en el nivel actual con fórmula oficial
                const mockRemainingHealth = 22;
                const mockTurns = 6;
                final formulaScore = (100 * profile.highestUnlockedLevel) + (5 * mockRemainingHealth) - (2 * mockTurns);

                await _service.recordVictory(
                  uid: currentUserId,
                  completedLevel: profile.highestUnlockedLevel,
                  matchScore: formulaScore,
                );
              },
              icon: const Icon(Icons.flash_on, color: Colors.white),
              label: const Text('Simular Victoria en Batalla', style: TextStyle(color: Colors.white, fontSize: 16)),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // PESTAÑA 2: RANKING GLOBAL CON STREAMBUILDER
  // ============================================================
  Widget _buildGlobalRankingTab() {
    return StreamBuilder<List<ScoreModel>>(
      stream: _service.streamTopScores(limit: 20),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFFD210EB)));
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error al cargar ranking: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent)),
          );
        }

        final scores = snapshot.data ?? [];

        if (scores.isEmpty) {
          return const Center(
            child: Text('Aún no hay puntuaciones registradas en el ranking.', style: TextStyle(color: Colors.white60)),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: scores.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final item = scores[index];
            final rank = index + 1;

            Color badgeColor;
            if (rank == 1) {
              badgeColor = Colors.amber;
            } else if (rank == 2) {
              badgeColor = Colors.grey.shade300;
            } else if (rank == 3) {
              badgeColor = const Color(0xFFCD7F32);
            } else {
              badgeColor = Colors.white24;
            }

            return Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E1B2E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: rank <= 3 ? badgeColor : Colors.white12),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: badgeColor,
                  child: Text(
                    '#$rank',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                ),
                title: Text(
                  item.playerName,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                ),
                subtitle: Text(
                  'Nivel alcanzado: ${item.levelReached}',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                trailing: Text(
                  '${item.points} pts',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFD210EB),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1B2E),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: const Color(0xFFD210EB), size: 28),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.white60)),
          ],
        ),
      ),
    );
  }
}
