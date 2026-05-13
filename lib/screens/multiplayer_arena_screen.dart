import 'dart:async';

import 'package:flutter/material.dart';

import '../config/app_constants.dart';
import '../models/question.dart';
import '../services/audio_service.dart';
import '../services/question_service.dart';
import '../services/storage_service.dart';
import '../widgets/app_gradient_background.dart';
import '../widgets/option_card.dart';

enum _MultiplayerPhase {
  lobby,
  playing,
  betweenPlayers,
  result,
}

class MultiplayerArenaScreen extends StatefulWidget {
  const MultiplayerArenaScreen({super.key});

  @override
  State<MultiplayerArenaScreen> createState() => _MultiplayerArenaScreenState();
}

class _MultiplayerArenaScreenState extends State<MultiplayerArenaScreen> {
  final TextEditingController _nameController = TextEditingController();
  final QuestionService _questionService = LocalQuestionService();

  _MultiplayerPhase _phase = _MultiplayerPhase.lobby;

  String _topic = 'mixed';
  int _questionCount = 10;
  int _secondsPerQuestion = 20;

  final List<String> _participants = <String>[];
  final Map<String, _ParticipantRun> _runs = <String, _ParticipantRun>{};

  List<Question> _questionSet = <Question>[];
  List<_Standing> _standings = <_Standing>[];

  List<Map<String, dynamic>> _recentMatches = <Map<String, dynamic>>[];

  int _currentParticipantIndex = 0;
  int _currentQuestionIndex = 0;
  int _timeLeft = 20;

  Timer? _timer;
  bool _answerLocked = false;
  bool _persistingResult = false;

  int? _selectedIndex;
  String _feedback = '';

  @override
  void initState() {
    super.initState();
    _loadRecentMatches();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadRecentMatches() async {
    final recent = await StorageService.getMultiplayerHistory();
    if (!mounted) {
      return;
    }
    setState(() {
      _recentMatches = recent;
    });
  }

  String get _currentParticipant => _participants[_currentParticipantIndex];

  Question get _currentQuestion => _questionSet[_currentQuestionIndex];

  _ParticipantRun get _currentRun => _runs[_currentParticipant]!;

  _ParticipantRun get _lastFinishedRun {
    final index = _currentParticipantIndex - 1;
    return _runs[_participants[index]]!;
  }

  void _addParticipant() {
    final rawName = _nameController.text.trim();
    if (rawName.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Enter at least 2 characters for student name.')),
      );
      return;
    }

    final exists = _participants
        .any((name) => name.toLowerCase() == rawName.toLowerCase());
    if (exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$rawName is already added.')),
      );
      return;
    }

