/* * ファイル名: playback_controller.dart
 * 役割: 「次は何の曲か？」というHOS独自の再生ルール
 * （跨ぎ・リピート・シャッフル）を計算する司令塔
 */

import 'dart:math';
import 'package:on_audio_query/on_audio_query.dart';

class PlaybackController {
  // 次または前の曲を「フォルダ移動も含めて」計算し、再生すべき曲を返す
  static SongModel? getTargetSong({
    required bool isNext, // true:次、false:前
    required bool isAutomatic, // 手動かどうか true:自動
    required List<SongModel> playlistSongs,
    required SongModel? selectSong,
    required bool isFolderBridgeEnabled,
    required int playMode,
    required String? playingFolderName,
    required String? playingParentName,
    required List<String> folderSequence,
    required Map<String, List<String>> parentFolderMap,
    required Map<String, List<SongModel>> folderMap,
    // フォルダが移動したことをメイン画面に伝えるためのコールバック
    required Function(String nextFolderName, List<SongModel> nextSongs)
    onFolderChanged,
  }) {
    // 再生リストが空、または現在選択されている曲がない場合は中断
    if (playlistSongs.isEmpty || selectSong == null) return null;

    int currentSongIndex = playlistSongs.indexOf(selectSong);
    if (currentSongIndex == -1) return null;

    // --- グローバルシャッフル（跨ぎONのシャッフルモード）---
    if (isFolderBridgeEnabled && playMode == 3) {
      List<String> currentLoopList = (playingParentName == "All Songs")
          ? folderSequence
          : (parentFolderMap[playingParentName] ?? []);
      if (currentLoopList.isNotEmpty) {
        // 対象フォルダ群からランダムに1つ選択
        String randomFolder =
            currentLoopList[Random().nextInt(currentLoopList.length)];
        List<SongModel> randomSongs = folderMap[randomFolder] ?? [];
        if (randomSongs.isNotEmpty) {
          // そのフォルダの中からランダムに1曲選択
          SongModel targetSongIndex =
              randomSongs[Random().nextInt(randomSongs.length)];
          // フォルダが移動する場合は状態を更新
          if (playingFolderName != randomFolder) {
            onFolderChanged(randomFolder, randomSongs);
          }
          return targetSongIndex;
        }
      }
    }

    // --- 同一フォルダ内でのインデックス計算（通常）---
    int targetIndex = isNext ? (currentSongIndex + 1) : (currentSongIndex - 1);

    // --- シャッフルモードの次曲計算（跨ぎOFFの時）---
    if (!isFolderBridgeEnabled && isNext && playMode == 3) {
      targetIndex =
          (currentSongIndex +
              1 +
              Random().nextInt(max(1, playlistSongs.length - 1))) %
          playlistSongs.length;
    }

    // フォルダの境界を越えたかどうかの判定
    bool isOutOfBounds = isNext
        ? (targetIndex >= playlistSongs.length)
        : (targetIndex < 0);

    // --- 以下フォルダ境界を越えたときの処理 --- //

    if (isOutOfBounds) {
      // --- 跨ぎが無効、または個別ループ設定なら、今のフォルダ内でループ(手動) ---
      if (!isFolderBridgeEnabled || playMode == 2) {
        return playlistSongs[isNext ? 0 : playlistSongs.length - 1];
      }
      // 再生順を決定する「LoopList」の作成
      List<String> currentLoopList;
      if (playingParentName == "All Songs") {
        // All Songs 階層では「シーケンス設定」の名簿を使う
        currentLoopList = folderSequence;
      } else {
        // 自作まとめ階層では、そのフォルダに入っている並び順をそのまま使う
        currentLoopList = parentFolderMap[playingParentName] ?? [];
      }

      // 目録の中で「今再生しているフォルダ」が何番目にあるか探す
      int currentFolderIndex = currentLoopList.indexOf(playingFolderName ?? "");

      // 目録の中の今のフォルダが存在する場合のみ、隣のフォルダへの移動を試みる
      if (currentFolderIndex != -1) {
        int targetFolderIndex = isNext
            ? currentFolderIndex + 1
            : currentFolderIndex - 1;
        // 目録の端（最初または最後）に到達した場合のループ処理
        if (targetFolderIndex < 0 ||
            targetFolderIndex >= currentLoopList.length) {
          if (playMode == 1 || isAutomatic) {
            // 全曲リピート設定(または手動の1曲リピート・順次再生)なら、目録の反対側の端に戻る
            targetFolderIndex = isNext ? 0 : currentLoopList.length - 1;
          } else {
            // 順次再生かつフォルダが最後なら、止まる
            return null;
          }
        }
        // 移動先のフォルダ名を取得
        String targetFolderName = currentLoopList[targetFolderIndex];
        List<SongModel> nextSongs = folderMap[targetFolderName] ?? [];
        // 次のフォルダに曲が入っていれば、状態を更新して移動
        if (nextSongs.isNotEmpty) {
          // 画面側に通知
          onFolderChanged(targetFolderName, nextSongs);
          // 次のフォルダの「最初の曲」または「最後の曲」を返す
          return nextSongs[isNext ? 0 : nextSongs.length - 1];
        } else {
          // TODO 次フォルダに曲がない場合はさらに次へ行く
          // 3回までは繰り返し飛ばしていいものとする？（空ばっかりだったらループしすぎてしまうため）
        }
      }
      // 目録外だった場合や次のフォルダが空だった場合は、今のフォルダ内でループ
      return playlistSongs[isNext ? 0 : playlistSongs.length - 1];
    }
    // 境界を越えていない場合は、そのまま同じリスト内の曲を返す
    return playlistSongs[targetIndex];
  }
}
