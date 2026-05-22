/* * ファイル名: scan_manager.dart
 * 役割: 端末スキャン、物理削除データのクリーンアップ、メモリ上のフォルダ構造再構築を担う司令塔
 */

import 'package:flutter/material.dart';
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

      setMusicFiles(songs);

      // 実体が消えたデータのクリーンアップ
      cleanUpDeletedPhysicalData();
      // メモリ上のデータをもとに、フォルダ構造を組み立てる
      rebuildFolderStructures();
    } catch (e) {
      debugPrint("スキャン中にエラーが発生しました: $e"); // エラー補足
    } finally {
      isScanning = false; // 必ずフラグを戻す
      updateUI(); // setStateを反映
    }
  }

  // --- 物理ファイルが消えていた場合の周辺データの自動掃除 ---
  void cleanUpDeletedPhysicalData() {
    final musicFiles = getMusicFiles();
    final favoriteFolders = getFavoriteFolders();
    final folderMap = getFolderMap();
    final songNicknames = getSongNicknames();
    final folderNicknames = getFolderNicknames();
    final parentFolderOrder = getParentFolderOrder();
    final folderSequence = getFolderSequence();

    // 現在実在するフォルダマップを仮構築
    Map<String, List<SongModel>> tempMap = {};
    for (var song in musicFiles) {
      // 絶対パスから所属フォルダ名を切り出す
      String? folderPath = song.data.substring(0, song.data.lastIndexOf('/'));
      String folderName = folderPath.substring(folderPath.lastIndexOf('/') + 1);
      if (!tempMap.containsKey(folderName)) tempMap[folderName] = [];
      tempMap[folderName]!.add(song);
    }

    // 物理削除への自動追従（実体が消えたデータのクリーンアップ）
    // (a) ピン留めリスト(favoriteFolders)から、ストレージに存在しなくなった物理フォルダを自動削除
    favoriteFolders.retainWhere(
      (folderName) => tempMap.containsKey(folderName),
    );
    // (b) ユーザー作成の仮想フォルダ内から、ストレージに存在しなくなった実体曲を自動除外
    folderMap.forEach((key, songList) {
      if (key.startsWith("VIRTUAL_")) {
        // 今回のスキャンの結果(musicFiles)に今も残っている曲だけを生き残らせる
        songList.retainWhere(
          (virtualSong) => musicFiles.any(
            (actualSong) => actualSong.data == virtualSong.data,
          ),
        );
      }
    });
    // (c) 曲のニックネームの実在する曲のパス以外を削除
    songNicknames.removeWhere(
      (path, _) => !musicFiles.any((s) => s.data == path),
    );
    // (d) フォルダのニックネームを、実在する物理フォルダ・VIRTUAL_フォルダだけを残す
    folderNicknames.removeWhere(
      (id, _) => !tempMap.containsKey(id) && !id.startsWith("VIRTUAL_"),
    );
    // (e) 最上位の並び順リストの、実在しないフォルダ文字を消す
    parentFolderOrder.retainWhere(
      (id) =>
          id == "お気に入り・ピン留め" ||
          id == "All Songs" ||
          tempMap.containsKey(id) ||
          id.startsWith("VIRTUAL_"),
    );
    // (f) フォルダループシーケンス内の実在しないフォルダを再生順から削除
    folderSequence.retainWhere(
      (id) => tempMap.containsKey(id) || id == "⭐ お気に入り",
    );
  }

  // --- マップ再構築ロジック ---
  // メモリ上のデータを並び替えて最新の状態にする（ボタンタップ時などはこれだけを実行）
  void rebuildFolderStructures() {
    final musicFiles = getMusicFiles();
    final folderMap = getFolderMap();
    final virtualFolderPaths = getVirtualFolderPaths();
    final favoriteSongs = getFavoriteSongs();
    final parentFolderMap = getParentFolderMap();
    final favoriteFolders = getFavoriteFolders();
    final parentFolderOrder = getParentFolderOrder();
    final folderSequence = getFolderSequence();

    // 1. musicFiles（前回のスキャン結果）から物理フォルダマップを再生成
    Map<String, List<SongModel>> tempMap = {};
    for (var song in musicFiles) {
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
    virtualFolderPaths.forEach((uniqueId, savedPaths) {
      if (folderMap.containsKey(uniqueId)) {
        List<SongModel> currentVirtualSongs = folderMap[uniqueId] ?? [];
        List<SongModel> orderedSongs = [];

        for (String path in savedPaths) {
          final found = currentVirtualSongs.where((s) => s.data == path);
          if (found.isNotEmpty) {
            orderedSongs.add(found.first);
          }
        }
        folderMap[uniqueId] = orderedSongs;
      }
    });

    // 3. 「⭐ お気に入り」仮想フォルダの中身を favoriteSongs を基に再構築
    // (お気に入りに入っている曲の実体がストレージから消えていた場合も、ここで自動的に除外されます)
    tempMap["⭐ お気に入り"] = musicFiles
        .where((s) => favoriteSongs.contains(s.data))
        .toList();

    // 4. 既存の folderMap から「物理フォルダ」と「⭐ お気に入り」を一旦リフレッシュ
    // (ユーザーが作った仮想フォルダ VIRTUAL_ は消さずにそのまま残します)
    folderMap.removeWhere(
      (key, _) => !key.startsWith("VIRTUAL_") && key != "⭐ お気に入り",
    );
    folderMap.addAll(tempMap);

    // 5. システムまとめフォルダ(All Songs)の構築・更新
    parentFolderMap["All Songs"] = tempMap.keys
        .where((k) => k != "⭐ お気に入り")
        .toList();

    // 6.「お気に入り・ピン留め」まとめフォルダの中身を最新のピン留め順で更新
    List<String> favSummary = ["⭐ お気に入り"];
    favSummary.addAll(favoriteFolders.toList());
    parentFolderMap["お気に入り・ピン留め"] = favSummary;

    // 7. 最上位順序のクリーンアップと固定
    parentFolderOrder.remove("All Songs");
    parentFolderOrder.remove("お気に入り・ピン留め");

    parentFolderOrder.insert(0, "お気に入り・ピン留め");
    parentFolderOrder.insert(1, "All Songs");

    // 8. 初期シーケンス（フォルダループ順）の自動準備
    //（最初は「⭐ お気に入り」のみをループ対象にする）
    if (folderSequence.isEmpty) {
      folderSequence.add("⭐ お気に入り");
    }

    updateUI(); // setStateを反映
  }
}
