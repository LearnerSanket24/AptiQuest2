import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../config/app_constants.dart';
import '../game/battle_controller.dart';
import '../game/shadow_game.dart';
import '../models/monster.dart';
import '../models/player.dart';
import '../models/question.dart';
import '../services/audio_service.dart';
import '../services/question_service.dart';
import '../services/storage_service.dart';
import '../widgets/ability_button.dart';
import '../widgets/hp_bar.dart';
import '../widgets/option_card.dart';
import '../widgets/app_gradient_background.dart';
import 'result_screen.dart';

class BattleScreen extends StatefulWidget {
  final Player player;
  final List<Monster> monsters;
  final String category;
  final String floorTitle;
  final String floorId;

  const BattleScreen({
    super.key,
    required this.player,
    required this.monsters,
    required this.category,
    required this.floorTitle,
    required this.floorId,
  });

  @override
  State<BattleScreen> createState() => _BattleScreenState();
}

class _BattleScreenState extends State<BattleScreen> {
  late final ShadowGame _shadowGame;
  final QuestionService _questionService = LocalQuestionService();
  late List<Question> _questions;
  late Monster _currentMonster;

  int _monsterIndex = 0;
  int _questionIndex = 0;
  int _questionTimeLeft = BattleConstants.questionTimerSeconds;

  int _correctCount = 0;
  int _wrongCount = 0;

  bool _loading = true;
  bool _processing = false;
  bool _answered = false;

  int? _selectedIndex;
  String _feedback = '';
  Set<int> _hiddenOptions = <int>{};
  final List<String> _eventFeed = <String>[];

  bool _used5050 = false;
  bool _usedShield = false;
  bool _usedDoubleDamage = false;
  bool _usedTimeFreeze = false;
  bool _usedRevival = false;

  bool _shieldArmed = false;
  bool _doubleDamageArmed = false;

  Timer? _questionTimer;

  @override
  void initState() {
    super.initState();
    _shadowGame = ShadowGame();
    _initBattle();
  }

  Future<void> _initBattle() async {
    _questions = await _questionService.getQuestionsByTopic(widget.category);
    if (_questions.isEmpty) {
      _questions = await _questionService.getQuestionsByTopic('mixed');
    }
    _questions.shuffle();
    _currentMonster = widget.monsters[0];

    _shadowGame.configureRound(
      playerHp: widget.player.currentHp,
      enemyHp: _currentMonster.currentHp,
      enemyMaxHp: _currentMonster.maxHp,
      isBoss: false,
    );
    _addEvent('⚔ ${widget.player.name} entered ${widget.floorTitle}.');

    if (!mounted) {
      return;
    }

    setState(() {
      _loading = false;
    });
    _startQuestionTimer();
  }

  Question get _currentQ => _questions[_questionIndex % _questions.length];

  void _startQuestionTimer() {
    _questionTimer?.cancel();
    setState(() {
      _questionTimeLeft = BattleConstants.questionTimerSeconds;
    });

    _questionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_processing || _answered) {
        return;
      }

      if (_questionTimeLeft <= 1) {
        timer.cancel();
        _onAnswerTap(-1);
        return;
      }

