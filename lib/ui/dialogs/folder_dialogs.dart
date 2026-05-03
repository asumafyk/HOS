/* * ファイル名: folder_dialogs.dart
 * 役割: フォルダ操作に関連するダイアログ（新規作成、名前変更、エラー警告）
 */

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class FolderDialogs {
  // 名前が空文字の際の警告用関数
  static void showEmptyError(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme(context).exitBackground,
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.amber),
            SizedBox(width: 8),
            Text("名前が空白"),
          ],
        ),
        content: Text("名前が空白です。\n名前を入力してください。"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("了解"),
          ),
        ],
      ),
    );
  }

  // 名前が重複時の警告用サブ・ダイアログ
  static void showDuplicateWarning(BuildContext context, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme(context).exitBackground,
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.amber),
            SizedBox(width: 8),
            Text("名前の重複"),
          ],
        ),
        content: Text("「$name」は既に使われています。\n別の名前を入力してください。"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("了解"),
          ),
        ],
      ),
    );
  }

  // 削除するときの安全バー(加えて、実際の削除を担当する)関数
  static void confirmDelete({
    required BuildContext context,
    required String name,
    required Map<String, List<String>> parentFolderMap, // データの地図
    required Map<String, String> folderNicknames, // ニックネームの地図
    required VoidCallback onConfirm,
  }) {
    List<String> contents = parentFolderMap[name] ?? [];
    int count = contents.length;
    String folderPreview = "";

    if (count > 0) {
      // 最大文字数を設定
      const int maxChars = 12;
      // 各フォルダをスキャンし、長すぎる場合は切り詰める
      final truncatedNames = contents
          .take(2)
          .map((id) {
            // ニックネームへの変換
            String rawName = folderNicknames[id] ?? id;
            if (rawName.startsWith("VIRTUAL_")) rawName = "名称未設定フォルダ";
            // 指定文字数より長ければカット
            String displayName = (rawName.length > maxChars)
                ? "${rawName.substring(0, maxChars)}…"
                : rawName;
            return "「$displayName」";
          })
          .join("・");
      // 記述内容
      folderPreview =
          "\n$truncatedNames${count > 2 ? " などのフォルダ" : ""} が含まれています)";
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme(context).exitBackground,
        title: Text("「$name」を削除しますか？", style: const TextStyle(fontSize: 17)),
        content: Text(
          "1件を削除します。$folderPreview",
          style: const TextStyle(fontSize: 14),
        ),
        actionsAlignment: MainAxisAlignment.end,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("キャンセル"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            child: const Text("削除する", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // 一括削除時の確認
  static void showBatchDeleteConfirm({
    required BuildContext context,
    required int count,
    required VoidCallback onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("一括削除の確認"),
        content: Text("選択された $count 個のアイテムを削除/除外しますか？"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("キャンセル"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            child: const Text("削除", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
