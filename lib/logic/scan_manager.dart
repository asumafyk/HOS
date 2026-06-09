/* * ファイル名: scan_manager.dart
 * 役割: 端末スキャン、物理削除データのクリーンアップ、メモリ上のフォルダ構造再構築を担う司令塔
 */

import 'package:flutter/material.dart';
import 'package:my_first_app/logic/folder_manager.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';

class ScanManager {
  final OnAudioQuery audioQuery = OnAudioQuery();
  bool isScanning = false;

  // main_screen.dart 側の変数を操作、または同期するためのコールバックや参照
  List<SongModel> Function() getMusicFiles;
  void Function(List<SongModel>) setMusicFiles;

  Map<String, List<SongModel>> Function() getFolderMap;
  Map<String, List<String>> Function() getParentFolderMap;
  List<String> Function() getParentFolderOrder;
  List<String> Function() getFolderSequence;

  Set<String> Function() getFavoriteFolders;
  Set<String> Function() getFavoriteSongs;
  Map<String, List<String>> Function() getVirtualFolderPaths;
  Map<String, String> Function() getSongNicknames;
  Map<String, String> Function() getFolderNicknames;

  final VoidCallback updateUI;

  ScanManager({
    required this.getMusicFiles,
    required this.setMusicFiles,
    required this.getFolderMap,
    required this.getParentFolderMap,
    required this.getParentFolderOrder,
    required this.getFolderSequence,
    required this.getFavoriteFolders,
    required this.getFavoriteSongs,
    required this.getVirtualFolderPaths,
    required this.getSongNicknames,
    required this.getFolderNicknames,
    required this.updateUI,
  });

  // --- デバイス内から起動時に音楽ファイルを探す ---
  Future<void> scanDevice() async {
    // 2重スキャン防止ガード：非同期処理の多重実行によるクラッシュやデータ破壊を防ぐ
    if (isScanning) return;
    isScanning = true;
    updateUI(); // インジケーター表示などのためUI更新

    try {
      debugPrint("HOS: デバイススキャン開始...");
      // ストレージのアクセス権限チェック
      bool hasPermission = await Permission.audio.isGranted;
      if (!hasPermission) {
        hasPermission = await Permission.audio.request().isGranted;
      }
      // Android 13未満などの古い端末向けにstorage権限も念のためチェック
      if (!hasPermission) {
        hasPermission = await Permission.storage.isGranted;
        if (!hasPermission) {
          hasPermission = await Permission.storage.request().isGranted;
        }
      }
      if (!hasPermission) return;

      // スマホ内のデータベースに全音声ファイル・曲ファイルを要求する
      List<SongModel> songs = await audioQuery.querySongs(
        ignoreCase: true,
        sortType: SongSortType.DISPLAY_NAME, // DISPLAY_NAME（ファイル名）を基準の並び替え
        orderType: OrderType.ASC_OR_SMALLER, // 昇順（あいうえお順
        uriType: UriType.EXTERNAL, // 外部ストレージ
      );
      debugPrint("HOS: スキャン完了。${songs.length}曲見つかりました。");

      // 1. 消えた曲の検知と、それに連動するすべての周辺お掃除をここで一気に執行
      _handleDeletedPhysicalData(songs);

      // 2. メモリ上の全曲リストを最新スキャン結果で更新
      setMusicFiles(songs);

      // 3. 構造の再構築を実行
      rebuildFolderStructures(songs);
    } catch (e) {
      debugPrint("スキャン中にエラーが発生しました: $e"); // エラー補足
    } finally {
      isScanning = false; // 必ずフラグを戻す
      updateUI(); // setStateを反映
    }
  }

