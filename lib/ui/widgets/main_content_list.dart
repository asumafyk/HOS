/* * ファイル名: main_content_list.dart
 * 役割: まとめ、フォルダ、曲の各リストを統合的に表示するメインエリア
 */

import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import '../../core/constants.dart';
import 'music_tile.dart';

class MainContentList extends StatelessWidget {
  final ViewLevel level;
  final List<dynamic> items; // String(ID) または SongModel
  final String? playingId;
  final Set<String> selectedIds;
  final bool isSelectionMode;
  final bool isSortMode;
  final bool isRenameMode;
  final bool isDeleteMode;
  final Set<String> favoriteIds;
  final Map<String, String> nicknames;

  // 各種操作のコールバック
  final Function(dynamic, int) onTap;
  final Function(dynamic, bool?) onCheckboxChanged;
  final Function(dynamic) onFavoriteTap;
  final Function(dynamic) onRenameTap;
  final Function(dynamic) onDeleteTap;
  final ReorderCallback onReorder;

  const MainContentList({
    super.key,
    required this.level,
    required this.items,
    this.playingId,
    required this.selectedIds,
    required this.isSelectionMode,
    required this.isSortMode,
    required this.isRenameMode,
    required this.isDeleteMode,
    required this.favoriteIds,
    required this.nicknames,
    required this.onTap,
    required this.onCheckboxChanged,
    required this.onFavoriteTap,
    required this.onRenameTap,
    required this.onDeleteTap,
    required this.onReorder,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(
        child: Text(
          level == ViewLevel.sub ? "このまとめは空です" : "このフォルダは空です",
          style: TextStyle(color: Colors.white24, fontSize: 16),
        ),
      );
    }

    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      itemCount: items.length,
      proxyDecorator: _buildProxyDecorator,
      onReorder: onReorder,
      itemBuilder: (context, index) {
        final item = items[index];
        final String id = (item is SongModel) ? item.data : item.toString();

        // 表示名の決定
        String displayName =
            nicknames[id] ?? ((item is SongModel) ? item.displayNameWOExt : id);
        if (displayName.startsWith("VIRTUAL_")) displayName = "名称未設定フォルダ";

        return MusicTile(
          level: level,
          id: id, // まとめフォルダ・フォルダ・曲ファイル名
          index: index, // 並び順
          song: (item is SongModel) ? item : null,
          isPlaying: playingId == id,
          isChecked: selectedIds.contains(id),
          isSelectionMode: isSelectionMode,
          isSortMode: isSortMode,
          isRenameMode: isRenameMode,
          isDeleteMode: isDeleteMode,
          isFavorite: favoriteIds.contains(id),
          displayName: displayName,
          onTap: () => onTap(item, index),
          onCheckboxChanged: (val) => onCheckboxChanged(item, val),
          onFavoriteTap: () => onFavoriteTap(item),
          onRenameTap: () => onRenameTap(item),
          onDeleteTap: () => onDeleteTap(item),
        );
      },
    );
  }

  // リストの項目を持ち上げた(ドラッグ)際の装飾関数
  Widget _buildProxyDecorator(
    Widget child,
    int index,
    Animation<double> animation,
  ) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, animChild) {
        // 持ち上げ進行度
        final double animValue = Curves.easeInOut.transform(animation.value);
        // 左にずらす量
        final double offsetX = animValue * -10.0;
        // 上にずらす量
        final double offsetY = animValue * -6.0;
        // 影の深さ
        final double elevation = animValue * 8.0;
        return Transform.translate(
          offset: Offset(offsetX, offsetY),
          child: Material(
            elevation: elevation,
            color: Colors.greenAccent.withValues(alpha: 0.3), // 浮いているときの色
            shadowColor: Colors.black54,
            child: child,
          ),
        );
      },
    );
  }
}
