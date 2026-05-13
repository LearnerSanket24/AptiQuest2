import 'package:flutter/material.dart';

import '../models/player.dart';
import '../models/monster.dart';
import '../services/storage_service.dart';
import '../widgets/app_gradient_background.dart';
import 'battle_screen.dart';
import 'boss_room.dart';
import 'leaderboard_screen.dart';

class DungeonMap extends StatefulWidget {
  final String playerName;

  const DungeonMap({super.key, required this.playerName});

  @override
  State<DungeonMap> createState() => _DungeonMapState();
}

class _DungeonMapState extends State<DungeonMap> {
  Player? _player;
  Map<String, bool> _progress = {};
  bool _loading = true;

  final List<Map<String, dynamic>> _floors = [
    {
      'id': 'quant',
      'title': 'Floor 1: Quantitative Aptitude',
      'emoji': '🔢',
      'desc': 'Battle the Speed Demon & Profit Goblin',
      'category': 'quant',
      'color': Colors.orange,
      'monsters': [
        Monster(name: 'Speed Demon', emoji: '💨', maxHp: 80, category: 'quant'),
        Monster(name: 'Profit Goblin', emoji: '💰', maxHp: 100, category: 'quant'),
      ],
    },
    {
      'id': 'logic',
      'title': 'Floor 2: Logical Reasoning',
      'emoji': '🧩',
      'desc': 'Battle the Logic Wizard',
      'category': 'logic',
      'color': Colors.blue,
      'monsters': [
        Monster(name: 'Logic Wizard', emoji: '🧙', maxHp: 110, category: 'logic'),
      ],
    },
    {
      'id': 'english',
      'title': 'Floor 3: English',
      'emoji': '📖',
      'desc': 'Battle the Grammar Dragon',
      'category': 'english',
      'color': Colors.green,
      'monsters': [
        Monster(name: 'Grammar Dragon', emoji: '🐉', maxHp: 120, category: 'english'),
      ],
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final profile = await StorageService.getPlayerProfile() ?? Player(name: widget.playerName);
    final progress = await StorageService.getFloorProgress();
    if (!mounted) {
      return;
    }
    setState(() {
      _player = profile;
      _progress = progress;
      _loading = false;
    });
  }

  bool _isFloorUnlocked(int index) {
    if (index == 0) {
      return true;
    }
    final prevFloorId = _floors[index - 1]['id'] as String;
    return _progress[prevFloorId] == true;
  }

  bool _isBossUnlocked() {
    return (_progress['quant'] == true) &&
        (_progress['logic'] == true) &&
        (_progress['english'] == true);
  }

  Future<void> _openFloor(Map<String, dynamic> floor, int index) async {
    if (!_isFloorUnlocked(index)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This floor is locked. Clear previous floor first.')),
      );
      return;
    }
    final current = _player ?? Player(name: widget.playerName);
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BattleScreen(
          player: current,
          monsters: floor['monsters'] as List<Monster>,
          category: floor['category'] as String,
          floorTitle: floor['title'] as String,
          floorId: floor['id'] as String,
        ),
      ),
    );
    _loadState();
  }

  @override
  Widget build(BuildContext context) {
    final player = _player;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF12314A),
        title: Text('⚔️ ${widget.playerName}\'s Dungeon',
            style: const TextStyle(color: Colors.amberAccent)),
        actions: [
          IconButton(
            icon: const Icon(Icons.emoji_events, color: Colors.amberAccent),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const LeaderboardScreen())),
          ),
        ],
      ),
      body: AppGradientBackground(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              if (_loading)
                const Expanded(child: Center(child: CircularProgressIndicator()))
              else ...[
                if (player != null)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E3A),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'LVL ${player.level}  |  HP ${player.currentHp}/${player.maxHp}  |  XP ${player.xp}/100  |  Coins ${player.coins}',
                      style: const TextStyle(color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                  ),
                const Text('🗺 Choose a floor:',
                    style: TextStyle(color: Colors.white70, fontSize: 16)),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    itemCount: _floors.length,
                    itemBuilder: (context, index) {
                      final floor = _floors[index];
                      final floorId = floor['id'] as String;
                      final completed = _progress[floorId] == true;
                      final unlocked = _isFloorUnlocked(index);
                      final color = floor['color'] as Color;
                      return Card(
                        color: unlocked ? const Color(0xFF1E1E3A) : const Color(0xFF111122),
                        margin: const EdgeInsets.only(bottom: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () {
                            _openFloor(floor, index);
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Row(
                              children: [
                                Text(floor['emoji'] as String,
                                    style: const TextStyle(fontSize: 36)),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(floor['title'] as String,
                                          style: TextStyle(
                                              color: unlocked ? color : Colors.white38,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15)),
                                      const SizedBox(height: 4),
                                      Text(floor['desc'] as String,
                                          style: const TextStyle(
                                              color: Colors.white54, fontSize: 13)),
                                    ],
                                  ),
                                ),
                                Icon(
                                  completed
                                      ? Icons.check_circle
                                      : unlocked
                                          ? Icons.chevron_right
                                          : Icons.lock,
                                  color: completed ? Colors.greenAccent : color,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isBossUnlocked() ? Colors.red[900] : Colors.grey[800],
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      if (!_isBossUnlocked()) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Defeat all topic floors to unlock boss room.')),
                        );
                        return;
                      }
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  BossRoom(player: player ?? Player(name: widget.playerName))));
                    },
                    child: const Text('👑  FINAL BOSS ROOM',
                        style: TextStyle(
                            fontSize: 17,
                            color: Colors.white,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
