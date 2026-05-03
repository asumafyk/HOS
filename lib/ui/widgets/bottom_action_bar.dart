/* 
 * ファイル名: bottom_action_bar.dart
 * 役割: 削除モードなどの選択モード中に表示される、一括操作用のメニュー
 */

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class BottomActionBar extends StatelessWidget {
  final int count;
  final String modeName; // "削除", "並び替え", "名前変更", "コピー", "移動"
  final String actionLabel; // "削除を実行", "ここに移動" など
  final VoidCallback onExecute;
  final VoidCallback onCancel;

  const BottomActionBar({
    super.key,
    required this.count,
    required this.modeName,
    required this.actionLabel,
    required this.onExecute,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme(context);
    bool hasSelection = count > 0;

    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        border: const Border(top: BorderSide(color: Colors.white10)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 10),
        ],
      ),
      child: hasSelection
          ? _buildSelectionActiveUI() // 選択あり：キャンセル + 実行
          : _buildModeEndUI(), // 選択無し：モード終了のみ
    );
  }

  // 選択があるときのUI
  Widget _buildSelectionActiveUI() {
    return Row(
      children: [
        // 1. 左エリア：キャンセルボタン（左寄せ）
        Expanded(
          flex: 1,
          child: Align(
            alignment: Alignment.centerLeft,
            child: FittedBox(
              fit: BoxFit.scaleDown, // 枠を超えたら縮小
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: onCancel,
                child: const Text(
                  "キャンセル",
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ),
            ),
          ),
        ),

        // 2. 中央エリア：選択件数（中央寄せ）
        Expanded(
          flex: 1,
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                "$count 件選択中",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.blueAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ),

        // 3. 右エリア：実行ボタン（右寄せ）
        Expanded(
          flex: 1,
          child: Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: onExecute,
              style: ElevatedButton.styleFrom(
                backgroundColor: actionLabel.contains("削除")
                    ? Colors.redAccent
                    : Colors.blueAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                // ボタンの最小サイズを少し小さくして、はみ出しを防ぐ
                minimumSize: const Size(60, 36),
              ),
              child: Text(
                actionLabel,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, height: 1.1),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // 選択が無いときのUI
  Widget _buildModeEndUI() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onCancel,
        icon: const Icon(Icons.close, size: 18),
        label: Text("$modeNameモード終了"),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white70,
          side: const BorderSide(color: Colors.white24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}
