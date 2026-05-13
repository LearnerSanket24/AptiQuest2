import 'dart:async';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../config/app_constants.dart';
import '../game/battle_controller.dart';
import '../game/shadow_game.dart';
import '../models/player.dart';
import '../models/monster.dart';
import '../models/question.dart';
import '../services/audio_service.dart';
import '../services/question_service.dart';
import '../services/storage_service.dart';
import '../widgets/hp_bar.dart';
import '../widgets/ability_button.dart';
import '../widgets/option_card.dart';
import '../widgets/app_gradient_background.dart';
import 'result_screen.dart';

class BossRoom extends StatefulWidget {
  final Player player;

  const BossRoom({super.key, required this.player});

  @override
  State<BossRoom> createState() => _BossRoomState();
}

class _BossRoomState extends State<BossRoom> {
  final QuestionService _questionService = LocalQuestionService();
  late final ShadowGame _shadowGame;

  late List<Question> _questions;
  late Boss _boss;
  int _currentIndex = 0;
  int _score = 0;
  int _wrong = 0;
  int _timeLeft = BossConstants.totalTimerSeconds;

  bool _answered = false;
  int? _selectedIndex;
  Timer? _timer;
  bool _loading = true;
  String _feedback = '';
  bool _used5050 = false;
  bool _usedTimeFreeze = false;
  Set<int> _hiddenOptions = <int>{};
  final List<String> _eventFeed = <String>[];

  final Map<String, Map<String, int>> _topicBreakdown = {
    'quant': {'attempted': 0, 'correct': 0},
    'logic': {'attempted': 0, 'correct': 0},
    'english': {'attempted': 0, 'correct': 0},
  };

  @override
  void initState() {
    super.initState();
    _shadowGame = ShadowGame();
    _initBossRoom();
  }

