import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/question.dart';
import '../services/audio_service.dart';
import '../services/online_match_service.dart';
import '../services/storage_service.dart';
import '../widgets/app_gradient_background.dart';
import '../widgets/option_card.dart';

class OnlineArenaScreen extends StatefulWidget {
  const OnlineArenaScreen({super.key});

  @override
  State<OnlineArenaScreen> createState() => _OnlineArenaScreenState();
}

class _OnlineArenaScreenState extends State<OnlineArenaScreen> {
  final OnlineMatchService _service = OnlineMatchService.instance;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _roomCodeController = TextEditingController();
  final TextEditingController _draftQuestionController =
      TextEditingController();
  final TextEditingController _draftOptionAController = TextEditingController();
  final TextEditingController _draftOptionBController = TextEditingController();
  final TextEditingController _draftOptionCController = TextEditingController();
  final TextEditingController _draftOptionDController = TextEditingController();

  bool _checkingFirebase = true;
  bool _firebaseReady = false;
  bool _busy = false;

  String _topic = 'mixed';
  int _questionCount = 10;
  int _secondsPerQuestion = 20;

  String? _roomId;
  String? _playerId;
  String _statusMessage = '';
  Stream<OnlineRoomSnapshot?>? _roomStream;
  Stream<List<OnlinePlayerState>>? _playersStream;

  int _timeLeft = 20;
  int _activeQuestionIndex = -1;
  bool _submittedCurrent = false;
  int? _selectedIndex;
  DateTime? _questionStartedAt;
  Timer? _roundTimer;
  int _draftCorrectIndex = 0;
  String _draftTopic = 'quant';
  bool _syncScheduled = false;
  bool _hostProgressSyncInFlight = false;
  bool _submitInFlight = false;
  bool _persistingResults = false;
  String _roundSyncSignature = '';
  String? _lastPersistedRoomId;
  DateTime? _lastHostSyncAt;
  OnlineRoomSnapshot? _latestRoom;
  OnlinePlayerState? _latestSelf;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    final name = await StorageService.getPlayerName();
    final ready = await _service.ensureFirebaseReady();

    if (!mounted) {
      return;
    }

