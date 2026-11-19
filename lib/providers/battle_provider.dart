import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:card_quest/models/card_model.dart';

/// Posibles estados finales o actuales de la partida
enum BattleStatus {
  inProgress, // Combate activo en curso
  victory,    // El enemigo fue derrotado (enemyHp <= 0)
  defeat,     // El jugador fue derrotado (playerHp <= 0)
}

/// Gestor de estado del combate utilizando ChangeNotifier (patrón Provider).
/// Se encarga de la lógica de turnos, puntos de vida, energía, mazo, mano y descarte.
class BattleProvider with ChangeNotifier {
  // ============================================================
  // 1. ESTADO DE VIDA (Jugador y Enemigo)
  // ============================================================

  /// Vida máxima base con la que inicia el jugador
  final int maxPlayerHp = 100;

  /// Vida máxima base con la que inicia el enemigo
  final int maxEnemyHp = 80;

  /// Puntos de vida actuales del jugador (privado para proteger la mutación directa)
  int _playerHp = 100;

  /// Puntos de vida actuales del enemigo
  int _enemyHp = 80;

  /// Puntos de escudo que absorben daño antes de reducir la vida del jugador
  int _playerShield = 0;

  /// Getters públicos de sólo lectura para que la UI los consuma
  int get playerHp => _playerHp;
  int get enemyHp => _enemyHp;
  int get playerShield => _playerShield;

  // ============================================================
  // 2. ESTADO DE ENERGÍA DISPONIBLE
  // ============================================================

  /// Límite máximo de energía por turno
  final int maxEnergy = 3;

  /// Energía restante en el turno actual para gastar en cartas
  int _currentEnergy = 3;

  /// Getter público de la energía disponible
  int get currentEnergy => _currentEnergy;

  // ============================================================
  // 3. MAZO, MANO Y DESCARTE
  // ============================================================

  /// Pila de robo (cartas por salir)
  final List<CardModel> _deck = [];

  /// Cartas actualmente disponibles en la mano del jugador
  final List<CardModel> _hand = [];

  /// Pila de descarte (cartas ya jugadas o descartadas al terminar turno)
  final List<CardModel> _discardPile = [];

  /// Listas inmutables expuestas para evitar modificaciones accidentales desde la UI
  List<CardModel> get hand => List.unmodifiable(_hand);
  List<CardModel> get deck => List.unmodifiable(_deck);
  List<CardModel> get discardPile => List.unmodifiable(_discardPile);

  // ============================================================
  // 4. ESTADO DE LA BATALLA (Victoria / Derrota)
  // ============================================================

  /// Estado actual del combate (en curso, victoria o derrota)
  BattleStatus _status = BattleStatus.inProgress;
  BattleStatus get status => _status;

  /// Bandera para saber si la partida terminó y bloquear nuevas acciones
  bool get isGameOver => _status != BattleStatus.inProgress;

  /// Indica de quién es el turno: true = Jugador, false = Enemigo
  bool _isPlayerTurn = true;
  bool get isPlayerTurn => _isPlayerTurn;

  // ============================================================
  // INICIALIZACIÓN Y REINICIO DE BATALLA
  // ============================================================

  /// El constructor inicializa automáticamente una nueva partida
  BattleProvider() {
    startNewBattle();
  }

  /// Reinicia todos los contadores y configura el mazo para un nuevo combate
  void startNewBattle() {
    _playerHp = maxPlayerHp;
    _enemyHp = maxEnemyHp;
    _playerShield = 0;
    _currentEnergy = maxEnergy;
    _status = BattleStatus.inProgress;
    _isPlayerTurn = true;

    // Limpiar pilas anteriores
    _deck.clear();
    _hand.clear();
    _discardPile.clear();

    // Crear el mazo de cartas temático
    _deck.addAll([
      const CardModel(
        id: '1',
        name: 'Corte Samurai',
        energyCost: 1,
        value: 15,
        type: CardType.attack,
        description: 'Inflige 15 de daño al enemigo',
      ),
      const CardModel(
        id: '2',
        name: 'Golpe de Katana',
        energyCost: 1,
        value: 12,
        type: CardType.attack,
        description: 'Inflige 12 de daño al enemigo',
      ),
      const CardModel(
        id: '3',
        name: 'Postura Defensiva',
        energyCost: 1,
        value: 10,
        type: CardType.defense,
        description: 'Otorga 10 de escudo',
      ),
      const CardModel(
        id: '4',
        name: 'Estocada Veloz',
        energyCost: 2,
        value: 25,
        type: CardType.attack,
        description: 'Inflige 25 de daño crítico',
      ),
      const CardModel(
        id: '5',
        name: 'Guardia Imperial',
        energyCost: 2,
        value: 20,
        type: CardType.defense,
        description: 'Otorga 20 de escudo resistente',
      ),
    ]);

    // Barajar y robar 4 cartas iniciales
    _shuffleDeck();
    _drawCards(4);

    // 5. Notificar a los widgets suscritos para redibujar la pantalla
    notifyListeners();
  }

