import 'package:flutter/material.dart';

import '../services/audio_service.dart';
import '../services/storage_service.dart';
import '../widgets/app_gradient_background.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _sound = true;
  bool _music = true;
  String _difficulty = 'normal';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = await StorageService.getSettings();
    if (!mounted) {
      return;
    }
    setState(() {
      _sound = settings['sound'] == true;
      _music = settings['music'] == true;
      _difficulty = settings['difficulty'] as String? ?? 'normal';
      _loading = false;
    });
  }

  Future<void> _save() async {
    await StorageService.saveSettings({
      'sound': _sound,
      'music': _music,
      'difficulty': _difficulty,
    });
    await AudioService.instance.refreshSettings();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Settings saved')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF12314A),
        title: const Text('Settings', style: TextStyle(color: Colors.amberAccent)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: AppGradientBackground(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  SwitchListTile(
                    value: _sound,
                    onChanged: (v) => setState(() => _sound = v),
                    title: const Text('Sound Effects', style: TextStyle(color: Colors.white)),
                    subtitle: const Text('Enable battle and UI sounds', style: TextStyle(color: Colors.white54)),
                  ),
                  SwitchListTile(
                    value: _music,
                    onChanged: (v) => setState(() => _music = v),
                    title: const Text('Background Music', style: TextStyle(color: Colors.white)),
                    subtitle: const Text('Play dungeon music', style: TextStyle(color: Colors.white54)),
                  ),
                  const SizedBox(height: 12),
                  const Text('Difficulty', style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'easy', label: Text('Easy')),
                      ButtonSegment(value: 'normal', label: Text('Normal')),
                      ButtonSegment(value: 'hard', label: Text('Hard')),
                    ],
                    selected: {_difficulty},
                    onSelectionChanged: (selection) {
                      setState(() => _difficulty = selection.first);
                    },
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Save', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
      ),
    );
  }
}
