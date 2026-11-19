import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:card_quest/models/card_model.dart';
import 'package:card_quest/models/level_config.dart';

/// Posibles estados del combate
enum BattleStatus {
  inProgress, // Combate activo en curso
  victory,    // El enemigo fue derrotado (enemyHp <= 0)
  defeat,     // El jugador fue derrotado (playerHp <= 0)
}

/// Gestor de estado del combate ajustado estrictamente a las reglas de la Sección 6
/// del documento de requerimientos oficiales de Card Quest.
class BattleProvider with ChangeNotifier {
  // ============================================================
  // 1. REGLAS DE VIDA (Jugador: 30 HP máx, Enemigo según nivel)
  // ============================================================

  /// Jugador: 30 de vida máxima fija (Sección 6)
  static const int maxPlayerHp = 30;
  int _playerHp = maxPlayerHp;

  /// Nivel actual y configuración del enemigo
  LevelConfig _currentLevel = LevelConfig.officialLevels[0];
  int _enemyHp = 18;

  /// Escudo del jugador (persiste durante el turno enemigo y se reinicia al inicio de su turno)
  int _playerShield = 0;

  /// Getters de lectura
  int get playerHp => _playerHp;
  int get enemyHp => _enemyHp;
  int get enemyMaxHp => _currentLevel.enemyMaxHealth;
  int get playerShield => _playerShield;
  LevelConfig get currentLevel => _currentLevel;

  // ============================================================
  // 2. ENERGÍA Y TURNOS
  // ============================================================

  /// Jugador: 3 de energía por turno (Sección 6)
  static const int maxEnergy = 3;
  int _currentEnergy = maxEnergy;
  int get currentEnergy => _currentEnergy;

  /// Contador de turnos completados (usado en la fórmula de puntaje)
  int _turnsCompleted = 0;
  int get turnsCompleted => _turnsCompleted;

  /// Turno actual: true = Jugador, false = Enemigo
  bool _isPlayerTurn = true;
  bool get isPlayerTurn => _isPlayerTurn;

  /// Bandera para evitar dobles ejecuciones mientras se procesa una acción (RF-08)
  bool _isActionResolving = false;
  bool get isActionResolving => _isActionResolving;

  /// El enemigo cura 4 puntos una sola vez por combate si su vida es <= 30% (Sección 6)
  bool _enemyHasHealedOnce = false;

  /// Intención del enemigo para mostrar en la interfaz (RF-07)
  String _enemyIntent = 'Atacar';
  String get enemyIntent => _enemyIntent;

  // ============================================================
  // 3. MAZO, MANO Y DESCARTE (Mano máxima 5, Mazo inicial de 10 cartas)
  // ============================================================

  static const int maxHandSize = 5;

  final List<CardModel> _deck = [];
  final List<CardModel> _hand = [];
  final List<CardModel> _discardPile = [];

  List<CardModel> get hand => List.unmodifiable(_hand);
  List<CardModel> get deck => List.unmodifiable(_deck);
  List<CardModel> get discardPile => List.unmodifiable(_discardPile);

  // ============================================================
  // 4. ESTADO DE LA BATALLA Y RESULTADOS
  // ============================================================

  BattleStatus _status = BattleStatus.inProgress;
  BattleStatus get status => _status;
  bool get isGameOver => _status != BattleStatus.inProgress;

  /// Puntuación final calculada al ganar: max(0, 100 * nivel + 5 * vidaRestante - 2 * turnos)
  int _calculatedScore = 0;
  int get calculatedScore => _calculatedScore;

  // ============================================================
  // INICIALIZACIÓN DE LA BATALLA
  // ============================================================

  BattleProvider({int levelNumber = 1}) {
    startBattle(levelNumber: levelNumber);
  }

