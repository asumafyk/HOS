import 'package:flutter/material.dart';
import 'header_menu.dart';

class HeaderMenuContent extends StatelessWidget {
  final String? currentParentName;
  final String? currentFolderName;

  // メイン画面側の各種ロジックを呼び出すための「電話線（コールバック）」
  final VoidCallback onAddSongsToSummary; // まとめ内に曲を追加（All Songs物理フォルダ内）
  final VoidCallback onSortDisplayedSongs; // 並べ替え（曲一覧）
  final VoidCallback onSearchSongs; // お気に入り内での曲検索
  final VoidCallback onAddSongsFromAllSongs; // All Songsから曲を追加（仮想フォルダ内）
  final VoidCallback onStartCopyMode; // コピーモード開始
  final VoidCallback onStartMoveMode; // 移動モード開始
  final VoidCallback onStartDeleteModeSongs; // 削除モード開始（曲）
  final VoidCallback onStartAssignMode; // まとめフォルダに追加（All Songsフォルダ一覧）
  final VoidCallback onAddFoldersToSummary; // All Songsからフォルダ追加（カスタムまとめ内）
  final VoidCallback onCreateVirtualFolder; // 空フォルダ作成
  final VoidCallback onStartRenameMode; // 名前変更モード開始
  final VoidCallback onStartSortModeFolders; // 並べ替えモード開始（フォルダ）
  final VoidCallback onStartDeleteModeFolders; // まとめから外す・削除モード開始（フォルダ）
  final VoidCallback onCreateParentFolder; // まとめ新規作成

  const HeaderMenuContent({
    super.key,
    required this.currentParentName,
    required this.currentFolderName,
    required this.onAddSongsToSummary,
    required this.onSortDisplayedSongs,
    required this.onSearchSongs,
    required this.onAddSongsFromAllSongs,
    required this.onStartCopyMode,
    required this.onStartMoveMode,
    required this.onStartDeleteModeSongs,
    required this.onStartAssignMode,
    required this.onAddFoldersToSummary,
    required this.onCreateVirtualFolder,
    required this.onStartRenameMode,
    required this.onStartSortModeFolders,
    required this.onStartDeleteModeFolders,
    required this.onCreateParentFolder,
  });

  @override
  Widget build(BuildContext context) {
    // 表示するボタンのリストを階層ごとに準備
    List<HeaderMenuItem> items = [];

    if (currentFolderName != null) {
      // --- 最下層（曲一覧）でのメニュー ---

      // All Songs内の物理フォルダ内である場合
      if (currentParentName == "All Songs") {
        items = [
          HeaderMenuItem(
            icon: Icons.library_add,
            label: "まとめフォルダ内に\n曲を追加",
            onTap: onAddSongsToSummary,
          ),
          HeaderMenuItem(
            icon: Icons.sort,
            label: "並べ替え\n(表示順のみ)",
            onTap: onSortDisplayedSongs,
          ),
        ];
      } else if (currentFolderName == "⭐ お気に入り") {
        items = [
          HeaderMenuItem(
            icon: Icons.search,
            label: "曲検索",
            color: Colors.white60,
            onTap: onSearchSongs,
          ),
        ];
      } else {
        // 仮想フォルダ内（自作まとめ内）：フル編集可能
        items = [
          HeaderMenuItem(
            icon: Icons.library_add,
            label: "All Songs から\n曲を追加",
            onTap: onAddSongsFromAllSongs,
          ),
          HeaderMenuItem(
            icon: Icons.copy,
            label: "コピー",
            onTap: onStartCopyMode,
          ),
          HeaderMenuItem(
            icon: Icons.move_up,
            label: "移動",
            onTap: onStartMoveMode,
          ),
          HeaderMenuItem(
            icon: Icons.sort,
            label: "並べ替え\n(再生順も同期)",
            onTap: onSortDisplayedSongs,
          ),
          HeaderMenuItem(
            icon: Icons.delete_sweep,
            label: "削除",
            color: Colors.redAccent,
            onTap: onStartDeleteModeSongs,
          ),
        ];
      }
    } else if (currentParentName != null) {
      // --- 中位（自作まとめフォルダ）でのメニュー ---
      if (currentParentName == "All Songs") {
        // --- All Songs でのメニュー
        items = [
          HeaderMenuItem(
            icon: Icons.rule_rounded,
            label: "まとめフォルダ\nに追加",
            onTap: onStartAssignMode,
          ),
          HeaderMenuItem(
            icon: Icons.rule_rounded, // TODO変更
            label: "フォルダの表示・非表示\nの切り替え",
            onTap:
                () {}, //TODO 変更の結果はフォルダ追加・シーケンスにも影響（All Songsから一時的に抜くような対応で可能？）
          ),
        ];
      } else if (currentParentName == "お気に入り・ピン留め") {
        items = [
          HeaderMenuItem(
            icon: Icons.search,
            label: "フォルダ検索",
            color: Colors.white60,
            onTap: onSearchSongs, // 共用
          ),
        ];
      } else {
        // --- 基本的なまとめフォルダでのメニュー ---
        items = [
          HeaderMenuItem(
            icon: Icons.add_to_photos_outlined,
            label: "All Songs から\nフォルダ追加",
            onTap: onAddFoldersToSummary,
          ),
          HeaderMenuItem(
            icon: Icons.add_to_photos_outlined, // TODO変更
            label: "別のまとめフォルダ\nからフォルダ追加",
            onTap: () {}, // TODO
          ),
          HeaderMenuItem(
            icon: Icons.create_new_folder_outlined,
            label: "空フォルダ作成",
            onTap: onCreateVirtualFolder,
          ),
          HeaderMenuItem(
            icon: Icons.edit_note,
            label: "名前変更",
            onTap: onStartRenameMode,
          ),
          HeaderMenuItem(
            icon: Icons.sort,
            label: "並べ替え\n(再生順も同期)",
            onTap: onStartSortModeFolders,
          ),
          HeaderMenuItem(
            icon: Icons.playlist_remove,
            label: "まとめから外す",
            color: Colors.orangeAccent,
            onTap: onStartDeleteModeFolders,
          ),
        ];
      }
    } else {
      // --- 親階層（まとめ一覧）でのメニュー ---
      items = [
        HeaderMenuItem(
          icon: Icons.create_new_folder_outlined,
          label: "まとめ\n新規作成",
          onTap: onCreateParentFolder,
        ),
        HeaderMenuItem(
          icon: Icons.edit_note,
          label: "名前変更",
          onTap: onStartRenameMode,
        ),
        HeaderMenuItem(
          icon: Icons.sort,
          label: "並べ替え",
          onTap: onStartSortModeFolders
        ),
        HeaderMenuItem(
          icon: Icons.remove_circle_outline,
          label: "削除",
          color: Colors.redAccent,
          onTap: onStartDeleteModeFolders,
        ),
      ];
    }

    if (items.isEmpty) return const SizedBox.shrink();
    return HeaderMenu(items: items);
  }
}
