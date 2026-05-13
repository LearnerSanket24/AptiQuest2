import 'package:flutter/material.dart';

import '../services/storage_service.dart';
import '../widgets/app_gradient_background.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  Map<String, Map<String, int>> _stats = {};
  List<Map<String, dynamic>> _history = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final stats = await StorageService.getTopicStats();
    final history = await StorageService.getBattleHistory();
    if (!mounted) {
      return;
    }
    setState(() {
      _stats = stats;
      _history = history;
      _loading = false;
    });
  }

  double _accuracy(String topic) {
    final data = _stats[topic] ?? {'attempted': 0, 'correct': 0};
    final attempted = data['attempted'] ?? 0;
    if (attempted == 0) {
      return 0;
    }
    return (data['correct'] ?? 0) / attempted;
  }

  String _weakestTopic() {
    final topics = ['quant', 'logic', 'english'];
    topics.sort((a, b) => _accuracy(a).compareTo(_accuracy(b)));
    return topics.first;
  }

  Widget _topicBar(String topic, String label, Color color) {
    final acc = _accuracy(topic);
    final percent = (acc * 100).toStringAsFixed(0);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E3A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              Text('$percent%', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              minHeight: 12,
              value: acc,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF12314A),
        title: const Text('Performance Analytics', style: TextStyle(color: Colors.amberAccent)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: AppGradientBackground(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _topicBar('quant', 'Quantitative Aptitude', Colors.orange),
                  _topicBar('logic', 'Logical Reasoning', Colors.blue),
                  _topicBar('english', 'English', Colors.green),
                  const SizedBox(height: 8),
                  Card(
                    color: const Color(0xFF1E1E3A),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Text(
                        'Weakest topic: ${_weakestTopic().toUpperCase()} - Focus this area for better placement readiness.',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('Recent Battles', style: TextStyle(color: Colors.white70, fontSize: 16)),
                  const SizedBox(height: 8),
                  if (_history.isEmpty)
                    const Text('No battle history yet.', style: TextStyle(color: Colors.white38))
                  else
                    ..._history.take(8).map(
                      (entry) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Text(entry['won'] == true ? '🏆' : '💀'),
                        title: Text(entry['floorTitle'] as String? ?? 'Unknown', style: const TextStyle(color: Colors.white)),
                        subtitle: Text('Score: ${entry['score']}', style: const TextStyle(color: Colors.white54)),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
