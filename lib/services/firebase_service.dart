import '../models/question.dart';

class FirebaseService {
  Future<List<Question>> loadQuestionsFromCloud({String? topic}) async {
    // Placeholder for Phase 3 Firebase integration.
    return <Question>[];
  }

  Future<void> syncScore({required String name, required int score}) async {
    // Placeholder for Phase 3 Firebase integration.
  }
}