      if (mounted) {
        setState(() {
          _questionTimeLeft--;
        });
      }
    });
  }

  Future<void> _onAnswerTap(int index) async {
    if (_processing || _answered) {
      return;
    }

    _questionTimer?.cancel();
    final timedOut = index < 0;
    final correct = !timedOut && index == _currentQ.correctIndex;

    try {
      await StorageService.recordQuestionResult(topic: widget.category, correct: correct);
    } catch (e, st) {
      debugPrint('recordQuestionResult failed: $e');
      debugPrint('$st');
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _processing = true;
      _answered = true;
      _selectedIndex = index >= 0 ? index : null;
    });

    try {
      late CombatStepResult combat;

      if (correct) {
        unawaited(AudioService.instance.playSfx(volume: 0.6));
        widget.player.correctAnswer();
        _correctCount++;

        var playerDamage = widget.player.damageDealt;
        var forceCritical = false;
        if (_doubleDamageArmed) {
          _doubleDamageArmed = false;
          playerDamage = playerDamage < BattleConstants.criticalDamage
              ? BattleConstants.criticalDamage
              : playerDamage;
          forceCritical = true;
        }

        combat = await _shadowGame.resolveAnswer(
          correct: true,
          playerDamage: playerDamage,
          forceCritical: forceCritical,
        );

        _currentMonster.takeDamage(combat.damageApplied);

        setState(() {
          _feedback = combat.critical
              ? '⚡ Critical strike! -${combat.damageApplied} HP to ${_currentMonster.name}'
              : '✅ Combo hit! -${combat.damageApplied} HP to ${_currentMonster.name}';
        });
        _addEvent(
          combat.critical
              ? '⚡ Critical combo x${combat.comboCount} for ${combat.damageApplied}.'
              : '✅ Hit landed for ${combat.damageApplied}.',
        );
      } else {
        unawaited(AudioService.instance.playSfx(volume: 0.45));
        _wrongCount++;

        combat = await _shadowGame.resolveAnswer(
          correct: false,
          enemyDamage: BattleConstants.wrongDamageToPlayer,
          shieldActive: _shieldArmed,
        );

        if (_shieldArmed) {
          _shieldArmed = false;
          widget.player.resetStreak();
          setState(() {
            _feedback = '🛡 Shield blocked the demon combo!';
          });
          _addEvent('🛡 Shield absorbed incoming damage.');
        } else {
          widget.player.takeDamage(combat.damageApplied);

          if (!widget.player.isAlive && widget.player.canUseRevival && !_usedRevival) {
            _usedRevival = true;
            widget.player.heal(50);
            _shadowGame.syncPlayerHp(widget.player.currentHp);
            setState(() {
              _feedback = '💚 Revival! You restored 50 HP.';
            });
          } else {
            setState(() {
              _feedback = timedOut
                  ? '⌛ Time up! Demon hit you for ${combat.damageApplied} HP'
                  : '❌ Wrong! Demon combo dealt ${combat.damageApplied} HP';
            });
            _addEvent(
              timedOut
                  ? '⌛ Timed out and took ${combat.damageApplied} damage.'
                  : '❌ Took ${combat.damageApplied} damage from counterattack.',
            );
          }
        }
      }

      if (!mounted) {
        return;
      }

      await Future<void>.delayed(const Duration(milliseconds: 260));

      if (!widget.player.isAlive) {
        _goToResult(false);
        return;
      }

      if (!_currentMonster.isAlive) {
        _onMonsterDefeated();
        return;
      }

      setState(() {
        _questionIndex++;
        _processing = false;
        _answered = false;
        _selectedIndex = null;
        _hiddenOptions = <int>{};
        _feedback = '';
      });

      _startQuestionTimer();
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _processing = false;
        _answered = false;
        _selectedIndex = null;
        _feedback = 'Recovered from a battle animation glitch. Try again.';
      });
      _startQuestionTimer();
    }
  }

  void _onMonsterDefeated() {
    if (_monsterIndex + 1 < widget.monsters.length) {
      setState(() {
        _monsterIndex++;
        _currentMonster = widget.monsters[_monsterIndex];
        _processing = false;
        _answered = false;
        _selectedIndex = null;
        _hiddenOptions = <int>{};
      });

      _shadowGame.configureRound(
        playerHp: widget.player.currentHp,
        enemyHp: _currentMonster.currentHp,
        enemyMaxHp: _currentMonster.maxHp,
        isBoss: false,
      );
      _addEvent('👹 ${_currentMonster.name} enters the arena!');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_currentMonster.name} appears!')),
      );

      _startQuestionTimer();
      return;
    }

    _goToResult(true);
  }

  void _goToResult(bool won) {
    _questionTimer?.cancel();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          player: widget.player,
          score: _correctCount * BattleConstants.xpPerCorrect,
          coinsEarned: _correctCount * BattleConstants.coinsPerCorrect,
          won: won,
          floorTitle: widget.floorTitle,
          floorId: widget.floorId,
          correctCount: _correctCount,
          wrongCount: _wrongCount,
        ),
      ),
    );
  }

  void _use5050() {
    if (_used5050 || _processing || _answered) {
      return;
    }

    final wrong = <int>[];
    for (var i = 0; i < _currentQ.options.length; i++) {
      if (i != _currentQ.correctIndex) {
        wrong.add(i);
      }
    }

    wrong.shuffle();
    setState(() {
      _used5050 = true;
      _hiddenOptions = wrong.take(2).toSet();
      _feedback = '✨ 50-50 activated';
    });
  }

  void _useShield() {
    if (_usedShield || _processing || _answered || !widget.player.canUseShield) {
      return;
    }

    setState(() {
      _usedShield = true;
      _shieldArmed = true;
      _feedback = '🛡 Shield armed for next enemy hit';
    });
  }

  void _useDoubleDamage() {
    if (_usedDoubleDamage || _processing || _answered || !widget.player.canUseDoubleDamage) {
      return;
    }

    setState(() {
      _usedDoubleDamage = true;
      _doubleDamageArmed = true;
      _feedback = '⚔ Double damage armed';
    });
  }

  void _useTimeFreeze() {
    if (_usedTimeFreeze || _processing || _answered || !widget.player.canUseTimeFreeze) {
      return;
    }

    setState(() {
      _usedTimeFreeze = true;
      _questionTimeLeft += 30;
      _feedback = '⏳ Time freeze +30s';
    });
  }

  @override
  void dispose() {
    _questionTimer?.cancel();
    _shadowGame.pauseEngine();
    super.dispose();
  }

  Widget _buildBattleRenderer() {
    return GameWidget<ShadowGame>(
      game: _shadowGame,
      loadingBuilder: (context) => const ColoredBox(
        color: Color(0xFF0C1030),
        child: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      ),
      errorBuilder: (context, error) => Container(
        color: const Color(0xFF2B0F16),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(12),
        child: Text(
          'Battle renderer failed: $error',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  void _addEvent(String event) {
    _eventFeed.insert(0, event);
    if (_eventFeed.length > 4) {
      _eventFeed.removeLast();
    }
  }

  Color _optionColor(int index) {
    if (!_answered) {
      return const Color(0xFF2A2A4A);
    }
    if (index == _currentQ.correctIndex) {
      return Colors.green[700]!;
    }
    if (index == _selectedIndex) {
      return Colors.red[700]!;
    }
    return const Color(0xFF2A2A4A);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0D0D1A),
        body: AppGradientBackground(
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final q = _currentQ;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF12314A),
        title: Text(
          widget.floorTitle,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Row(
              children: [
                const Text('🪙', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 4),
                Text(
                  '${widget.player.coins}',
                  style: const TextStyle(color: Colors.amberAccent, fontSize: 16),
                ),
              ],
            ),
          ),
        ],
      ),
      body: AppGradientBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
            Row(
              children: [
                const Text('⏳', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 6),
                Expanded(
                  child: LinearProgressIndicator(
                    value: (_questionTimeLeft / BattleConstants.questionTimerSeconds).clamp(0.0, 1.0),
                    minHeight: 10,
                    backgroundColor: Colors.white12,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _questionTimeLeft > 10 ? Colors.green : Colors.red,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text('$_questionTimeLeft s', style: const TextStyle(color: Colors.white70)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: HpBar(
                    label: '${widget.player.name} HP',
                    percent: widget.player.hpPercent,
                    barColor: Colors.green,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: HpBar(
                    label: '${_currentMonster.name} HP',
                    percent: _currentMonster.currentHp / _currentMonster.maxHp,
                    barColor: Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _shadowGame.comboCount >= 2 ? '🔥 COMBO x${_shadowGame.comboCount}' : ' ',
              style: const TextStyle(color: Colors.orangeAccent, fontSize: 13),
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: (widget.player.streak % 3) / 3,
                minHeight: 8,
                backgroundColor: Colors.white10,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.amberAccent),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.player.streak % 3 == 2
                  ? 'Next correct answer triggers CRITICAL!'
                  : 'Build streak to trigger critical combos',
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                AbilityButton(
                  emoji: '✨',
                  label: '50-50',
                  enabled: !_used5050,
                  onTap: _use5050,
                ),
                AbilityButton(
                  emoji: '🛡',
                  label: 'Shield',
                  enabled: widget.player.canUseShield && !_usedShield,
                  onTap: _useShield,
                ),
                AbilityButton(
                  emoji: '⚔',
                  label: 'Double',
                  enabled: widget.player.canUseDoubleDamage && !_usedDoubleDamage,
                  onTap: _useDoubleDamage,
                ),
                AbilityButton(
                  emoji: '⏳',
                  label: 'Freeze',
                  enabled: widget.player.canUseTimeFreeze && !_usedTimeFreeze,
                  onTap: _useTimeFreeze,
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 220,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: _buildBattleRenderer(),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF171A34),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Battle Feed',
                    style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  if (_eventFeed.isEmpty)
                    const Text('No actions yet.', style: TextStyle(color: Colors.white38)),
                  ..._eventFeed.map(
                    (event) => Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(event, style: const TextStyle(color: Colors.white60, fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (_feedback.isNotEmpty)
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: Container(
                  key: ValueKey<String>(_feedback),
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A3A),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _feedback,
                    style: const TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Card(
              color: const Color(0xFF1E1E3A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Text(
                  q.questionText,
                  style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.5),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(height: 12),
            ...List.generate(q.options.length, (i) {
              if (_hiddenOptions.contains(i)) {
                return const SizedBox.shrink();
              }
              return OptionCard(
                text: q.options[i],
                onTap: () => _onAnswerTap(i),
                color: _answered ? _optionColor(i) : null,
              );
            }),
            ],
          ),
        ),
      ),
    );
  }
}
