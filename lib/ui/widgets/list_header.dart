/* * ファイル名: list_header.dart
 * 役割: リスト上部のタイトル表示と、展開式の操作メニュー
 */

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ListHeader extends StatelessWidget {
  final String title;
  final bool isHeaderOpen;
  final bool isTopLevel;
  final bool showPinButton;
  final bool isPinned;
  final VoidCallback onHeaderTap;
  final VoidCallback onBackTap;
  final VoidCallback onPinTap;
  final Widget menuContent; // 階層に応じたメニューの中身を受け取る

  const ListHeader({
    super.key,
    required this.title,
    required this.isHeaderOpen,
    required this.isTopLevel,
    required this.showPinButton,
    required this.isPinned,
    required this.onHeaderTap,
    required this.onBackTap,
    required this.onPinTap,
    required this.menuContent,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme(context);

    return Column(
      children: [
        // --- ヘッダー本体 ---
        InkWell(
          onTap: onHeaderTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: theme.listBackground.withValues(alpha: 0.8),
              border: Border(
                bottom: BorderSide(color: theme.listBorder, width: 0.5),
              ),
            ),
            child: Row(
              children: [
                // 左端：戻るボタン または ホームアイコン(まとめ一覧のみ)
                isTopLevel
                    // ホームアイコン
                    ? Icon(
                        Icons.home, //TODO アイコン・左右の幅等の修正
                        color: theme.backAndMenuIcon,
                        size: 33,
                      )
                    // 戻るボタン
                    : IconButton(
                        padding: EdgeInsets.zero, // paddingをゼロにし、左端へ
                        constraints: const BoxConstraints(), // アイコン自体のサイズに凝縮
                        icon: Icon(
                          Icons.arrow_back,
                          color: theme.backAndMenuIcon,
                          size: 30,
                        ),
                        onPressed: onBackTap,
                      ),
                // 中央：タイトル
                Expanded(
                  child: Text(
                    title,
                    // ヘッダーが開いている時は2行、閉じている時は1行
                    maxLines: isHeaderOpen ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: theme.folderHeaderText,
                    ),
                  ),
                ),

                const SizedBox(width: 4),

                // 開閉状態アイコン
                Icon(
                  isHeaderOpen
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: Colors.blue,
                  size: 20,
                ),

                // 右端：ピン留めボタン(必要な時のみ)
                if (showPinButton)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                      color: isPinned ? Colors.blueAccent : Colors.white24,
                      size: 25,
                    ),
                    onPressed: onPinTap,
                  )
                else
                  const SizedBox(width: 35),
              ],
            ),
          ),
        ),

        // --- ポップダウン・メニューエリア ---
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          child: isHeaderOpen
              ? menuContent // 既存のメニュー関数を呼び出し
              : const SizedBox(width: double.infinity, height: 0),
        ),
      ],
    );
  }
}
