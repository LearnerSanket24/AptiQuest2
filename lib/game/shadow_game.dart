import 'dart:async';
import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'battle_controller.dart';
import 'enemy.dart';
import 'player.dart';

class ShadowGame extends FlameGame {
  late final PositionComponent stage;
  late final RectangleComponent backdrop;
  late final RectangleComponent floorGlow;
  late final CircleComponent playerAura;
  late final CircleComponent enemyAura;
  late final RectangleComponent playerFallback;
  late final RectangleComponent enemyFallback;
  late final TextComponent arenaLabel;
  late final ShadowPlayer player;
  late final ShadowEnemy enemy;
  late final BattleController battleController;
  Sprite? _slashSprite;

  final Random _random = Random();

  bool _loaded = false;
  bool _spriteLoadFailed = false;
  _RoundConfig? _pendingRound;
  final Completer<void> _readyCompleter = Completer<void>();

  @override
  Color backgroundColor() => const Color(0xFF0C1030);

  @override
  Future<void> onLoad() async {
    stage = PositionComponent();
    add(stage);

    backdrop = RectangleComponent(
      size: Vector2(900, 420),
      paint: Paint()..color = const Color(0xFF0C1030),
    )..priority = 0;

    floorGlow = RectangleComponent(
      size: Vector2(900, 130),
      position: Vector2(0, 290),
      paint: Paint()..color = const Color(0x552B3F8A),
    )..priority = 1;

    playerAura = CircleComponent(
      radius: 46,
      paint: Paint()..color = const Color(0x55FFD36A),
      anchor: Anchor.center,
      priority: 2,
    );

    enemyAura = CircleComponent(
      radius: 46,
      paint: Paint()..color = const Color(0x55FF5C5C),
      anchor: Anchor.center,
      priority: 2,
    );

    playerFallback = RectangleComponent(
      size: Vector2(74, 110),
      paint: Paint()..color = const Color(0xFFFFD36A),
      anchor: Anchor.bottomCenter,
      priority: 6,
    );

    enemyFallback = RectangleComponent(
      size: Vector2(74, 110),
      paint: Paint()..color = const Color(0xFFFF5C5C),
      anchor: Anchor.bottomCenter,
      priority: 6,
    );

    arenaLabel = TextComponent(
      text: 'ARENA',
      priority: 40,
      anchor: Anchor.topCenter,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Color(0xB3FFFFFF),
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );

    stage.add(backdrop);
    stage.add(floorGlow);
    stage.add(playerAura);
    stage.add(enemyAura);
    stage.add(playerFallback);
    stage.add(enemyFallback);
    stage.add(arenaLabel);

    player = ShadowPlayer(maxHp: 100, currentHp: 100);
    enemy = ShadowEnemy(maxHp: 100, currentHp: 100);

    stage.add(player);
    stage.add(enemy);

    try {
      await player.loaded;
      await enemy.loaded;
      playerFallback.removeFromParent();
      enemyFallback.removeFromParent();
    } catch (_) {
      _spriteLoadFailed = true;
    }

    try {
      _slashSprite = await loadSprite('slash.png');
    } catch (_) {
      _slashSprite = null;
    }

    battleController = BattleController(game: this, player: player, enemy: enemy);

    _layoutStage();
    _loaded = true;
    if (!_readyCompleter.isCompleted) {
      _readyCompleter.complete();
    }

    if (_pendingRound != null) {
      final pending = _pendingRound!;
      _pendingRound = null;
      configureRound(
        playerHp: pending.playerHp,
        enemyHp: pending.enemyHp,
        enemyMaxHp: pending.enemyMaxHp,
        isBoss: pending.isBoss,
      );
    }
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _layoutStage();
  }

  void _layoutStage() {
    if (!_loaded) {
      return;
    }

    final stageWidth = size.x > 1 ? size.x : 360.0;
    final stageHeight = max(size.y > 1 ? size.y : 250.0, 280.0);
    backdrop.size = Vector2(stageWidth, stageHeight);

    player.setBasePosition(Vector2(stageWidth * 0.23, stageHeight - 18));
    enemy.setBasePosition(Vector2(stageWidth * 0.77, stageHeight - 18));
    playerFallback.position = player.basePosition.clone();
    enemyFallback.position = enemy.basePosition.clone();
    playerAura.position = player.basePosition + Vector2(0, -42);
    enemyAura.position = enemy.basePosition + Vector2(0, -42);
    floorGlow.size = Vector2(stageWidth, 130);
    floorGlow.position = Vector2(0, stageHeight - 130);
    arenaLabel.position = Vector2(stageWidth / 2, 8);
  }