  // --- 物理ファイルの消滅時のみ発動するピンポイントクリーンアップ ---
  void _handleDeletedPhysicalData(List<SongModel> scannedSongs) {
    final currentMusicFiles = getMusicFiles(); // 前回保存されていた古い全曲リスト
    final favoriteSongs = getFavoriteSongs();
    final songNicknames = getSongNicknames();
    final folderMap = getFolderMap();
    final virtualFolderPaths = getVirtualFolderPaths();
    final folderNicknames = getFolderNicknames();
    final favoriteFolders = getFavoriteFolders();
    final parentFolderOrder = getParentFolderOrder();
    final folderSequence = getFolderSequence();
    final parentFolderMap = getParentFolderMap();

    // 初回起動時など、前回データがまだない場合はスキップ
    if (currentMusicFiles.isEmpty) return;

    // スキャンされた最新の物理パスのセット
    final Set<String> scannedPaths = scannedSongs.map((s) => s.data).toSet();

    // 前回あったのに、今回スキャンされなかった（消えてしまった）曲のパスを特定
    List<String> deletedSongPaths = [];
    for (var oldSong in currentMusicFiles) {
      if (!scannedPaths.contains(oldSong.data)) {
        deletedSongPaths.add(oldSong.data);
      }
    }

    // 物理削除が発覚した時だけクリーンアップを執行
    if (deletedSongPaths.isNotEmpty) {
      debugPrint("HOS: 物理ファイルの消滅を検知。周辺データの連動クリーンアップを開始します。");

      // 1. 削除前の「各仮想フォルダの曲数」を正確に記憶しておく（巻き込み防止ガード用）
      Map<String, int> preDeleteCounts = {};
      folderMap.forEach((key, songList) {
        if (key.startsWith("VIRTUAL_")) {
          preDeleteCounts[key] = songList.length;
        }
      });

      // 2. 現在生き残っている「最新の物理フォルダ名の一覧」を、最新スキャンデータから集計
      Map<String, List<SongModel>> tempMap = {};
      for (var song in scannedSongs) {
        String? folderPath = song.data.substring(0, song.data.lastIndexOf('/'));
        String folderName = folderPath.substring(
          folderPath.lastIndexOf('/') + 1,
        );
        tempMap.putIfAbsent(folderName, () => []).add(song);
      }

      // 3. 消えた「曲」のゴミデータを各名簿・フォルダ空完全に除外
      for (String delPath in deletedSongPaths) {
        // (a) お気に入り曲リストから削除
        favoriteSongs.remove(delPath);
        // (b) 曲のニックネームから削除
        songNicknames.remove(delPath);
        // (c) 仮想フォルダを含むすべてのフォルダの中身(SongModel)から削除
        folderMap.forEach((key, songList) {
          songList.removeWhere((s) => s.data == delPath);
        });
        // (d) 仮想フォルダのパス記録（永続化データ用）から削除
        virtualFolderPaths.forEach((key, pathList) {
          pathList.remove(delPath);
        });
      }

      // 4. 曲が消滅した結果、「もともと曲が入っていたのに、今回のクリーンアップで空になったフォルダ」を厳選して自動除外
      List<String> autoDeleteKeys = [];
      // 削除するべき仮想フォルダを探す
      folderMap.forEach((key, songList) {
        if (key.startsWith("VIRTUAL_") && songList.isEmpty) {
          int originalCount = preDeleteCounts[key] ?? 0;
          // もともと曲数が1つ以上あったフォルダのみを削除対象にする
          if (originalCount > 0) {
            autoDeleteKeys.add(key);
          }
        }
      });
      // 実際に上記で選択した仮想フォルダを削除する
      for (String vKey in autoDeleteKeys) {
        folderMap.remove(vKey);
        virtualFolderPaths.remove(vKey);
        folderNicknames.remove(vKey);
        favoriteFolders.remove(vKey);
        // すべてのまとめフォルダ（親）の登録名簿からも完全に除外
        parentFolderMap.forEach((parentKey, subList) {
          subList.remove(vKey);
        });
        debugPrint("HOS: 曲ファイル消滅により、空になった仮想フォルダ($vKey)を完全自動削除しました。");
      }

      // 5. 物理「フォルダ」側のクリーンアップ（ニックネーム・ピン・並び順）
      // (a) ピン留めリスト(favoriteFolders)から、ストレージに存在しなくなった物理・仮想フォルダを自動削除
      favoriteFolders.retainWhere(
        (folderName) =>
            tempMap.containsKey(folderName) ||
            folderName.startsWith("VIRTUAL_"),
      );
      // (b) フォルダのニックネームを、実在する物理フォルダ・VIRTUAL_フォルダだけを残す
      folderNicknames.removeWhere(
        (id, _) => !tempMap.containsKey(id) && !id.startsWith("VIRTUAL_"),
      );
      // (c) 最上位の並び順リストの、実在しないフォルダ文字を消す
      parentFolderOrder.retainWhere(
        (id) =>
            id == "お気に入り・ピン留め" ||
            id == "All Songs" ||
            tempMap.containsKey(id) ||
            id.startsWith("VIRTUAL_") ||
            parentFolderMap.containsKey(id), // カスタムまとめフォルダの生存許可
      );
      // (d) フォルダループシーケンス内の実在しないフォルダを再生順から削除
      folderSequence.retainWhere(
        (id) => tempMap.containsKey(id) || id == "⭐ お気に入り",
      );
    }
  }

