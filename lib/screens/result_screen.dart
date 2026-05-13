import 'package:flutter/material.dart';

import '../models/player.dart';
import '../services/storage_service.dart';
import '../widgets/app_gradient_background.dart';
import 'dungeon_map.dart';
import 'home_screen.dart';

class ResultScreen extends StatefulWidget {
  final Player player;
  final int score;
  final int coinsEarned;
  final bool won;
  final String floorTitle;
  final String floorId;
  final int correctCount;
  final int wrongCount;
  final String? bossScore;
  final Map<String, String>? topicBreakdown;

  const ResultScreen({
    super.key,
    required this.player,
    required this.score,
    required this.coinsEarned,
    required this.won,
    required this.floorTitle,
    required this.floorId,
    required this.correctCount,
    required this.wrongCount,
    this.bossScore,
    this.topicBreakdown,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  @override
  void initState() {
    super.initState();
    _persistResult();
  }

  Future<void> _persistResult() async {
    await StorageService.saveScore(widget.player.name, widget.score);
    await StorageService.addBattleHistory(
      floorTitle: widget.floorTitle,
      score: widget.score,
      won: widget.won,
    );

    if (widget.won) {
      await StorageService.markFloorCompleted(widget.floorId);
      widget.player.recoverAfterFloor();
    }
    await StorageService.savePlayerProfile(widget.player);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      body: AppGradientBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(widget.won ? '🏆' : '💀',
                    style: const TextStyle(fontSize: 80)),
                const SizedBox(height: 16),
                Text(
                  widget.won ? 'VICTORY!' : 'DEFEATED!',
                  style: TextStyle(
                    color: widget.won ? Colors.amberAccent : Colors.red,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(widget.floorTitle,
                    style:
                    const TextStyle(color: Colors.white54, fontSize: 14)),
                const SizedBox(height: 32),

                // Stats
                Card(
                  color: const Color(0xFF1E1E3A),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        _row('🧙 Player', widget.player.name),
                        const Divider(color: Colors.white12),
                        _row('⭐ XP', '${widget.score}'),
                        _row('🪙 Coins Earned', '${widget.coinsEarned}'),
                        _row('🪙 Total Coins', '${widget.player.coins}'),
                        _row('📈 Level', '${widget.player.level}'),
                        _row('✅ Correct', '${widget.correctCount}'),
                        _row('❌ Wrong', '${widget.wrongCount}'),
                        if (widget.bossScore != null)
                          _row('🎯 Boss Score', widget.bossScore!),
                        if (widget.topicBreakdown != null) ...[
                          const Divider(color: Colors.white12),
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text('Topic Breakdown',
                                style: TextStyle(color: Colors.white70)),
                          ),
                          const SizedBox(height: 8),
                          ...widget.topicBreakdown!.entries.map(
                            (entry) => _row(entry.key.toUpperCase(), entry.value),
                          ),
                        ]
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                DungeonMap(playerName: widget.player.name)),
                            (route) => false,
                      );
                    },
                    child: const Text('⚔️  BACK TO MAP',
                        style: TextStyle(color: Colors.white, fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const HomeScreen()),
                          (route) => false,
                    );
                  },
                  child: const Text('Main Menu',
                      style: TextStyle(color: Colors.white38)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70)),
          Text(value,
              style: const TextStyle(
                  color: Colors.amberAccent,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}