  Future<void> _initBossRoom() async {
    _questions = await _questionService.getBossQuestions();
    _boss = Boss(
      name: 'Placement Boss',
      emoji: '💀',
      maxHp: BossConstants.bossHp,
      category: 'all',
    );
    _shadowGame.configureRound(
      playerHp: widget.player.currentHp,
      enemyHp: _boss.currentHp,
      enemyMaxHp: _boss.maxHp,
      isBoss: true,
    );
    _addEvent('👑 Final boss encounter started.');
    _startTimer();
    if (!mounted) {
      return;
    }
    setState(() {
      _loading = false;
    });
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeLeft <= 1) {
        timer.cancel();
        _endBattle();
      } else {
        setState(() => _timeLeft--);
      }
    });
  }

  Future<void> _onAnswerTap(int index) async {
    if (_answered) return;
    final currentQuestion = _questions[_currentIndex];
    final correct = index == _questions[_currentIndex].correctIndex;
    await StorageService.recordQuestionResult(topic: currentQuestion.topic, correct: correct);
    final topicStats = _topicBreakdown[currentQuestion.topic] ?? {'attempted': 0, 'correct': 0};
    topicStats['attempted'] = (topicStats['attempted'] ?? 0) + 1;
    if (correct) {
      topicStats['correct'] = (topicStats['correct'] ?? 0) + 1;
    }
    _topicBreakdown[currentQuestion.topic] = topicStats;

    late CombatStepResult combat;
    String feedback;
    String event;

    setState(() {
      _answered = true;
      _selectedIndex = index;
    });

    unawaited(AudioService.instance.playSfx(volume: correct ? 0.58 : 0.44));

    if (correct) {
      _score++;
      widget.player.correctAnswer();
      combat = await _shadowGame.resolveAnswer(
        correct: true,
        playerDamage: BattleConstants.correctDamage,
        forceCritical: _score > 0 && _score % 3 == 0,
      );
      _boss.takeDamage(combat.damageApplied);
      feedback = combat.critical
          ? '⚡ Critical hit! -${combat.damageApplied} HP'
          : '✅ Strike landed! -${combat.damageApplied} HP';
      event = '✅ You hit boss for ${combat.damageApplied}.';
    } else {
      _wrong++;
      combat = await _shadowGame.resolveAnswer(
        correct: false,
        enemyDamage: BattleConstants.wrongDamageToPlayer,
        shieldActive: false,
      );
      widget.player.takeDamage(combat.damageApplied);
      feedback = '❌ Boss countered for ${combat.damageApplied} HP';
      event = '❌ Boss dealt ${combat.damageApplied} damage.';
    }

    _shadowGame.configureRound(
      playerHp: widget.player.currentHp,
      enemyHp: _boss.currentHp,
      enemyMaxHp: _boss.maxHp,
      isBoss: true,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _feedback = feedback;
      _addEvent(event);
    });

    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      if (_boss.currentHp <= 0 || !widget.player.isAlive || _currentIndex + 1 >= _questions.length) {
        _timer?.cancel();
        _endBattle();
      } else {
        setState(() {
          _currentIndex++;
          _answered = false;
          _selectedIndex = null;
          _hiddenOptions = <int>{};
          _feedback = '';
        });
      }
    });
  }

  void _use5050() {
    if (_used5050 || _answered || _loading) {
      return;
    }
    final wrong = <int>[];
    for (var i = 0; i < _questions[_currentIndex].options.length; i++) {
      if (i != _questions[_currentIndex].correctIndex) {
        wrong.add(i);
      }
    }
    wrong.shuffle();
    setState(() {
      _used5050 = true;
      _hiddenOptions = wrong.take(2).toSet();
    });
  }

  void _useTimeFreeze() {
    if (_usedTimeFreeze || !widget.player.canUseTimeFreeze) {
      return;
    }
    setState(() {
      _usedTimeFreeze = true;
      _timeLeft += 30;
    });
  }

  void _endBattle() {
    final topicAccuracy = {
      for (final entry in _topicBreakdown.entries)
        entry.key: '${entry.value['correct']}/${entry.value['attempted']}'
    };
    final won = _boss.currentHp == 0;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          player: widget.player,
          score: _score * BattleConstants.xpPerCorrect,
          coinsEarned: _score * BattleConstants.coinsPerCorrect,
          won: won,
          floorTitle: '👑 Final Boss Room',
          floorId: 'boss',
          bossScore: '$_score / ${_questions.length}',
          correctCount: _score,
          wrongCount: _wrong,
          topicBreakdown: topicAccuracy,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _shadowGame.pauseEngine();
    super.dispose();
  }

  Widget _buildBossArena() {
    return GameWidget<ShadowGame>(
      game: _shadowGame,
      loadingBuilder: (context) => const ColoredBox(
        color: Color(0xFF170B14),
        child: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      ),
      errorBuilder: (context, error) => Container(
        color: const Color(0xFF170B14),
        alignment: Alignment.center,
        child: Text(
          'Boss arena failed: $error',
          style: const TextStyle(color: Colors.white70),
          textAlign: TextAlign.center,
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
    if (!_answered) return const Color(0xFF2A2A4A);
    if (index == _questions[_currentIndex].correctIndex) return Colors.green[700]!;
    if (index == _selectedIndex) return Colors.red[700]!;
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

    final q = _questions[_currentIndex];

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        backgroundColor: Colors.red[900],
        title: const Text('👑 FINAL BOSS BATTLE',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        automaticallyImplyLeading: false,
      ),
      body: AppGradientBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
            // Timer bar
            Row(
              children: [
                const Text('⏳ ', style: TextStyle(fontSize: 20)),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: (_timeLeft / BossConstants.totalTimerSeconds).clamp(0.0, 1.0),
                      minHeight: 14,
                      backgroundColor: Colors.grey[800],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _timeLeft > 60 ? Colors.green : Colors.red,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text('$_timeLeft s',
                    style: TextStyle(
                        color: _timeLeft <= 10 ? Colors.red : Colors.white70,
                        fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: HpBar(
                    label: '${widget.player.name} HP',
                    percent: widget.player.hpPercent,
                    barColor: Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: HpBar(
                    label: 'Boss HP',
                    percent: _boss.currentHp / _boss.maxHp,
                    barColor: Colors.red,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Wrap(
              spacing: 8,
              children: [
                AbilityButton(
                  emoji: '✨',
                  label: '50-50',
                  enabled: !_used5050,
                  onTap: _use5050,
                ),
                AbilityButton(
                  emoji: '⏳',
                  label: 'Freeze',
                  enabled: widget.player.canUseTimeFreeze && !_usedTimeFreeze,
                  onTap: _useTimeFreeze,
                ),
              ],
            ),

            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 220,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: _buildBossArena(),
              ),
            ),
            const SizedBox(height: 8),
            const Text('PLACEMENT BOSS',
                style: TextStyle(
                    color: Colors.redAccent,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),

            const SizedBox(height: 8),
            Text(
              'Q ${_currentIndex + 1} / ${_questions.length}  •  Score: $_score',
              style: const TextStyle(color: Colors.white54),
            ),

            if (_feedback.isNotEmpty) ...[
              const SizedBox(height: 10),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: Container(
                  key: ValueKey<String>(_feedback),
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A1A2A),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _feedback,
                    style: const TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF221125),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Boss Combat Log',
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

            const SizedBox(height: 20),

            Card(
              color: const Color(0xFF1E1E3A),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Text(q.questionText,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 16, height: 1.5),
                    textAlign: TextAlign.center),
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

            const SizedBox(height: 12),
            Text('Defeat the boss by reducing HP to 0!',
                style: TextStyle(color: Colors.red[300], fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}