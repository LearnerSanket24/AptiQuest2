import 'dart:async';

import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/widgets.dart';

import 'storage_service.dart';

class AudioService {
  AudioService._();

  static final AudioService instance = AudioService._();

  static const String _audioAsset = 'audio/bgm.mpeg';

  bool _initialized = false;
  bool _musicEnabled = true;
  bool _soundEnabled = true;
  bool _inBackground = false;
  bool _bgmPlaying = false;

  final Set<AudioPlayer> _activeSfxPlayers = <AudioPlayer>{};

  Future<void> init() async {
    if (_initialized) {
      return;
    }

    FlameAudio.bgm.initialize();
    await refreshSettings();
    _initialized = true;
  }

  Future<void> refreshSettings() async {
    final settings = await StorageService.getSettings();
    _musicEnabled = settings['music'] == true;
    _soundEnabled = settings['sound'] == true;

    await _syncBgmWithState();
    if (!_soundEnabled) {
      await _stopAllSfx();
    }
  }

  Future<void> handleLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      _inBackground = false;
      await _syncBgmWithState();
      await _resumeSfx();
      return;
    }

    _inBackground = true;
    await _pauseBgm();
    await _pauseSfx();
  }

  Future<void> playSfx({double volume = 0.55}) async {
    if (!_initialized) {
      await init();
    }
    if (_inBackground || !_soundEnabled) {
      return;
    }

    try {
      final player = await FlameAudio.play(_audioAsset, volume: volume);
      _activeSfxPlayers.add(player);

      unawaited(
        Future<void>.delayed(const Duration(milliseconds: 280)).then((_) async {
          try {
            await player.stop();
            await player.dispose();
          } catch (_) {}
          _activeSfxPlayers.remove(player);
        }),
      );
    } catch (_) {
      // Ignore playback errors to keep game flow uninterrupted.
    }
  }

  Future<void> _syncBgmWithState() async {
    if (_inBackground || !_musicEnabled) {
      if (_bgmPlaying) {
        await FlameAudio.bgm.stop();
        _bgmPlaying = false;
      }
      return;
    }

    if (_bgmPlaying) {
      return;
    }

    try {
      await FlameAudio.bgm.play(_audioAsset, volume: 0.35);
      _bgmPlaying = true;
    } catch (_) {
      _bgmPlaying = false;
    }
  }

  Future<void> _pauseBgm() async {
    if (!_bgmPlaying) {
      return;
    }
    try {
      await FlameAudio.bgm.pause();
    } catch (_) {}
  }

  Future<void> _pauseSfx() async {
    for (final player in _activeSfxPlayers.toList()) {
      try {
        await player.pause();
      } catch (_) {}
    }
  }

  Future<void> _resumeSfx() async {
    if (!_soundEnabled || _inBackground) {
      return;
    }
    for (final player in _activeSfxPlayers.toList()) {
      try {
        await player.resume();
      } catch (_) {}
    }
  }

  Future<void> _stopAllSfx() async {
    for (final player in _activeSfxPlayers.toList()) {
      try {
        await player.stop();
        await player.dispose();
      } catch (_) {}
    }
    _activeSfxPlayers.clear();
  }
}