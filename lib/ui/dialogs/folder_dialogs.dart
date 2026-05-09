/* * ファイル名: folder_dialogs.dart
 * 役割: フォルダ操作に関連するダイアログ（新規作成、名前変更、エラー警告）
 */

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:permission_handler/permission_handler.dart';

class FolderDialogs {
  //  --- 名前が空文字の際の警告用ダイアログ ---
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

  // --- 名前が重複時の警告用サブ・ダイアログ ---
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

  // --- 削除するときの安全バー(加えて、実際の削除を担当する)ダイアログ ---
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

  // --- 一括削除時の確認 ---
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

  // --- 権限エラーダイアログ ---
  static void showPermissionDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false, // 権限がないと進めないため、外側タップで閉じないようにする
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme(context).exitBackground,
        title: const Row(
          children: [
            Icon(Icons.lock_outline, color: Colors.amber),
            SizedBox(width: 8),
            Text("権限が必要です", style: TextStyle(fontSize: 18)),
          ],
        ),
        content: const Text(
          "音楽ファイルへアクセスするために、\n端末の設定で権限を許可してください。",
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("キャンセル"),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              // 直接スマホの設定画面を開く（permission_handlerの機能）
              await openAppSettings();
            },
            child: const Text("端末の設定を開く"),
          ),
        ],
      ),
    );
  }

  // --- All Songs 内のフォルダの「仕分け先を選択」するダイアログ ---
  static void showAssignSelectorDialog({
    required BuildContext context,
    required Map<String, List<String>> parentFolderMap,
    required Function(String) onTargetSelected, // 移動先を決定した時の報告用
    required Function(String) onCreateAndAssign, // 移動先を新規作成しての追加用
  }) {
    String newParentName = "";
    final theme = AppTheme(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.sequenceBackground,
        title: const Text(
          "仕分け先を選択",
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 新規作成用の入力欄
              TextField(
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: "新規まとめフォルダ...",
                  hintStyle: TextStyle(color: Colors.white24),
                ),
                onChanged: (val) => newParentName = val,
              ),
              const Divider(color: Colors.white10),
              // 既存のまとめフォルダ一覧（All Songs 以外）
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: parentFolderMap.keys
                      .where((key) => key != "All Songs")
                      .map(
                        (target) => ListTile(
                          leading: const Icon(
                            Icons.folder_special,
                            color: Colors.blue,
                          ),
                          title: Text(
                            target,
                            style: const TextStyle(color: Colors.white),
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            onTargetSelected(target);
                          },
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("キャンセル", style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              if (newParentName.isNotEmpty) {
                Navigator.pop(context);
                onCreateAndAssign(newParentName);
              }
            },
            child: const Text("新規作成して追加"),
          ),
        ],
      ),
    );
  }
}