  /// Inicia el combate configurando el nivel solicitado (1 a 5)
  void startBattle({int levelNumber = 1}) {
    final levelIndex = (levelNumber - 1).clamp(0, LevelConfig.officialLevels.length - 1);
    _currentLevel = LevelConfig.officialLevels[levelIndex];

    _playerHp = maxPlayerHp;
    _enemyHp = _currentLevel.enemyMaxHealth;
    _playerShield = 0;
    _currentEnergy = maxEnergy;
    _turnsCompleted = 0;
    _isPlayerTurn = true;
    _isActionResolving = false;
    _enemyHasHealedOnce = false;
    _status = BattleStatus.inProgress;
    _calculatedScore = 0;
    _updateEnemyIntent();

    // RF-06: Mazo inicial de diez instancias con repeticiones permitidas:
    // cuatro Golpes, tres Escudos, dos Pociones y un Fuego.
    _deck.clear();
    _hand.clear();
    _discardPile.clear();

    _deck.addAll([
      // 4 Golpes (Costo 1, Daño 4)
      const CardModel(id: 'golpe_1', name: 'Golpe', energyCost: 1, value: 4, type: CardType.attack, description: 'Inflige 4 de daño'),
      const CardModel(id: 'golpe_2', name: 'Golpe', energyCost: 1, value: 4, type: CardType.attack, description: 'Inflige 4 de daño'),
      const CardModel(id: 'golpe_3', name: 'Golpe', energyCost: 1, value: 4, type: CardType.attack, description: 'Inflige 4 de daño'),
      const CardModel(id: 'golpe_4', name: 'Golpe', energyCost: 1, value: 4, type: CardType.attack, description: 'Inflige 4 de daño'),

      // 3 Escudos (Costo 1, Añade 5 de escudo)
      const CardModel(id: 'escudo_1', name: 'Escudo', energyCost: 1, value: 5, type: CardType.defense, description: 'Añade 5 de escudo'),
      const CardModel(id: 'escudo_2', name: 'Escudo', energyCost: 1, value: 5, type: CardType.defense, description: 'Añade 5 de escudo'),
      const CardModel(id: 'escudo_3', name: 'Escudo', energyCost: 1, value: 5, type: CardType.defense, description: 'Añade 5 de escudo'),

      // 2 Pociones (Costo 2, Cura 6)
      const CardModel(id: 'pocion_1', name: 'Poción', energyCost: 2, value: 6, type: CardType.heal, description: 'Cura 6 puntos de vida'),
      const CardModel(id: 'pocion_2', name: 'Poción', energyCost: 2, value: 6, type: CardType.heal, description: 'Cura 6 puntos de vida'),

      // 1 Fuego (Costo 2, Daño 7)
      const CardModel(id: 'fuego_1', name: 'Fuego', energyCost: 2, value: 7, type: CardType.attack, description: 'Inflige 7 de daño de fuego'),
    ]);

    // Comienza el combate con el mazo barajado, mano vacía y descarte vacío
    _shuffleDeck();
    _drawCardsUntilFull(); // Al iniciar el turno roba hasta tener 5 cartas
    notifyListeners();
  }

  // ============================================================
  // ACCIÓN DEL JUGADOR: JUGAR CARTA (RF-08)
  // ============================================================

  bool playCard(CardModel card) {
    if (isGameOver || !_isPlayerTurn || _isActionResolving) return false;
    if (!_hand.contains(card)) return false;
    if (_currentEnergy < card.energyCost) return false;

    _isActionResolving = true;

    // Descontar costo de energía
    _currentEnergy -= card.energyCost;

    // Aplicar efecto de la carta
    switch (card.type) {
      case CardType.attack:
        _enemyHp = max(0, _enemyHp - card.value);
        break;
      case CardType.defense:
        _playerShield += card.value;
        break;
      case CardType.heal:
        // La vida nunca supera el máximo de 30 (Sección 6)
        _playerHp = min(maxPlayerHp, _playerHp + card.value);
        break;
      case CardType.special:
        break;
    }

    // Pasa de la mano al descarte
    _hand.remove(card);
    _discardPile.add(card);

    _updateEnemyIntent();
    _checkBattleEnd();

    _isActionResolving = false;
    notifyListeners();
    return true;
  }

  // ============================================================
  // TURNO DEL ENEMIGO (RF-09 / Sección 6)
  // ============================================================

