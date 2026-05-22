/*
 * ファイル名: main_screen.dart
 * 役割: UIの構築・データの更新
 */

import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_first_app/service/storage_service.dart';
import 'package:my_first_app/ui/dialogs/folder_dialogs.dart';
import 'package:my_first_app/ui/dialogs/sequence_dialog.dart';
import 'package:my_first_app/ui/widgets/bottom_action_bar.dart';
import 'package:my_first_app/ui/widgets/main_content_list.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';
// 自前ファイル
import '../../core/constants.dart';
import '../theme/app_theme.dart';
import '../../service/audio_player_service.dart';
import '../widgets/player_panel.dart'; // 再生パネル
import '../widgets/app_drawer.dart';
import '../widgets/list_header.dart';
import '../widgets/header_menu.dart';
import '../../logic/playback_controller.dart';
import '../../logic/folder_manager.dart';
import '../../logic/scan_manager.dart';

// 定数や設定だけを書く場所「看板(Widget)」
class MusicScanner extends StatefulWidget {
  final Function(ThemeMode) onThemeChanged;
  final ThemeMode currentTheme;
  const MusicScanner({
    super.key,
    required this.onThemeChanged,
    required this.currentTheme,
  });

  @override
  State<MusicScanner> createState() => _MusicScannerState();
}

// ずっと保持したい道具はこちら「楽屋(State)」
class _MusicScannerState extends State<MusicScanner> {
  //音楽を再生するためのメイン道具
  final AudioPlayerService _audioService = AudioPlayerService();

  // 上位フォルダ -> その中に入るフォルダ名のリスト
  Map<String, List<String>> parentFolderMap = {
    "All Songs": [], // ここには常に全フォルダが入る
    "好きな曲の入ったフォルダをまとめよう！": [], // 初期ガイド用フォルダ
  };
  // 選択モードかどうか
  bool isSelectionMode = false;
  // チェックを入れたフォルダ名のセット
  Set<String> selectedFolders = {};
  // チェックを入れた曲ファイルのセット
  Set<String> selectedSongPaths = {};
  // 削除モードかどうか
  bool isDeleteMode = false;
  // 並べ替えモード
  bool isSortMode = false;
  // 並び順のリスト
  List<String> parentFolderOrder = [];
  // 名前変更モードかどうか
  bool isRenameMode = false;
  // コピー作業中かどうか
  bool isCopyMode = false;
  // ファイル移動作業中かどうか
  bool isMoveMode = false;
  // 仕分けモードかどうか（AllSongs内にて）
  bool isAssignMode = false;
  // ヘッダーが開いているかどうか
  bool isHeaderOpen = false;

  // アプリ内でのフォルダの仮想名（名前変更に対応）
  Map<String, String> folderNicknames = {}; // {"物理名": "仮想名"}
  // アプリ内での曲ファイルの仮想名（名前変更に対応）
  Map<String, String> songNicknames = {}; // {"ファイルパス": "仮想曲名"}

  // 検索用の道具
  List<SongModel> musicFiles = [];
  // 現在の曲名を保存する箱
  SongModel? selectSong;

  // Scaffoldを外部から操作するための「鍵」(ドロワー)
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  // サイドメニュー内での画面切り替え用(menu / settings)のフラグ
  String drawerType = "menu";

  // 今表示しているフォルダ内の曲を入れるリスト
  List<SongModel> displayedSongs = [];
  // 今「再生中」の曲たちが属しているリスト
  List<SongModel> playlistSongs = [];
  // どのフォルダに何という曲が入っているかを整理する地図
  Map<String, List<SongModel>> folderMap = {};
  // 今どのフォルダを見ているか、空ならフォルダ一覧を表示
  String? currentFolderName;
  // 現在「再生中」の曲が属しているフォルダ名
  String? playingFolderName;
  // 今どの上位フォルダを開いているか、空なら上位フォルダ一覧を表示
  String? currentParentName;
  // 今流れている曲が属している「まとめ」の名前
  String? playingParentName;

  // 仮想フォルダID -> その中に入っている曲のパス一覧
  Map<String, List<String>> virtualFolderPaths = {};

  // { "現在のフォルダ": "次のフォルダ" }
  Map<String, String> nextFolderRoute = {};
  // 単一のシーケンス管理(All Sognsでの)
  List<String> folderSequence = [];
  // その中でループさせたいフォルダのセット
  Set<String> loopingFolders = {};

  // お気に入りの曲を管理するための箱
  Set<String> favoriteSongs = {};
  // お気に入りフォルダ名を保存する箱
  Set<String> favoriteFolders = {};

  // "play" (再生中), "pause" (一時停止), "stop" (停止)
  String status = "stop";

  // 0: 順次再生, 1: 全曲リピート, 2: 1曲リピート, 3: シャッフル
  int playMode = 1;

  // フォルダを跨いで再生するかどうか (false: フォルダ内でループ, true: 次のフォルダへ)
  bool isFolderBridgeEnabled = false;

  // 曲全体の長さ情報
  Duration duration = Duration.zero;
  // 現在の再生位置（今何秒目か）
  Duration position = Duration.zero;

  // 権限があるかどうかを覚えておく（最初は false）
  bool isPermissionGranted = false;

  late final ScanManager _scanManager;

  // listenの結果を保存する変数（後で中身を入れるので late を使います）
  late StreamSubscription _positionSubscription;
  late StreamSubscription _durationSubscription;
  late StreamSubscription _completeSubscription;

  // ループのダイアログを開いているかの更新（確認）用関数を保持する変数
  StateSetter? dialogUpdater;

