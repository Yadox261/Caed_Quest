/// Tipo de efecto principal que ejecuta la carta al ser jugada
enum CardType {
  attack,  // Inflige daño a los puntos de vida del enemigo
  defense, // Proporciona escudo temporal al jugador para absorber daño
  heal,    // Restaura puntos de vida al jugador (hasta el máximo de 30)
  special, // Efectos especiales (ej. robo de cartas)
}

/// Modelo de datos que representa una carta dentro de Card Quest (Sección 6 del documento)
class CardModel {
  /// Identificador único de instancia de la carta
  final String id;

  /// Nombre visible de la carta (ej. 'Golpe', 'Escudo', 'Poción', 'Fuego')
  final String name;

  /// Costo de energía por turno para poder jugarla
  final int energyCost;

  /// Valor del efecto: cantidad de daño, escudo o curación
  final int value;

  /// Tipo de carta (ataque, defensa, curación o especial)
  final CardType type;

  /// Descripción detallada del efecto según las reglas del documento
  final String description;

  const CardModel({
    required this.id,
    required this.name,
    required this.energyCost,
    required this.value,
    required this.type,
    required this.description,
  });
}
