import 'enemy.dart';
import 'shadow_game.dart';
import 'player.dart';

class CombatStepResult {
  final bool correct;
  final bool critical;
  final bool blocked;
  final int damageApplied;
  final int comboCount;
  final int playerHp;
  final int enemyHp;
  final bool playerDefeated;
  final bool enemyDefeated;

  const CombatStepResult({
    required this.correct,
    required this.critical,
    required this.blocked,
    required this.damageApplied,
    required this.comboCount,
    required this.playerHp,
    required this.enemyHp,
    required this.playerDefeated,
    required this.enemyDefeated,
  });
}

class BattleController {
  final ShadowGame game;
  final ShadowPlayer player;
  final ShadowEnemy enemy;

  bool _busy = false;
  int streak = 0;
  int comboCount = 0;
  bool bossMode = false;

  BattleController({
    required this.game,
    required this.player,
    required this.enemy,
  });

  bool get isBusy => _busy;

  void resetForRound({
    required int playerHp,
    required int enemyHp,
    required int enemyMaxHp,
    required bool isBoss,
  }) {
    bossMode = isBoss;
    player.resetForRound(hp: playerHp, maxRoundHp: player.maxHp);
    enemy.resetForRound(hp: enemyHp, maxRoundHp: enemyMaxHp);
  }

  Future<CombatStepResult> resolveAnswer({
    required bool correct,
    int playerDamage = 20,
    int enemyDamage = 10,
    bool shieldActive = false,
    bool forceCritical = false,
  }) async {
    if (_busy) {
      return CombatStepResult(
        correct: correct,
        critical: false,
        blocked: false,
        damageApplied: 0,
        comboCount: comboCount,
        playerHp: player.currentHp,
        enemyHp: enemy.currentHp,
        playerDefeated: player.currentHp <= 0,
        enemyDefeated: enemy.currentHp <= 0,
      );
    }

    _busy = true;

    try {
      if (correct) {
        streak++;
        comboCount++;

        final critical = forceCritical || (streak > 0 && streak % 3 == 0);
        final appliedDamage = critical ? (playerDamage < 40 ? 40 : playerDamage) : playerDamage;
        final finisher = enemy.currentHp <= appliedDamage;

        await game.playerAttack(
          damage: appliedDamage,
          critical: critical,
          finisher: finisher,
          comboHits: critical ? 4 : 3,
        );

        enemy.takeDamage(appliedDamage);

        return CombatStepResult(
          correct: true,
          critical: critical,
          blocked: false,
          damageApplied: appliedDamage,
          comboCount: comboCount,
          playerHp: player.currentHp,
          enemyHp: enemy.currentHp,
          playerDefeated: player.currentHp <= 0,
          enemyDefeated: enemy.currentHp <= 0,
        );
      }

      streak = 0;
      comboCount = 0;

      final appliedEnemyDamage = shieldActive ? 0 : enemyDamage;

      await game.enemyAttack(
        damage: appliedEnemyDamage,
        blocked: shieldActive,
        heavy: bossMode,
      );

      if (!shieldActive) {
        player.takeDamage(appliedEnemyDamage);
      }

      return CombatStepResult(
        correct: false,
        critical: false,
        blocked: shieldActive,
        damageApplied: appliedEnemyDamage,
        comboCount: comboCount,
        playerHp: player.currentHp,
        enemyHp: enemy.currentHp,
        playerDefeated: player.currentHp <= 0,
        enemyDefeated: enemy.currentHp <= 0,
      );
    } catch (_) {
      if (correct) {
        final critical = forceCritical || (streak > 0 && streak % 3 == 0);
        final appliedDamage = critical ? (playerDamage < 40 ? 40 : playerDamage) : playerDamage;
        enemy.takeDamage(appliedDamage);
        return CombatStepResult(
          correct: true,
          critical: critical,
          blocked: false,
          damageApplied: appliedDamage,
          comboCount: comboCount,
          playerHp: player.currentHp,
          enemyHp: enemy.currentHp,
          playerDefeated: player.currentHp <= 0,
          enemyDefeated: enemy.currentHp <= 0,
        );
      }

      streak = 0;
      comboCount = 0;
      final appliedEnemyDamage = shieldActive ? 0 : enemyDamage;
      if (!shieldActive) {
        player.takeDamage(appliedEnemyDamage);
      }
      return CombatStepResult(
        correct: false,
        critical: false,
        blocked: shieldActive,
        damageApplied: appliedEnemyDamage,
        comboCount: comboCount,
        playerHp: player.currentHp,
        enemyHp: enemy.currentHp,
        playerDefeated: player.currentHp <= 0,
        enemyDefeated: enemy.currentHp <= 0,
      );
    } finally {
      _busy = false;
    }
  }
}
