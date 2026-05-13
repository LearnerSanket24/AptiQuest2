import 'package:flutter/material.dart';

class AppColors {
  static const Color bg = Color(0xFF0D0D1A);
  static const Color card = Color(0xFF1E1E3A);
  static const Color panel = Color(0xFF1A1A3A);
  static const Color hpRed = Color(0xFFFF4444);
  static const Color xpGold = Color(0xFFFFD700);
}

class AppGradients {
  static const LinearGradient home = LinearGradient(
    colors: [
      Color(0xFF0A1A2A),
      Color(0xFF102D42),
      Color(0xFF253B56),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class BattleConstants {
  static const int correctDamage = 20;
  static const int criticalDamage = 40;
  static const int wrongDamageToPlayer = 10;
  static const int xpPerCorrect = 10;
  static const int coinsPerCorrect = 5;
  static const int levelXpThreshold = 100;
  static const int questionTimerSeconds = 30;
}

class BossConstants {
  static const int questionCount = 30;
  static const int bossHp = 300;
  static const int passScore = 18;
  static const int totalTimerSeconds = 300;
}

class AbilityConstants {
  static const int levelShield = 3;
  static const int levelDoubleDamage = 5;
  static const int levelTimeFreeze = 7;
  static const int levelRevival = 10;
}

class StorageKeys {
  static const String name = 'player_name';
  static const String leaderboard = 'leaderboard_v2';
  static const String profile = 'player_profile_v1';
  static const String topicStats = 'topic_stats_v1';
  static const String floorProgress = 'floor_progress_v1';
  static const String settings = 'settings_v1';
  static const String history = 'battle_history_v1';
  static const String multiplayerHistory = 'multiplayer_history_v1';
  static const String teacherQuestions = 'teacher_questions_v1';
  static const String disabledQuestionIds = 'disabled_question_ids_v1';
}