    setState(() {
      _participants.add(rawName);
      _nameController.clear();
    });
  }

  void _removeParticipant(String name) {
    setState(() {
      _participants.remove(name);
    });
  }

  Future<List<Question>> _buildQuestionSet() async {
    final source = await _questionService.getQuestionsByTopic(_topic);
    if (source.isEmpty) {
      return <Question>[];
    }

    source.shuffle();
    final selected = <Question>[];
    while (selected.length < _questionCount) {
      source.shuffle();
      selected.addAll(source);
    }

    return selected.take(_questionCount).toList();
  }

  Future<void> _startMatch() async {
    if (_participants.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Add at least 2 students to start multiplayer match.')),
      );
      return;
    }

    final questions = await _buildQuestionSet();
    if (!mounted) {
      return;
    }
    if (questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No questions found for selected topic.')),
      );
      return;
    }

    final seededRuns = <String, _ParticipantRun>{
      for (final name in _participants) name: _ParticipantRun(name: name),
    };

    _timer?.cancel();
    setState(() {
      _questionSet = questions;
      _runs
        ..clear()
        ..addAll(seededRuns);
      _standings = <_Standing>[];
      _currentParticipantIndex = 0;
      _currentQuestionIndex = 0;
      _timeLeft = _secondsPerQuestion;
      _selectedIndex = null;
      _feedback = '';
      _answerLocked = false;
      _persistingResult = false;
      _phase = _MultiplayerPhase.playing;
    });

    _startQuestionTimer();
  }

  void _startQuestionTimer() {
    _timer?.cancel();
    setState(() {
      _timeLeft = _secondsPerQuestion;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_answerLocked) {
        return;
      }

      if (_timeLeft <= 1) {
        timer.cancel();
        _submitAnswer(-1);
        return;
      }

      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _timeLeft--;
      });
    });
  }

  Future<void> _submitAnswer(int index) async {
    if (_answerLocked || _phase != _MultiplayerPhase.playing) {
      return;
    }

    _timer?.cancel();

    final question = _currentQuestion;
    final timedOut = index < 0;
    final correct = !timedOut && index == question.correctIndex;
    final usedSeconds =
        (_secondsPerQuestion - _timeLeft).clamp(0, _secondsPerQuestion);

    final run = _currentRun;
    run.totalTimeMs += (usedSeconds == 0 ? 1 : usedSeconds) * 1000;

    if (correct) {
      run.correct++;
      run.score += BattleConstants.xpPerCorrect;
    } else {
      run.wrong++;
    }

    if (_topic != 'mixed') {
      unawaited(
          StorageService.recordQuestionResult(topic: _topic, correct: correct));
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _answerLocked = true;
      _selectedIndex = timedOut ? null : index;
      _feedback = correct
          ? '✅ Correct +${BattleConstants.xpPerCorrect}'
          : timedOut
              ? '⌛ Time up!'
              : '❌ Wrong answer';
    });

    unawaited(AudioService.instance.playSfx(
      volume: correct ? 0.56 : (timedOut ? 0.36 : 0.42),
    ));

    await Future<void>.delayed(const Duration(milliseconds: 600));

    if (!mounted) {
      return;
    }

    if (_currentQuestionIndex + 1 < _questionSet.length) {
      setState(() {
        _currentQuestionIndex++;
        _selectedIndex = null;
        _feedback = '';
        _answerLocked = false;
      });
      _startQuestionTimer();
      return;
    }

    if (_currentParticipantIndex + 1 < _participants.length) {
      setState(() {
        _currentParticipantIndex++;
        _phase = _MultiplayerPhase.betweenPlayers;
        _selectedIndex = null;
        _feedback = '';
        _answerLocked = false;
      });
      return;
    }

    await _finalizeMatch();
  }

  Future<void> _finalizeMatch() async {
    _timer?.cancel();

    final standings = _runs.values
        .map(
          (run) => _Standing(
            name: run.name,
            score: run.score,
            correct: run.correct,
            wrong: run.wrong,
            totalTimeMs: run.totalTimeMs,
          ),
        )
        .toList()
      ..sort((a, b) {
        final byScore = b.score.compareTo(a.score);
        if (byScore != 0) {
          return byScore;
        }
        final byCorrect = b.correct.compareTo(a.correct);
        if (byCorrect != 0) {
          return byCorrect;
        }
        return a.totalTimeMs.compareTo(b.totalTimeMs);
      });

    if (!mounted) {
      return;
    }

    setState(() {
      _standings = standings;
      _phase = _MultiplayerPhase.result;
      _persistingResult = true;
    });

    try {
      for (final row in standings) {
        await StorageService.saveScore(row.name, row.score);
      }

      await StorageService.addMultiplayerHistory(
        topic: _topic,
        questionCount: _questionCount,
        secondsPerQuestion: _secondsPerQuestion,
        standings: standings.map((s) => s.toJson()).toList(),
      );

      await _loadRecentMatches();
    } finally {
      if (mounted) {
        setState(() {
          _persistingResult = false;
        });
      }
    }
  }

  void _startNextParticipant() {
    setState(() {
      _currentQuestionIndex = 0;
      _timeLeft = _secondsPerQuestion;
      _selectedIndex = null;
      _feedback = '';
      _answerLocked = false;
      _phase = _MultiplayerPhase.playing;
    });
    _startQuestionTimer();
  }

  Color _optionColor(int index) {
    if (!_answerLocked) {
      return const Color(0xFF2A2A4A);
    }
    if (index == _currentQuestion.correctIndex) {
      return Colors.green[700]!;
    }
    if (index == _selectedIndex) {
      return Colors.red[700]!;
    }
    return const Color(0xFF2A2A4A);
  }

  String _topicLabel(String topic) {
    switch (topic) {
      case 'quant':
        return 'Quant';
      case 'logic':
        return 'Logic';
      case 'english':
        return 'English';
      default:
        return 'Mixed';
    }
  }

  String _durationText(int totalTimeMs) {
    final secs = (totalTimeMs / 1000).round();
    return '$secs' 's';
  }

  List<_Standing> get _winners {
    if (_standings.isEmpty) {
      return <_Standing>[];
    }

    final top = _standings.first;
    return _standings
        .where((s) => s.score == top.score && s.correct == top.correct)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF12314A),
        title: const Text('⚔ Multiplayer Arena'),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: AppGradientBackground(
          child: switch (_phase) {
            _MultiplayerPhase.lobby => _buildLobby(),
            _MultiplayerPhase.playing => _buildPlaying(),
            _MultiplayerPhase.betweenPlayers => _buildBetweenPlayers(),
            _MultiplayerPhase.result => _buildResult(),
          },
        ),
      ),
    );
  }

  Widget _buildLobby() {
    return SingleChildScrollView(
      key: const ValueKey<String>('lobby'),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Create Competition Match',
            style: TextStyle(
                color: Colors.amberAccent,
                fontSize: 22,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add students, set topic and rounds, then each student plays the same question set.',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 16),
          Card(
            color: const Color(0xFF1E1E3A),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Topic', style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: _topic,
                    style: const TextStyle(color: Colors.white),
                    dropdownColor: const Color(0xFF1E1E3A),
                    decoration: const InputDecoration(
                      filled: true,
                      fillColor: Color(0xFF2A2A4A),
                      border: OutlineInputBorder(borderSide: BorderSide.none),
                    ),
                    items: const [
                      DropdownMenuItem(
                          value: 'mixed',
                          child: Text('Mixed', style: TextStyle(color: Colors.white))),
                      DropdownMenuItem(
                          value: 'quant',
                          child: Text('Quant', style: TextStyle(color: Colors.white))),
                      DropdownMenuItem(
                          value: 'logic',
                          child: Text('Logic', style: TextStyle(color: Colors.white))),
                      DropdownMenuItem(
                          value: 'english',
                          child: Text('English', style: TextStyle(color: Colors.white))),
                    ],
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      setState(() {
                        _topic = value;
                      });
                    },
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Questions per student: $_questionCount',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  Slider(
                    min: 5,
                    max: 20,
                    divisions: 15,
                    value: _questionCount.toDouble(),
                    activeColor: Colors.amberAccent,
                    onChanged: (value) {
                      setState(() {
                        _questionCount = value.round();
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Seconds per question: $_secondsPerQuestion',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  Slider(
                    min: 10,
                    max: 45,
                    divisions: 35,
                    value: _secondsPerQuestion.toDouble(),
                    activeColor: Colors.cyanAccent,
                    onChanged: (value) {
                      setState(() {
                        _secondsPerQuestion = value.round();
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            color: const Color(0xFF1E1E3A),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Add Students',
                      style: TextStyle(
                          color: Colors.white70, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _nameController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Enter student name',
                            hintStyle: const TextStyle(color: Colors.white38),
                            filled: true,
                            fillColor: const Color(0xFF2A2A4A),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onSubmitted: (_) => _addParticipant(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: _addParticipant,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF5E35B1),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 16),
                        ),
                        child: const Text('Add'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_participants.isEmpty)
                    const Text('No students added yet.',
                        style: TextStyle(color: Colors.white54))
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _participants
                          .map(
                            (name) => Chip(
                              label: Text(name,
                                  style: const TextStyle(color: Colors.white)),
                              backgroundColor: const Color(0xFF2A2A4A),
                              deleteIcon: const Icon(Icons.close,
                                  size: 18, color: Colors.white70),
                              onDeleted: () => _removeParticipant(name),
                            ),
                          )
                          .toList(),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _startMatch,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00897B),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('START MULTIPLAYER MATCH'),
            ),
          ),
          const SizedBox(height: 22),
          const Text('Recent Matches',
              style: TextStyle(
                  color: Colors.amberAccent,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          if (_recentMatches.isEmpty)
            const Text('No multiplayer matches yet.',
                style: TextStyle(color: Colors.white54))
          else
            ..._recentMatches.take(5).map((match) {
              final topic = (match['topic'] as String?) ?? 'mixed';
              final standingsRaw = match['standings'];
              final standings = standingsRaw is List
                  ? standingsRaw
                      .map((e) =>
                          Map<String, dynamic>.from(e as Map<dynamic, dynamic>))
                      .toList()
                  : <Map<String, dynamic>>[];

              final winnerNames = _winnerNamesFromRows(standings);

              return Card(
                color: const Color(0xFF1E1E3A),
                child: ListTile(
                  title: Text(
                    '${_topicLabel(topic)} • Q${match['questionCount'] ?? '-'} • ${match['secondsPerQuestion'] ?? '-'}s',
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    'Winner: ${winnerNames.join(', ')}',
                    style: const TextStyle(color: Colors.amberAccent),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildPlaying() {
    final question = _currentQuestion;

    return SingleChildScrollView(
      key: const ValueKey<String>('playing'),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            color: const Color(0xFF1E1E3A),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Player ${_currentParticipantIndex + 1}/${_participants.length}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      Text(
                        _currentParticipant,
                        style: const TextStyle(
                          color: Colors.amberAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Question ${_currentQuestionIndex + 1}/$_questionCount',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      Text(
                        '⏳ $_timeLeft s',
                        style: TextStyle(
                          color:
                              _timeLeft <= 5 ? Colors.redAccent : Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: (_timeLeft / _secondsPerQuestion).clamp(0.0, 1.0),
                    minHeight: 10,
                    backgroundColor: Colors.white12,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _timeLeft > 5 ? Colors.green : Colors.red,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Score: ${_currentRun.score} • Correct: ${_currentRun.correct} • Wrong: ${_currentRun.wrong}',
                    style: const TextStyle(color: Colors.cyanAccent),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            color: const Color(0xFF1E1E3A),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                question.questionText,
                style: const TextStyle(
                    color: Colors.white, fontSize: 16, height: 1.45),
              ),
            ),
          ),
          const SizedBox(height: 10),
          ...List.generate(question.options.length, (index) {
            return OptionCard(
              text: question.options[index],
              color: _optionColor(index),
              onTap: () => _submitAnswer(index),
            );
          }),
          if (_feedback.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A3A),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _feedback,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBetweenPlayers() {
    final run = _lastFinishedRun;

    return Center(
      key: const ValueKey<String>('between'),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🎯', style: TextStyle(fontSize: 72)),
            const SizedBox(height: 12),
            Text(
              '${run.name} completed!',
              style: const TextStyle(
                  color: Colors.amberAccent,
                  fontSize: 24,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Score: ${run.score}  •  Correct: ${run.correct}  •  Wrong: ${run.wrong}  •  Time: ${_durationText(run.totalTimeMs)}',
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Text(
              'Pass device to $_currentParticipant',
              style: const TextStyle(color: Colors.cyanAccent, fontSize: 16),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: 240,
              child: ElevatedButton(
                onPressed: _startNextParticipant,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E88E5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('START NEXT STUDENT'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResult() {
    final winners = _winners;

    return SingleChildScrollView(
      key: const ValueKey<String>('result'),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(child: Text('🏆', style: TextStyle(fontSize: 72))),
          const SizedBox(height: 8),
          Center(
            child: Text(
              winners.length > 1
                  ? 'Winners: ${winners.map((w) => w.name).join(', ')}'
                  : 'Winner: ${winners.first.name}',
              style: const TextStyle(
                  color: Colors.amberAccent,
                  fontSize: 22,
                  fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              '${_topicLabel(_topic)} • $_questionCount questions • ${_secondsPerQuestion}s each',
              style: const TextStyle(color: Colors.white70),
            ),
          ),
          if (_persistingResult)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Center(child: CircularProgressIndicator()),
            ),
          const SizedBox(height: 14),
          Card(
            color: const Color(0xFF1E1E3A),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: _standings.asMap().entries.map((entry) {
                  final index = entry.key;
                  final row = entry.value;

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          index == 0 ? Colors.amber : const Color(0xFF2A2A4A),
                      child: Text(
                        '#${index + 1}',
                        style: TextStyle(
                          color: index == 0 ? Colors.black : Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      row.name,
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      'Correct ${row.correct} • Wrong ${row.wrong} • Time ${_durationText(row.totalTimeMs)}',
                      style: const TextStyle(color: Colors.white60),
                    ),
                    trailing: Text(
                      row.score.toString(),
                      style: const TextStyle(
                        color: Colors.amberAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                setState(() {
                  _phase = _MultiplayerPhase.lobby;
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3949AB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('CREATE NEW MATCH'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.amberAccent,
                side: const BorderSide(color: Colors.amberAccent),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('BACK TO HOME'),
            ),
          ),
        ],
      ),
    );
  }

  List<String> _winnerNamesFromRows(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) {
      return <String>['-'];
    }

    rows.sort((a, b) {
      final scoreA = (a['score'] as num?)?.toInt() ?? 0;
      final scoreB = (b['score'] as num?)?.toInt() ?? 0;
      if (scoreA != scoreB) {
        return scoreB.compareTo(scoreA);
      }
      final correctA = (a['correct'] as num?)?.toInt() ?? 0;
      final correctB = (b['correct'] as num?)?.toInt() ?? 0;
      if (correctA != correctB) {
        return correctB.compareTo(correctA);
      }
      final timeA = (a['totalTimeMs'] as num?)?.toInt() ?? 0;
      final timeB = (b['totalTimeMs'] as num?)?.toInt() ?? 0;
      return timeA.compareTo(timeB);
    });

    final topScore = (rows.first['score'] as num?)?.toInt() ?? 0;
    final topCorrect = (rows.first['correct'] as num?)?.toInt() ?? 0;

    return rows
        .where(
          (row) =>
              ((row['score'] as num?)?.toInt() ?? 0) == topScore &&
              ((row['correct'] as num?)?.toInt() ?? 0) == topCorrect,
        )
        .map((row) => (row['name'] as String?) ?? 'Unknown')
        .toList();
  }
}

class _ParticipantRun {
  _ParticipantRun({required this.name});

  final String name;
  int score = 0;
  int correct = 0;
  int wrong = 0;
  int totalTimeMs = 0;
}

class _Standing {
  const _Standing({
    required this.name,
    required this.score,
    required this.correct,
    required this.wrong,
    required this.totalTimeMs,
  });

  final String name;
  final int score;
  final int correct;
  final int wrong;
  final int totalTimeMs;

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'score': score,
      'correct': correct,
      'wrong': wrong,
      'totalTimeMs': totalTimeMs,
    };
  }
}