  void configureRound({
    required int playerHp,
    required int enemyHp,
    required int enemyMaxHp,
    required bool isBoss,
  }) {
    if (!_loaded) {
      _pendingRound = _RoundConfig(
        playerHp: playerHp,
        enemyHp: enemyHp,
        enemyMaxHp: enemyMaxHp,
        isBoss: isBoss,
      );
      return;
    }

    battleController.resetForRound(
      playerHp: playerHp,
      enemyHp: enemyHp,
      enemyMaxHp: enemyMaxHp,
      isBoss: isBoss,
    );
  }

  Future<CombatStepResult> resolveAnswer({
    required bool correct,
    int playerDamage = 20,
    int enemyDamage = 10,
    bool shieldActive = false,
    bool forceCritical = false,
  }) async {
    if (!_loaded) {
      await _readyCompleter.future;
    }

    return battleController.resolveAnswer(
      correct: correct,
      playerDamage: playerDamage,
      enemyDamage: enemyDamage,
      shieldActive: shieldActive,
      forceCritical: forceCritical,
    );
  }

  int get comboCount {
    if (!_loaded) {
      return 0;
    }
    return battleController.comboCount;
  }

  void syncPlayerHp(int hp) {
    if (!_loaded) {
      return;
    }
    player.setHp(hp);
  }

  void syncEnemyHp({required int hp, required int maxHp}) {
    if (!_loaded) {
      return;
    }
    enemy.resetForRound(hp: hp, maxRoundHp: maxHp);
  }

  Future<void> playerAttack({
    required int damage,
    required bool critical,
    required bool finisher,
    required int comboHits,
  }) async {
    player.playRun();

    final dashDistance = critical ? 200 : 150;
    await _moveByAndWait(
      player,
      Vector2(dashDistance.toDouble(), 0),
      duration: 0.12,
      curve: Curves.easeOutCubic,
    );

    for (var i = 0; i < comboHits; i++) {
      player.playAttack();
      final isFinalHit = i == comboHits - 1;
      final showDamage = isFinalHit ? damage : max(6, damage ~/ comboHits);

      await _showSlashEffect(enemy.position.clone(), big: isFinalHit);
      await _showDamagePopup(
        text: critical && isFinalHit ? 'CRITICAL $damage' : '-$showDamage',
        position: enemy.position.clone() + Vector2(0, -80),
        color: critical && isFinalHit ? Colors.orangeAccent : Colors.redAccent,
      );

      enemy.playHit();
      await _moveByAndWait(
        enemy,
        Vector2(isFinalHit ? 90 : 32, 0),
        duration: isFinalHit ? 0.2 : 0.12,
        curve: Curves.easeOut,
      );

      await _hitStop(isFinalHit ? 120 : 90);
      await _shakeStage(intensity: isFinalHit ? 14 : 9, durationMs: isFinalHit ? 140 : 90);

      if (isFinalHit && finisher) {
        enemy.playDeath();
      }

      await Future<void>.delayed(Duration(milliseconds: isFinalHit ? 170 : 110));
    }

    await _moveToBaseAndIdle();
  }

