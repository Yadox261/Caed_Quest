/// Configuración de nivel según la tabla de la Sección 6 del documento de requerimientos
class LevelConfig {
  final int levelNumber;
  final String enemyName;
  final int enemyMaxHealth;
  final int enemyDamage;

  const LevelConfig({
    required this.levelNumber,
    required this.enemyName,
    required this.enemyMaxHealth,
    required this.enemyDamage,
  });

  /// Lista fija de los 5 niveles obligatorios del documento (RF-05 / Sección 6)
  static const List<LevelConfig> officialLevels = [
    LevelConfig(levelNumber: 1, enemyName: 'Bandido de los Caminos', enemyMaxHealth: 18, enemyDamage: 3),
    LevelConfig(levelNumber: 2, enemyName: 'Espadachín Renegado', enemyMaxHealth: 23, enemyDamage: 4),
    LevelConfig(levelNumber: 3, enemyName: 'Guardia Imperial Corrupto', enemyMaxHealth: 28, enemyDamage: 4),
    LevelConfig(levelNumber: 4, enemyName: 'General de Sombras', enemyMaxHealth: 33, enemyDamage: 5),
    LevelConfig(levelNumber: 5, enemyName: 'Señor del Abismo', enemyMaxHealth: 38, enemyDamage: 6),
  ];
}
