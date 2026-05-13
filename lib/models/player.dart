class Player {
  Player({
    required String name,
    int maxHp = 100,
    int currentHp = 100,
    int xp = 0,
    int level = 1,
    int coins = 10,
    int streak = 0,
  })  : _name = name,
        _maxHp = maxHp,
        _currentHp = currentHp,
        _xp = xp,
        _level = level,
        _coins = coins,
        _streak = streak;

  String _name;
  int _maxHp;
  int _currentHp;
  int _xp;
  int _level;
  int _coins;
  int _streak;

  String get name => _name;
  int get maxHp => _maxHp;
  int get currentHp => _currentHp;
  int get xp => _xp;
  int get level => _level;
  int get coins => _coins;
  int get streak => _streak;

  bool get isAlive => _currentHp > 0;
  bool get isCritical => _streak > 0 && _streak % 3 == 0;

  double get hpPercent => _maxHp == 0 ? 0 : _currentHp / _maxHp;

  bool get canUseShield => _level >= 3;
  bool get canUseDoubleDamage => _level >= 5;
  bool get canUseTimeFreeze => _level >= 7;
  bool get canUseRevival => _level >= 10;

  int get damageDealt => isCritical ? 40 : 20;

  void setName(String value) {
    _name = value;
  }

  void takeDamage(int damage) {
    _currentHp -= damage;
    if (_currentHp < 0) {
      _currentHp = 0;
    }
    _streak = 0;
  }

  void heal(int amount) {
    _currentHp += amount;
    if (_currentHp > _maxHp) {
      _currentHp = _maxHp;
    }
  }

  void recoverAfterFloor() {
    heal(25);
  }

  void gainXp(int amount) {
    _xp += amount;
    while (_xp >= 100) {
      _xp -= 100;
      _level++;
    }
  }

  void addCoins(int value) {
    _coins += value;
  }

  void correctAnswer({int xpEarned = 10, int coinsEarned = 5}) {
    _streak++;
    addCoins(coinsEarned);
    gainXp(xpEarned);
  }

  void resetStreak() {
    _streak = 0;
  }

  factory Player.fromJson(Map<String, dynamic> json) {
    return Player(
      name: json['name'] as String? ?? 'Player',
      maxHp: json['maxHp'] as int? ?? 100,
      currentHp: json['currentHp'] as int? ?? 100,
      xp: json['xp'] as int? ?? 0,
      level: json['level'] as int? ?? 1,
      coins: json['coins'] as int? ?? 10,
      streak: json['streak'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': _name,
      'maxHp': _maxHp,
      'currentHp': _currentHp,
      'xp': _xp,
      'level': _level,
      'coins': _coins,
      'streak': _streak,
    };
  }
}