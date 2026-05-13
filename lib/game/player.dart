import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/game.dart';

enum _PlayerAnimState { idle, run, attack, hit, death }

class ShadowPlayer extends SpriteAnimationComponent with HasGameReference<FlameGame> {
  SpriteAnimation? _idleAnimation;
  SpriteAnimation? _runAnimation;
  SpriteAnimation? _attackAnimation;
  SpriteAnimation? _hitAnimation;
  SpriteAnimation? _deathAnimation;

  bool _animationsReady = false;
  _PlayerAnimState _pendingState = _PlayerAnimState.idle;
  double _motionTime = 0;

  int maxHp;
  int currentHp;
  bool _dead = false;
  Vector2 basePosition = Vector2.zero();

  ShadowPlayer({this.maxHp = 100, this.currentHp = 100})
      : super(
          size: Vector2(160, 160),
          anchor: Anchor.bottomCenter,
          priority: 10,
        );

  @override
  Future<void> onLoad() async {
    final spriteSheet = await game.images.load('player_sheet.png');

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

  void playIdle() {
    if (_dead) {
      return;
    }
    _pendingState = _PlayerAnimState.idle;
    _applyPendingAnimation();
  }

  void playRun() {
    if (_dead) {
      return;
    }
    _pendingState = _PlayerAnimState.run;
    _applyPendingAnimation();
  }

  void playAttack() {
    if (_dead) {
      return;
    }
    _pendingState = _PlayerAnimState.attack;
    _applyPendingAnimation();
  }

  void playHit() {
    if (_dead) {
      return;
    }
    _pendingState = _PlayerAnimState.hit;
    _applyPendingAnimation();
  }

  void playDeath() {
    _dead = true;
    _pendingState = _PlayerAnimState.death;
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
      case _PlayerAnimState.idle:
        animation = _idleAnimation;
        break;
      case _PlayerAnimState.run:
        animation = _runAnimation;
        break;
      case _PlayerAnimState.attack:
        animation = _attackAnimation;
        break;
      case _PlayerAnimState.hit:
        animation = _hitAnimation;
        break;
      case _PlayerAnimState.death:
        animation = _deathAnimation;
        break;
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _motionTime += dt;

    switch (_pendingState) {
      case _PlayerAnimState.idle:
        final breath = 1 + sin(_motionTime * 4.0) * 0.02;
        scale = Vector2.all(breath);
        break;
      case _PlayerAnimState.run:
        final pace = 1 + sin(_motionTime * 14.0) * 0.045;
        scale = Vector2(1.02, pace);
        break;
      case _PlayerAnimState.attack:
        scale = Vector2(1.08, 1.02);
        break;
      case _PlayerAnimState.hit:
        scale = Vector2(0.95, 1.03);
        break;
      case _PlayerAnimState.death:
        scale = Vector2(0.88, 0.88);
        break;
    }
  }
}
