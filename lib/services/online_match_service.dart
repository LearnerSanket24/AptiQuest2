import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../config/app_constants.dart';
import '../data/questions.dart';
import '../firebase_options.dart';
import '../models/question.dart';
import 'question_service.dart';

List<Question> _decodeRoomQuestions(Map<String, dynamic> data) {
  final dynamicList = data['roomQuestions'] as List<dynamic>?;
  if (dynamicList != null && dynamicList.isNotEmpty) {
    final parsed = dynamicList
        .whereType<Map<dynamic, dynamic>>()
        .map((e) => Map<String, dynamic>.from(e))
        .map(Question.fromJson)
        .toList();
    if (parsed.isNotEmpty) {
      return parsed;
    }
  }

  final indexes = (data['questions'] as List<dynamic>? ?? <dynamic>[])
      .map((e) => (e as num?)?.toInt() ?? -1)
      .toList();

  if (indexes.isEmpty) {
    return <Question>[];
  }

  return indexes
      .where((i) => i >= 0 && i < allQuestions.length)
      .map((i) => allQuestions[i])
      .toList();
}

class OnlineJoinResult {
  const OnlineJoinResult({
    required this.roomId,
    required this.playerId,
  });

  final String roomId;
  final String playerId;
}

class OnlinePlayerState {
  const OnlinePlayerState({
    required this.playerId,
    required this.name,
    required this.ready,
    required this.score,
    required this.correct,
    required this.wrong,
    required this.totalTimeMs,
    required this.lastAnsweredIndex,
    required this.currentQuestion,
    required this.isFinished,
  });

  final String playerId;
  final String name;
  final bool ready;
  final int score;
  final int correct;
  final int wrong;
  final int totalTimeMs;
  final int lastAnsweredIndex;
  final int currentQuestion;
  final bool isFinished;

  factory OnlinePlayerState.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final currentQuestion = (data['currentQuestion'] as num?)?.toInt() ?? 0;
    final isFinished = data['isFinished'] == true;
    final explicitLast = (data['lastAnsweredIndex'] as num?)?.toInt();

    return OnlinePlayerState(
      playerId: (data['uid'] as String?) ?? doc.id,
      name: data['name'] as String? ?? 'Unknown',
      ready: data['ready'] == true,
      score: (data['score'] as num?)?.toInt() ?? 0,
      correct: (data['correct'] as num?)?.toInt() ?? 0,
      wrong: (data['wrong'] as num?)?.toInt() ?? 0,
      totalTimeMs: (data['totalTimeMs'] as num?)?.toInt() ?? 0,
      lastAnsweredIndex: explicitLast ?? (currentQuestion - 1),
      currentQuestion: currentQuestion,
      isFinished: isFinished,
    );
  }
}

class OnlineRoomSnapshot {
  const OnlineRoomSnapshot({
    required this.roomId,
    required this.hostPlayerId,
    required this.topic,
    required this.questionCount,
    required this.secondsPerQuestion,
    required this.status,
    required this.currentQuestionIndex,
    required this.questionIndexes,
    required this.roomQuestions,
    required this.winnerNames,
    required this.roundStartedAt,
  });

  final String roomId;
  final String hostPlayerId;
  final String topic;
  final int questionCount;
  final int secondsPerQuestion;
  final String status;
  final int currentQuestionIndex;
  final List<int> questionIndexes;
  final List<Question> roomQuestions;
  final List<String> winnerNames;
  final DateTime? roundStartedAt;

  bool get isLobby => status == 'waiting';
  bool get isPlaying => status == 'ongoing';
  bool get isFinished => status == 'finished';

  factory OnlineRoomSnapshot.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final roundStartedTs = data['roundStartedAt'] as Timestamp?;
    final questions = (data['questions'] as List<dynamic>? ?? <dynamic>[])
        .map((e) => (e as num).toInt())
        .toList();
    final roomQuestions = _decodeRoomQuestions(data);