  // ============================================================
  // ACCIÓN: JUGAR CARTA
  // ============================================================

  /// Ejecuta el efecto de una carta desde la mano del jugador
  bool playCard(CardModel card) {
    // Validar si el juego ya terminó o si no es el turno del jugador
    if (isGameOver || !_isPlayerTurn) return false;

    // Validar si el jugador cuenta con la energía requerida
    if (_currentEnergy < card.energyCost) return false;

    // 1) Deducir la energía gastada
    _currentEnergy -= card.energyCost;

    // 2) Aplicar el efecto de acuerdo al tipo de carta
    if (card.type == CardType.attack) {
      // Inflige daño asegurando que la vida no baje de cero
      _enemyHp = max(0, _enemyHp - card.value);
    } else if (card.type == CardType.defense) {
      // Suma escudo defensivo temporal
      _playerShield += card.value;
    }

    // 3) Mover la carta de la mano a la pila de descarte
    _hand.remove(card);
    _discardPile.add(card);

    // 4) Verificar si el ataque provocó la derrota del enemigo
    _checkBattleEnd();

    // 5) Actualizar la interfaz gráfica reactivamente
    notifyListeners();
    return true;
  }

  // ============================================================
  // GESTIÓN DE TURNOS (JUGADOR Y ENEMIGO)
  // ============================================================

  /// Finaliza el turno del jugador y procesa la respuesta del enemigo
  Future<void> endPlayerTurn() async {
    if (isGameOver || !_isPlayerTurn) return;

    // Cambiar control al turno del enemigo
    _isPlayerTurn = false;

    // Al finalizar el turno, las cartas no usadas en mano van al descarte
    _discardPile.addAll(_hand);
    _hand.clear();

    // Notificar cambio de turno inmediatamente a la UI
    notifyListeners();

    // Pausa simulada para darle dramatismo a la acción del rival (1.5s)
    await Future.delayed(const Duration(milliseconds: 1500));

    // Cálculo aleatorio de ataque enemigo (entre 10 y 20 de daño)
    final randomDamage = Random().nextInt(10) + 10;
    int remainingDamage = randomDamage;

    // El escudo del jugador absorbe el daño en primer lugar
    if (_playerShield > 0) {
      final shieldDamage = min(_playerShield, remainingDamage);
      _playerShield -= shieldDamage;
      remainingDamage -= shieldDamage;
    }

    // El remanente de daño que el escudo no absorbió impacta en la salud
    if (remainingDamage > 0) {
      _playerHp = max(0, _playerHp - remainingDamage);
    }

    // Comprobar si el golpe derrotó al jugador
    _checkBattleEnd();

    // Si la partida no ha acabado, iniciar el siguiente turno del jugador
    if (!isGameOver) {
      _startPlayerTurn();
    } else {
      notifyListeners();
    }
  }

  /// Restaura los recursos al comenzar un nuevo turno del jugador
  void _startPlayerTurn() {
    _isPlayerTurn = true;
    _currentEnergy = maxEnergy; // Se restaura la barra de energía
    _playerShield = 0;         // El escudo temporal se reinicia cada turno
    _drawCards(4);             // Roba 4 nuevas cartas
    notifyListeners();
  }

  // ============================================================
  // ROBO Y REVOLVEDORA DE CARTAS
  // ============================================================

  /// Roba un número determinado de cartas del mazo a la mano
  void _drawCards(int count) {
    for (int i = 0; i < count; i++) {
      // Si la pila de robo se agota, el descarte se recicla al mazo
      if (_deck.isEmpty) {
        if (_discardPile.isEmpty) break; // Ya no hay más cartas en ningún lado
        _deck.addAll(_discardPile);
        _discardPile.clear();
        _shuffleDeck();
      }
      if (_deck.isNotEmpty) {
        _hand.add(_deck.removeLast());
      }
    }
  }

  /// Baraja las cartas de la pila de robo usando orden aleatorio
  void _shuffleDeck() {
    _deck.shuffle(Random());
  }

  // ============================================================
  // CONDICIONES DE VICTORIA O DERROTA
  // ============================================================

  /// Evalúa los puntos de vida para declarar un ganador
  void _checkBattleEnd() {
    if (_enemyHp <= 0) {
      _status = BattleStatus.victory;
    } else if (_playerHp <= 0) {
      _status = BattleStatus.defeat;
    }
  }
}