  Future<void> endPlayerTurn() async {
    if (isGameOver || !_isPlayerTurn || _isActionResolving) return;

    _isActionResolving = true;
    _isPlayerTurn = false;
    _turnsCompleted++;

    // Al finalizar el turno, las cartas restantes en mano pasan al descarte
    _discardPile.addAll(_hand);
    _hand.clear();
    notifyListeners();

    // Pausa visual para la animación/acción del rival (1.2 segundos)
    await Future.delayed(const Duration(milliseconds: 1200));

    // Regla de IA del enemigo (Sección 6):
    // "Si su vida es 30% o menos, cura 4 puntos una sola vez por combate; en otro caso ataca con su daño configurado"
    final enemyHpThreshold = (_currentLevel.enemyMaxHealth * 0.30).ceil();

    if (_enemyHp <= enemyHpThreshold && !_enemyHasHealedOnce) {
      // Curación del enemigo (una sola vez)
      _enemyHp = min(_currentLevel.enemyMaxHealth, _enemyHp + 4);
      _enemyHasHealedOnce = true;
    } else {
      // Ataque del enemigo
      int remainingDamage = _currentLevel.enemyDamage;

      // El escudo absorbe daño antes que la vida
      if (_playerShield > 0) {
        final absorbed = min(_playerShield, remainingDamage);
        _playerShield -= absorbed;
        remainingDamage -= absorbed;
      }

      // El remanente reduce la vida (nunca baja de cero)
      if (remainingDamage > 0) {
        _playerHp = max(0, _playerHp - remainingDamage);
      }
    }

    _checkBattleEnd();

    if (!isGameOver) {
      _startPlayerTurn();
    } else {
      _isActionResolving = false;
      notifyListeners();
    }
  }

  /// Al iniciar cada turno del jugador (Sección 6):
  /// - Su escudo vuelve a cero
  /// - Su energía vuelve a 3
  /// - Roba hasta tener 5 cartas (máximo de 5)
  void _startPlayerTurn() {
    _isPlayerTurn = true;
    _playerShield = 0;
    _currentEnergy = maxEnergy;
    _drawCardsUntilFull();
    _updateEnemyIntent();
    _isActionResolving = false;
    notifyListeners();
  }

  // ============================================================
  // ROBO Y BARAJAJE (Sección 6)
  // ============================================================

  /// Roba hasta tener cinco cartas en mano
  void _drawCardsUntilFull() {
    while (_hand.length < maxHandSize) {
      if (_deck.isEmpty) {
        if (_discardPile.isEmpty) break; // Si no hay cartas en ningún lado, roba lo posible
        // Si se agota el mazo al robar, se baraja el descarte para formar uno nuevo
        _deck.addAll(_discardPile);
        _discardPile.clear();
        _shuffleDeck();
      }
      if (_deck.isNotEmpty) {
        _hand.add(_deck.removeLast());
      }
    }
  }

  void _shuffleDeck() {
    _deck.shuffle(Random());
  }

  void _updateEnemyIntent() {
    final enemyHpThreshold = (_currentLevel.enemyMaxHealth * 0.30).ceil();
    if (_enemyHp <= enemyHpThreshold && !_enemyHasHealedOnce) {
      _enemyIntent = 'Curar (+4 HP)';
    } else {
      _enemyIntent = 'Atacar (${_currentLevel.enemyDamage} Daño)';
    }
  }

  // ============================================================
  // EVALUACIÓN DE VICTORIA / DERROTA Y FÓRMULA DE PUNTAJE (Sección 6)
  // ============================================================

  void _checkBattleEnd() {
    if (_enemyHp <= 0) {
      _status = BattleStatus.victory;
      // Fórmula oficial: max(0, 100 * nivel + 5 * vidaRestante - 2 * turnos)
      final scoreFormula = (100 * _currentLevel.levelNumber) +
          (5 * _playerHp) -
          (2 * _turnsCompleted);
      _calculatedScore = max(0, scoreFormula);
    } else if (_playerHp <= 0) {
      _status = BattleStatus.defeat;
      _calculatedScore = 0; // Una derrota no suma puntaje
    }
  }
}