  /*
    権限をリクエストする関数
  */
  Future<void> requestPermission() async {
    Map<Permission, PermissionStatus> statuses;
    if (await Permission.audio.isRestricted) {
      // 古い端末の場合
      statuses = await [Permission.storage].request();
    } else {
      // Android 13以降など
      statuses = await [Permission.audio, Permission.storage].request();
    }

    bool granted = statuses[Permission.audio]?.isGranted ?? false;
    bool storageGranted = statuses[Permission.storage]?.isGranted ?? false;

    // 上記のどちらかが許可されたらスキャンを開始する
    if (granted || storageGranted) {
      setState(() => isPermissionGranted = true); // 許可された
      _scanManager.scanDevice();
    } else {
      setState(() => isPermissionGranted = false); // 拒否された
      Future.delayed(Duration.zero, () {
        if (mounted) FolderDialogs.showPermissionDialog(context);
      });
      debugPrint("Permission Denied: Audio=$granted, Sstorage=$storageGranted");
    }
  }

  /*
    さまざまな設定をスマホに保存する関数
  */
  Future<void> _saveAllSettings() async {
    // 現在の folderMap から仮想フォルダの「パス一覧」を抽出
    Map<String, List<String>> newVirtualPaths = {};

    folderMap.forEach((key, songs) {
      if (key.startsWith("VIRTUAL_")) {
        newVirtualPaths[key] = songs.map((s) => s.data).toList();
      }
    });
    setState(() {
      // クラス変数の virtualFolderPaths も最新の状態を更新する
      virtualFolderPaths = newVirtualPaths;
    });

    await StorageService.saveAll(
      // 曲のリストを保存
      favoriteSongs: favoriteSongs,
      // フォルダのリストも保存
      favoriteFolders: favoriteFolders,
      // 跨ぎのON/OFFを保存
      isFolderBridgeEnabled: isFolderBridgeEnabled,
      // 再生モードを保存
      playMode: playMode,
      // シーケンスの保存(フォルダ跨ぎの)
      folderSequence: folderSequence,
      // 上位フォルダの地図を保存
      parentFolderMap: parentFolderMap,
      // 上位フォルダの並び順を保存
      parentFolderOrder: parentFolderOrder,
      // フォルダのニックネームMapをJSON形式で保存
      folderNicknames: folderNicknames,
      // 曲ファイルのニックネームMapをJSON形式で保存
      songNicknames: songNicknames,
      // 仮想フォルダのパス一覧を保存
      virtualFolderPaths: newVirtualPaths,
    );

    // 保存が完了したら、連動してメモリ側の地図を最新にする
    _scanManager.rebuildFolderStructures();
  }

  /* 
    保存されたさまざまな設定を読み込む関数
  */
  Future<void> _loadAllSettings() async {
    final data = await StorageService.loadAll();

    if (!mounted) return;

    setState(() {
      // お気に入り曲の読み込み
      favoriteSongs = data['favoriteSongs'];
      // お気に入りフォルダの読み込み
      favoriteFolders = data['favoriteFolders'];
      // 跨ぎのON/OFFを読み込み
      isFolderBridgeEnabled = data['isFolderBridgeEnabled'];
      // 再生モードを読み込み
      playMode = data['playMode'];
      // シーケンスの読み込み(フォルダ跨ぎの)
      folderSequence = data['folderSequence'];
      // 上位フォルダ地図 (parentFolderMap) の復元
      parentFolderMap = data['parentFolderMap'];
      // 上位フォルダの並び順を読み込み
      parentFolderOrder = data['parentFolderOrder'];
      // フォルダのニックネームMapの復元
      folderNicknames = data['folderNicknames'];
      // 曲ファイルのニックネームMapの復元
      songNicknames = data['songNicknames'];
      // 仮想フォルダのパス一覧を復元
      virtualFolderPaths = data['virtualFolderPaths'];

      // 初回起動時などでデータが空、またはAll Songsがない場合の初期化
      if (parentFolderMap.isEmpty ||
          !parentFolderMap.containsKey("All Songs")) {
        parentFolderMap = {
          "お気に入り・ピン留め": [],
          "All Songs": [],
          "好きな曲の入ったフォルダをまとめよう！": [],
        };
      }

      // Mapにあるのにリストにないフォルダ（新規追加分など）を補充
      for (var key in parentFolderMap.keys) {
        if (!parentFolderOrder.contains(key)) parentFolderOrder.add(key);
      }
      // 削除されたフォルダをリストから掃除
      parentFolderOrder.retainWhere((key) => parentFolderMap.containsKey(key));
    });
    await _saveAllSettings();
    debugPrint("--- All Settings Loaded Successfully ---");
  }

  /*
    共通部品：リストのヘッダー作成用の関数
  */
  Widget _buildUnifiedListHeader() {
    // 表示するタイトルの決定ロジック
    String title = "";
    if (currentParentName == null) {
      title = "まとめフォルダ一覧";
    } else if (currentFolderName == null) {
      title = folderNicknames[currentParentName] ?? currentParentName!;
      if (title == "All Songs") {
        title = "All Songs(フォルダ一覧)";
      }
    } else {
      // 最下層（曲一覧）の時はフォルダ名を表示
      title = folderNicknames[currentFolderName] ?? currentFolderName!;
    }

    // 条件：現在のまとめが "All Songs" かつ、まだフォルダの中に入っていない時
    bool isAllSongsSummary =
        (currentParentName == "All Songs" && currentFolderName == null);

    return ListHeader(
      title: title,
      isHeaderOpen: isHeaderOpen,
      isTopLevel: currentParentName == null,
      showPinButton:
          currentFolderName != null &&
          currentFolderName != "⭐ お気に入り" &&
          !currentFolderName!.startsWith("VIRTUAL_"), // 仮想フォルダはピン留め不可
      showSequenceButton: isAllSongsSummary,
      onSequenceTap: _showRouteSelector,
      isPinned: favoriteFolders.contains(currentFolderName),
      onHeaderTap: () => setState(() => isHeaderOpen = !isHeaderOpen),
      onBackTap: backToFolders,
      onPinTap: () {
        setState(() {
          if (favoriteFolders.contains(currentFolderName)) {
            favoriteFolders.remove(currentFolderName);
          } else {
            favoriteFolders.add(currentFolderName!);
          }
        });
        _saveAllSettings();
      },
      menuContent: _buildHeaderPopDownMenu(), // メニューの中身を渡す
    );
  }

