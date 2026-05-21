/* 
 * ファイル名: music_tile.dart
 * 役割: リストに表示される一行（タイル）の見た目と基本操作を管理
 */

import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import '../../core/constants.dart';
import '../theme/app_theme.dart';

class MusicTile extends StatelessWidget {
  final ViewLevel level;
  final String id;
  final int index;
  final SongModel? song;
  final bool isSelectionMode;
  final bool isPlaying; // 背景の青い光用
  final bool isChecked; // チェックボックスのON/OFF用
  final bool isSortMode;
  final bool isRenameMode;
  final bool isDeleteMode;
  final bool isFavorite;
  final String displayName;

  // 操作をメイン画面に伝えるためのコールバック（電話線）
  final VoidCallback onTap;
  final Function(bool?) onCheckboxChanged;
  final VoidCallback onFavoriteTap;
  final VoidCallback onRenameTap;
  final VoidCallback onDeleteTap;
  final Widget? proxyDecorator; // 並べ替え時の装飾用

  const MusicTile({
    super.key,
    required this.level,
    required this.id,
    required this.index,
    this.song,
    required this.isPlaying,
    required this.isChecked,
    required this.isSelectionMode,
    required this.isSortMode,
    required this.isRenameMode,
    required this.isDeleteMode,
    required this.isFavorite,
    required this.displayName,
    required this.onTap,
    required this.onCheckboxChanged,
    required this.onFavoriteTap,
    required this.onRenameTap,
    required this.onDeleteTap,
    this.proxyDecorator,
  });

  @override
  Widget build(BuildContext context) {
    // テーマの読み込み
    final theme = AppTheme(context);

    // サブタイトルの決定（曲ならアーティスト名,まとめフォルダ内なら中の曲数）
    Widget? subTitle;
    if (level == ViewLevel.sub) {
      // TODO
      /*subTitle = Text(
        "(${folderMap[id]?.length ?? 0})",
        style: TextStyle(color: theme.songCount, fontSize: 12),
      );*/
    } else if (level == ViewLevel.song) {
      subTitle = Text(
        song?.artist ?? "不明なアーティスト",
        style: TextStyle(color: theme.artistText, fontSize: 12),
      );
    }

    return Material(
      key: ValueKey("${level.name}_$id"), // ReorderableListViewに必須
      color: Colors.transparent,
      child: InkWell(
        // タイルタップ処理
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            gradient: isPlaying
                ? LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: theme.playingListTileGradient,
                    stops: const [0.0, 0.4, 1.0],
                  )
                : null,
            color: null,
            border: Border(
              bottom: BorderSide(
                color: AppTheme(context).listBorder,
                width: 0.5, // 線の太さ
              ),
            ),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 0,
            ),
            // 左側
            leading: (isSelectionMode && id != "All Songs" && id != "お気に入り・ピン留め")
                ? Checkbox(
                    value: isChecked, // チェック状態は呼び出し側から受け取る
                    activeColor: Colors.blueAccent,
                    onChanged: (val) => onCheckboxChanged(val),
                  )
                : _buildLeadingIcon(theme),
            // 中央タイトル
            title: Text(
              displayName,
              maxLines: level == ViewLevel.parent ? 2 : 1, // 親なら2行、それ以外は1行
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isPlaying ? theme.playingText : theme.listText,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            subtitle: subTitle,
            // 右側
            trailing: _buildTrailingWidget(theme),
          ),
        ),
      ),
    );
  }

  /*
    タイルの左側のアイコン生成関数
  */
  Widget _buildLeadingIcon(AppTheme theme) {
    // 曲階層の場合
    if (level == ViewLevel.song) {
      return Container(
        width: 35,
        alignment: Alignment.center,
        child: Text(
          "${index + 1}.",
          style: TextStyle(
            color: isPlaying ? theme.playingText : theme.listText,
            fontWeight: FontWeight.bold,
            fontFamily: "monospace",
          ),
        ),
      );
    }
    // フォルダ階層（親・物理）の場合はアイコンを表示
    IconData icon = (id == "⭐ お気に入り") ? Icons.star_sharp : Icons.folder;
    Color color = (id == "⭐ お気に入り"
        ? Colors.yellow
        : Colors.amber.withValues(alpha: 0.8));
    return Icon(icon, color: color, size: 35);
  }

  /*
    タイルの右側のアイコンを、モード別で生成する補助関数
  */
  Widget _buildTrailingWidget(AppTheme theme) {
    // All Songs は移動も削除もできない
    if (id == "All Songs" || id == "お気に入り・ピン留め") {
      return const Icon(Icons.lock_outlined, size: 18, color: Colors.white10);
    }
    // 並べ替えモード
    if (isSortMode) {
      return ReorderableDragStartListener(
        index: index,
        child: const Icon(Icons.menu, color: Colors.blue),
      );
    }
    // 名前変更モード
    if (isRenameMode) {
      return IconButton(
        icon: const Icon(Icons.edit_note, color: Colors.blueAccent),
        onPressed: onRenameTap,
      );
    }
    // 削除モード
    if (isDeleteMode) {
      return IconButton(
        icon: const Icon(Icons.delete, color: Colors.red),
        onPressed: onDeleteTap,
      );
    }
    // 通常時かつフォルダ階層でのピン（お気に入り）ボタン
    if (level == ViewLevel.sub) {
      return IconButton(
        visualDensity: VisualDensity.compact,
        icon: Icon(
          isFavorite ? Icons.push_pin : Icons.push_pin_outlined,
          color: isFavorite ? Colors.blueAccent : Colors.white24,
          size: 25,
        ),
        onPressed: onFavoriteTap,
      );
    }
    // 通常時かつ曲階層でのお気に入りボタン
    if (level == ViewLevel.song) {
      return IconButton(
        icon: Icon(
          isFavorite ? Icons.star : Icons.star_border,
          color: isFavorite ? Colors.yellow : Colors.white60,
        ),
        onPressed: onFavoriteTap,
      );
    }
    // 通常時
    return const Icon(Icons.chevron_right, color: Colors.white24);
  }
}
