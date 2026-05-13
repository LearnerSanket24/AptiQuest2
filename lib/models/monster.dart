class Monster {
  String name;
  String emoji;
  int maxHp;
  int currentHp;
  String category;

  Monster({
    required this.name,
    required this.emoji,
    required this.maxHp,
    required this.category,
  }) : currentHp = maxHp;

  bool get isAlive => currentHp > 0;

  void takeDamage(int dmg) {
    currentHp -= dmg;
    if (currentHp < 0) currentHp = 0;
  }
}

class Boss extends Monster {
  Boss({
    required super.name,
    required super.emoji,
    required super.maxHp,
    required super.category,
  });
}