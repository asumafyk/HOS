/* 
 * ファイル名: storage_service.dart
 * 役割: 設定（お気に入り、フォルダ構成、ニックネーム等）の永続化（保存と読み込み）
 */

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  // 保存するための鍵（タイポを防ぐために定数に）
  static const String _keyFavoriteSongs = "favorite_songs";
  static const String _keyFavoriteFolders = "favorite_folders";
  static const String _keyBridgeEnabled = "is_folder_bridge_enabled";
  static const String _keyFolderSequence = "folder_sequence";
  static const String _keyParentFolderMap = "parent_folder_map";
  static const String _keyParentFolderOrder = "parent_folder_order";
  static const String _keyFolderNicknames = "folder_nicknames";
  static const String _keySongNicknames = "song_nicknames";
  static const String _keyVirtualPaths = "virtual_folder_paths";
  static const String _keyPlayMode = 'play_mode';

  // --- 全ての設定を一括保存する ---
  static Future<void> saveAll({
    required Set<String> favoriteSongs,
    required Set<String> favoriteFolders,
    required bool isFolderBridgeEnabled,
    required List<String> folderSequence,
    required Map<String, List<String>> parentFolderMap,
    required List<String> parentFolderOrder,
    required Map<String, String> folderNicknames,
    required Map<String, String> songNicknames,
    required Map<String, List<String>> virtualFolderPaths,
    required int playMode,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    // 曲のリストを保存
    await prefs.setStringList(_keyFavoriteSongs, favoriteSongs.toList());
    // フォルダのリストも保存
    await prefs.setStringList(_keyFavoriteFolders, favoriteFolders.toList());
    // 跨ぎのON/OFFを保存
    await prefs.setBool(_keyBridgeEnabled, isFolderBridgeEnabled);
    // シーケンスの保存(フォルダ跨ぎの)
    await prefs.setStringList(_keyFolderSequence, folderSequence);
    // 上位フォルダの並び順を保存
    await prefs.setStringList(_keyParentFolderOrder, parentFolderOrder);
    // 再生モードを保存
    await prefs.setInt(_keyPlayMode, playMode);

    //--- Map系はJSONに変換して保存 ---

    // 上位フォルダの地図を保存
    await prefs.setString(_keyParentFolderMap, jsonEncode(parentFolderMap));
    // フォルダのニックネームMapをJSON形式で保存
    await prefs.setString(_keyFolderNicknames, jsonEncode(folderNicknames));
    // 曲ファイルのニックネームMapをJSON形式で保存
    await prefs.setString(_keySongNicknames, jsonEncode(songNicknames));
    // 仮想フォルダのパス一覧を保存
    await prefs.setString(_keyVirtualPaths, jsonEncode(virtualFolderPaths));
  }

  // --- 保存されたデータを読み込む（Map形式でまとめて返す）---
  static Future<Map<String, dynamic>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();

    return {
      // お気に入り曲の読み込み
      'favoriteSongs':
          prefs.getStringList(_keyFavoriteSongs)?.toSet() ?? <String>{},
      // お気に入りフォルダの読み込み
      'favoriteFolders':
          prefs.getStringList(_keyFavoriteFolders)?.toSet() ?? <String>{},
      // 跨ぎのON/OFFを読み込み
      'isFolderBridgeEnabled': prefs.getBool(_keyBridgeEnabled) ?? false,
      // シーケンスの読み込み(フォルダ跨ぎの)
      'folderSequence': prefs.getStringList(_keyFolderSequence) ?? <String>[],
      // 上位フォルダの並び順を読み込み
      'parentFolderOrder':
          prefs.getStringList(_keyParentFolderOrder) ?? <String>[],
      // 再生モードを読み込み
      'playMode': prefs.getInt(_keyPlayMode) ?? 1, // 未保持ならデフォルト(1:全曲ループ再生)
      // 上位フォルダ地図 (parentFolderMap) の復元
      'parentFolderMap': _decodeMap(prefs.getString(_keyParentFolderMap)),
      // フォルダのニックネームMapの復元
      'folderNicknames': _decodeStringMap(prefs.getString(_keyFolderNicknames)),
      // 曲ファイルのニックネームMapの復元
      'songNicknames': _decodeStringMap(prefs.getString(_keySongNicknames)),
      // 仮想フォルダのパス一覧を復元
      'virtualFolderPaths': _decodeMap(prefs.getString(_keyVirtualPaths)),
    };
  }

  // JSONデコード用の補助関数(List<String>用)
  static Map<String, List<String>> _decodeMap(String? jsonStr) {
    if (jsonStr == null) return {};
    try {
      Map<String, dynamic> decoded = jsonDecode(jsonStr);
      return decoded.map(
        (key, value) => MapEntry(key, List<String>.from(value)),
      );
    } catch (e) {
      return {};
    }
  }

  // JSONデコード用の補助関数(String用)
  static Map<String, String> _decodeStringMap(String? jsonStr) {
    if (jsonStr == null) return {};
    try {
      return Map<String, String>.from(jsonDecode(jsonStr));
    } catch (e) {
      return {};
    }
  }
}
