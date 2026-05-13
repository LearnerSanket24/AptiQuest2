import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../widgets/app_gradient_background.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  List<Map<String, dynamic>> _leaderboard = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final data = await StorageService.getLeaderboard();
    setState(() {
      _leaderboard = data;
      _isLoading = false;
    });
  }

  String _medal(int index) {
    if (index == 0) return '🥇';
    if (index == 1) return '🥈';
    if (index == 2) return '🥉';
    return '${index + 1}.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF12314A),
        title: const Text('🏆 Leaderboard',
            style: TextStyle(color: Colors.amberAccent)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white38),
            onPressed: () async {
              await StorageService.clearLeaderboard();
              _loadData();
            },
          ),
        ],
      ),
      body: AppGradientBackground(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _leaderboard.isEmpty
                ? const Center(
                    child: Text('No scores yet!\nGo battle some monsters 🗡',
                        style: TextStyle(color: Colors.white38, fontSize: 16),
                        textAlign: TextAlign.center))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _leaderboard.length,
                    itemBuilder: (context, index) {
                      final entry = _leaderboard[index];
                      return Card(
                        color: const Color(0xFF1E1E3A),
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          leading: Text(_medal(index),
                              style: const TextStyle(fontSize: 28)),
                          title: Text(entry['name'] as String,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                          trailing: Text('${entry['score'] ?? 0} XP',
                              style: const TextStyle(
                                  color: Colors.amberAccent,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold)),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}