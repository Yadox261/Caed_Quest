/// Tipo de efecto principal que ejecuta la carta al ser jugada
enum CardType {
  attack,  // Inflige daño a los puntos de vida del enemigo
  defense, // Proporciona escudo temporal al jugador para absorber daño
  special, // Efectos especiales (curación, robo adicional, potenciadores)
}

/// Modelo de datos que representa una carta dentro del combate
class CardModel {
  /// Identificador único de la carta
  final String id;

  /// Nombre visible de la carta (ej. 'Corte Samurai')
  final String name;

  /// Costo de puntos de energía requeridos para poder jugarla
  final int energyCost;

  /// Valor numérico principal: cantidad de daño infligido o escudo generado
  final int value;

  /// Categoría o tipo de la carta (ataque, defensa o especial)
  final CardType type;

  /// Descripción detallada del efecto para mostrar en la interfaz
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