    return OnlineRoomSnapshot(
      roomId: doc.id,
      hostPlayerId:
          data['hostId'] as String? ?? data['hostPlayerId'] as String? ?? '',
      topic: data['topic'] as String? ?? 'mixed',
      questionCount: (data['questionCount'] as num?)?.toInt() ??
          (roomQuestions.isNotEmpty ? roomQuestions.length : questions.length),
      secondsPerQuestion: (data['secondsPerQuestion'] as num?)?.toInt() ?? 20,
      status: data['status'] as String? ?? 'waiting',
      currentQuestionIndex: (data['currentQuestion'] as num?)?.toInt() ??
          (data['currentQuestionIndex'] as num?)?.toInt() ??
          0,
      questionIndexes: questions,
      roomQuestions: roomQuestions,
      winnerNames: (data['winnerNames'] as List<dynamic>? ?? <dynamic>[])
          .map((e) => '$e')
          .toList(),
      roundStartedAt: roundStartedTs?.toDate(),
    );
  }
}

class OnlineMatchService {
  OnlineMatchService._();

  static final OnlineMatchService instance = OnlineMatchService._();

  final Random _random = Random();
  final QuestionService _questionService = LocalQuestionService();
  String? _lastInitError;

  String? get lastInitError => _lastInitError;

  CollectionReference<Map<String, dynamic>> get _rooms =>
      FirebaseFirestore.instance.collection('matches');

  Future<bool> ensureFirebaseReady() async {
    try {
      _lastInitError = null;

      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }

      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInAnonymously();
      }