  // --- マップ再構築ロジック ---
  // メモリ上のデータを並び替えて最新の状態にする（ボタンタップ時などはこれだけを実行）
  void rebuildFolderStructures(List<SongModel> latestSongs) {
    // 既存のデータを取得（現状のメモリ状態）
    final folderMap = getFolderMap();
    final virtualFolderPaths = getVirtualFolderPaths();
    final favoriteSongs = getFavoriteSongs();
    final parentFolderMap = getParentFolderMap();
    final favoriteFolders = getFavoriteFolders();
    final parentFolderOrder = getParentFolderOrder();
    final folderSequence = getFolderSequence();

    // 1. musicFiles（前回のスキャン結果）から物理フォルダマップを再生成
    Map<String, List<SongModel>> tempMap = {};
    for (var song in latestSongs) {
      // 絶対パスから所属フォルダ名を切り出す
      String? folderPath = song.data.substring(0, song.data.lastIndexOf('/'));
      String folderName = folderPath.substring(folderPath.lastIndexOf('/') + 1);
      if (!tempMap.containsKey(folderName)) {
        tempMap[folderName] = [];
      }
      tempMap[folderName]!.add(song);
    }

    // 2. ユーザーが手動で並び替えた「仮想フォルダ内の固有の曲順」を復元維持する
    // (保存されたパスリスト　virtualFolderPaths の順序に SongModel を並び替えてつめなおす)
    for (var entry in virtualFolderPaths.entries) {
      final uniqueId = entry.key;
      final savedPaths = entry.value;

      if (uniqueId != "⭐ お気に入り") {
        List<SongModel> orderedSongs = [];
        for (String path in savedPaths) {
          final found = latestSongs.where((s) => s.data == path);
          if (found.isNotEmpty) {
            orderedSongs.add(found.first);
          }
        }
        tempMap[uniqueId] = orderedSongs;
      }
    }

    // 3. 「⭐ お気に入り」仮想フォルダの中身を favoriteSongs を基に再構築
    // (お気に入りに入っている曲の実体がストレージから消えていた場合も、ここで自動的に除外されます)
    tempMap["⭐ お気に入り"] = latestSongs
        .where((s) => favoriteSongs.contains(s.data))
        .toList();

    // 4. 既存の folderMapから「物理フォルダ」と「⭐ お気に入り」を一旦リフレッシュ
    folderMap.clear();
    folderMap.addAll(tempMap);

    // 5. 空フォルダの生存保証、
    // virtualFolderPathsに登録されている空の仮想フォルダを強制担保
    for (var vKey in virtualFolderPaths.keys) {
      if (!folderMap.containsKey(vKey)) {
        folderMap[vKey] = <SongModel>[]; // 空のリストでフォルダを維持
      }
    }

    // 6. システムまとめフォルダ(All Songs)の構築・更新
    // (⭐ お気に入り 以外の、物理フォルダ ＋ 空を含むすべての仮想フォルダを登録)
    parentFolderMap["All Songs"] = tempMap.keys
        .where((k) => k != "⭐ お気に入り")
        .toList();

    // 7.「お気に入り・ピン留め」まとめフォルダの中身を最新のピン留め順で更新
    List<String> favSummary = ["⭐ お気に入り"];
    for (String fName in favoriteFolders) {
      if (folderMap.containsKey(fName) && fName != "⭐ お気に入り") {
        favSummary.add(fName);
      }
    }
    parentFolderMap["お気に入り・ピン留め"] = favSummary;

    // 8. 最上位順序のクリーンアップと固定
    parentFolderOrder.remove("All Songs");
    parentFolderOrder.remove("お気に入り・ピン留め");

    parentFolderOrder.insert(0, "お気に入り・ピン留め");
    parentFolderOrder.insert(1, "All Songs");

    // 9. ユーザーが作ったカスタムまとめフォルダの「枠」を維持・復元する
    // 不要になったシステムキーだけを除外するか、
    // 現在の parentFolderOrder に存在するカスタムフォルダのキーと中身を退避して復元します。
    Map<String, List<String>> userSummaryBackup = {};
    parentFolderMap.forEach((key, value) {
      if (key != "All Songs" &&
          key != "お気に入り・ピン留め" &&
          key != FolderManager.virtualMasterKey) {
        userSummaryBackup[key] = List<String>.from(value);
      }
    });
    // 既存のマップからシステム系以外を整理し、バックアップから復元
    parentFolderMap.removeWhere(
      (key, _) => key != "All Songs" && key != "お気に入り・ピン留め",
    );
    // バックアップからカスタムまとめを復元（空のまとめもこれで維持される）
    for (String pName in parentFolderOrder) {
      if (pName != "All Songs" && pName != "お気に入り・ピン留め") {
        parentFolderMap[pName] = userSummaryBackup[pName] ?? <String>[];
      }
    }

    // 10. 初期シーケンス（フォルダループ順）の自動準備
    //（最初は「⭐ お気に入り」のみをループ対象にする）
    if (folderSequence.isEmpty) {
      folderSequence.add("⭐ お気に入り");
    }

    // setStateを反映し、UIを最新の地図にリフレッシュ
    updateUI();
  }
}
