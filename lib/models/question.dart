class Question {
  final String id;
  final String questionText;
  final List<String> options;
  final int correctIndex;
  final String topic;
  final String difficulty;
  final String explanation;

  Question({
    String? id,
    required this.questionText,
    required this.options,
    required this.correctIndex,
    String? topic,
    String? category,
    this.difficulty = 'medium',
    this.explanation = '',
  })  : topic = topic ?? category ?? 'general',
        id = id ?? _buildStableId(
          topic: topic ?? category ?? 'general',
          questionText: questionText,
          options: options,
          correctIndex: correctIndex,
        );

  String get category => topic;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'questionText': questionText,
      'options': options,
      'correctIndex': correctIndex,
      'topic': topic,
      'difficulty': difficulty,
      'explanation': explanation,
    };
  }

  factory Question.fromJson(Map<String, dynamic> json) {
    final options = (json['options'] as List<dynamic>? ?? <dynamic>[])
        .map((e) => '$e')
        .toList();

    final topic = (json['topic'] as String?) ?? (json['category'] as String?) ?? 'general';
    final questionText = json['questionText'] as String? ?? '';
    final correctIndex = (json['correctIndex'] as num?)?.toInt() ?? 0;

    return Question(
      id: json['id'] as String?,
      questionText: questionText,
      options: options,
      correctIndex: correctIndex,
      topic: topic,
      difficulty: json['difficulty'] as String? ?? 'medium',
      explanation: json['explanation'] as String? ?? '',
    );
  }

  static String _buildStableId({
    required String topic,
    required String questionText,
    required List<String> options,
    required int correctIndex,
  }) {
    final normalizedQuestion = questionText.trim().toLowerCase();
    final normalizedTopic = topic.trim().toLowerCase();
    final normalizedOptions = options
        .map((o) => o.trim().toLowerCase())
        .join('|');
    return '$normalizedTopic::$normalizedQuestion::$normalizedOptions::$correctIndex';
  }
}