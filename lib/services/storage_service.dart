import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_constants.dart';
import '../models/player.dart';
import '../models/question.dart';

class StorageService {
  static Future<void> savePlayerName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(StorageKeys.name, name);
  }

  static Future<String> getPlayerName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(StorageKeys.name) ?? '';
  }

  static Future<void> savePlayerProfile(Player player) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(StorageKeys.profile, jsonEncode(player.toJson()));
  }

  static Future<Player?> getPlayerProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(StorageKeys.profile);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    final jsonMap = jsonDecode(raw) as Map<String, dynamic>;
    return Player.fromJson(jsonMap);
  }

  static Future<Map<String, bool>> getFloorProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(StorageKeys.floorProgress);
    if (raw == null || raw.isEmpty) {
      return {
        'quant': false,
        'logic': false,
        'english': false,
        'boss': false,
      };
    }
    final decoded = Map<String, dynamic>.from(jsonDecode(raw) as Map<dynamic, dynamic>);
    return decoded.map((k, v) => MapEntry(k, v == true));
  }

  static Future<void> markFloorCompleted(String floorId) async {
    final progress = await getFloorProgress();
    progress[floorId] = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(StorageKeys.floorProgress, jsonEncode(progress));
  }

  static Future<Map<String, dynamic>> getSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(StorageKeys.settings);
    if (raw == null || raw.isEmpty) {
      return {
        'sound': true,
        'music': true,
        'difficulty': 'normal',
      };
    }
    return Map<String, dynamic>.from(jsonDecode(raw) as Map<dynamic, dynamic>);
  }

  static Future<void> saveSettings(Map<String, dynamic> settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(StorageKeys.settings, jsonEncode(settings));
  }

  static Future<Map<String, Map<String, int>>> getTopicStats() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(StorageKeys.topicStats);
    if (raw == null || raw.isEmpty) {
      return {
        'quant': {'attempted': 0, 'correct': 0},
        'logic': {'attempted': 0, 'correct': 0},
        'english': {'attempted': 0, 'correct': 0},
      };
    }
    try {
      final decoded = Map<String, dynamic>.from(jsonDecode(raw) as Map<dynamic, dynamic>);
      return decoded.map((topic, value) {
        if (value is Map) {
          return MapEntry(
            topic,
            {
              'attempted': (value['attempted'] as num?)?.toInt() ?? 0,
              'correct': (value['correct'] as num?)?.toInt() ?? 0,
            },
          );
        }

        return MapEntry(
          topic,
          {
            'attempted': 0,
            'correct': 0,
          },
        );
      });
    } catch (_) {
      return {
        'quant': {'attempted': 0, 'correct': 0},
        'logic': {'attempted': 0, 'correct': 0},
        'english': {'attempted': 0, 'correct': 0},
      };
    }
  }

  static Future<void> recordQuestionResult({
    required String topic,
    required bool correct,
  }) async {
    final stats = await getTopicStats();
    final topicStats = stats[topic] ?? {'attempted': 0, 'correct': 0};
    topicStats['attempted'] = (topicStats['attempted'] ?? 0) + 1;
    if (correct) {
      topicStats['correct'] = (topicStats['correct'] ?? 0) + 1;
    }
    stats[topic] = topicStats;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(StorageKeys.topicStats, jsonEncode(stats));
  }

  static Future<void> addBattleHistory({
    required String floorTitle,
    required int score,
    required bool won,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(StorageKeys.history);
    final history = raw == null || raw.isEmpty
        ? <Map<String, dynamic>>[]
        : (jsonDecode(raw) as List<dynamic>)
        .map((e) => Map<String, dynamic>.from(e as Map<dynamic, dynamic>))
            .toList();

    history.insert(0, {
      'floorTitle': floorTitle,
      'score': score,
      'won': won,
      'date': DateTime.now().toIso8601String(),
    });

    if (history.length > 20) {
      history.removeRange(20, history.length);
    }

    await prefs.setString(StorageKeys.history, jsonEncode(history));
  }

  static Future<void> addMultiplayerHistory({
    required String topic,
    required int questionCount,
    required int secondsPerQuestion,
    required List<Map<String, dynamic>> standings,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(StorageKeys.multiplayerHistory);
    final history = raw == null || raw.isEmpty
        ? <Map<String, dynamic>>[]
        : (jsonDecode(raw) as List<dynamic>)
            .map((e) => Map<String, dynamic>.from(e as Map<dynamic, dynamic>))
            .toList();

    history.insert(0, {
      'topic': topic,
      'questionCount': questionCount,
      'secondsPerQuestion': secondsPerQuestion,
      'standings': standings,
      'date': DateTime.now().toIso8601String(),
    });

    if (history.length > 25) {
      history.removeRange(25, history.length);
    }

    await prefs.setString(StorageKeys.multiplayerHistory, jsonEncode(history));
  }

  static Future<List<Map<String, dynamic>>> getMultiplayerHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(StorageKeys.multiplayerHistory);
    if (raw == null || raw.isEmpty) {
      return <Map<String, dynamic>>[];
    }

    return (jsonDecode(raw) as List<dynamic>)
        .map((entry) => Map<String, dynamic>.from(entry as Map<dynamic, dynamic>))
        .toList();
  }

  static Future<List<Map<String, dynamic>>> getBattleHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(StorageKeys.history);
    if (raw == null || raw.isEmpty) {
      return <Map<String, dynamic>>[];
    }
    return (jsonDecode(raw) as List<dynamic>)
      .map((e) => Map<String, dynamic>.from(e as Map<dynamic, dynamic>))
        .toList();
  }

  static Future<void> saveScore(String playerName, int score) async {
    final prefs = await SharedPreferences.getInstance();
    final board = await getLeaderboard();
    board.add({'name': playerName, 'score': score, 'timestamp': DateTime.now().toIso8601String()});
    board.sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));
    final trimmed = board.take(10).toList();
    await prefs.setString(StorageKeys.leaderboard, jsonEncode(trimmed));
  }

  static Future<List<Map<String, dynamic>>> getLeaderboard() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(StorageKeys.leaderboard);
    if (raw == null || raw.isEmpty) {
      return <Map<String, dynamic>>[];
    }
    return (jsonDecode(raw) as List<dynamic>)
        .map(
          (entry) {
            final e = Map<String, dynamic>.from(entry as Map<dynamic, dynamic>);
            return {
              'name': e['name'] as String? ?? 'Unknown',
              'score': (e['score'] as num?)?.toInt() ?? 0,
              'timestamp': e['timestamp'] as String? ?? '',
            };
          },
        )
        .toList();
  }

  static Future<void> clearLeaderboard() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(StorageKeys.leaderboard);
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  static Future<List<Question>> getTeacherQuestions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(StorageKeys.teacherQuestions);
    if (raw == null || raw.isEmpty) {
      return <Question>[];
    }

    try {
      final list = (jsonDecode(raw) as List<dynamic>)
          .map((e) => Map<String, dynamic>.from(e as Map<dynamic, dynamic>))
          .map(Question.fromJson)
          .toList();
      return list;
    } catch (_) {
      return <Question>[];
    }
  }

  static Future<void> saveTeacherQuestions(List<Question> questions) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(questions.map((q) => q.toJson()).toList());
    await prefs.setString(StorageKeys.teacherQuestions, raw);
  }

  static Future<void> addTeacherQuestion(Question question) async {
    final current = await getTeacherQuestions();
    final alreadyExists = current.any((q) => q.id == question.id);
    if (!alreadyExists) {
      current.add(question);
      await saveTeacherQuestions(current);
    }
  }

  static Future<void> removeTeacherQuestion(String questionId) async {
    final current = await getTeacherQuestions();
    current.removeWhere((q) => q.id == questionId);
    await saveTeacherQuestions(current);
  }

  static Future<Set<String>> getDisabledQuestionIds() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(StorageKeys.disabledQuestionIds);
    if (raw == null) {
      return <String>{};
    }
    return raw.toSet();
  }

  static Future<void> saveDisabledQuestionIds(Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(StorageKeys.disabledQuestionIds, ids.toList());
  }

  static Future<void> setQuestionEnabled({
    required String questionId,
    required bool enabled,
  }) async {
    final disabled = await getDisabledQuestionIds();
    if (enabled) {
      disabled.remove(questionId);
    } else {
      disabled.add(questionId);
    }
    await saveDisabledQuestionIds(disabled);
  }
}