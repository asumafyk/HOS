/* 
 * ファイル名: audio_player_service.dart
 * 役割: 音楽の再生・一時停止・シーク・連続スキップなどの実務
 * 備考: 将来的にここでフォルダごとの「音量比率」を計算します
 */

import 'dart:async';
import 'package:audioplayers/audioplayers.dart';

class AudioPlayerService {
  final AudioPlayer _player = AudioPlayer();

  // 連続スキップ用のタイマー
  Timer? _continuousSkipTimer;

  // 現在の再生状況を外部（画面）に教えるためのストリーム
  Stream<Duration> get onPositionChanged => _player.onPositionChanged;
  Stream<Duration> get onDurationChanged => _player.onDurationChanged;
  Stream<void> get onPlayerComplete => _player.onPlayerComplete;

  // --- 再生実行 ---
  Future<void> play(String path) async {
    // 【ここに注目！】将来、ここで path（フォルダ）を確認して
    // setVolume(0.8) や setVolume(1.2) を自動実行するようにします
    await _player.play(DeviceFileSource(path));
  }

  // --- 一時停止 ---
  Future<void> pause() async => await _player.pause();

  // --- 再開 ---
  Future<void> resume() async => await _player.resume();

  // --- 停止 ---
  Future<void> stop() async => await _player.stop();

  // --- シーク（ジャンプ） ---
  Future<void> seek(Duration position) async => await _player.seek(position);

  /*
    連続スキップ用の関数
  */
  void startContinuousSkip(bool isNext, Function action) {
    // 既にタイマーが動いていたら一度止める（安全策）
    stopContinuousSkip();
    // 1回目は即実行（タップ）
    action();
    // 2回目以降、一定間隔で実行
    _continuousSkipTimer = Timer.periodic(const Duration(milliseconds: 300), (
      timer,
    ) {
      action();
    });
  }

  /*
    連続スキップを止める関数
  */
  void stopContinuousSkip() {
    _continuousSkipTimer?.cancel();
    _continuousSkipTimer = null;
  }

  // --- 解放 ---
  void dispose() {
    stopContinuousSkip(); // タイマーが裏で暴走しないように
    _player.dispose();
  }
}