  /*
    共通部品：ヘッダー管理メニュー作成用の関数
  */
  Widget _buildHeaderPopDownMenu() {
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
            onTap: () {},
          ), // TODO
          HeaderMenuItem(
            icon: Icons.sort,
            label: "並べ替え\n(表示順のみ)",
            onTap: () => setState(() {
              _resetModes();
              // TODO 現状では再生順も同期している isSortMode = true;
            }),
          ),
        ];
      } else if (currentFolderName == "⭐ お気に入り") {
        items = [
          HeaderMenuItem(
            icon: Icons.search,
            label: "曲検索",
            color: Colors.white60,
            onTap: () {
              // TODO 未来的に検索ロジックをここに実装
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("検索機能は今後のアップデートで実装予定です")),
              );
            },
          ),
        ];
      } else {
        // 仮想フォルダ内（自作まとめ内）：フル編集可能
        items = [
          HeaderMenuItem(
            icon: Icons.library_add,
            label: "All Songs から\n曲を追加",
            onTap: () {},
          ), // TODO
          HeaderMenuItem(
            icon: Icons.copy,
            label: "コピー",
            onTap: () => setState(() {
              _resetModes();
              isSelectionMode = true;
              isCopyMode = true;
            }),
          ),
          HeaderMenuItem(
            icon: Icons.move_up,
            label: "移動",
            onTap: () => setState(() {
              _resetModes();
              isSelectionMode = true;
              isMoveMode = true;
            }),
          ),
          HeaderMenuItem(
            icon: Icons.sort,
            label: "並べ替え\n(再生順も同期)",
            onTap: () => setState(() {
              _resetModes();
              isSortMode = true;
            }),
          ),
          HeaderMenuItem(
            icon: Icons.delete_sweep,
            label: "削除",
            color: Colors.redAccent,
            onTap: () => setState(() {
              _resetModes();
              isDeleteMode = true;
              isSelectionMode = true;
            }),
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
            onTap: () => setState(() {
              _resetModes();
              isSelectionMode = true;
              isAssignMode = true;
            }),
          ),
          HeaderMenuItem(
            icon: Icons.rule_rounded, // TODO変更
            label: "フォルダの表示・非表示\nの切り替え",
            onTap: () => setState(() {
              _resetModes();
              isSelectionMode = true;
            }), // 変更の結果はフォルダ追加・シーケンスにも影響（All Songsから一時的に抜くような対応で可能？）
          ),
        ];
      } else if (currentParentName == "お気に入り・ピン留め") {
        items = [
          HeaderMenuItem(
            icon: Icons.search,
            label: "フォルダ検索",
            color: Colors.white60,
            onTap: () {
              // TODO 未来的に検索ロジックをここに実装
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("検索機能は今後のアップデートで実装予定です")),
              );
            },
          ),
        ];
      } else {
        // --- 基本的なまとめフォルダでのメニュー ---
        items = [
          HeaderMenuItem(
            icon: Icons.add_to_photos_outlined,
            label: "All Songs から\nフォルダ追加",
            onTap: _showAddFoldersToSummaryDialog,
          ),
          HeaderMenuItem(
            icon: Icons.add_to_photos_outlined, // TODO変更
            label: "別のまとめフォルダ\nからフォルダ追加",
            onTap: () {}, // TODO
          ),
          HeaderMenuItem(
            icon: Icons.create_new_folder_outlined,
            label: "空フォルダ作成",
            onTap: _showCreateVirtualFolderDialog,
          ),
          HeaderMenuItem(
            icon: Icons.edit_note,
            label: "名前変更",
            onTap: () => setState(() {
              _resetModes();
              isRenameMode = true;
            }),
          ),
          HeaderMenuItem(
            icon: Icons.sort,
            label: "並べ替え\n(再生順も同期)",
            onTap: () => setState(() {
              _resetModes();
              isSortMode = true;
            }),
          ),
          HeaderMenuItem(
            icon: Icons.playlist_remove,
            label: "まとめから外す",
            color: Colors.orangeAccent,
            onTap: () => setState(() {
              _resetModes();
              isDeleteMode = true;
              isSelectionMode = true;
            }),
          ),
        ];
      }
    } else {
      // --- 親階層（まとめ一覧）でのメニュー ---
      items = [
        HeaderMenuItem(
          icon: Icons.create_new_folder_outlined,
          label: "まとめ\n新規作成",
          onTap: _showAddParentFolderDialog,
        ),
        HeaderMenuItem(
          icon: Icons.edit_note,
          label: "名前変更",
          onTap: () => setState(() {
            _resetModes();
            isRenameMode = true;
          }),
        ),
        HeaderMenuItem(
          icon: Icons.sort,
          label: "並べ替え",
          onTap: () => setState(() {
            _resetModes();
            isSortMode = true;
          }),
        ),
        HeaderMenuItem(
          icon: Icons.remove_circle_outline,
          label: "削除",
          color: Colors.redAccent,
          onTap: () => setState(() {
            _resetModes();
            isDeleteMode = true;
            isSelectionMode = true;
          }),
        ),
      ];
    }

    if (items.isEmpty) return const SizedBox.shrink();
    return HeaderMenu(items: items);
  }

  /*
    モードリセット用ヘルパー関数
  */
  void _resetModes() {
    setState(() {
      isDeleteMode = false;
      isSortMode = false;
      isRenameMode = false;
      isHeaderOpen = false;
      isCopyMode = false;
      isMoveMode = false;
      isSelectionMode = false;
      isAssignMode = false;
      selectedSongPaths.clear();
      selectedFolders.clear();
    });
  }

  /*
    上位フォルダ作成用（まとめフォルダ新規作成）の関数
  */
  void _showAddParentFolderDialog() {
    FolderDialogs.showCreateFolderDialog(
      context: context,
      title: "新規まとめフォルダの作成",
      hintText: "まとめフォルダ名を入力してください",
      // バリデーション：既存のまとめ名と被っていないか
      onValidate: (name) => !parentFolderMap.containsKey(name),
      onConfirm: (name) {
        if (!mounted) return;
        // すべてクリアなら作成
        setState(() {
          parentFolderMap[name] = [];
          parentFolderOrder.add(name);
        });
        _saveAllSettings();
      },
    );
  }

  /*
    上位フォルダの名前を変更する関数
  */
  void _showRenameParentFolderDialog(String oldName) {
    FolderDialogs.showCreateFolderDialog(
      context: context,
      title: "まとめフォルダ名の変更",
      hintText: "新しい名前を入力",
      initialText: oldName, // 現在の名前を初期値として渡す
      // バリデーション：自分以外で名前が被っていないか
      onValidate: (name) =>
          name == oldName || !parentFolderMap.containsKey(name),
      onConfirm: (name) {
        if (name == oldName) return; // 名前の変更がない状態なら処理終了
        setState(() {
          List<String> contents = parentFolderMap[oldName] ?? [];
          parentFolderMap[name] = contents;
          parentFolderMap.remove(oldName);
          int index = parentFolderOrder.indexOf(oldName);
          if (index != -1) parentFolderOrder[index] = name;
        });
        _saveAllSettings();
      },
    );
  }

  /*
    All Songs 内にて選択した各フォルダに対して
    「移動先を選択」する処理用の関数
  */
  void _showBatchAssignmentDialog() {
    FolderDialogs.showAssignSelectorDialog(
      context: context,
      parentFolderMap: parentFolderMap,
      onTargetSelected: _executeAssign,
      onCreateAndAssign: _executeAssign,
    );
  }

  /*
    上記に対する実際の書き込み処理
  */
  void _executeAssign(String targetParent) {
    setState(() {
      FolderManager.executeAssign(
        targetParent: targetParent,
        selectedFolders: selectedFolders,
        parentFolderMap: parentFolderMap,
        folderMap: folderMap,
        folderNicknames: folderNicknames,
        parentFolderOrder: parentFolderOrder,
        virtualFolderPaths: virtualFolderPaths,
      );
      _resetModes();
    });
    _saveAllSettings();
  }

  /*
    まとめフォルダ内に、空のフォルダを作成する関数
  */
  void _showCreateVirtualFolderDialog() {
    FolderDialogs.showCreateFolderDialog(
      context: context,
      title: "空フォルダの作成",
      hintText: "フォルダ名を入力してください",
      // バリデーション：全フォルダのニックネームと被っていないか
      onValidate: (name) =>
          !folderMap.keys.any((k) => (folderNicknames[k] ?? k) == name),
      onConfirm: (name) {
        setState(() {
          // 実体リスト(folderaMap)に空のリストとして登録
          String uniqueKey = "VIRTUAL_${DateTime.now().millisecondsSinceEpoch}";
          folderMap[uniqueKey] = [];
          folderNicknames[uniqueKey] = name; // ニックネームとして登録
          parentFolderMap[currentParentName]!.add(uniqueKey);
        });
        _saveAllSettings();
      },
    );
  }

  /*
    自作まとめフォルダにて、All Songs からフォルダを追加する関数
  */
  void _showAddFoldersToSummaryDialog() {
    FolderDialogs.showAddFoldersToSummaryDialog(
      context: context,
      currentParentName: currentParentName!,
      // 追加候補を、物理フォルダのみを管理している All Songs の名簿から取得する
      availableFolders: parentFolderMap["All Songs"] ?? [],
      folderNicknames: folderNicknames,
      onFoldersAdded: (selectedList) {
        setState(() {
          FolderManager.executeAssign(
            targetParent: currentParentName!,
            selectedFolders: selectedList, // ダイアログで選ばれたリスト
            parentFolderMap: parentFolderMap,
            folderMap: folderMap,
            folderNicknames: folderNicknames,
            parentFolderOrder: parentFolderOrder,
            virtualFolderPaths: virtualFolderPaths,
          );
        });
        _saveAllSettings();
      },
    );
  }

  /*
    物理フォルダの名前変更（仮想名）用関数
  */
  void _showRenamePhysicalFolderDialog(String id) {
    // 現在のニックネーム、無ければ物理名を初期値にする
    String oldName = folderNicknames[id] ?? id;

    FolderDialogs.showCreateFolderDialog(
      context: context,
      title: "表示名の変更",
      hintText: "新しい名前を入力してください",
      initialText: oldName,
      // バリデーション：他のフォルダ名と被っていないか
      onValidate: (name) =>
          name == oldName ||
          !folderMap.keys.any(
            (k) => k != id && (folderNicknames[k] ?? k) == name,
          ),
      onConfirm: (name) {
        if (name == oldName) return; // 名前の変更がない状態なら処理終了
        setState(() {
          folderNicknames[id] = name;
        });
        _saveAllSettings();
      },
    );
  }

  /*
    画面下部の確定（実行）ボタンの、各モードに応じた処理関数
  */
  void _executeBulkAction() {
    if (isDeleteMode) {
      _executeBulkDelete();
    } else if (isSortMode) {
      // 並び替えは ReorderableListView で即時反映されていることが多いですが、
      // ここで最終的な保存をかけると確実です。
      _saveAllSettings();
      _resetModes();
    } else if (isRenameMode) {
      _resetModes();
    } else if (isCopyMode || isMoveMode) {
      // 今後実装するコピー・移動の確定処理
      // _executeBulkMove(); など
      _resetModes();
    } else if (isAssignMode) {
      _showBatchAssignmentDialog();
    }
  }

  /*
    削除の確認用関数
  */
  void _confirmBulkAction() {
    // 削除モードの時だけ確認ダイアログを出す
    if (isDeleteMode) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppTheme(context).exitBackground,
          title: const Text("一括削除の確認", style: TextStyle(fontSize: 17)),
          content: Text(
            "${selectedFolders.length + selectedSongPaths.length} 件のアイテムを除外しますか？\n（元のファイルは削除されません）",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("キャンセル"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
              ),
              onPressed: () {
                Navigator.pop(context);
                _executeBulkDelete(); // 実際の削除ロジックへ
              },
              child: const Text(
                "削除実行",
                style: TextStyle(color: Colors.orangeAccent),
              ),
            ),
          ],
        ),
      );
    } else {
      // 削除以外（移動・コピー等）ならそのまま実行
      _executeBulkAction();
    }
  }

  /*
    全階層での一括削除（除外）を実行する関数
  */
  void _executeBulkDelete() {
    setState(() {
      FolderManager.executeBulkDelete(
        // 現在の階層に応じて、選択されているIDセットを渡す
        selectedIds: currentFolderName == null
            ? selectedFolders
            : selectedSongPaths,
        currentParentName: currentParentName,
        currentFolderName: currentFolderName,
        parentFolderMap: parentFolderMap,
        folderMap: folderMap,
        folderNicknames: folderNicknames,
        parentFolderOrder: parentFolderOrder,
        virtualFolderPaths: virtualFolderPaths,
      );
      // モード解除と選択解除
      _resetModes();
    });
    _saveAllSettings();
  }

  /*
    曲ファイルの移動・コピー用（自作まとめフォルダ内）関数
  */
  void _showDestinationFolderSelector() {
    // 現在自分がいる「まとめ」の中にあるフォルダたちを候補にする（自分自身は除外）
    List<String> destinations = (parentFolderMap[currentParentName] ?? [])
        .where((id) => id != currentFolderName)
        .toList();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme(context).sequenceBackground,
        title: Text(
          isCopyMode ? "コピー先を選択" : "移動先を選択",
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: destinations.isEmpty
            ? const Text(
                "移動可能なフォルダがありません",
                style: TextStyle(color: Colors.white70),
              )
            : SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: destinations.length,
                  itemBuilder: (context, index) {
                    String id = destinations[index];
                    String name = folderNicknames[id] ?? id;
                    return ListTile(
                      leading: const Icon(Icons.folder, color: Colors.amber),
                      title: Text(
                        name,
                        style: const TextStyle(color: Colors.white),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        _executeMoveOrCopy(id);
                      },
                    );
                  },
                ),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("キャンセル"),
          ),
        ],
      ),
    );
  }

  /*
    上記に従って、データの移し替え回路
  */
  void _executeMoveOrCopy(String targetFolderId) {
    // 移動対象のSongModelたちを確保
    List<SongModel> targets = displayedSongs
        .where((s) => selectedSongPaths.contains(s.data))
        .toList();

    if (targets.isEmpty) return;

    setState(() {
      // コピー（移動）先に追加
      if (!folderMap.containsKey(targetFolderId)) {
        folderMap[targetFolderId] = [];
      }
      folderMap[targetFolderId]!.addAll(targets);

      // 移動モードなら、現在のフォルダから削除
      if (isMoveMode) {
        folderMap[currentFolderName]!.removeWhere(
          (s) => selectedSongPaths.contains(s.data),
        );
        displayedSongs = List.from(folderMap[currentFolderName]!);
      }
      // モード解除とクリーンアップ
      _resetModes();
    });
    _saveAllSettings();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("${targets.length}曲を${isCopyMode ? 'コピー' : '移動'}しました"),
      ),
    );
  }

  /*
    フォルダをタップして中に入る関数
  */
  void enterFolder(String folderName) {
    _resetModes();
    setState(() {
      currentFolderName = folderName;
      // 地図からそのフォルダの曲リストを取り出して表示用にセット
      displayedSongs = folderMap[folderName] ?? [];
    });
  }

  /*
    戻るボタン関数
  */
  void backToFolders() {
    _resetModes();
    setState(() {
      if (currentFolderName != null) {
        // 曲一覧からフォルダ一覧へ戻る
        currentFolderName = null; // 名前を空っぽにすれば一覧に戻る合図
        displayedSongs = [];
        isHeaderOpen = false; // フォルダから出る時にフォルダ名の展開状態をリセット
      } else {
        // フォルダ一覧から「まとめ一覧」へ戻る
        currentParentName = null;
      }
    });
    if (!mounted) return;
  }

  /*
    シーケンス設定でのフォルダ選択の関数
  */
  void _showRouteSelector() async {
    SequenceDialog.show(
      context: context,
      folderSequence: folderSequence,
      folderMap: folderMap,
      playingFolderName: playingFolderName,
      onStateSetterCreated: (setter) => dialogUpdater = setter,
      onSave: (newSequence) {
        setState(() => folderSequence = newSequence);
        _saveAllSettings();
      },
    );
  }

  /*
    次または前の曲を「フォルダ移動も含めて」計算し、再生すべき曲を返す関数
  */
  SongModel? _calculateTarget(bool isNext, {bool isAutomatic = false}) {
    return PlaybackController.getTargetSong(
      isNext: isNext, // trueなら次、falseなら前
      isAutomatic: isAutomatic,
      playlistSongs: playlistSongs,
      selectSong: selectSong,
      isFolderBridgeEnabled: isFolderBridgeEnabled,
      playMode: playMode,
      playingFolderName: playingFolderName,
      playingParentName: playingParentName,
      folderSequence: folderSequence,
      parentFolderMap: parentFolderMap,
      folderMap: folderMap,
      // フォルダが移動した場合の画面更新処理
      onFolderChanged: (nextFolderName, nextSongs) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() {
            playingFolderName = nextFolderName; // 再生中リストを更新
            playlistSongs = nextSongs; // 再生リストを入替え
            // ユーザがフォルダ画面を開いているなら、表示も追従させる
            if (currentFolderName != null) {
              currentFolderName = nextFolderName;
              displayedSongs = nextSongs;
            }
          });
        });
      },
    );
  }

  /* 
    次の曲を再生する関数
  */
  void playNextSong({bool isAutomatic = false}) {
    // 1曲リピートのみの自動遷移時のみ
    if (isAutomatic && playMode == 2 && selectSong != null) {
      _audioService.play(selectSong!.data);
      return;
    }
    // 次を再生する
    _executePlay(_calculateTarget(true, isAutomatic: isAutomatic));
  }

  /*
    前の曲に戻る関数
  */
  void playPreviousSong() {
    // 前を再生する
    _executePlay(_calculateTarget(false, isAutomatic: false));
  }

  /*
    曲を再生する関数
  */
  void _executePlay(SongModel? target) {
    if (target != null) {
      setState(() {
        selectSong = target;
        status = "play";
        // フォルダを跨いだ場合、playlistSongsは_calculateTarget内で更新済み
      });
      _audioService.play(target.data);
      // 曲が切り替わった（＝フォルダが変わった可能性がある）時だけ
      // ダイアログが開いていれば描き直させる
      if (dialogUpdater != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (dialogUpdater != null) {
            dialogUpdater!(() {});
          }
        });
      }
    } else {
      //次の曲がない、またはエラー時は停止
      _audioService.stop();
      setState(() => status = "stop");
    }
  }

  /*
    再生ボタン・一時停止ボタンを押したときの関数
  */
  void _handlePlayPause() async {
    if (status == "play") {
      await _audioService.pause();
      setState(() => status = "pause");
    } else {
      if (selectSong == null && displayedSongs.isNotEmpty) {
        setState(() {
          playlistSongs = List.from(displayedSongs);
          playingFolderName = currentFolderName;
        });
        _executePlay(playlistSongs[0]);
      } else if (selectSong != null) {
        status == "pause"
            ? await _audioService.resume()
            : _executePlay(selectSong);
        setState(() => status = "play");
      }
    }
  }

  /*
    アプリ終了の確認ダイアログ関数
  */
  void _showExitDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme(context).exitBackground,
        title: Text(
          "アプリの終了",
          style: TextStyle(color: AppTheme(context).exitBigText),
        ),
        content: Text(
          "アプリを閉じますか？\n(再生中の音楽は停止します)",
          style: TextStyle(color: AppTheme(context).exitSmallText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), // ダイアログを閉じるだけ
            child: const Text(
              "キャンセル",
              style: TextStyle(color: Colors.lightBlueAccent),
            ),
          ),
          TextButton(
            onPressed: () {
              _audioService.stop(); // ダイアログを閉じるだけ
              SystemNavigator.pop();
            },
            child: const Text(
              "終了",
              style: TextStyle(color: Color.fromARGB(255, 255, 60, 120)),
            ),
          ),
        ],
      ),
    );
  }

  @override // 画面が生まれた瞬間に実行する処理
  void initState() {
    super.initState();

    // ScanManager の初期化と main_screen 側のデータ構造の紐付け
    _scanManager = ScanManager(
      getMusicFiles: () => musicFiles,
      setMusicFiles: (songs) => musicFiles = songs,
      getFolderMap: () => folderMap,
      getParentFolderMap: () => parentFolderMap,
      getParentFolderOrder: () => parentFolderOrder,
      getFolderSequence: () => folderSequence,
      getFavoriteFolders: () => favoriteFolders,
      getFavoriteSongs: () => favoriteSongs,
      getVirtualFolderPaths: () => virtualFolderPaths,
      getSongNicknames: () => songNicknames,
      getFolderNicknames: () => folderNicknames,
      updateUI: () => setState(() {}),
    );

    // アプリが立ち上がった瞬間に、設定読み込みと権限チェック
    _initializeHOS();
  }

  /*
    HOSの起動シーケンス関数
  */
  Future<void> _initializeHOS() async {
    // 1. ローカルに保存されている設定（お気に入りやニックネームなど）を復元
    debugPrint("HOS: 設定の読み込み開始...");
    await _loadAllSettings();
    debugPrint("HOS: 設定の読み込み完了。権限確認開始...");

    // 2. ScanManager経由でスマホの全曲物理スキャンを実行
    await _scanManager.scanDevice();

    // 3．監視役を登録して、変数に代入しておく
    _completeSubscription = _audioService.onPlayerComplete.listen((_) {
      playNextSong(isAutomatic: true); // 自動であることの証明
    });
    _durationSubscription = _audioService.onDurationChanged.listen((
      newDuration,
    ) {
      if (!mounted) return; // 画面が消えていたら何もしない
      setState(() => duration = newDuration);
    });
    _positionSubscription = _audioService.onPositionChanged.listen((
      newPosition,
    ) {
      if (!mounted) return; // 画面が消えていたら何もしない
      setState(() => position = newPosition);
    });

    // 4. 権限のリクエスト
    await requestPermission();
    debugPrint("HOS: 初期化シーケンス完了。");
  }

  /*
    モード選択メニューの共通関数
  */

  @override // 画面の見た目の処理
  Widget build(BuildContext context) {
    // --- 現在どのモードか特定する ---
    bool isAnyMode =
        isDeleteMode ||
        isSortMode ||
        isRenameMode ||
        isCopyMode ||
        isMoveMode ||
        isSelectionMode;
    String currentModeName = "";
    String currentActionLabel = "";
    if (isDeleteMode) {
      currentModeName = "削除";
      currentActionLabel = currentParentName == null ? "まとめて削除" : "一括除外";
    } else if (isSortMode) {
      currentModeName = "並び替え";
      currentActionLabel = "順序を保存";
    } else if (isRenameMode) {
      currentModeName = "名前変更";
      currentActionLabel = "変更を適用";
    } else if (isCopyMode) {
      currentModeName = "コピー";
      currentActionLabel = "ここにコピー";
    } else if (isAssignMode) {
      currentModeName = "仕分け";
      currentActionLabel = "仕分け先を\n選択";
    }
    // 選択件数の集計
    int selectedCount = currentFolderName == null
        ? selectedFolders.length
        : selectedSongPaths.length;

    return PopScope(
      canPop: false, // 勝手にアプリが閉じないようにする「関所」
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        if (_scaffoldKey.currentState?.isDrawerOpen ?? false) return;

        // モード中なら、戻るボタンの代わりにモードをリセットする
        if (isAnyMode) {
          _resetModes();
        }
        // もし下位フォルダまたは、上位フォルダの中にいるなら
        else if (currentFolderName != null || currentParentName != null) {
          backToFolders();
        } else {
          // どこにも属さない（一番上の階層）にいるなら、確認ダイアログを出す
          _showExitDialog();
        }
      },
      child: Scaffold(
        key: _scaffoldKey, // 鍵を接続
        // 画面全体の背景色の設定
        backgroundColor: AppTheme(context).mainBackground,

        // --- 左から出てくるメニュー（ドロワー） ---
        drawer: AppDrawer(
          drawerType: drawerType, // 現在の状態を渡す
          onTypeChanged: (type) =>
              setState(() => drawerType = type), // 切り替えを記録する
          currentTheme: widget.currentTheme,
          onThemeChanged: widget.onThemeChanged,
          onScanPressed: () {
            // スキャンを手動で開始
            Navigator.pop(context); // メニューを閉じる
            _scanManager.scanDevice();
          },
        ),

        // --- 画面本体 ---
        body: SafeArea(
          child: Column(
            children: [
              // 再生パネル
              PlayerPanel(
                selectSong: selectSong,
                status: status,
                duration: duration,
                position: position,
                playMode: playMode,
                isFolderBridgeEnabled: isFolderBridgeEnabled,
                currentIndex: selectSong != null
                    ? playlistSongs.indexOf(selectSong!) + 1
                    : 0,
                totalCount: playlistSongs.length,
                onMenuPressed: () {
                  _scaffoldKey.currentState?.openDrawer();
                },
                onPlayPausePressed: _handlePlayPause,
                onNextPressed: () => playNextSong(isAutomatic: false),
                onPreviousPressed: playPreviousSong,
                onContinuousSkipStart: (isNext) {
                  _audioService.startContinuousSkip(isNext, () {
                    if (isNext) {
                      playNextSong(isAutomatic: false);
                    } else {
                      playPreviousSong();
                    }
                  });
                },
                onContinuousSkipStop: _audioService.stopContinuousSkip,
                onSeek: (val) =>
                    _audioService.seek(Duration(seconds: val.toInt())),
                onModeToggle: () {
                  setState(() {
                    playMode = (playMode + 1) % 4;
                  });
                  _saveAllSettings();
                },
                onBridgeToggle: () {
                  setState(
                    () => isFolderBridgeEnabled = !isFolderBridgeEnabled,
                  );
                  _saveAllSettings();
                },
              ),

              const Divider(height: 1, color: Colors.white24), // 境界線
              // リストヘッダー部分
              _buildUnifiedListHeader(),

              // リスト本体
              Expanded(
                child: Stack(
                  children: [
                    // メインリストの表示
                    MainContentList(
                      // --- 現在の階層に応じたレベルとアイテムを切り替える ---
                      level: currentParentName == null
                          ? ViewLevel.parent
                          : (currentFolderName == null
                                ? ViewLevel.sub
                                : ViewLevel.song),
                      items: currentParentName == null
                          ? parentFolderOrder
                                .where(
                                  (k) => k != FolderManager.virtualMasterKey,
                                )
                                .toList() // マスターリストは隠す
                          : (currentFolderName == null
                                ? (parentFolderMap[currentParentName] ??
                                      []) // 既にAll Songs は物理のみなのでフィルタ不要
                                : displayedSongs),
                      // --- 状態の受け渡し ---
                      playingId: (currentFolderName != null)
                          ? selectSong?.data
                          : (currentParentName == null
                                ? playingParentName
                                : playingFolderName),
                      selectedIds: currentFolderName == null
                          ? selectedFolders
                          : selectedSongPaths,
                      isSelectionMode: isSelectionMode,
                      isSortMode: isSortMode,
                      isRenameMode: isRenameMode,
                      isDeleteMode: isDeleteMode,
                      //「⭐ お気に入り」という名前のフォルダ自体は、お気に入り(スター)対象から除外する
                      favoriteIds: currentFolderName != null
                          ? favoriteSongs // 曲一覧を表示中なら、常にfavoriteSongsを渡す
                          : (currentParentName == "お気に入り・ピン留め"
                                ? favoriteFolders
                                      .where((f) => f != "⭐ お気に入り")
                                      .toSet()
                                : favoriteFolders),
                      nicknames: currentFolderName == null
                          ? folderNicknames
                          : songNicknames,
                      // --- 各種操作ロジック（既存の関数をつなぐ） ---
                      onTap: (item, index) {
                        final id = (item is SongModel)
                            ? item.data
                            : item.toString();
                        // 最上位階層（まとめ一覧）にいる時、特定のフォルダは操作させない
                        bool isSystemFolder =
                            (id == "All Songs" || id == "お気に入り・ピン留め");

                        // 1. タップ時のロジック
                        if (isSelectionMode) {
                          // システムフォルダならチェックを入れさせない
                          if (currentParentName == null && isSystemFolder) {
                            return;
                          }

                          setState(() {
                            final id = (item is SongModel)
                                ? item.data
                                : item.toString();
                            if (currentFolderName == null) {
                              selectedFolders.contains(id)
                                  ? selectedFolders.remove(id)
                                  : selectedFolders.add(id);
                            } else {
                              selectedSongPaths.contains(id)
                                  ? selectedSongPaths.remove(id)
                                  : selectedSongPaths.add(id);
                            }
                          });
                          return;
                        }
                        if (isSortMode || isRenameMode) return;

                        _resetModes();
                        if (currentParentName == null) {
                          setState(() => currentParentName = item.toString());
                        } else if (currentFolderName == null) {
                          enterFolder(item.toString());
                        } else {
                          setState(() {
                            playlistSongs = List.from(displayedSongs);
                            playingFolderName = currentFolderName;
                            playingParentName = currentParentName;
                          });
                          _executePlay(item as SongModel);
                        }
                      },
                      onReorder: (oldIdx, newIdx) {
                        // 2. 並び替え時のロジック
                        setState(() {
                          if (oldIdx < newIdx) newIdx -= 1;

                          if (currentParentName == null) {
                            if (oldIdx <= 1 || newIdx <= 1) {
                              return; // 0番目(お気に入り)と1番目(All Songs)は動かさない
                            }
                            final item = parentFolderOrder.removeAt(oldIdx);
                            parentFolderOrder.insert(newIdx, item);
                          } else if (currentFolderName == null) {
                            final list = parentFolderMap[currentParentName!]!;
                            final item = list.removeAt(oldIdx);
                            list.insert(newIdx, item);
                          } else {
                            final item = displayedSongs.removeAt(oldIdx);
                            displayedSongs.insert(newIdx, item);
                            folderMap[currentFolderName!] =
                                List<SongModel>.from(displayedSongs);
                          }
                        });
                        _saveAllSettings();
                      },
                      onCheckboxChanged: (item, val) {
                        // 3. チェックボックスの変更時ロジック
                        setState(() {
                          final id = (item is SongModel)
                              ? item.data
                              : item.toString();
                          if (currentFolderName == null) {
                            val!
                                ? selectedFolders.add(id)
                                : selectedFolders.remove(id);
                          } else {
                            val!
                                ? selectedSongPaths.add(id)
                                : selectedSongPaths.remove(id);
                          }
                        });
                      },
                      onFavoriteTap: (item) {
                        // 4. お気に入り（スター/ピン）タップ時のロジック
                        final id = (item is SongModel)
                            ? item.data
                            : item.toString();

                        // 「⭐ お気に入り」フォルダそのものは触れないようにガード
                        if (currentParentName == "お気に入り・ピン留め" &&
                            id == "⭐ お気に入り") {
                          return;
                        }
                        // 仮想フォルダならピン留めをしない
                        if (id.startsWith("VIRTUAL_")) {
                          return;
                        }

                        setState(() {
                          if (item is SongModel) {
                            // 曲のお気に入り登録・解除
                            favoriteSongs.contains(id)
                                ? favoriteSongs.remove(id)
                                : favoriteSongs.add(id);
                          } else {
                            // 物理フォルダのピン留め登録・解除
                            favoriteFolders.contains(id)
                                ? favoriteFolders.remove(id)
                                : favoriteFolders.add(id);
                          }
                        });
                        _saveAllSettings();
                      },
                      onRenameTap: (item) {
                        // 5. 名前変更タップ時のロジック
                        final id = item.toString();
                        if (currentParentName == null) {
                          _showRenameParentFolderDialog(id);
                        } else {
                          _showRenamePhysicalFolderDialog(id);
                        }
                      },
                      onDeleteTap: (item) {
                        // 6. 削除タップ時のロジック
                        final id = item.toString();
                        // 個別削除ボタンも「1件選択して一括削除ロジックに投げる」形に統一すると非常にシンプルです
                        FolderDialogs.confirmDelete(
                          context: context,
                          name: folderNicknames[id] ?? id,
                          parentFolderMap: parentFolderMap,
                          folderNicknames: folderNicknames,
                          onConfirm: () {
                            setState(() {
                              FolderManager.executeBulkDelete(
                                selectedIds: {id}, // 1件だけのセットとして渡す
                                currentParentName: currentParentName,
                                currentFolderName: currentFolderName,
                                parentFolderMap: parentFolderMap,
                                folderMap: folderMap,
                                folderNicknames: folderNicknames,
                                parentFolderOrder: parentFolderOrder,
                                virtualFolderPaths: virtualFolderPaths,
                              );
                            });
                            _saveAllSettings();
                          },
                        );
                      },
                    ),

                    // 下から出てくるメニュー
                    if (isAnyMode)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: BottomActionBar(
                          count: selectedCount,
                          modeName: currentModeName,
                          actionLabel: currentActionLabel,
                          onExecute: _confirmBulkAction, // 各モードに応じた一括処理関数へ
                          onCancel: _resetModes,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        floatingActionButton:
            (isSelectionMode &&
                selectedSongPaths.isNotEmpty &&
                (isCopyMode || isMoveMode))
            ? FloatingActionButton.extended(
                backgroundColor: isCopyMode
                    ? Colors.blueAccent
                    : Colors.orangeAccent,
                onPressed: _showDestinationFolderSelector,
                icon: Icon(isCopyMode ? Icons.copy : Icons.move_up),
                label: Text(isCopyMode ? "コピー先を選択" : "移動先を選択"),
              )
            : null,
      ),
    );
  }

  @override // 画面が消える時の後片付け
  void dispose() {
    _audioService.dispose(); // アプリ終了時に呼び出す
    // 耳(listen)を閉じる
    _completeSubscription.cancel();
    _durationSubscription.cancel();
    _positionSubscription.cancel();

    dialogUpdater = null;
    super.dispose();
  }
}