      return true;
    } on UnsupportedError catch (e) {
      _lastInitError = '$e';
      return false;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'operation-not-allowed') {
        _lastInitError =
            'Anonymous sign-in is disabled in Firebase Auth. Enable Anonymous provider in Firebase Console > Authentication > Sign-in method.';
      } else {
        _lastInitError =
            'Firebase Auth error (${e.code}): ${e.message ?? 'Unknown error'}';
      }
      return false;
    } on FirebaseException catch (e) {
      _lastInitError =
          'Firebase error (${e.code}): ${e.message ?? 'Unknown error'}';
      return false;
    } catch (e) {
      _lastInitError = 'Firebase setup failed: $e';
      debugPrint(_lastInitError);
      return false;
    }
  }

  Future<String> _ensureSignedInUid() async {
    final ready = await ensureFirebaseReady();
    if (!ready) {
      throw Exception(_lastInitError ?? 'Firebase is not ready');
    }

    final user = FirebaseAuth.instance.currentUser;

    final uid = user?.uid;
    if (uid == null || uid.isEmpty) {
      throw Exception('Unable to sign in anonymously');
    }

    return uid;
  }

  Future<OnlineJoinResult> createRoom({
    required String hostName,
    required String topic,
    required int questionCount,
    required int secondsPerQuestion,
    List<Question>? seedQuestions,
  }) async {
    final uid = await _ensureSignedInUid();
    final roomId = await _generateUniqueRoomCode();
    final playerId = uid;

    final pickedQuestions = seedQuestions != null && seedQuestions.isNotEmpty
        ? seedQuestions
        : await _pickRoomQuestions(topic: topic, count: questionCount);

    final questionIndexes = pickedQuestions
        .map((q) => allQuestions.indexWhere((base) => base.id == q.id))
        .toList();

    final roomRef = _rooms.doc(roomId);
    final playerRef = roomRef.collection('players').doc(playerId);

    final batch = FirebaseFirestore.instance.batch();
    batch.set(roomRef, {
      'matchId': roomId,
      'topic': topic,
      'questionCount': pickedQuestions.length,
      'secondsPerQuestion': secondsPerQuestion,
      'status': 'waiting',
      'hostId': playerId,
      'hostName': hostName,
      'currentQuestion': 0,
      'questions': questionIndexes,
      'roomQuestions': pickedQuestions.map((q) => q.toJson()).toList(),
      'winnerNames': <String>[],
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.set(playerRef, {
      'uid': playerId,
      'name': hostName,
      'ready': true,
      'score': 0,
      'correct': 0,
      'wrong': 0,
      'currentQuestion': 0,
      'isFinished': false,
      'totalTimeMs': 0,
      'lastAnsweredIndex': -1,
      'joinedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();

    return OnlineJoinResult(roomId: roomId, playerId: playerId);
  }

  Future<OnlineJoinResult> joinRoom({
    required String roomId,
    required String name,
  }) async {
    final uid = await _ensureSignedInUid();
    final normalizedRoom = roomId.trim().toUpperCase();
    final roomRef = _rooms.doc(normalizedRoom);
    final roomSnap = await roomRef.get();

    if (!roomSnap.exists) {
      throw Exception('Room not found');
    }

    final room = OnlineRoomSnapshot.fromDoc(roomSnap);
    if (!room.isLobby) {
      throw Exception('Room already started');
    }

    await roomRef.collection('players').doc(uid).set({
      'uid': uid,
      'name': name,
      'ready': false,
      'score': 0,
      'correct': 0,
      'wrong': 0,
      'currentQuestion': 0,
      'isFinished': false,
      'totalTimeMs': 0,
      'lastAnsweredIndex': -1,
      'joinedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return OnlineJoinResult(roomId: normalizedRoom, playerId: uid);
  }

  Stream<OnlineRoomSnapshot?> watchRoom(String roomId) {
    return _rooms.doc(roomId).snapshots().map((doc) {
      if (!doc.exists) {
        return null;
      }
      return OnlineRoomSnapshot.fromDoc(doc);
    });
  }

  Future<OnlineRoomSnapshot?> getRoom(String roomId) async {
    final doc = await _rooms.doc(roomId).get();
    if (!doc.exists) {
      return null;
    }
    return OnlineRoomSnapshot.fromDoc(doc);
  }

  Stream<List<OnlinePlayerState>> watchPlayers(String roomId) {
    return _rooms
        .doc(roomId)
        .collection('players')
        .orderBy('joinedAt')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map(OnlinePlayerState.fromDoc).toList());
  }

  Future<List<OnlinePlayerState>> getPlayers(String roomId) async {
    final snapshot = await _rooms
        .doc(roomId)
        .collection('players')
        .orderBy('joinedAt')
        .get();
    return snapshot.docs.map(OnlinePlayerState.fromDoc).toList();
  }

  Future<void> setReady({
    required String roomId,
    required String playerId,
    required bool ready,
  }) {
    return _rooms.doc(roomId).collection('players').doc(playerId).set({
      'ready': ready,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> startMatch({
    required String roomId,
    required String hostPlayerId,
  }) async {
    final roomRef = _rooms.doc(roomId);

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final roomSnap = await tx.get(roomRef);
      if (!roomSnap.exists) {
        throw Exception('Room not found');
      }

      final room = OnlineRoomSnapshot.fromDoc(roomSnap);
      if (room.hostPlayerId != hostPlayerId) {
        throw Exception('Only host can start match');
      }

      if (room.roomQuestions.length < 3) {
        throw Exception('Add at least 3 questions before starting match');
      }

      final playersQuery = await roomRef.collection('players').get();
      if (playersQuery.docs.length < 2) {
        throw Exception('At least 2 players required');
      }

      final allReady =
          playersQuery.docs.every((doc) => doc.data()['ready'] == true);
      if (!allReady) {
        throw Exception('All players must be ready');
      }

      tx.set(
          roomRef,
          {
            'status': 'ongoing',
            'currentQuestion': 0,
            'questionCount': room.roomQuestions.length,
            'winnerNames': <String>[],
            'roundStartedAt': FieldValue.serverTimestamp(),
            'startedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true));

      for (final player in playersQuery.docs) {
        tx.set(
            player.reference,
            {
              'uid': player.id,
              'score': 0,
              'correct': 0,
              'wrong': 0,
              'currentQuestion': 0,
              'isFinished': false,
              'totalTimeMs': 0,
              'lastAnsweredIndex': -1,
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true));
      }
    });
  }

  Future<bool> submitAnswer({
    required String roomId,
    required String playerId,
    required int questionIndex,
    required int selectedIndex,
    required int timeSpentMs,
  }) async {
    final roomRef = _rooms.doc(roomId);
    final playerRef = roomRef.collection('players').doc(playerId);

    final didAcceptSubmission =
        await FirebaseFirestore.instance.runTransaction<bool>((tx) async {
      final roomSnap = await tx.get(roomRef);
      final playerSnap = await tx.get(playerRef);

      if (!roomSnap.exists || !playerSnap.exists) {
        throw Exception('Room/player not found');
      }

      final room = OnlineRoomSnapshot.fromDoc(roomSnap);
      final player = OnlinePlayerState.fromDoc(playerSnap);

      if (!room.isPlaying) {
        return false;
      }

      final activeQuestionIndex = room.currentQuestionIndex;
      if (questionIndex != activeQuestionIndex) {
        return false;
      }

      if (player.isFinished ||
          player.currentQuestion > activeQuestionIndex ||
          player.lastAnsweredIndex >= activeQuestionIndex) {
        return false;
      }

      if (activeQuestionIndex < 0 ||
          activeQuestionIndex >= room.roomQuestions.length) {
        return false;
      }

      final correctAnswerIndex =
          room.roomQuestions[activeQuestionIndex].correctIndex;
        final normalizedSelected = selectedIndex < 0 ? -1 : selectedIndex;
        final correct = normalizedSelected == correctAnswerIndex;
      final nextQuestion = activeQuestionIndex + 1;
      final finished = nextQuestion >= room.questionCount;

      tx.set(
          playerRef,
          {
            'uid': player.playerId,
            'score':
                player.score + (correct ? BattleConstants.xpPerCorrect : 0),
            'correct': player.correct + (correct ? 1 : 0),
            'wrong': player.wrong + (correct ? 0 : 1),
            'totalTimeMs': player.totalTimeMs + max(0, timeSpentMs),
            'currentQuestion': nextQuestion,
            'isFinished': finished,
            'lastAnsweredIndex': activeQuestionIndex,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true));

      return true;
    });

    if (didAcceptSubmission) {
      await _recomputeRoomProgress(roomId);
    }

    return didAcceptSubmission;
  }

  Future<void> syncRoomProgressIfHost({
    required String roomId,
    required String playerId,
  }) async {
    final room = await getRoom(roomId);
    if (room == null || room.hostPlayerId != playerId || !room.isPlaying) {
      return;
    }

    await _recomputeRoomProgress(roomId);
  }

  Future<void> forceAdvanceQuestion({
    required String roomId,
    required String hostPlayerId,
  }) async {
    final roomRef = _rooms.doc(roomId);
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final roomSnap = await tx.get(roomRef);
      if (!roomSnap.exists) {
        return;
      }

      final room = OnlineRoomSnapshot.fromDoc(roomSnap);
      if (room.hostPlayerId != hostPlayerId || !room.isPlaying) {
        return;
      }

      if (room.currentQuestionIndex + 1 >= room.questionCount) {
        tx.set(
            roomRef,
            {
              'status': 'finished',
              'updatedAt': FieldValue.serverTimestamp(),
              'finishedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true));
        return;
      }

      tx.set(
          roomRef,
          {
            'currentQuestion': room.currentQuestionIndex + 1,
            'roundStartedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true));
    });

    await _recomputeRoomProgress(roomId);
  }

  Future<void> forceFinish({
    required String roomId,
    required String hostPlayerId,
  }) async {
    final roomRef = _rooms.doc(roomId);

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final roomSnap = await tx.get(roomRef);
      if (!roomSnap.exists) {
        return;
      }

      final room = OnlineRoomSnapshot.fromDoc(roomSnap);
      if (room.hostPlayerId != hostPlayerId) {
        return;
      }

      tx.set(
          roomRef,
          {
            'status': 'finished',
            'updatedAt': FieldValue.serverTimestamp(),
            'finishedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true));
    });

    await _recomputeRoomProgress(roomId);
  }

  Future<void> addRoomQuestion({
    required String roomId,
    required String hostPlayerId,
    required Question question,
  }) async {
    final roomRef = _rooms.doc(roomId);
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final roomSnap = await tx.get(roomRef);
      if (!roomSnap.exists) {
        throw Exception('Room not found');
      }

      final room = OnlineRoomSnapshot.fromDoc(roomSnap);
      if (room.hostPlayerId != hostPlayerId) {
        throw Exception('Only host can edit room questions');
      }
      if (!room.isLobby) {
        throw Exception('Question list can be edited only in lobby');
      }

      final updated = List<Question>.from(room.roomQuestions);
      final exists = updated.any((q) => q.id == question.id);
      if (!exists) {
        updated.add(question);
      }

      tx.set(
          roomRef,
          {
            'roomQuestions': updated.map((q) => q.toJson()).toList(),
            'questionCount': updated.length,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true));
    });
  }

  Future<void> removeRoomQuestion({
    required String roomId,
    required String hostPlayerId,
    required String questionId,
  }) async {
    final roomRef = _rooms.doc(roomId);
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final roomSnap = await tx.get(roomRef);
      if (!roomSnap.exists) {
        throw Exception('Room not found');
      }

      final room = OnlineRoomSnapshot.fromDoc(roomSnap);
      if (room.hostPlayerId != hostPlayerId) {
        throw Exception('Only host can edit room questions');
      }
      if (!room.isLobby) {
        throw Exception('Question list can be edited only in lobby');
      }

      final updated = List<Question>.from(room.roomQuestions)
        ..removeWhere((q) => q.id == questionId);

      if (updated.length < 3) {
        throw Exception('Room needs at least 3 questions');
      }

      tx.set(
          roomRef,
          {
            'roomQuestions': updated.map((q) => q.toJson()).toList(),
            'questionCount': updated.length,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true));
    });
  }

  Future<void> _recomputeRoomProgress(String roomId) async {
    final roomRef = _rooms.doc(roomId);
    final roomSnap = await roomRef.get();
    if (!roomSnap.exists) {
      return;
    }

    final room = OnlineRoomSnapshot.fromDoc(roomSnap);
    final playerSnaps = await roomRef.collection('players').get();
    final players = playerSnaps.docs.map(OnlinePlayerState.fromDoc).toList();

    if (players.isEmpty) {
      return;
    }

    if (room.isPlaying) {
      final currentQ = room.currentQuestionIndex;
      final everyoneFinished = players.every((p) => p.isFinished);
      final everyoneAnsweredCurrent =
          players.every((p) => p.isFinished || p.currentQuestion > currentQ);

      if (everyoneFinished || everyoneAnsweredCurrent) {
        if (everyoneFinished || currentQ + 1 >= room.questionCount) {
          final winnerNames = _computeWinners(players);
          await roomRef.set({
            'status': 'finished',
            'winnerNames': winnerNames,
            'updatedAt': FieldValue.serverTimestamp(),
            'finishedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } else {
          await roomRef.set({
            'currentQuestion': currentQ + 1,
            'updatedAt': FieldValue.serverTimestamp(),
            'roundStartedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      }
      return;
    }

    if (room.isFinished) {
      final winnerNames = _computeWinners(players);
      await roomRef.set({
        'winnerNames': winnerNames,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  List<String> _computeWinners(List<OnlinePlayerState> players) {
    final ordered = List<OnlinePlayerState>.from(players)
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

    if (ordered.isEmpty) {
      return <String>[];
    }

    final top = ordered.first;
    return ordered
        .where((p) => p.score == top.score && p.correct == top.correct)
        .map((p) => p.name)
        .toList();
  }

  Future<List<Question>> _pickRoomQuestions({
    required String topic,
    required int count,
  }) async {
    final pool = await _questionService.getQuestionsByTopic(topic);

    if (pool.isEmpty) {
      throw Exception('No questions available for topic $topic');
    }

    final result = <Question>[];
    while (result.length < count) {
      pool.shuffle(_random);
      result.addAll(pool);
    }

    return result.take(count).toList();
  }

  Future<String> _generateUniqueRoomCode() async {
    for (var i = 0; i < 25; i++) {
      final code = _newRoomCode();
      final snap = await _rooms.doc(code).get();
      if (!snap.exists) {
        return code;
      }
    }
    return '${_newRoomCode()}${_random.nextInt(9)}';
  }

  String _newRoomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    return List<String>.generate(
      6,
      (_) => chars[_random.nextInt(chars.length)],
    ).join();
  }
}
