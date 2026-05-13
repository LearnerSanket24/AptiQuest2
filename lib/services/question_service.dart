import '../data/questions.dart';
import '../models/question.dart';
import 'storage_service.dart';

abstract class QuestionService {
  Future<List<Question>> getAllQuestions({
    bool includeDisabled,
  });

  Future<List<Question>> getQuestionsByTopic(
    String topic, {
    bool includeDisabled,
  });

  Future<List<Question>> getBossQuestions({
    bool includeDisabled,
  });

  Future<List<Question>> getTeacherQuestions();
  Future<void> addTeacherQuestion(Question question);
  Future<void> removeTeacherQuestion(String questionId);
  Future<void> setQuestionEnabled({
    required String questionId,
    required bool enabled,
  });
}

class LocalQuestionService implements QuestionService {
  @override
  Future<List<Question>> getAllQuestions({
    bool includeDisabled = false,
  }) async {
    final teacher = await StorageService.getTeacherQuestions();
    final disabled = includeDisabled
        ? <String>{}
        : await StorageService.getDisabledQuestionIds();

    final merged = <Question>[
      ...allQuestions,
      ...teacher,
    ];

    if (includeDisabled) {
      return merged;
    }

    return merged.where((q) => !disabled.contains(q.id)).toList();
  }

  @override
  Future<List<Question>> getQuestionsByTopic(
    String topic, {
    bool includeDisabled = false,
  }) async {
    final list = await getAllQuestions(includeDisabled: includeDisabled);
    if (topic == 'mixed') {
      return list;
    }
    return list.where((q) => q.topic == topic).toList();
  }

  @override
  Future<List<Question>> getBossQuestions({
    bool includeDisabled = false,
  }) async {
    final all = await getAllQuestions(includeDisabled: includeDisabled);
    if (all.isEmpty) {
      return <Question>[];
    }

    final source = List<Question>.from(all);
    final result = <Question>[];
    while (result.length < 30) {
      source.shuffle();
      result.addAll(source);
    }
    return result.take(30).toList();
  }

  @override
  Future<List<Question>> getTeacherQuestions() {
    return StorageService.getTeacherQuestions();
  }

  @override
  Future<void> addTeacherQuestion(Question question) {
    return StorageService.addTeacherQuestion(question);
  }

  @override
  Future<void> removeTeacherQuestion(String questionId) {
    return StorageService.removeTeacherQuestion(questionId);
  }

  @override
  Future<void> setQuestionEnabled({
    required String questionId,
    required bool enabled,
  }) {
    return StorageService.setQuestionEnabled(questionId: questionId, enabled: enabled);
  }
}