    setState(() {
      if (name.isNotEmpty) {
        _nameController.text = name;
      }
      _firebaseReady = ready;
      _checkingFirebase = false;
      if (!ready) {
        _statusMessage = _service.lastInitError ??
            'Firebase is not configured yet. Add FlutterFire config to enable online rooms.';
      }
    });
  }

  @override
  void dispose() {
    _roundTimer?.cancel();
    _nameController.dispose();
    _roomCodeController.dispose();
    _draftQuestionController.dispose();
    _draftOptionAController.dispose();
    _draftOptionBController.dispose();
    _draftOptionCController.dispose();
    _draftOptionDController.dispose();
    super.dispose();
  }

  bool get _inRoom => _roomId != null && _playerId != null;

  String get _playerName => _nameController.text.trim();

  Future<void> _createRoom() async {
    if (_busy || !_firebaseReady) {
      return;
    }

    if (_playerName.length < 2) {
      _showSnack('Enter at least 2 characters for your name.');
      return;
    }

    setState(() {
      _busy = true;
      _statusMessage = 'Creating room...';
    });

    try {
      await StorageService.savePlayerName(_playerName);
      final join = await _service.createRoom(
        hostName: _playerName,
        topic: _topic,
        questionCount: _questionCount,
        secondsPerQuestion: _secondsPerQuestion,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _roomId = join.roomId;
        _playerId = join.playerId;
        _bindRoomStreams(join.roomId);
        _statusMessage =
            'Room ${join.roomId} created. Share code with students.';
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _statusMessage = 'Create room failed: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _joinRoom() async {
    if (_busy || !_firebaseReady) {
      return;
    }

    if (_playerName.length < 2) {
      _showSnack('Enter at least 2 characters for your name.');
      return;
    }

    final roomCode = _roomCodeController.text.trim().toUpperCase();
    if (roomCode.length < 4) {
      _showSnack('Enter a valid room code.');
      return;
    }

    setState(() {
      _busy = true;
      _statusMessage = 'Joining room...';
    });

    try {
      await StorageService.savePlayerName(_playerName);
      final join = await _service.joinRoom(
        roomId: roomCode,
        name: _playerName,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _roomId = join.roomId;
        _playerId = join.playerId;
        _bindRoomStreams(join.roomId);
        _statusMessage = 'Joined room ${join.roomId}.';
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _statusMessage = 'Join room failed: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _toggleReady(OnlineRoomSnapshot room, bool ready) async {
    final roomId = _roomId;
    final playerId = _playerId;
    if (roomId == null || playerId == null) {
      return;
    }

    try {
      await _service.setReady(roomId: roomId, playerId: playerId, ready: ready);
    } catch (e) {
      _showSnack('Could not update ready state: $e');
    }
  }

  Future<void> _startMatch(OnlineRoomSnapshot room) async {
    final roomId = _roomId;
    final playerId = _playerId;
    if (roomId == null || playerId == null || _busy) {
      return;
    }

    setState(() {
      _busy = true;
    });

    try {
      await _service.startMatch(roomId: roomId, hostPlayerId: playerId);
    } catch (e) {
      _showSnack('$e');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _addRoomQuestion(OnlineRoomSnapshot room) async {
    final roomId = _roomId;
    final playerId = _playerId;
    if (roomId == null || playerId == null || _busy) {
      return;
    }

    final questionText = _draftQuestionController.text.trim();
    final options = <String>[
      _draftOptionAController.text.trim(),
      _draftOptionBController.text.trim(),
      _draftOptionCController.text.trim(),
      _draftOptionDController.text.trim(),
    ];

    if (questionText.length < 10) {
      _showSnack('Question should be at least 10 characters.');
      return;
    }
    if (options.any((o) => o.isEmpty)) {
      _showSnack('All 4 options are required.');
      return;
    }

    final topic = room.topic == 'mixed' ? _draftTopic : room.topic;

    setState(() {
      _busy = true;
    });

    try {
      await _service.addRoomQuestion(
        roomId: roomId,
        hostPlayerId: playerId,
        question: Question(
          questionText: questionText,
          options: options,
          correctIndex: _draftCorrectIndex,
          topic: topic,
        ),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _draftQuestionController.clear();
        _draftOptionAController.clear();
        _draftOptionBController.clear();
        _draftOptionCController.clear();
        _draftOptionDController.clear();
        _draftCorrectIndex = 0;
      });
    } catch (e) {
      _showSnack('Add question failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _removeRoomQuestion(
      OnlineRoomSnapshot room, Question question) async {
    final roomId = _roomId;
    final playerId = _playerId;
    if (roomId == null || playerId == null) {
      return;
    }

    try {
      await _service.removeRoomQuestion(
        roomId: roomId,
        hostPlayerId: playerId,
        questionId: question.id,
      );
    } catch (e) {
      _showSnack('Remove failed: $e');
    }
  }

  Future<void> _forceNext(OnlineRoomSnapshot room) async {
    final roomId = _roomId;
    final playerId = _playerId;
    if (roomId == null || playerId == null) {
      return;
    }

    try {
      await _service.forceAdvanceQuestion(
          roomId: roomId, hostPlayerId: playerId);
    } catch (e) {
      _showSnack('Force next failed: $e');
    }
  }

  Future<void> _forceFinish(OnlineRoomSnapshot room) async {
    final roomId = _roomId;
    final playerId = _playerId;
    if (roomId == null || playerId == null) {
      return;
    }

    try {
      await _service.forceFinish(roomId: roomId, hostPlayerId: playerId);
    } catch (e) {
      _showSnack('Force finish failed: $e');
    }
  }

  Future<void> _submitAnswer({
    required OnlineRoomSnapshot room,
    required OnlinePlayerState self,
    required int selectedIndex,
  }) async {
    final roomId = _roomId;
    final playerId = _playerId;
    if (roomId == null || playerId == null) {
      return;
    }

    if (!room.isPlaying ||
        _submittedCurrent ||
        _submitInFlight ||
        self.lastAnsweredIndex >= room.currentQuestionIndex) {
      return;
    }

    final spentMs = DateTime.now()
        .difference(_questionStartedAt ?? DateTime.now())
        .inMilliseconds;

    setState(() {
      _submitInFlight = true;
      _submittedCurrent = true;
      _selectedIndex = selectedIndex >= 0 ? selectedIndex : null;
    });

    final questionIndex = room.currentQuestionIndex;
    final hasQuestion =
        questionIndex >= 0 && questionIndex < room.roomQuestions.length;
    final isCorrect = hasQuestion &&
        selectedIndex >= 0 &&
        selectedIndex == room.roomQuestions[questionIndex].correctIndex;

    unawaited(AudioService.instance.playSfx(
      volume: isCorrect ? 0.56 : (selectedIndex < 0 ? 0.36 : 0.42),
    ));

    try {
      final accepted = await _service.submitAnswer(
        roomId: roomId,
        playerId: playerId,
        questionIndex: room.currentQuestionIndex,
        selectedIndex: selectedIndex,
        timeSpentMs: spentMs,
      );

      if (!accepted && mounted && _activeQuestionIndex == room.currentQuestionIndex) {
        setState(() {
          _submittedCurrent = false;
          _selectedIndex = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _submittedCurrent = false;
          _selectedIndex = null;
        });
      }
      _showSnack('Submit failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _submitInFlight = false;
        });
      } else {
        _submitInFlight = false;
      }
    }
  }

  Future<void> _syncProgressIfHost({
    required OnlineRoomSnapshot room,
    required OnlinePlayerState self,
  }) async {
    final roomId = _roomId;
    if (roomId == null ||
        _hostProgressSyncInFlight ||
        !room.isPlaying ||
        self.playerId != room.hostPlayerId) {
      return;
    }

    final now = DateTime.now();
    if (_lastHostSyncAt != null &&
        now.difference(_lastHostSyncAt!).inMilliseconds < 850) {
      return;
    }
    _lastHostSyncAt = now;

    _hostProgressSyncInFlight = true;
    try {
      await _service.syncRoomProgressIfHost(
        roomId: roomId,
        playerId: self.playerId,
      );
    } catch (e) {
      debugPrint('Host progress sync skipped: $e');
    } finally {
      _hostProgressSyncInFlight = false;
    }
  }

  void _syncRoundState(OnlineRoomSnapshot room, OnlinePlayerState self) {
    if (!mounted) {
      return;
    }

    if (!room.isPlaying) {
      if (_activeQuestionIndex != -1) {
        _roundTimer?.cancel();
        setState(() {
          _activeQuestionIndex = -1;
          _timeLeft = room.secondsPerQuestion;
          _submittedCurrent = false;
          _selectedIndex = null;
        });
      }
      return;
    }

    if (_activeQuestionIndex == room.currentQuestionIndex) {
      final backendAnswered =
          self.lastAnsweredIndex >= room.currentQuestionIndex;
      final syncedTimeLeft = _timeLeftFor(room);
      if (backendAnswered != _submittedCurrent || syncedTimeLeft != _timeLeft) {
        setState(() {
          _submittedCurrent = backendAnswered;
          _timeLeft = syncedTimeLeft;
        });
      }
      return;
    }

    _startRoundTimer(room, self);
    final backendAnswered = self.lastAnsweredIndex >= room.currentQuestionIndex;

    setState(() {
      _activeQuestionIndex = room.currentQuestionIndex;
      _submittedCurrent = backendAnswered;
      _selectedIndex = null;
      _questionStartedAt = room.roundStartedAt ?? DateTime.now();
    });
  }

  void _startRoundTimer(OnlineRoomSnapshot room, OnlinePlayerState self) {
    _roundTimer?.cancel();
    _timeLeft = _timeLeftFor(room);

    _roundTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final roomNow = _latestRoom ?? room;
      final selfNow = _latestSelf ?? self;
      if (!roomNow.isPlaying) {
        timer.cancel();
        return;
      }

      final nextTimeLeft = _timeLeftFor(roomNow);
      if (nextTimeLeft != _timeLeft) {
        setState(() {
          _timeLeft = nextTimeLeft;
        });
      }

      if (_submittedCurrent) {
        return;
      }

      if (nextTimeLeft <= 0) {
        timer.cancel();
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted || _submittedCurrent) {
            return;
          }
          await _submitAnswer(room: roomNow, self: selfNow, selectedIndex: -1);
        });
        return;
      }
    });
  }

  void _leaveRoom() {
    _roundTimer?.cancel();
    setState(() {
      _roomId = null;
      _playerId = null;
      _roomStream = null;
      _playersStream = null;
      _statusMessage = 'Left room.';
      _activeQuestionIndex = -1;
      _submittedCurrent = false;
      _selectedIndex = null;
      _submitInFlight = false;
      _persistingResults = false;
      _lastPersistedRoomId = null;
      _roundSyncSignature = '';
      _lastHostSyncAt = null;
      _latestRoom = null;
      _latestSelf = null;
    });
  }

  Future<void> _persistLeaderboardForFinishedRoom(
    OnlineRoomSnapshot room,
    List<OnlinePlayerState> players,
  ) async {
    if (!room.isFinished || players.isEmpty) {
      return;
    }
    if (_persistingResults || _lastPersistedRoomId == room.roomId) {
      return;
    }

    _persistingResults = true;
    _lastPersistedRoomId = room.roomId;

    final sorted = _sortedPlayers(players);
    if (sorted.isEmpty) {
      _persistingResults = false;
      return;
    }

    final top = sorted.first;
    final winners = sorted
        .where((p) => p.score == top.score && p.correct == top.correct)
        .toList();

    try {
      for (final winner in winners) {
        await StorageService.saveScore(winner.name, winner.score);
      }
    } finally {
      _persistingResults = false;
    }
  }

  void _bindRoomStreams(String roomId) {
    _roomStream = _service.watchRoom(roomId);
    _playersStream = _service.watchPlayers(roomId);
  }

  void _scheduleRoundSync(OnlineRoomSnapshot room, OnlinePlayerState self) {
    _latestRoom = room;
    _latestSelf = self;

    final nextSignature =
        '${room.status}:${room.currentQuestionIndex}:${self.lastAnsweredIndex}:${self.currentQuestion}:${self.isFinished}:${room.roundStartedAt?.millisecondsSinceEpoch ?? -1}';

    if (_syncScheduled || nextSignature == _roundSyncSignature) {
      return;
    }

    _roundSyncSignature = nextSignature;

    _syncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncScheduled = false;
      if (!mounted) {
        return;
      }
      _syncRoundState(room, self);
      _syncProgressIfHost(room: room, self: self);
    });
  }

  OnlinePlayerState? _findSelf(List<OnlinePlayerState> players) {
    final playerId = _playerId;
    if (playerId == null) {
      return null;
    }

    for (final p in players) {
      if (p.playerId == playerId) {
        return p;
      }
    }

    return null;
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

  List<OnlinePlayerState> _sortedPlayers(List<OnlinePlayerState> players) {
    final sorted = List<OnlinePlayerState>.from(players);
    sorted.sort((a, b) {
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
    return sorted;
  }

  int _timeLeftFor(OnlineRoomSnapshot room) {
    final roundStartedAt = room.roundStartedAt;
    if (roundStartedAt == null) {
      return _activeQuestionIndex == room.currentQuestionIndex
          ? _timeLeft
          : room.secondsPerQuestion;
    }

    final elapsedSeconds = DateTime.now().difference(roundStartedAt).inSeconds;
    final remaining = room.secondsPerQuestion - max(0, elapsedSeconds);
    return remaining.clamp(0, room.secondsPerQuestion).toInt();
  }

  Question? _currentQuestionForRoom(OnlineRoomSnapshot room) {
    final qIndex = room.currentQuestionIndex;
    if (qIndex < 0 || qIndex >= room.roomQuestions.length) {
      return null;
    }

    return room.roomQuestions[qIndex];
  }

  Color _optionColor({
    required Question question,
    required int optionIndex,
  }) {
    if (!_submittedCurrent) {
      return const Color(0xFF2A2A4A);
    }
    if (optionIndex == question.correctIndex) {
      return Colors.green[700]!;
    }
    if (_selectedIndex == optionIndex) {
      return Colors.red[700]!;
    }
    return const Color(0xFF2A2A4A);
  }

  void _showSnack(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF12314A),
        title: Text(
            _inRoom ? '🌐 Online Arena (${_roomId ?? ''})' : '🌐 Online Arena'),
        actions: [
          if (_inRoom)
            IconButton(
              tooltip: 'Copy room code',
              onPressed: () {
                final room = _roomId;
                if (room == null) {
                  return;
                }
                Clipboard.setData(ClipboardData(text: room));
                _showSnack('Room code copied: $room');
              },
              icon: const Icon(Icons.copy),
            ),
          if (_inRoom)
            IconButton(
              tooltip: 'Leave room',
              onPressed: _leaveRoom,
              icon: const Icon(Icons.logout),
            ),
        ],
      ),
      body: AppGradientBackground(
        child: _checkingFirebase
            ? const Center(child: CircularProgressIndicator())
            : !_inRoom
                ? _buildSetup()
                : _buildRoom(),
      ),
    );
  }

  Widget _buildSetup() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Online Multiplayer Rooms',
            style: TextStyle(
                color: Colors.amberAccent,
                fontSize: 24,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'Create room for class competition or join using a room code.',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 14),
          if (!_firebaseReady)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF402020),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Firebase is not configured for this app yet.\nAdd FlutterFire config (google-services / firebase options) to use online rooms.',
                style: TextStyle(color: Colors.white),
              ),
            ),
          const SizedBox(height: 12),
          Card(
            color: const Color(0xFF1E1E3A),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _nameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Your name',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: const Color(0xFF2A2A4A),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
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
                  const SizedBox(height: 10),
                  Text(
                    'Questions per player: $_questionCount',
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
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _firebaseReady && !_busy ? _createRoom : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1565C0),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('CREATE ROOM'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Divider(color: Colors.white12),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _roomCodeController,
                    textCapitalization: TextCapitalization.characters,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Enter room code',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: const Color(0xFF2A2A4A),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _firebaseReady && !_busy ? _joinRoom : null,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.cyanAccent,
                        side: const BorderSide(color: Colors.cyanAccent),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('JOIN ROOM'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_statusMessage.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(_statusMessage, style: const TextStyle(color: Colors.white60)),
          ],
        ],
      ),
    );
  }

  Widget _buildRoom() {
    final roomId = _roomId;
    if (roomId == null) {
      return const SizedBox.shrink();
    }

    _roomStream ??= _service.watchRoom(roomId);
    _playersStream ??= _service.watchPlayers(roomId);

    return StreamBuilder<OnlineRoomSnapshot?>(
      stream: _roomStream,
      builder: (context, roomSnapshot) {
        if (roomSnapshot.connectionState == ConnectionState.waiting &&
            !roomSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final room = roomSnapshot.data;
        if (room == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Room not found or closed.',
                      style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: _leaveRoom,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF455A64),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Back'),
                  ),
                ],
              ),
            ),
          );
        }

        return StreamBuilder<List<OnlinePlayerState>>(
          stream: _playersStream,
          builder: (context, playersSnapshot) {
            if (playersSnapshot.connectionState == ConnectionState.waiting &&
                !playersSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final players = playersSnapshot.data ?? <OnlinePlayerState>[];
            final self = _findSelf(players);
            if (self == null) {
              return const Center(
                child: Text('You are not in this room.',
                    style: TextStyle(color: Colors.white70)),
              );
            }

            _scheduleRoundSync(room, self);
            if (room.isFinished) {
              _persistLeaderboardForFinishedRoom(room, players);
            }

            final sorted = _sortedPlayers(players);
            final isHost = self.playerId == room.hostPlayerId;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    color: const Color(0xFF1E1E3A),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Room Code: ${room.roomId}',
                            style: const TextStyle(
                              color: Colors.amberAccent,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_topicLabel(room.topic)} • Q${room.questionCount} • ${room.secondsPerQuestion}s',
                            style: const TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Status: ${room.status.toUpperCase()}',
                            style: const TextStyle(color: Colors.cyanAccent),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Players',
                    style: TextStyle(
                        color: Colors.white70, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  ...players.map((p) {
                    final readyIcon = p.ready
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked;
                    return Card(
                      color: const Color(0xFF1E1E3A),
                      child: ListTile(
                        leading: Icon(readyIcon,
                            color: p.ready ? Colors.green : Colors.white38),
                        title: Text(p.name,
                            style: const TextStyle(color: Colors.white)),
                        subtitle: Text(
                          'Score ${p.score} • Correct ${p.correct} • Wrong ${p.wrong}',
                          style: const TextStyle(color: Colors.white60),
                        ),
                        trailing: Text(
                          '${(p.totalTimeMs / 1000).round()}s',
                          style: const TextStyle(color: Colors.amberAccent),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 10),
                  if (room.isLobby) ...[
                    _buildQuestionDeckEditor(room: room, isHost: isHost),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      value: self.ready,
                      onChanged: (value) => _toggleReady(room, value),
                      title: const Text('Ready',
                          style: TextStyle(color: Colors.white)),
                      subtitle: const Text(
                        'All players must be ready before host starts match.',
                        style: TextStyle(color: Colors.white54),
                      ),
                    ),
                    if (isHost)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _busy ? null : () => _startMatch(room),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00897B),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('START MATCH'),
                        ),
                      ),
                  ],
                  if (room.isPlaying) ...[
                    const SizedBox(height: 12),
                    _buildPlayingSection(
                        room: room, self: self, sorted: sorted, isHost: isHost),
                  ],
                  if (room.isFinished) ...[
                    const SizedBox(height: 12),
                    _buildFinishedSection(room: room, sorted: sorted),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPlayingSection({
    required OnlineRoomSnapshot room,
    required OnlinePlayerState self,
    required List<OnlinePlayerState> sorted,
    required bool isHost,
  }) {
    final question = _currentQuestionForRoom(room);

    return Card(
      color: const Color(0xFF1E1E3A),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Round ${room.currentQuestionIndex + 1}/${room.questionCount}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
                Text(
                  '⏳ $_timeLeft s',
                  style: TextStyle(
                    color: _timeLeft <= 5 ? Colors.redAccent : Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: (_timeLeft / room.secondsPerQuestion).clamp(0.0, 1.0),
              minHeight: 10,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation<Color>(
                _timeLeft > 5 ? Colors.green : Colors.red,
              ),
            ),
            const SizedBox(height: 12),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, animation) {
                final slideAnimation = Tween<Offset>(
                  begin: const Offset(0.04, 0),
                  end: Offset.zero,
                ).animate(animation);
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(position: slideAnimation, child: child),
                );
              },
              child: question == null
                  ? const Text(
                      'Question not available',
                      key: ValueKey<String>('missing-question'),
                      style: TextStyle(color: Colors.white60),
                    )
                  : Column(
                      key: ValueKey<int>(room.currentQuestionIndex),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          question.questionText,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 16, height: 1.4),
                        ),
                        const SizedBox(height: 10),
                        if (_submittedCurrent ||
                            self.lastAnsweredIndex >= room.currentQuestionIndex)
                          const Text(
                            'Answer submitted. Waiting for other players...',
                            style: TextStyle(color: Colors.cyanAccent),
                          )
                        else
                          ...List.generate(question.options.length, (index) {
                            return OptionCard(
                              text: question.options[index],
                              color: _optionColor(
                                  question: question, optionIndex: index),
                              onTap: () => _submitAnswer(
                                  room: room, self: self, selectedIndex: index),
                            );
                          }),
                      ],
                    ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Live Standings',
              style:
                  TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            ...sorted.take(5).map((p) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        p.name,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                    Text(
                      '${p.score}',
                      style: const TextStyle(color: Colors.amberAccent),
                    ),
                  ],
                ),
              );
            }),
            if (isHost) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton(
                    onPressed: () => _forceNext(room),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepOrange,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Force Next'),
                  ),
                  ElevatedButton(
                    onPressed: () => _forceFinish(room),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Force Finish'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionDeckEditor({
    required OnlineRoomSnapshot room,
    required bool isHost,
  }) {
    final questions = room.roomQuestions;

    return Card(
      color: const Color(0xFF1D243F),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Question Deck (${questions.length})',
              style: const TextStyle(
                color: Colors.amberAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Host can add/remove questions before match starts.',
              style: TextStyle(color: Colors.white60, fontSize: 12),
            ),
            const SizedBox(height: 8),
            ...questions.take(8).map((q) {
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  q.questionText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                subtitle: Text(
                  '${q.topic.toUpperCase()} • ${q.options[q.correctIndex]}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
                trailing: isHost
                    ? IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.redAccent),
                        onPressed: () => _removeRoomQuestion(room, q),
                      )
                    : null,
              );
            }),
            if (questions.length > 8)
              Text(
                '+ ${questions.length - 8} more questions',
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
            if (isHost) ...[
              const Divider(color: Colors.white12),
              TextField(
                controller: _draftQuestionController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Add a custom question for this room',
                  hintStyle: TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: Color(0xFF26314D),
                  border: OutlineInputBorder(borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _draftOptionAController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'A',
                        hintStyle: TextStyle(color: Colors.white38),
                        filled: true,
                        fillColor: Color(0xFF26314D),
                        border: OutlineInputBorder(borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _draftOptionBController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'B',
                        hintStyle: TextStyle(color: Colors.white38),
                        filled: true,
                        fillColor: Color(0xFF26314D),
                        border: OutlineInputBorder(borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _draftOptionCController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'C',
                        hintStyle: TextStyle(color: Colors.white38),
                        filled: true,
                        fillColor: Color(0xFF26314D),
                        border: OutlineInputBorder(borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _draftOptionDController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'D',
                        hintStyle: TextStyle(color: Colors.white38),
                        filled: true,
                        fillColor: Color(0xFF26314D),
                        border: OutlineInputBorder(borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _draftCorrectIndex,
                      style: const TextStyle(color: Colors.white),
                      dropdownColor: const Color(0xFF1E1E3A),
                      decoration: const InputDecoration(
                        filled: true,
                        fillColor: Color(0xFF26314D),
                        border: OutlineInputBorder(borderSide: BorderSide.none),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 0,
                          child: Text('Correct: A', style: TextStyle(color: Colors.white))),
                        DropdownMenuItem(
                          value: 1,
                          child: Text('Correct: B', style: TextStyle(color: Colors.white))),
                        DropdownMenuItem(
                          value: 2,
                          child: Text('Correct: C', style: TextStyle(color: Colors.white))),
                        DropdownMenuItem(
                          value: 3,
                          child: Text('Correct: D', style: TextStyle(color: Colors.white))),
                      ],
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        setState(() {
                          _draftCorrectIndex = value;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (room.topic == 'mixed')
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _draftTopic,
                        style: const TextStyle(color: Colors.white),
                        dropdownColor: const Color(0xFF1E1E3A),
                        decoration: const InputDecoration(
                          filled: true,
                          fillColor: Color(0xFF26314D),
                          border:
                              OutlineInputBorder(borderSide: BorderSide.none),
                        ),
                        items: const [
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
                            _draftTopic = value;
                          });
                        },
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _busy ? null : () => _addRoomQuestion(room),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('ADD QUESTION TO ROOM'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFinishedSection({
    required OnlineRoomSnapshot room,
    required List<OnlinePlayerState> sorted,
  }) {
    final winnerNames = room.winnerNames.isEmpty
        ? sorted.take(1).map((p) => p.name).toList()
        : room.winnerNames;

    return Card(
      color: const Color(0xFF1E1E3A),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(child: Text('🏆', style: TextStyle(fontSize: 64))),
            const SizedBox(height: 8),
            Center(
              child: Text(
                winnerNames.length > 1
                    ? 'Winners: ${winnerNames.join(', ')}'
                    : 'Winner: ${winnerNames.first}',
                style: const TextStyle(
                  color: Colors.amberAccent,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 10),
            ...sorted.asMap().entries.map((entry) {
              final i = entry.key;
              final p = entry.value;
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      i == 0 ? Colors.amber : const Color(0xFF2A2A4A),
                  child: Text(
                    '#${i + 1}',
                    style: TextStyle(
                      color: i == 0 ? Colors.black : Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title:
                    Text(p.name, style: const TextStyle(color: Colors.white)),
                subtitle: Text(
                  'Correct ${p.correct} • Wrong ${p.wrong} • Time ${(p.totalTimeMs / 1000).round()}s',
                  style: const TextStyle(color: Colors.white54),
                ),
                trailing: Text(
                  '${p.score}',
                  style: const TextStyle(
                    color: Colors.amberAccent,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            }),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _leaveRoom,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3949AB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('BACK TO ONLINE LOBBY'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