  Future<void> enemyAttack({
    required int damage,
    required bool blocked,
    required bool heavy,
  }) async {
    enemy.playRun();

    await _moveByAndWait(
      enemy,
      Vector2(-150, 0),
      duration: 0.12,
      curve: Curves.easeOutCubic,
    );

    enemy.playAttack();
    await _showSlashEffect(player.position.clone(), big: heavy);
    await _showDamagePopup(
      text: blocked ? 'BLOCK' : '-$damage',
      position: player.position.clone() + Vector2(0, -80),
      color: blocked ? Colors.cyanAccent : Colors.redAccent,
    );

    if (!blocked) {
      player.playHit();
      await _moveByAndWait(
        player,
        Vector2(heavy ? -85 : -45, 0),
        duration: heavy ? 0.2 : 0.12,
        curve: Curves.easeOut,
      );
      await _hitStop(100);
      await _shakeStage(intensity: heavy ? 14 : 10, durationMs: heavy ? 140 : 100);
    }

    await Future<void>.delayed(const Duration(milliseconds: 220));

    enemy.playIdle();
    if (player.currentHp > 0) {
      player.playIdle();
    }

    await _moveByAndWait(
      enemy,
      enemy.basePosition - enemy.position,
      duration: 0.12,
      curve: Curves.easeInOut,
    );

    if (player.currentHp > 0) {
      await _moveByAndWait(
        player,
        player.basePosition - player.position,
        duration: 0.12,
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _moveToBaseAndIdle() async {
    await _moveByAndWait(
      player,
      player.basePosition - player.position,
      duration: 0.14,
      curve: Curves.easeOut,
    );
    player.playIdle();

    if (enemy.currentHp > 0) {
      await _moveByAndWait(
        enemy,
        enemy.basePosition - enemy.position,
        duration: 0.14,
        curve: Curves.easeOut,
      );
      enemy.playIdle();
    }
  }

  Future<void> _moveByAndWait(
    PositionComponent component,
    Vector2 delta, {
    required double duration,
    Curve curve = Curves.linear,
  }) {
    final completer = Completer<void>();
    component.add(
      MoveByEffect(
        delta,
        EffectController(duration: duration, curve: curve),
        onComplete: () {
          if (!completer.isCompleted) {
            completer.complete();
          }
        },
      ),
    );
    return completer.future;
  }

  Future<void> _showSlashEffect(Vector2 targetPosition, {required bool big}) async {
    if (_slashSprite != null) {
      final slash = SpriteComponent(
        sprite: _slashSprite,
        size: big ? Vector2(130, 130) : Vector2(95, 95),
        position: targetPosition + Vector2(0, -58),
        anchor: Anchor.center,
        priority: 25,
      );

      slash.angle = _random.nextBool() ? 0.35 : -0.35;
      stage.add(slash);

      await Future<void>.delayed(const Duration(milliseconds: 120));
      slash.removeFromParent();
      return;
    }

    final fallbackSlash = RectangleComponent(
      size: big ? Vector2(120, 18) : Vector2(90, 14),
      position: targetPosition + Vector2(0, -58),
      anchor: Anchor.center,
      priority: 25,
      paint: Paint()..color = const Color(0xCCFFB3A7),
    );
    fallbackSlash.angle = _random.nextBool() ? 0.35 : -0.35;
    stage.add(fallbackSlash);

    await Future<void>.delayed(const Duration(milliseconds: 120));
    fallbackSlash.removeFromParent();
  }

  Future<void> _showDamagePopup({
    required String text,
    required Vector2 position,
    required Color color,
  }) async {
    final popup = TextComponent(
      text: text,
      position: position,
      anchor: Anchor.center,
      priority: 30,
      textRenderer: TextPaint(
        style: TextStyle(
          color: color,
          fontSize: 20,
          fontWeight: FontWeight.w900,
          shadows: const [Shadow(blurRadius: 12, color: Colors.black)],
        ),
      ),
    );

    stage.add(popup);
    popup.add(MoveByEffect(Vector2(0, -26), EffectController(duration: 0.22, curve: Curves.easeOut)));

    await Future<void>.delayed(const Duration(milliseconds: 220));
    popup.removeFromParent();
  }

  Future<void> _shakeStage({required double intensity, required int durationMs}) async {
    final original = stage.position.clone();
    final endAt = DateTime.now().add(Duration(milliseconds: durationMs));

    while (DateTime.now().isBefore(endAt)) {
      stage.position = original +
          Vector2(
            (_random.nextDouble() - 0.5) * intensity,
            (_random.nextDouble() - 0.5) * intensity,
          );
      await Future<void>.delayed(const Duration(milliseconds: 16));
    }

    stage.position = original;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_loaded) {
      playerAura.position = player.position + Vector2(0, -42);
      enemyAura.position = enemy.position + Vector2(0, -42);
      if (_spriteLoadFailed) {
        playerFallback.position = player.position.clone();
        enemyFallback.position = enemy.position.clone();
      }
    }
  }

  Future<void> _hitStop(int milliseconds) {
    return Future<void>.delayed(Duration(milliseconds: milliseconds));
  }
}

class _RoundConfig {
  final int playerHp;
  final int enemyHp;
  final int enemyMaxHp;
  final bool isBoss;

  const _RoundConfig({
    required this.playerHp,
    required this.enemyHp,
    required this.enemyMaxHp,
    required this.isBoss,
  });
}
