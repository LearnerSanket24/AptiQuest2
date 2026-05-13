import 'package:flutter/material.dart';

import '../models/question.dart';
import '../services/question_service.dart';
import '../services/storage_service.dart';
import '../widgets/app_gradient_background.dart';

class TeacherQuestionStudioScreen extends StatefulWidget {
  const TeacherQuestionStudioScreen({super.key});

  @override
  State<TeacherQuestionStudioScreen> createState() =>
      _TeacherQuestionStudioScreenState();
}

class _TeacherQuestionStudioScreenState
    extends State<TeacherQuestionStudioScreen> {
  final QuestionService _questionService = LocalQuestionService();

  final TextEditingController _questionController = TextEditingController();
  final TextEditingController _optionAController = TextEditingController();
  final TextEditingController _optionBController = TextEditingController();
  final TextEditingController _optionCController = TextEditingController();
  final TextEditingController _optionDController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  bool _loading = true;
  bool _saving = false;

  String _topic = 'quant';
  int _correctIndex = 0;
  String _filterTopic = 'all';

  List<Question> _allQuestions = <Question>[];
  Set<String> _teacherQuestionIds = <String>{};
  Set<String> _disabledIds = <String>{};

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _questionController.dispose();
    _optionAController.dispose();
    _optionBController.dispose();
    _optionCController.dispose();
    _optionDController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final teacher = await _questionService.getTeacherQuestions();
    final all = await _questionService.getAllQuestions(includeDisabled: true);
    final disabled = await StorageService.getDisabledQuestionIds();

    if (!mounted) {
      return;
    }

    setState(() {
      _teacherQuestionIds = teacher.map((q) => q.id).toSet();
      _allQuestions = all;
      _disabledIds = disabled;
      _loading = false;
    });
  }

  Future<void> _addQuestion() async {
    if (_saving) {
      return;
    }

    final questionText = _questionController.text.trim();
    final options = <String>[
      _optionAController.text.trim(),
      _optionBController.text.trim(),
      _optionCController.text.trim(),
      _optionDController.text.trim(),
    ];

    if (questionText.length < 10) {
      _showSnack('Question should be at least 10 characters.');
      return;
    }
    if (options.any((o) => o.isEmpty)) {
      _showSnack('Please fill all 4 options.');
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      await _questionService.addTeacherQuestion(
        Question(
          questionText: questionText,
          options: options,
          correctIndex: _correctIndex,
          topic: _topic,
        ),
      );

      _questionController.clear();
      _optionAController.clear();
      _optionBController.clear();
      _optionCController.clear();
      _optionDController.clear();
      _correctIndex = 0;

      await _refresh();
      _showSnack('Question added to teacher bank.');
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _removeTeacherQuestion(Question question) async {
    await _questionService.removeTeacherQuestion(question.id);
    await _refresh();
    _showSnack('Teacher question removed.');
  }

  Future<void> _toggleQuestionEnabled(Question question, bool enabled) async {
    await _questionService.setQuestionEnabled(
        questionId: question.id, enabled: enabled);
    await _refresh();
  }

  List<Question> get _visibleQuestions {
    final search = _searchController.text.trim().toLowerCase();
    return _allQuestions.where((q) {
      final matchesTopic = _filterTopic == 'all' || q.topic == _filterTopic;
      if (!matchesTopic) {
        return false;
      }
      if (search.isEmpty) {
        return true;
      }
      return q.questionText.toLowerCase().contains(search) ||
          q.options.any((o) => o.toLowerCase().contains(search));
    }).toList();
  }

  int get _activeCount =>
      _allQuestions.where((q) => !_disabledIds.contains(q.id)).length;

  int get _teacherCount => _teacherQuestionIds.length;

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
      appBar: AppBar(
        title: const Text('Teacher Question Studio'),
      ),
      body: AppGradientBackground(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildStatsCard(),
                    const SizedBox(height: 12),
                    _buildAddQuestionCard(),
                    const SizedBox(height: 12),
                    _buildFilterBar(),
                    const SizedBox(height: 10),
                    ..._visibleQuestions.map(_buildQuestionTile),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildStatsCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0E2738),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2C8FBF), width: 1),
      ),
      child: Row(
        children: [
          _statChip(
              'Total', '${_allQuestions.length}', const Color(0xFF81D4FA)),
          const SizedBox(width: 8),
          _statChip('Active', '$_activeCount', const Color(0xFFA5D6A7)),
          const SizedBox(width: 8),
          _statChip('Teacher', '$_teacherCount', const Color(0xFFFFE082)),
        ],
      ),
    );
  }

  Widget _statChip(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF163750),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    color: color, fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildAddQuestionCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF113047),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Add Question',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _questionController,
            style: const TextStyle(color: Colors.white),
            minLines: 2,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Write your question',
              hintStyle: TextStyle(color: Colors.white38),
              filled: true,
              fillColor: Color(0xFF1E4763),
              border: OutlineInputBorder(borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _optionField(_optionAController, 'Option A')),
              const SizedBox(width: 8),
              Expanded(child: _optionField(_optionBController, 'Option B')),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _optionField(_optionCController, 'Option C')),
              const SizedBox(width: 8),
              Expanded(child: _optionField(_optionDController, 'Option D')),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _topic,
                  style: const TextStyle(color: Colors.white),
                  dropdownColor: const Color(0xFF1E4763),
                  decoration: const InputDecoration(
                    filled: true,
                    fillColor: Color(0xFF1E4763),
                    border: OutlineInputBorder(borderSide: BorderSide.none),
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
                      _topic = value;
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: _correctIndex,
                  style: const TextStyle(color: Colors.white),
                  dropdownColor: const Color(0xFF1E4763),
                  decoration: const InputDecoration(
                    filled: true,
                    fillColor: Color(0xFF1E4763),
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
                      _correctIndex = value;
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _addQuestion,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00A896),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: const Icon(Icons.add),
              label: const Text('ADD TO QUESTION BANK'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _optionField(TextEditingController controller, String hint) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38),
        filled: true,
        fillColor: const Color(0xFF1E4763),
        border: const OutlineInputBorder(borderSide: BorderSide.none),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF10324A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white),
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'Search question text or options',
              hintStyle: TextStyle(color: Colors.white38),
              filled: true,
              fillColor: Color(0xFF1E4763),
              border: OutlineInputBorder(borderSide: BorderSide.none),
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _filterTopic,
            style: const TextStyle(color: Colors.white),
            dropdownColor: const Color(0xFF1E4763),
            decoration: const InputDecoration(
              filled: true,
              fillColor: Color(0xFF1E4763),
              border: OutlineInputBorder(borderSide: BorderSide.none),
            ),
            items: const [
              DropdownMenuItem(
                value: 'all',
                child: Text('All topics', style: TextStyle(color: Colors.white))),
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
                _filterTopic = value;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionTile(Question question) {
    final teacherOwned = _teacherQuestionIds.contains(question.id);
    final enabled = !_disabledIds.contains(question.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F2C41),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: enabled ? const Color(0xFF2AA876) : const Color(0xFF8A8A8A),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  question.questionText,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: teacherOwned
                      ? const Color(0xFFFFB74D)
                      : const Color(0xFF4FC3F7),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  teacherOwned ? 'Teacher' : 'Built-in',
                  style: const TextStyle(
                      color: Colors.black,
                      fontSize: 11,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Topic: ${question.topic.toUpperCase()}  •  Correct: ${question.options[question.correctIndex]}',
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: enabled,
                  onChanged: (value) => _toggleQuestionEnabled(question, value),
                  title: const Text('Include in gameplay',
                      style: TextStyle(color: Colors.white70, fontSize: 13)),
                ),
              ),
              if (teacherOwned)
                IconButton(
                  onPressed: () => _removeTeacherQuestion(question),
                  icon:
                      const Icon(Icons.delete_forever, color: Colors.redAccent),
                  tooltip: 'Delete teacher question',
                ),
            ],
          ),
        ],
      ),
    );
  }
}
