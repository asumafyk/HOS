/* * ファイル名: folder_manager.dart
 * 役割: 仮想フォルダやまとめフォルダのデータ操作（作成・削除・移動・名前変更）の純粋なロジック
 */

import 'package:on_audio_query/on_audio_query.dart';

class FolderManager {
  // 仮想フォルダを管理する内部的な隠しキー
  static const String virtualMasterKey = "__VIRTUAL_MASTER__";

  // --- 名前がかぶらないニックネームを生成 ---
  static String generateUniqueNickname(
    String baseName,
    List<String> existingNames,
  ) {
    // 被っていなければそのまま返す
    if (!existingNames.contains(baseName)) return baseName;
    // 被っている場合は、_2, _3 ... と空きを探す
    int counter = 2;
    while (existingNames.contains("${baseName}_$counter")) {
      counter++;
    }
    return "${baseName}_$counter";
  }

  // --- 名前変更ロジック（仮想フォルダ・仮想曲ファイル）---
  static void renameItem({
    required String id,
    required String newName,
    required Map<String, String> folderNicknames,
    required Map<String, String> songNicknames,
    required bool isSong,
  }) {
    if (isSong) {
      songNicknames[id] = newName;
    } else {
      folderNicknames[id] = newName;
    }
  }

  // --- コピー・移動実行 ---
  static void executeMoveOrCopy({
    required bool isMoveMode,
    required String targetFolderId,
    required String? currentFolderName,
    required Set<String> selectedSongPaths,
    required Map<String, List<SongModel>> folderMap,
    required List<SongModel> displayedSongs,
  }) {
    List<SongModel> targets = displayedSongs
        .where((s) => selectedSongPaths.contains(s.data))
        .toList();

    if (!folderMap.containsKey(targetFolderId)) folderMap[targetFolderId] = [];
    folderMap[targetFolderId]!.addAll(targets);

    if (isMoveMode && currentFolderName != null) {
      folderMap[currentFolderName]!.removeWhere(
        (s) => selectedSongPaths.contains(s.data),
      );
    }
  }

  // --- All Songs からの仕分け・追加実行ロジック ---
  // (All Songs、まとめフォルダどちらから呼び出してもここは同じ)
  static void executeAssign({
    required String targetParent,
    required Set<String> selectedFolders,
    required Map<String, List<String>> parentFolderMap,
    required Map<String, List<SongModel>> folderMap,
    required Map<String, String> folderNicknames,
    required List<String> parentFolderOrder,
    required Map<String, List<String>> virtualFolderPaths,
  }) {
    // マスターリストが存在してなければ作成（Uiには表示しない）
    if (!parentFolderMap.containsKey(virtualMasterKey)) {
      parentFolderMap[virtualMasterKey] = [];
    }

    // 新規まとめ作成の場合
    if (!parentFolderMap.containsKey(targetParent)) {
      parentFolderMap[targetParent] = [];
      parentFolderOrder.add(targetParent);
    }

    // 選択中の「まとめ」内の表示名を取得して、被らない名前を生成
    List<String> siblingNames = parentFolderMap[targetParent]!
        .map((id) => folderNicknames[id] ?? id)
        .toList();

    for (var physicalName in selectedFolders) {
      String newNickname = generateUniqueNickname(physicalName, siblingNames);
      siblingNames.add(newNickname); // 追加分も考慮

      String uniqueId =
          "VIRTUAL_${DateTime.now().microsecondsSinceEpoch}_$physicalName";

      // 元の physicalName をキーにして、folderMap から曲リストを取得してディープコピー
      List<SongModel> songs = folderMap[physicalName] ?? [];
      folderMap[uniqueId] = List<SongModel>.from(songs);
      virtualFolderPaths[uniqueId] = songs
          .map((s) => s.data)
          .toList(); // 参照ではなく新しいリストを作成
      folderNicknames[uniqueId] = newNickname;

      // まとめへの追加
      parentFolderMap[targetParent]!.add(uniqueId);
      // マスターリストへの追加
      parentFolderMap[virtualMasterKey]!.add(uniqueId);
    }
  }

  // --- 一括削除ロジック（全階層対応） ---
  static void executeBulkDelete({
    required Set<String> selectedIds,
    required String? currentParentName,
    required String? currentFolderName,
    required Map<String, List<String>> parentFolderMap,
    required Map<String, List<SongModel>> folderMap,
    required Map<String, String> folderNicknames,
    required List<String> parentFolderOrder,
    required Map<String, List<String>> virtualFolderPaths,
  }) {
    // 1. まとめ一覧（最上位）での削除
    if (currentParentName == null) {
      for (var name in selectedIds) {
        if (name == virtualMasterKey ||
            name == "All Songs" ||
            name == "お気に入り・ピン留め") {
          continue; // マスターリスト自体と、All Songs、お気に入りフォルダは消さない
        }
        // まとめフォルダ内の仮想フォルダをクリーンアップ
        List<String> contents = parentFolderMap[name] ?? [];
        for (var id in contents) {
          // 他のまとめでも使われていないかチェックし、孤立するならパージ
          _handleVirtualOrphan(
            id,
            name,
            parentFolderMap,
            folderMap,
            folderNicknames,
            virtualFolderPaths,
          );
        }
        parentFolderMap.remove(name);
        parentFolderOrder.remove(name);
      }
    }
    // 2. まとめ内でのフォルダ削除（除外）
    else if (currentFolderName == null) {
      for (var id in selectedIds) {
        // 仮想フォルダなら実体も消去
        _handleVirtualOrphan(
          id,
          currentParentName,
          parentFolderMap,
          folderMap,
          folderNicknames,
          virtualFolderPaths,
        );
        parentFolderMap[currentParentName]?.remove(id);
      }
    }
    // 3. フォルダ内での曲削除（除外）
    else {
      for (var path in selectedIds) {
        // 現在のフォルダのリストからそのパスを持つ曲を除外
        folderMap[currentFolderName]?.removeWhere((s) => s.data == path);
      }
    }
  }

  // --- 仮想フォルダがどこからも参照されなくなった場合に実体データも消去する ---
  static void _handleVirtualOrphan(
    String id,
    String fromSummary,
    Map parentFolderMap,
    Map folderMap,
    Map folderNicknames,
    Map virtualFolderPaths,
  ) {
    if (!id.startsWith("VIRTUAL_")) return;

    // マスターリストからも削除
    parentFolderMap[virtualMasterKey]?.remove(id);

    // 他の「まとめ」に含まれているか確認
    bool isInOther = parentFolderMap.keys.any(
      (key) =>
          key != fromSummary &&
          key != virtualMasterKey &&
          (parentFolderMap[key] as List).contains(id),
    );

    // どこにも属さなくなったなら完全にパージ
    if (!isInOther) {
      _purgeVirtualFolder(id, folderMap, folderNicknames, virtualFolderPaths);
    }
  }

  // --- 仮想フォルダの実体データを完全に抹消する内部関数 ---
  static void _purgeVirtualFolder(
    String id,
    Map folderMap,
    Map folderNicknames,
    Map virtualFolderPaths,
  ) {
    folderMap.remove(id); // メモリ上の曲データ実体（Map）から削除
    folderNicknames.remove(id); // ニックネーム設定から削除
    virtualFolderPaths.remove(id); // パス（中身）のリストから削除

    //TODO? 今後実装する「音量比率データ」からもここで削除するようにします
    // volumeRatios.remove(folderId);
  }
}
