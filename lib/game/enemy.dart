import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/game.dart';

enum _EnemyAnimState { idle, run, attack, hit, death }

class ShadowEnemy extends SpriteAnimationComponent with HasGameReference<FlameGame> {
  SpriteAnimation? _idleAnimation;
  SpriteAnimation? _runAnimation;
  SpriteAnimation? _attackAnimation;
  SpriteAnimation? _hitAnimation;
  SpriteAnimation? _deathAnimation;

  bool _animationsReady = false;
  _EnemyAnimState _pendingState = _EnemyAnimState.idle;
  double _motionTime = 0;

  int maxHp;
  int currentHp;
  bool _dead = false;
  Vector2 basePosition = Vector2.zero();

  ShadowEnemy({this.maxHp = 100, this.currentHp = 100})
      : super(
          size: Vector2(160, 160),
          anchor: Anchor.bottomCenter,
          priority: 10,
        );

  @override
  Future<void> onLoad() async {
    final spriteSheet = await game.images.load('enemy_sheet.png');

    _idleAnimation = SpriteAnimation.fromFrameData(
      spriteSheet,
      SpriteAnimationData.sequenced(
        amount: 4,
        stepTime: 0.15,
        textureSize: Vector2(64, 64),
      ),
    );

    _runAnimation = SpriteAnimation.fromFrameData(
      spriteSheet,
      SpriteAnimationData.sequenced(
        amount: 6,
        stepTime: 0.1,
        textureSize: Vector2(64, 64),
      ),
    );

    _attackAnimation = SpriteAnimation.fromFrameData(
      spriteSheet,
      SpriteAnimationData.sequenced(
        amount: 6,
        stepTime: 0.08,
        textureSize: Vector2(64, 64),
      ),
    );

    _hitAnimation = SpriteAnimation.fromFrameData(
      spriteSheet,
      SpriteAnimationData.sequenced(
        amount: 3,
        stepTime: 0.09,
        textureSize: Vector2(64, 64),
      ),
    );

    _deathAnimation = SpriteAnimation.fromFrameData(
      spriteSheet,
      SpriteAnimationData.sequenced(
        amount: 4,
        stepTime: 0.14,
        textureSize: Vector2(64, 64),
      ),
    );

    _animationsReady = true;
    _applyPendingAnimation();
    flipHorizontallyAroundCenter();
  }

  void setBasePosition(Vector2 value) {
    basePosition = value;
    position = value.clone();
  }

  void setHp(int hp) {
    currentHp = hp.clamp(0, maxHp);
    _dead = currentHp <= 0;
    if (_dead) {
      playDeath();
    } else {
      playIdle();
    }
  }

  void setRoundMaxHp(int hp) {
    maxHp = hp;
  }

  bool get isDead => currentHp <= 0;

  void playIdle() {
    if (_dead) {
      return;
    }
    _pendingState = _EnemyAnimState.idle;
    _applyPendingAnimation();
  }

  void playRun() {
    if (_dead) {
      return;
    }
    _pendingState = _EnemyAnimState.run;
    _applyPendingAnimation();
  }

  void playAttack() {
    if (_dead) {
      return;
    }
    _pendingState = _EnemyAnimState.attack;
    _applyPendingAnimation();
  }

  void playHit() {
    if (_dead) {
      return;
    }
    _pendingState = _EnemyAnimState.hit;
    _applyPendingAnimation();
  }

  void playDeath() {
    _dead = true;
    _pendingState = _EnemyAnimState.death;
    _applyPendingAnimation();
  }

  void takeDamage(int damage) {
    if (damage <= 0 || _dead) {
      return;
    }
    currentHp = (currentHp - damage).clamp(0, maxHp);
    if (currentHp <= 0) {
      playDeath();
    } else {
      playHit();
    }
  }

  void resetForRound({required int hp, required int maxRoundHp}) {
    maxHp = maxRoundHp;
    currentHp = hp.clamp(0, maxHp);
    _dead = false;
    position = basePosition.clone();
    playIdle();
  }

  void _applyPendingAnimation() {
    if (!_animationsReady) {
      return;
    }

    switch (_pendingState) {
      case _EnemyAnimState.idle:
        animation = _idleAnimation;
        break;
      case _EnemyAnimState.run:
        animation = _runAnimation;
        break;
      case _EnemyAnimState.attack:
        animation = _attackAnimation;
        break;
      case _EnemyAnimState.hit:
        animation = _hitAnimation;
        break;
      case _EnemyAnimState.death:
        animation = _deathAnimation;
        break;
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _motionTime += dt;

    switch (_pendingState) {
      case _EnemyAnimState.idle:
        final breath = 1 + sin(_motionTime * 3.4) * 0.018;
        scale = Vector2.all(breath);
        break;
      case _EnemyAnimState.run:
        final pace = 1 + sin(_motionTime * 13.0) * 0.04;
        scale = Vector2(1.01, pace);
        break;
      case _EnemyAnimState.attack:
        scale = Vector2(1.09, 1.01);
        break;
      case _EnemyAnimState.hit:
        scale = Vector2(0.95, 1.04);
        break;
      case _EnemyAnimState.death:
        scale = Vector2(0.85, 0.85);
        break;
    }
  }
}
