/* 
 * ファイル名: player_panel.dart
 * 役割: 曲名表示、シークバー、再生・停止ボタンなどの操作パネルUI
 */

import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import '../../core/utils.dart';
import '../theme/app_theme.dart';

class PlayerPanel extends StatelessWidget {
  final SongModel? selectSong;
  final String status;
  final Duration duration;
  final Duration position;
  final int playMode;
  final bool isFolderBridgeEnabled;
  final int currentIndex;
  final int totalCount;

  // ボタン操作などをメイン画面に伝えるコールバック
  final VoidCallback onMenuPressed;
  final VoidCallback onPlayPausePressed;
  final VoidCallback onNextPressed;
  final VoidCallback onPreviousPressed;
  final Function(bool) onContinuousSkipStart;
  final VoidCallback onContinuousSkipStop;
  final Function(double) onSeek;
  final VoidCallback onModeToggle;
  final VoidCallback onBridgeToggle;

  const PlayerPanel({
    super.key,
    required this.selectSong,
    required this.status,
    required this.duration,
    required this.position,
    required this.playMode,
    required this.isFolderBridgeEnabled,
    required this.currentIndex,
    required this.totalCount,
    required this.onMenuPressed,
    required this.onPlayPausePressed,
    required this.onNextPressed,
    required this.onPreviousPressed,
    required this.onContinuousSkipStart,
    required this.onContinuousSkipStop,
    required this.onSeek,
    required this.onModeToggle,
    required this.onBridgeToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme(context);

    return Container(
      width: double.infinity,
      color: theme.mainBackground,
      child: Stack(
        children: [
          Column(
            // Columnにして情報を縦に並べる
            children: [
              // 1. 曲情報エリア
              _buildSongInfo(theme),
              // 2. シークバー
              _buildSeekBar(context, theme),
              // 3. 時間・状態表示
              _buildTimeAndStatus(theme),
              const SizedBox(height: 5),
              // 4. 操作ボタン
              _buildControls(theme),
              const SizedBox(height: 10),
            ],
          ),
          // ハンガーメニュー（左上の三本線）
          Positioned(
            left: 5,
            top: 5,
            child: IconButton(
              icon: Icon(Icons.menu, color: theme.backAndMenuIcon),
              onPressed: onMenuPressed,
            ),
          ),
        ],
      ),
    );
  }

  // --- 内部部品：曲情報 ---
  Widget _buildSongInfo(AppTheme theme) {
    return Padding(
      // 再生中の曲名を表示するテキスト
      // ボタンと重ならないよう、上(top)に隙間を作りました
      padding: const EdgeInsets.only(
        top: 18.0,
        bottom: 5.0,
        left: 60.0,
        right: 60.0,
      ),
      child: Column(
        children: [
          SizedBox(
            height: 20,
            child: Text(
              // statusの状態に合わせて表示を切り替える
              selectSong == null
                  ? "～NO DATA～"
                  : "📂 ${AppUtils.getFolderNameFromPath(selectSong!.data)}",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: theme.playerFolderText),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          const SizedBox(height: 6),

          // 曲名エリア
          Container(
            height: 70, // 2行分のおおよその高さを指定
            alignment: Alignment.center, // 中身を上下左右の中央に配置
            child: Text(
              selectSong?.displayNameWOExt ?? "曲を選択してください",
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: theme.playerSongsText,
              ),
            ),
          ),

          const SizedBox(height: 1),

          // 何曲目かを表示
          SizedBox(
            height: 20,
            child: selectSong != null
                ? Text(
                    "($currentIndex / $totalCount 曲目)",
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.blueGrey,
                    ),
                  )
                : Text(
                    "(0 / 0 曲目)",
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.blueGrey,
                    ),
                  ), // 曲が無いときの処理
          ),
        ],
      ),
    );
  }

  // --- 内部部品：シークバー ---
  Widget _buildSeekBar(BuildContext context, AppTheme theme) {
    // 最大値を「曲の全秒数」
    double maxVal = duration.inSeconds.toDouble();
    // 現在の位置
    double currentVal = position.inSeconds.toDouble().clamp(
      0.0,
      maxVal > 0 ? maxVal : 0.0,
    );

    return SizedBox(
      height: 24,
      child: SliderTheme(
        data: SliderTheme.of(context).copyWith(
          trackHeight: 3.0, // バーの太さ
          activeTrackColor: theme.sliderAlreadyplayed, // 再生済みの線の色
          inactiveTrackColor: theme.sliderBeforePlay, // 未再生の線の色（暗めの白）
          thumbColor: theme.sliderHandle, // つまみの丸の色
          overlayColor: Colors.blue.withValues(alpha: 0.6), // つまみを触った時の影の色
          overlayShape: const RoundSliderOverlayShape(
            overlayRadius: 12.5,
          ), // つまみを触った時の影の半径
          thumbShape: const RoundSliderThumbShape(
            enabledThumbRadius: 5.5,
          ), // つまみの大きさ
        ),
        child: Slider(
          min: 0,
          // 最大値が、0以下の場合はエラー回避のため0.0にする
          max: maxVal > 0 ? maxVal : 0.0,
          value: currentVal,
          onChanged: onSeek, // つまみを動かした時の処理
        ),
      ),
    );
  }

  // --- 内部部品：時間と再生モードのテキスト ---
  Widget _buildTimeAndStatus(AppTheme theme) {
    String playModeText = ["順次再生", "全曲リピート", "1曲リピート", "シャッフル"][playMode];

    // 時間の数字表示
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start, // 左側に寄せる
        children: [
          // 時間表示("0:00"/0:00)の前者
          Text(
            AppUtils.formatDuration(position),
            style: TextStyle(
              color: theme.playerTimeText,
              fontSize: 11,
              fontFamily: "monospace", // 数字の幅を一定にしてがたつきを防ぐ
            ),
          ),
          const SizedBox(width: 2),
          Text(
            "/",
            style: TextStyle(color: theme.playerTimeText, fontSize: 11),
          ),
          const SizedBox(width: 2),
          // 時間表示(0:00/"0:00")の後者
          Text(
            AppUtils.formatDuration(duration),
            style: TextStyle(
              color: theme.playerTimeText,
              fontSize: 11,
              fontFamily: "monospace", // 数字の幅を一定にしてがたつきを防ぐ
            ),
          ),
          const SizedBox(width: 14),

          // ステータス表示(再生モード・跨ぎON/OFF)
          Text(
            "($playModeText / ${isFolderBridgeEnabled ? "フォルダループ:ON" : "フォルダループ:OFF"})",
            style: const TextStyle(color: Colors.blueGrey, fontSize: 10),
          ),
        ],
      ),
    );
  }

  // --- 内部部品：操作ボタン ---
  Widget _buildControls(AppTheme theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center, // 中央寄せ
      children: [
        // 再生モードを切り替えるボタン
        IconButton(
          icon: Icon(
            [
              Icons.trending_flat,
              Icons.repeat,
              Icons.repeat_one,
              Icons.shuffle,
            ][playMode],
            color: playMode == 0
                ? theme.playerModeOffIcon
                : theme.playerModeOnIcon,
          ),
          onPressed: onModeToggle,
        ),

        const SizedBox(width: 20),

        // 前の曲へのボタン
        _buildTransportIcon(
          Icons.skip_previous,
          onPreviousPressed,
          () => onContinuousSkipStart(false),
          onContinuousSkipStop,
          theme,
        ),

        const SizedBox(width: 10),

        // 一時停止・再開ボタン
        IconButton(
          // ボタンの文字を切り替える
          icon: Icon(
            (status == "pause" || status == "stop")
                ? Icons.play_arrow
                : Icons.pause,
            size: 40, // アイコンの大きさを調整
            color: theme.playerIcon,
          ),
          onPressed: onPlayPausePressed,
        ),

        const SizedBox(width: 10),

        // 次の曲へボタン
        _buildTransportIcon(
          Icons.skip_next,
          onNextPressed,
          () => onContinuousSkipStart(true),
          onContinuousSkipStop,
          theme,
        ),

        const SizedBox(width: 20),

        // フォルダ跨ぎ切り替えボタン
        IconButton(
          icon: Icon(
            Icons.account_tree, // フォルダを跨ぐイメージのアイコン
            color: isFolderBridgeEnabled ? Colors.greenAccent : Colors.white24,
          ),
          onPressed: onBridgeToggle,
        ),
      ],
    );
  }

  // スキップボタン用の補助
  Widget _buildTransportIcon(
    IconData icon,
    VoidCallback tap,
    VoidCallback longPress,
    VoidCallback longPressEnd,
    AppTheme theme,
  ) {
    return InkWell(
      onTap: tap,
      onLongPress: longPress, // 長押し
      onTapUp: (_) => longPressEnd(), // 指を離したとき
      onTapCancel: () => longPressEnd(), // スライドして外れたとき
      borderRadius: BorderRadius.circular(50),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Icon(icon, size: 40, color: theme.playerIcon),
      ),
    );
  }
}
