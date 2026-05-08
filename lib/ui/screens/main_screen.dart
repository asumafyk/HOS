/*
  メイン画面
*/
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_first_app/service/storage_service.dart';
import 'package:my_first_app/ui/dialogs/folder_dialogs.dart';
import 'package:my_first_app/ui/widgets/bottom_action_bar.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';
// 自前ファイル
import 'package:my_first_app/core/constants.dart';
import 'package:my_first_app/ui/theme/app_theme.dart';
import '../../service/audio_player_service.dart';
import '../widgets/music_tile.dart';
import '../widgets/player_panel.dart'; // 再生パネル
import '../widgets/app_drawer.dart';

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
  final OnAudioQuery _audioQuery = OnAudioQuery();
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
  // 単一のシーケンス管理
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

  // スキャン中かどうかを判定するフラグ(2重実行防止用)
  bool _isScanning = false;

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
      setState(() {
        isPermissionGranted = true; // 許可された
      });
      scanDevice();
    } else {
      setState(() {
        isPermissionGranted = false; // 拒否された
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
        parentFolderMap = {"All Songs": [], "好きな曲の入ったフォルダをまとめよう！": []};
      }

      // Mapにあるのにリストにないフォルダ（新規追加分など）を補充
      for (var key in parentFolderMap.keys) {
        if (!parentFolderOrder.contains(key)) parentFolderOrder.add(key);
      }
      // 削除されたフォルダをリストから掃除
      parentFolderOrder.retainWhere((key) => parentFolderMap.containsKey(key));
    });
    debugPrint("--- All Settings Loaded Successfully ---");
  }

  /*
    デバイス内から音楽ファイルを探す関数
  */
  Future<void> scanDevice() async {
    // 二重実行と権限チェックのガード
    if (_isScanning || !isPermissionGranted) return;
    setState(() => _isScanning = true);

    bool check =
        await Permission.storage.isGranted || await Permission.audio.isGranted;
    setState(() {
      isPermissionGranted = check;
    });

    // 権限がなければ、これ以上進まない（曲を探しに行かない）
    if (!check) {
      _isScanning = false;
      return;
    }

    try {
      // スマホ内のデータベースに曲を要求する（権限がある前提）
      List<SongModel> songs = await _audioQuery.querySongs(
        ignoreCase: true,
        sortType: SongSortType.DISPLAY_NAME, // DISPLAY_NAME（ファイル名）を基準の並び替え
        orderType: OrderType.ASC_OR_SMALLER, // 昇順（あいうえお順
        uriType: UriType.EXTERNAL, // 外部ストレージ
      );

      // 最終的な地図
      Map<String, List<SongModel>> finalMap = {};

      // 仮想フォルダの復元
      virtualFolderPaths.forEach((uniqueId, savedPaths) {
        // 全曲データの中から、保存されたパスに一致する曲だけ抽出してリスト化
        List<SongModel> restoredSongs = songs
            .where((s) => savedPaths.contains(s.data))
            .toList();
        // 並び順を保存時のパスリストの順に合わせる
        List<SongModel> orderedSongs = [];
        for (String path in savedPaths) {
          final found = restoredSongs.where((s) => s.data == path);
          if (found.isNotEmpty) orderedSongs.add(found.first);
        }
        finalMap[uniqueId] = orderedSongs;
      });

      // 一時的な地図を用意
      Map<String, List<SongModel>> tempMap = {};

      // 物理フォルダの構築
      for (var song in songs) {
        // 曲のデータパスからフォルダ名（一番下のディレクトリ名）を抜き出す
        // 例: /storage/emulated/0/Music/ArtistA/song.mp3 -> ArtistA
        List<String> pathParts = song.data.split("/");
        String folderName = pathParts.length > 1
            ? pathParts[pathParts.length - 2]
            : "不明なフォルダ";
        if (!tempMap.containsKey(folderName)) {
          tempMap[folderName] = [];
        }
        tempMap[folderName]!.add(song);
      }
      //【最優先】曲のお気に入り「⭐ お気に入り」フォルダを入れる
      List<SongModel> favList = songs
          .where((s) => favoriteSongs.contains(s.data))
          .toList();
      finalMap["⭐ お気に入り"] = favList;

      //【次点】お気に入り（ピン留め）されたフォルダを先に入れる
      for (var folderName in tempMap.keys) {
        if (favoriteFolders.contains(folderName)) {
          finalMap[folderName] = tempMap[folderName]!;
        }
      }
      //【最後】それ以外の通常フォルダを入れる
      for (var folderName in tempMap.keys) {
        // ピン留めされておらず、かつ自動生成名でもないもの
        if (!favoriteFolders.contains(folderName) && folderName != "⭐ お気に入り") {
          finalMap[folderName] = tempMap[folderName]!;
        }
      }
      // All Songs フォルダに「物理フォルダ」のみを登録する
      parentFolderMap["All Songs"] = tempMap.keys.toList();

      // 初期シーケンスの準備
      if (folderSequence.isEmpty) {
        folderSequence = finalMap.keys
            .where((k) => k == "⭐ お気に入り" || favoriteFolders.contains(k))
            .toList();
      }

      if (mounted) {
        setState(() {
          musicFiles = songs; // 全曲データ（再生制御用）
          folderMap = finalMap; // 物理＋仮想が統合された地図
          parentFolderMap["All Songs"] = finalMap.keys
              .toList(); // All Songsフォルダを常に全物理フォルダと同期させる
          // 他の上位フォルダ内に「既に消された物理フォルダ」が残っていたら掃除する（クリーンアップ）
          parentFolderMap.forEach((key, folderList) {
            if (key != "All Songs") {
              folderList.retainWhere(
                (fName) =>
                    finalMap.containsKey(fName) || fName.startsWith("VIRTUAL_"),
              );
            }
          });
        });
      }
    } catch (e) {
      debugPrint("Scan Error: $e"); // エラー補足
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("スキャンに失敗しました。ファイルへのアクセスを確認してください。"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      _isScanning = false; // 必ず修正フラグを戻す
    }
  }

  /*
    共通部品：リストの項目を持ち上げた際の装飾関数
  */
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

  /*
    共通部品：リストのヘッダー作成用の関数
  */
  Widget _buildUnifiedListHeader() {
    final theme = AppTheme(context);

    // 表示するタイトルの決定
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

    return Column(
      children: [
        // ヘッダー本体
        InkWell(
          onTap: () => setState(() => isHeaderOpen = !isHeaderOpen),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: theme.listBackground.withValues(alpha: 0.8),
              border: Border(
                bottom: BorderSide(color: theme.listBorder, width: 0.5),
              ),
            ),
            child: Row(
              children: [
                if (currentParentName != null)
                  // 戻るボタン
                  IconButton(
                    padding: EdgeInsets.zero, // paddingをゼロにし、左端へ
                    constraints: const BoxConstraints(), // アイコン自体のサイズに凝縮
                    icon: Icon(
                      Icons.arrow_back,
                      color: AppTheme(context).backAndMenuIcon,
                      size: 30,
                    ),
                    onPressed: backToFolders,
                  )
                else
                  Icon(
                    Icons.home, //TODO
                    color: AppTheme(context).backAndMenuIcon,
                    size: 33,
                  ),

                // タイトル部分
                Expanded(
                  child: Text(
                    title,
                    // ここがポイント：開いている時は2行、閉じている時は1行
                    maxLines: isHeaderOpen ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme(context).folderHeaderText,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  isHeaderOpen
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: Colors.blue,
                  size: 20,
                ),
                if (currentFolderName != null && currentFolderName != "⭐ お気に入り")
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      favoriteFolders.contains(currentFolderName)
                          ? Icons.push_pin
                          : Icons.push_pin_outlined,
                      color: favoriteFolders.contains(currentFolderName)
                          ? Colors.blueAccent
                          : Colors.white24,
                      size: 25,
                    ),
                    onPressed: () {
                      setState(() {
                        if (favoriteFolders.contains(currentFolderName)) {
                          favoriteFolders.remove(currentFolderName);
                        } else {
                          favoriteFolders.add(currentFolderName!);
                        }
                      });
                      _saveAllSettings();
                      scanDevice(); // 並び順更新のため再スキャン
                    },
                  )
                else
                  SizedBox(width: 35),
              ],
            ),
          ),
        ),
        // ポップダウン・メニューエリア
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          child: isHeaderOpen
              ? _buildHeaderPopDownMenu() // 既存のメニュー関数を呼び出し
              : const SizedBox(width: double.infinity, height: 0),
        ),
      ],
    );
  }

  /*
    共通部品：ヘッダー管理メニュー作成用の関数
  */
  Widget _buildHeaderPopDownMenu() {
    // 表示するボタンのリストを階層ごとに準備
    List<Widget> menuItems = [];

    if (currentFolderName != null) {
      // --- 最下層（曲一覧）でのメニュー ---
      menuItems = [
        _buildMenuIcon(Icons.library_add, "All Songs から\n曲を追加", () {
          setState(() => _resetModes());
          //TODO _showAddSongsFromAllSongsDialog();
        }),
        _buildMenuIcon(Icons.copy, "コピー", () {
          setState(() {
            _resetModes();
            isSelectionMode = true;
            isCopyMode = true;
          });
        }),
        _buildMenuIcon(Icons.move_up, "移動", () {
          setState(() {
            _resetModes();
            isSelectionMode = true;
            isMoveMode = true;
          });
        }),
        _buildMenuIcon(Icons.delete_sweep, "削除", () {
          setState(() {
            _resetModes();
            isDeleteMode = true;
            isSelectionMode = true;
          });
        }, color: Colors.redAccent),
        _buildMenuIcon(Icons.sort, "並べ替え\n(再生順も同期)", () {
          setState(() {
            _resetModes();
            isSortMode = true;
          });
        }),
      ];
    } else if (currentParentName == "All Songs") {
      // --- All Songs でのメニュー
      menuItems = [
        _buildMenuIcon(Icons.rule_rounded, "まとめフォルダ\nに追加", () {
          setState(() {
            _resetModes();
            isSelectionMode = true;
            isAssignMode = true;
          });
        }),
      ];
    } else if (currentParentName != null) {
      // --- 中位（自作まとめフォルダ）でのメニュー ---
      menuItems = [
        _buildMenuIcon(
          Icons.add_to_photos_outlined,
          "All Songs から\nフォルダ追加",
          () {
            setState(() => _resetModes());
            _showAddFoldersToSummaryDialog();
          },
        ),
        _buildMenuIcon(Icons.create_new_folder_outlined, "空フォルダ作成", () {
          setState(() => _resetModes());
          _showCreateVirtualFolderDialog();
        }),
        _buildMenuIcon(Icons.edit_note, "名前変更", () {
          setState(() {
            _resetModes();
            isRenameMode = true;
          });
        }),
        _buildMenuIcon(Icons.sort, "並べ替え\n(再生順も同期)", () {
          setState(() {
            _resetModes();
            isSortMode = true;
          });
        }),
        _buildMenuIcon(Icons.playlist_remove, "まとめから外す", () {
          setState(() {
            _resetModes();
            isDeleteMode = true;
            isSelectionMode = true;
          });
        }, color: Colors.orangeAccent),
      ];
    } else {
      // --- 親階層（まとめ一覧）でのメニュー ---
      menuItems = [
        // まとめ新規作成
        _buildMenuIcon(Icons.create_new_folder_outlined, "まとめ\n新規作成", () {
          setState(() => _resetModes());
          _showAddParentFolderDialog();
        }),
        // 名前変更モード
        _buildMenuIcon(Icons.edit_note, "名前変更", () {
          setState(() {
            _resetModes();
            isRenameMode = true;
          });
        }),
        // 並べ替えモード
        _buildMenuIcon(Icons.sort, "並べ替え", () {
          setState(() {
            _resetModes();
            isSortMode = true;
          });
        }),
        // 削除モード
        _buildMenuIcon(Icons.remove_circle_outline, "削除", () {
          setState(() {
            _resetModes();
            isDeleteMode = true;
            isSelectionMode = true;
          });
        }, color: Colors.redAccent),
      ];
    }

    return Container(
      color: AppTheme(
        context,
      ).sequenceBackground.withValues(alpha: 0.5), // 少し透かすと重厚感が出ます
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: GridView.count(
        shrinkWrap: true, // 内容量に合わせる
        physics: const NeverScrollableScrollPhysics(), // スクロールさせない
        crossAxisCount: 4, // 4列
        mainAxisSpacing: 6, // 縦の隙間
        crossAxisSpacing: 8, // 横の隙間
        childAspectRatio: 1.0, // ボタンの形を少し横長にして高さを抑える
        children: menuItems,
      ),
    );
  }

  /*
    共通部品：ヘッダー管理メニューの項目ごとのアイコンボタン作成
  */
  Widget _buildMenuIcon(
    IconData icon,
    String label,
    VoidCallback onTap, {
    Color? color,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: (color ?? Colors.blueAccent).withValues(alpha: 0.3),
              width: 1,
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: color ?? Colors.blueAccent),
              const SizedBox(height: 2),
              Expanded(
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
    上位フォルダ一覧を表示する関数
  */
  Widget _buildParentFolderList() {
    return Column(
      children: [
        // 上位フォルダのリスト
        Expanded(
          child: ReorderableListView(
            buildDefaultDragHandles: false,
            proxyDecorator: _buildProxyDecorator,
            onReorder: (oldIndex, newIndex) {
              // All Songs が絡む移動はシステム的に拒否する
              if (oldIndex == 0 || newIndex == 0) return;
              setState(() {
                if (oldIndex < newIndex) newIndex -= 1;
                final item = parentFolderOrder.removeAt(oldIndex);
                parentFolderOrder.insert(newIndex, item);
              });
              _saveAllSettings();
            },
            children: parentFolderOrder.asMap().entries.map((entry) {
              int index = entry.key;
              String parentName = entry.value;

              // タイルの材料を準備
              final String displayName =
                  folderNicknames[parentName] ?? parentName;

              return MusicTile(
                key: ValueKey("parent_$parentName"), // 並べ替えに必須
                level: ViewLevel.parent, // 階層
                id: parentName, // まとめフォルダ名
                index: index, // 並び順
                displayName: displayName,
                isPlaying: (playingParentName == parentName), // 再生中の光
                isChecked: selectedFolders.contains(parentName),
                isSelectionMode: isSelectionMode && parentName != "All Songs",
                isSortMode: isSortMode,
                isRenameMode: isRenameMode,
                isDeleteMode: isDeleteMode,
                isFavorite: false,

                // タップの動きをメイン画面のロジックとつなぐ
                onTap: () {
                  // チェックボックスがある状態なら、チェックボックスを選択する
                  if (isSelectionMode && parentName != "All Songs") {
                    setState(() {
                      selectedFolders.contains(parentName)
                          ? selectedFolders.remove(parentName)
                          : selectedFolders.add(parentName);
                    });
                    return;
                  }
                  if (isSortMode || isRenameMode) return;
                  // 通常タップ処理
                  _resetModes();
                  setState(() => currentParentName = parentName);
                },
                onCheckboxChanged: parentName == "All Songs"
                    ? (_) {} // 何もしない（エラー回避）
                    : (val) {
                        setState(() {
                          val!
                              ? selectedFolders.add(parentName)
                              : selectedFolders.remove(parentName);
                        });
                      },
                onFavoriteTap: () {}, // 親階層では不要
                onRenameTap: () => _showRenameParentFolderDialog(parentName),
                onDeleteTap: () => _confirmDeleteParentFolder(parentName),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  /*
    上位フォルダ作成用（まとめフォルダ新規作成）の関数
  */
  void _showAddParentFolderDialog() {
    TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme(context).exitBackground,
        title: const SizedBox(
          width: double.infinity,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text("新規まとめ用フォルダ"),
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true, // ダイアログを開いた瞬間にキーボードを出す
          decoration: const InputDecoration(hintText: "フォルダ名を入力"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("キャンセル"),
          ),
          TextButton(
            onPressed: () {
              String inputName = controller.text.trim(); // 空白を除去
              // 0文字チェック
              if (inputName.isEmpty) {
                // 入力欄をすべて消去
                controller.clear();
                FolderDialogs.showEmptyError(context);
                return;
              }
              if (inputName.isNotEmpty) {
                // 重複チェック回路
                if (parentFolderMap.containsKey(inputName)) {
                  // 既に同じ名前が存在する場合：警告を出して作成させない
                  FolderDialogs.showDuplicateWarning(context, inputName);
                  // 入力欄の入力された文字をすべて「選択状態」にする
                  controller.selection = TextSelection(
                    baseOffset: 0,
                    extentOffset: controller.text.length,
                  );
                  return; // ここで処理を中断
                }
                if (!mounted) return;
                // すべてクリアなら作成
                setState(() {
                  parentFolderMap[inputName] = [];
                  parentFolderOrder.add(inputName);
                });
                _saveAllSettings();
                Navigator.pop(context);
              }
            },
            child: const Text("作成"),
          ),
        ],
      ),
    );
  }

  /*
    上位フォルダの名前を変更する関数
  */
  void _showRenameParentFolderDialog(String oldName) {
    // 最初から現在の名前を入力状態に
    TextEditingController controller = TextEditingController(text: oldName);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme(context).exitBackground,
        title: const Text("まとめフォルダ名の変更", style: TextStyle(fontSize: 16)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: "新しい名前を入力"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("キャンセル"),
          ),
          TextButton(
            onPressed: () {
              String newName = controller.text.trim();
              // 0文字チェック
              if (newName.isEmpty) {
                controller.clear(); // 空文字しかない場合は入力欄を消去
                FolderDialogs.showEmptyError(context);
                return;
              }
              // 何も変わって何ならそのまま閉じる
              if (newName == oldName) {
                Navigator.pop(context);
                return;
              }
              if (newName.isNotEmpty) {
                // 重複チェック
                if (parentFolderMap.containsKey(newName)) {
                  FolderDialogs.showDuplicateWarning(context, newName);
                  // 入力欄の入力された文字をすべて「選択状態」にする
                  controller.selection = TextSelection(
                    baseOffset: 0,
                    extentOffset: controller.text.length,
                  );
                  return; // 処理中断
                }
                if (!mounted) return;
                // データ書き換え作業
                setState(() {
                  // Mapの書き換え
                  List<String> contents = parentFolderMap[oldName] ?? [];
                  parentFolderMap[newName] = contents;
                  parentFolderMap.remove(oldName);
                  // 並び順の書き換え
                  int index = parentFolderOrder.indexOf(oldName);
                  if (index != -1) {
                    parentFolderOrder[index] = newName;
                  }
                });
                _saveAllSettings();
                Navigator.pop(context);
              }
            },
            child: const Text("変更確定"),
          ),
        ],
      ),
    );
  }

  /*
     上位フォルダを削除するときの安全バー(加えて、実際の削除を担当する)関数
  */
  void _confirmDeleteParentFolder(String name) {
    FolderDialogs.confirmDelete(
      context: context,
      name: name,
      parentFolderMap: parentFolderMap,
      folderNicknames: folderNicknames,
      onConfirm: () {
        setState(() {
          parentFolderMap.remove(name);
          parentFolderOrder.remove(name);
          isDeleteMode = false;
        });
        _saveAllSettings();
      },
    );
  }

  /*
    All Songs 内の各フォルダに対して「移動先を選択」する処理用の関数
  */
  void _showBatchAssignmentDialog() {
    String newParentName = "";
    final theme = AppTheme(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.sequenceBackground,
        title: const Text("仕分け先を選択", style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 新規作成用の入力欄
              TextField(
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: "新規まとめフォルダを作成...",
                  hintStyle: TextStyle(color: Colors.white24),
                  prefixIcon: Icon(Icons.add, color: Colors.blueAccent),
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
                            _executeAssign(target);
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
                _executeAssign(newParentName);
              }
            },
            child: const Text("新規作成して追加"),
          ),
        ],
      ),
    );
  }

  /*
    上記に対する実際の書き込み処理
  */
  void _executeAssign(String targetParent) {
    if (!mounted) return;

    setState(() {
      // ターゲットのまとめが存在しなければ作成
      if (!parentFolderMap.containsKey(targetParent)) {
        parentFolderMap[targetParent] = [];
        parentFolderOrder.add(targetParent);
      }

      for (var physicalName in selectedFolders) {
        // 固有IDの発行
        String uniqueId =
            "VIRTUAL_${DateTime.now().microsecondsSinceEpoch}_$physicalName";

        // 元の physicalName をキーにして、folderMap から曲リストを取得してディープコピー
        List<SongModel> songs = folderMap[physicalName] ?? [];
        folderMap[uniqueId] = List<SongModel>.from(songs); // 参照ではなく新しいリストを作成

        // パス一覧を保存
        virtualFolderPaths[uniqueId] = songs.map((s) => s.data).toList();

        // ニックネームの決定
        folderNicknames[uniqueId] = _generateUniqueNicknameInParent(
          physicalName,
          targetParent,
        );

        // まとめへの追加
        parentFolderMap[targetParent]!.add(uniqueId);
      }
      _resetModes();
    });
    _saveAllSettings();
    // ダイアログが開いていれば閉じる（安全策）
    if (Navigator.canPop(context)) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  /*
    指定されたまとめフォルダ内で、名前がかぶらないニックネームを生成する関数
  */
  String _generateUniqueNicknameInParent(String baseName, String targetParent) {
    List<String> siblingIds = parentFolderMap[targetParent] ?? [];
    // 現在そのまとめに入っているフォルダたちの「表示名」をリストアップ
    List<String> existingNicknames = siblingIds
        .map((id) => folderNicknames[id] ?? id)
        .toList();
    // 被っていなければそのまま返す
    if (!existingNicknames.contains(baseName)) return baseName;
    // 被っている場合は、_2, _3 ... と空きを探す
    int counter = 2;
    while (existingNicknames.contains("${baseName}_$counter")) {
      counter++;
    }
    return "${baseName}_$counter";
  }

  /*
    フォルダ一覧を表示するための交通整理用の関数
  */
  Widget _buildFolderList() {
    // もし権限がなければ、案内画面を返す
    if (!isPermissionGranted) {
      return _buildPermissionError(); // 権限エラー表示
    }

    if (currentParentName == "All Songs") {
      return _buildAllSongsManager(); // 全フォルダ表示 ＆ 仕分けモード
    } else {
      return _buildCustomFolderViewer(); // 特定のまとめフォルダ内を表示
    }
  }

  /*
    All Songs フォルダ用の関数（全フォルダ表示 ＆ 複数選択・仕分け）
  */
  Widget _buildAllSongsManager() {
    List<String> physicalFolders = folderMap.keys
        .where((key) => !key.startsWith("VIRTUAL_") && key != "All Songs")
        .toList();

    return Column(
      children: [
        // All Songs内のリスト
        Expanded(
          child: ReorderableListView(
            buildDefaultDragHandles: false,
            proxyDecorator: _buildProxyDecorator,
            onReorder: (oldIdx, newIdx) {
              // 並び順の関数
              setState(() {
                if (oldIdx < newIdx) newIdx -= 1;
                // TODO 注意：folderMap.keys は固定的なので、
                // 並び順を保持するなら physicalFolderOrder 等の別リストが必要です
              });
            },
            children: physicalFolders.asMap().entries.map((entry) {
              int index = entry.key;
              String folderName = entry.value;

              // タイルの材料を準備
              final String displayName =
                  folderNicknames[folderName] ?? folderName;

              return MusicTile(
                key: ValueKey("all_songs_$folderName"),
                level: ViewLevel.sub, // 階層
                id: folderName, // フォルダ名
                index: index, // 並び順
                displayName: displayName,
                isPlaying: (playingFolderName == folderName),
                isChecked: selectedFolders.contains(folderName),
                isSelectionMode: isSelectionMode,
                isSortMode: isSortMode,
                isRenameMode: false, // All Songs では名前変更不可
                isDeleteMode: false, // All Songs では削除不可
                isFavorite: favoriteFolders.contains(folderName),

                onTap: () {
                  // チェックボックスがある状態なら、チェックボックスを選択する
                  if (isSelectionMode) {
                    setState(() {
                      selectedFolders.contains(folderName)
                          ? selectedFolders.remove(folderName)
                          : selectedFolders.add(folderName);
                    });
                    return;
                  }
                  // 通常タップ処理
                  _resetModes();
                  enterFolder(folderName);
                },
                onCheckboxChanged: (val) {
                  setState(() {
                    val!
                        ? selectedFolders.add(folderName)
                        : selectedFolders.remove(folderName);
                  });
                },
                onFavoriteTap: () {
                  setState(() {
                    favoriteFolders.contains(folderName)
                        ? favoriteFolders.remove(folderName)
                        : favoriteFolders.add(folderName);
                  });
                  _saveAllSettings();
                },
                onRenameTap: () {},
                onDeleteTap: () {},
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  /*
    自作のまとめフォルダを表示する関数
  */
  Widget _buildCustomFolderViewer() {
    List<String> folders = parentFolderMap[currentParentName] ?? [];

    return Column(
      children: [
        // フォルダーリスト
        Expanded(
          child: folders.isEmpty
              ? const Center(
                  child: Text(
                    "このまとめは空です",
                    style: TextStyle(color: Colors.white24, fontSize: 16),
                  ),
                )
              : ReorderableListView(
                  buildDefaultDragHandles: false,
                  proxyDecorator: _buildProxyDecorator,
                  onReorder: (oldIdx, newIdx) {
                    setState(() {
                      if (oldIdx < newIdx) newIdx -= 1;
                      final item = folders.removeAt(oldIdx);
                      folders.insert(newIdx, item);
                    });
                    _saveAllSettings();
                  },
                  children: folders.asMap().entries.map((entry) {
                    int index = entry.key;
                    String folderName = entry.value;

                    // タイルの材料を準備
                    String displayName =
                        folderNicknames[folderName] ?? folderName;
                    if (displayName.startsWith("VIRTUAL_")) {
                      displayName = "名称未設定フォルダ";
                    }

                    return MusicTile(
                      key: ValueKey("custom_sub_$folderName"),
                      level: ViewLevel.sub, // 階層
                      id: folderName, // フォルダ名
                      index: index, // 並び順
                      displayName: displayName,
                      isPlaying: (playingFolderName == folderName),
                      isChecked: selectedFolders.contains(folderName),
                      isSelectionMode: isSelectionMode,
                      isSortMode: isSortMode,
                      isRenameMode: isRenameMode,
                      isDeleteMode: isDeleteMode,
                      isFavorite: favoriteFolders.contains(folderName),

                      onTap: () {
                        // チェックボックスがある状態なら、チェックボックスを選択する
                        if (isSelectionMode) {
                          setState(() {
                            selectedFolders.contains(folderName)
                                ? selectedFolders.remove(folderName)
                                : selectedFolders.add(folderName);
                          });
                          return;
                        }
                        if (isSortMode || isRenameMode) return;
                        // 通常タップ処理
                        _resetModes();
                        enterFolder(folderName);
                      },
                      onCheckboxChanged: (val) {
                        setState(() {
                          val!
                              ? selectedFolders.add(folderName)
                              : selectedFolders.remove(folderName);
                        });
                      },
                      onFavoriteTap: () {
                        setState(() {
                          favoriteFolders.contains(folderName)
                              ? favoriteFolders.remove(folderName)
                              : favoriteFolders.add(folderName);
                        });
                        _saveAllSettings();
                      },
                      onRenameTap: () =>
                          _showRenamePhysicalFolderDialog(folderName),
                      onDeleteTap: () => _confirmRemoveFromSummary(folderName),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }

  /*
    まとめフォルダ内に、空のフォルダを作成する関数
  */
  void _showCreateVirtualFolderDialog() {
    TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme(context).exitBackground,
        title: const Text("空フォルダの作成"),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: "フォルダ名を入力してください"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("キャンセル"),
          ),
          TextButton(
            onPressed: () {
              String name = controller.text.trim();
              // 空文字チェック
              if (name.isEmpty) {
                controller.clear();
                FolderDialogs.showEmptyError(context);
                return;
              }
              // 重複チェック
              bool isDuplicate = folderMap.keys.any(
                (k) => (folderNicknames[k] ?? k) == name,
              );
              if (isDuplicate) {
                FolderDialogs.showDuplicateWarning(context, name);
                return;
              }

              setState(() {
                // 実体リスト(folderaMap)に空のリストとして登録
                String uniqueKey =
                    "VIRTUAL_${DateTime.now().millisecondsSinceEpoch}";
                folderMap[uniqueKey] = [];
                folderNicknames[uniqueKey] = name; // ニックネームとして登録
                parentFolderMap[currentParentName]!.add(uniqueKey);
              });
              _saveAllSettings();
              Navigator.pop(context);
            },
            child: const Text("作成"),
          ),
        ],
      ),
    );
  }

  /*
    自作まとめフォルダにAll Songs 内のフォルダを追加する関数
  */
  void _showAddFoldersToSummaryDialog() {
    // まだ現在のまとめに入っていないフォルダを抽出
    List<String> allFolders = folderMap.keys.toList();
    List<String> available = allFolders;

    Set<String> localSelected = {}; // このダイアログ内での選択用

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppTheme(context).sequenceBackground,
          title: Text(
            "$currentParentName に追加",
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: ListView.builder(
              itemCount: available.length,
              itemBuilder: (context, index) {
                String physicalName = available[index];
                String displayName =
                    folderNicknames[physicalName] ?? physicalName;
                return CheckboxListTile(
                  title: Text(
                    displayName,
                    style: const TextStyle(color: Colors.white),
                  ),
                  value: localSelected.contains(physicalName),
                  onChanged: (val) => setDialogState(
                    () => val!
                        ? localSelected.add(physicalName)
                        : localSelected.remove(physicalName),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("キャンセル"),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  // executeAssign()内と同じような処理
                  for (var physicalName in localSelected) {
                    // 現在のまとめフォルダ内で被らないニックネームを生成（_2, _3付与）
                    String newNickname = _generateUniqueNicknameInParent(
                      physicalName,
                      currentParentName!,
                    );
                    // 内部用の固有IDを生成（物理名を含めることで由来を保持）
                    String uniqueId =
                        "VIRTUAL_${DateTime.now().microsecondsSinceEpoch}_$physicalName";

                    // 曲データのコピー
                    List<SongModel> songs = folderMap[physicalName] ?? [];
                    folderMap[uniqueId] = List<SongModel>.from(songs);

                    // ニックネームの登録
                    folderNicknames[uniqueId] = newNickname;
                    // 現在のまとめフォルダ（親）のリストに仮想IDを登録
                    parentFolderMap[currentParentName]!.add(uniqueId);
                  }
                });
                _saveAllSettings();
                Navigator.pop(context);
              },
              child: const Text("追加実行"),
            ),
          ],
        ),
      ),
    );
  }

  /*
    物理フォルダの名前変更（仮想名）用関数
  */
  void _showRenamePhysicalFolderDialog(String id) {
    // 現在のニックネーム、無ければ物理名を初期値にする
    String currentName = folderNicknames[id] ?? id;
    TextEditingController controller = TextEditingController(text: currentName);
    // 仮想フォルダかどうかの判定
    bool isVirtual = id.startsWith("VIRTUAL_");

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme(context).exitBackground,
        title: const Text("名前の変更", style: TextStyle(fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 物理フォルダの場合のみ、元の名前を表示するパーツ
            if (!isVirtual) ...[
              Text(
                "元のフォルダ名:",
                style: TextStyle(color: Colors.grey, fontSize: 11),
              ),
              Text(
                id, // 物理ID（実際のフォルダ名）を表示
                style: TextStyle(
                  color: AppTheme(context).listText.withValues(alpha: 0.7),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
            ],
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: "表示名",
                hintText: "新しい名前を入力",
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("キャンセル"),
          ),
          TextButton(
            onPressed: () {
              String newName = controller.text.trim();
              // 名前が空の場合
              if (newName.isEmpty) {
                controller.clear();
                FolderDialogs.showEmptyError(context);
                return;
              }
              // 重複チェック
              bool isDuplicate = folderMap.keys.any(
                (k) => k != id && (folderNicknames[k] ?? k) == newName,
              );
              if (isDuplicate) {
                FolderDialogs.showDuplicateWarning(context, newName);
                return;
              }

              setState(() {
                // 物理名をキーに、新しいニックネームを保存
                folderNicknames[id] = newName;
              });
              _saveAllSettings();
              Navigator.pop(context);
            },
            child: const Text("変更確定"),
          ),
        ],
      ),
    );
  }

  /*
    各モードに応じた処理関数
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
    一括削除ロジックの関数
  */
  void _executeBulkDelete() {
    setState(() {
      if (currentParentName == null) {
        // まとめフォルダの一括削除
        for (var name in selectedFolders) {
          parentFolderMap.remove(name);
          parentFolderOrder.remove(name);
        }
      } else if (currentFolderName == null) {
        // まとめ内のフォルダの一括削除
        for (var folderId in selectedFolders) {
          parentFolderMap[currentParentName!]?.remove(folderId);
          // 仮想フォルダなら実体も消す
          if (folderId.startsWith("VIRTUAL_")) {
            virtualFolderPaths.remove(folderId);
            folderNicknames.remove(folderId);
            folderMap.remove(folderId);
          }
        }
      } else {
        // 曲の一括除外（仮想フォルダからの削除など）
        for (var path in selectedSongPaths) {
          // 現在のフォルダのリストからそのパスを持つ曲を除外
          folderMap[currentFolderName!]?.removeWhere((s) => s.data == path);
        }
      }
      // モード解除と選択解除
      _resetModes();
    });
    _saveAllSettings();
  }

  /*
    まとめから特定のフォルダを外す際の確認用関数
  */
  void _confirmRemoveFromSummary(String folderId) {
    setState(() {
      // 1. 現在の「まとめ（Parent）」のリストから削除
      parentFolderMap[currentParentName!]?.remove(folderId);

      // 2. 仮想フォルダの場合、根元の全データを抹消
      if (folderId.startsWith("VIRTUAL_")) {
        // パス（中身）のリストから削除
        virtualFolderPaths.remove(folderId);
        // ニックネーム設定から削除
        folderNicknames.remove(folderId);
        // メモリ上の曲データ実体（Map）から削除
        folderMap.remove(folderId);

        // 今後実装する「音量比率データ」からもここで削除するようにします
        // volumeRatios.remove(folderId);
      }
    });

    // 3. 変更を保存
    _saveAllSettings();
  }

  /*
    フォルダ内の曲を表示する関数
  */
  Widget _buildSongList() {
    return Column(
      children: [
        // 曲のリストエリア
        Expanded(
          child: ReorderableListView(
            buildDefaultDragHandles: false,
            proxyDecorator: _buildProxyDecorator,
            onReorder: (oldIdx, newIdx) {
              setState(() {
                if (oldIdx < newIdx) newIdx -= 1;
                final item = displayedSongs.removeAt(oldIdx);
                displayedSongs.insert(newIdx, item);

                // 仮想フォルダの場合、見た目だけでなく曲の並び順リストも並べ替えて保存する
                if (currentFolderName != null &&
                    folderMap.containsKey(currentFolderName)) {
                  folderMap[currentFolderName!] = List<SongModel>.from(
                    displayedSongs,
                  );
                  _saveAllSettings();
                }
              });
            },
            children: displayedSongs.asMap().entries.map((entry) {
              int index = entry.key;
              SongModel song = entry.value;

              // タイルの材料を準備
              final String displayName =
                  songNicknames[song.data] ?? song.displayNameWOExt;

              return MusicTile(
                key: ValueKey("song_${song.data}"),
                level: ViewLevel.song, // 階層
                id: song.data, // 曲名
                index: index, // 並び順
                song: song,
                displayName: displayName,
                isPlaying:
                    (selectSong?.data == song.data &&
                    playingFolderName == currentFolderName),
                isChecked: selectedSongPaths.contains(song.data),
                isSelectionMode: isSelectionMode,
                isSortMode: isSortMode,
                isRenameMode: isRenameMode,
                isDeleteMode: isDeleteMode,
                isFavorite: favoriteSongs.contains(song.data),

                onTap: () {
                  // チェックボックスがある状態なら、チェックボックスを選択する
                  if (isSelectionMode) {
                    setState(() {
                      selectedSongPaths.contains(song.data)
                          ? selectedSongPaths.remove(song.data)
                          : selectedSongPaths.add(song.data);
                    });
                    return;
                  }
                  if (isSortMode || isRenameMode) return;
                  // 通常タップ処理
                  setState(() {
                    playlistSongs = List.from(displayedSongs);
                    playingFolderName = currentFolderName;
                    playingParentName = currentParentName;
                  });
                  _executePlay(song);
                },
                onCheckboxChanged: (val) {
                  setState(() {
                    val!
                        ? selectedSongPaths.add(song.data)
                        : selectedSongPaths.remove(song.data);
                  });
                },
                onFavoriteTap: () {
                  setState(() {
                    favoriteSongs.contains(song.data)
                        ? favoriteSongs.remove(song.data)
                        : favoriteSongs.add(song.data);
                  });
                  _saveAllSettings();
                },
                onRenameTap: () {},
                onDeleteTap: () {},
              );
            }).toList(),
          ),
        ),
      ],
    );
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
    List<String> tempSequence = List.from(folderSequence);
    // 上段リストの初期高さ
    double topListHeight = 220.0;

    // 上段のリストを操作するためのリモコン
    final ScrollController topScrollController = ScrollController();

    // 一番下までスクロールさせる命令関数
    void scrollToBottom() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (topScrollController.hasClients) {
          topScrollController.animateTo(
            topScrollController.position.maxScrollExtent, // 一番下
            duration: const Duration(milliseconds: 250), // 0.3秒かけて
            curve: Curves.easeOut, // 滑らかに
          );
        }
      });
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          dialogUpdater = setDialogState; // 更新役を外部から呼べるようにする
          List<String> availableFolders = folderMap.keys
              .where((f) => !tempSequence.contains(f))
              .toList();

          return AlertDialog(
            backgroundColor: AppTheme(context).sequenceBackground,
            titlePadding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            actionsPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            title: Text(
              "フォルダループ設定",
              style: TextStyle(
                color: AppTheme(context).sequenceHeaderText,
                fontSize: 18,
              ),
            ),
            content: SizedBox(
              width: double.maxFinite,
              height: 600,
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.only(bottom: 4.0), // 下のリストとの間に隙間を作る
                    child: SizedBox(
                      width: double.infinity,
                      child: FittedBox(
                        fit: BoxFit.scaleDown, // はみ出す時だけ小さくする
                        alignment: Alignment.center,
                        child: Text(
                          "(長押しで曲順を入替え / タップで削除)",
                          style: TextStyle(
                            color: AppTheme(context).sequenceText,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: topListHeight,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppTheme(context).sequenceTopBackground,
                        borderRadius: BorderRadius.circular(0), // 枠の角の丸み
                      ),
                      child: ReorderableListView(
                        scrollController: topScrollController, // リモコンを接続
                        // 持ち上げたときの見た目を定義する装飾ユニット
                        proxyDecorator: (child, index, animation) {
                          return AnimatedBuilder(
                            animation: animation,
                            builder: (context, child) {
                              // 持ち上げに合わせて 0.0 から 1.0 に変化する値
                              final double animValue = Curves.easeInOut
                                  .transform(animation.value);
                              // 左にずらす量
                              final double offsetX = animValue * -10.0;
                              // 上にずらす量
                              final double offsetY = animValue * -6.0;
                              // 影の深さ
                              final double elevation = animValue * 8.0;

                              return Transform.translate(
                                offset: Offset(
                                  offsetX,
                                  offsetY,
                                ), // 左上(X,Yをマイナス)へ移動
                                child: Material(
                                  elevation: elevation,
                                  color: Color.lerp(
                                    Colors.transparent, // 持ち上げ前は、背景色はもとのものに任せる
                                    AppTheme(
                                      context,
                                    ).sequenceTopHaveList, // 持ち上げた際の色
                                    animValue,
                                  ), //
                                  shadowColor: Colors.white.withValues(
                                    alpha: 0.4,
                                  ),
                                  borderRadius: BorderRadius.circular(0),
                                  child: Opacity(
                                    opacity: 1.0 - (animValue * 0.1),
                                    child: child,
                                  ),
                                ),
                              );
                            },
                            child: child,
                          );
                        },
                        onReorder: (oldIdx, newIdx) {
                          setDialogState(() {
                            if (oldIdx < newIdx) newIdx -= 1;
                            final item = tempSequence.removeAt(oldIdx);
                            tempSequence.insert(newIdx, item);
                          });
                        },
                        children: tempSequence.map((folder) {
                          // 今再生中のフォルダかどうかを判定
                          final bool isPlaying = folder == playingFolderName;

                          return ReorderableDelayedDragStartListener(
                            key: ValueKey("seq_$folder"),
                            index: tempSequence.indexOf(folder),
                            child: Material(
                              color: Colors.transparent,
                              child: Theme(
                                data: Theme.of(context).copyWith(
                                  highlightColor: AppTheme(context).flashColor,
                                ),
                                child: Ink(
                                  decoration: BoxDecoration(
                                    gradient: isPlaying
                                        ? LinearGradient(
                                            begin: Alignment.centerLeft,
                                            end: Alignment.centerRight,
                                            colors: AppTheme(
                                              context,
                                            ).sequenceTopSelectedGradient,
                                            stops: const [0.0, 0.6, 1.0],
                                          )
                                        : null,
                                    color: isPlaying
                                        ? null
                                        : AppTheme(
                                            context,
                                          ).sequenceTopBackground,
                                    border: Border(
                                      bottom: BorderSide(
                                        color: AppTheme(
                                          context,
                                        ).sequenceTopBorder, // 線の色
                                        width: 0.5, // 線の太さ
                                      ),
                                    ),
                                  ),
                                  child: ListTile(
                                    dense: true, // 全体の隙間をギュッと凝縮
                                    visualDensity: const VisualDensity(
                                      vertical: -2,
                                    ), // さらに上下の余白を削る（-4まで設定可能）
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 0,
                                    ), // 余白の微調整
                                    title: Text(
                                      folder,
                                      maxLines: 2, // 上段は最大2行
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        // 再生中なら色を変更
                                        color: isPlaying
                                            ? AppTheme(
                                                context,
                                              ).sequenceTopSelectedText
                                            : AppTheme(
                                                context,
                                              ).sequenceTopListText,
                                        fontSize: 14,
                                      ),
                                    ),
                                    trailing: IconButton(
                                      icon: Icon(
                                        Icons.remove_circle_outline,
                                        color: Color.fromARGB(174, 255, 82, 82),
                                        size: 20,
                                      ),
                                      onPressed: () async {
                                        // タップ時もフラッシュ（瞬き）を挟むとレスポンスが良いです
                                        await Future.delayed(
                                          const Duration(milliseconds: 90),
                                        );
                                        if (!mounted) return;
                                        setDialogState(
                                          () => tempSequence.remove(folder),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),

                  // 可動式の境界線
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onVerticalDragUpdate: (details) {
                      setDialogState(() {
                        // ドラッグ量に合わせて高さを増減（最小800px、最大450pxに制限）
                        topListHeight += details.delta.dy;
                        topListHeight = topListHeight.clamp(80.0, 450.0);
                      });
                    },
                    child: Container(
                      width: double.infinity,
                      height: 30, // 判定エリアを広めに確保（指で掴みやすくする）
                      color: Colors.transparent, // 見えないけど触れる「遊び」の部分
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // ベースとなる横線
                          const Divider(color: Colors.blue, thickness: 1),

                          // 重なる「掴み棒（ハンドル）」
                          Container(
                            width: 100,
                            height: 6,
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              borderRadius: BorderRadius.circular(3),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black54,
                                  blurRadius: 2,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 下段のラベル
                  Padding(
                    padding: EdgeInsets.only(bottom: 4.0), // 下のリストとの間に隙間を追加
                    child: SizedBox(
                      width: double.infinity,
                      child: FittedBox(
                        fit: BoxFit.scaleDown, // はみ出す時だけ小さくする
                        alignment: Alignment.center,
                        child: Text(
                          "(フォルダ名をタップしてループに追加)",
                          style: TextStyle(
                            color: AppTheme(context).sequenceText,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppTheme(context).sequenceUnderBackground,
                        borderRadius: BorderRadius.circular(6), // 枠の角の丸み
                      ),
                      child: ListView.builder(
                        itemCount: availableFolders.length,
                        itemBuilder: (context, index) {
                          final folder = availableFolders[index];
                          // 今再生中のフォルダかどうかを判定
                          final bool isPlaying = folder == playingFolderName;

                          return Material(
                            color: Colors.transparent,
                            child: Ink(
                              decoration: BoxDecoration(
                                // 再生中
                                gradient: isPlaying
                                    ? LinearGradient(
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                        colors: AppTheme(
                                          context,
                                        ).sequenceUnderSelectedeGradient,
                                        stops: const [0.0, 0.6, 1.0],
                                      )
                                    : null,
                                color: isPlaying
                                    ? null
                                    : AppTheme(context).sequenceUnderBackground,
                                // 下のリストにも仕切り線を追加
                                border: Border(
                                  bottom: BorderSide(
                                    color: AppTheme(
                                      context,
                                    ).sequenceUnderBorder, // 線の色
                                    width: 0.5, // 線の太さ
                                  ),
                                ),
                              ),
                              child: ListTile(
                                dense: true, // 隙間を狭くする
                                visualDensity: const VisualDensity(
                                  vertical: -2,
                                ), // 上下の余白をさらに削る
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 0,
                                ), // 余白の微調整
                                title: Text(
                                  folder,
                                  maxLines: 3, // 下段は最大3行
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: isPlaying
                                        ? AppTheme(
                                            context,
                                          ).sequenceUnderSelectedText
                                        : AppTheme(
                                            context,
                                          ).sequenceUnderListText,
                                    fontSize: 13,
                                  ),
                                ),
                                onTap: () async {
                                  await Future.delayed(
                                    const Duration(milliseconds: 90),
                                  );
                                  if (!mounted) return;
                                  setDialogState(() {
                                    tempSequence.add(folder);
                                  });
                                  scrollToBottom();
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween, // 左右に振り分ける
                children: [
                  // 左側：閉じるボタン（保存せずに戻る）
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      "閉じる",
                      style: TextStyle(color: Colors.lightBlueAccent),
                    ),
                  ),
                  // 右側：保存ボタン（反映して戻る）
                  ElevatedButton(
                    onPressed: () async {
                      await Future.delayed(const Duration(milliseconds: 90));
                      if (!mounted) return;
                      setState(() => folderSequence = tempSequence);
                      _saveAllSettings();
                      Navigator.pop(context);
                    },
                    child: const Text(
                      "保存",
                      style: TextStyle(color: Colors.blueAccent),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
    // リモコンを片付ける
    topScrollController.dispose();
    // ダイアログが閉じたら、更新役を解除して安全を確保する
    dialogUpdater = null;
  }

  /*
    次または前の曲を「フォルダ移動も含めて」計算し、再生すべき曲を返す関数
    isNext: trueなら次、falseなら前
  */
  SongModel? _getTargetSong(bool isNext, {bool isAutomatic = false}) {
    // 再生リストが空、または現在選択されている曲がない場合は中断
    if (playlistSongs.isEmpty || selectSong == null) return null;

    int currentSongIndex = playlistSongs.indexOf(selectSong!);
    if (currentSongIndex == -1) return null;

    // グローバルシャッフル（跨ぎONのシャッフルモード）
    if (isFolderBridgeEnabled && playMode == 3) {
      List<String> currentLoopList = (playingParentName == "All Songs")
          ? folderSequence
          : (parentFolderMap[playingParentName] ?? []);
      if (currentLoopList.isNotEmpty) {
        // 対象フォルダ群からランダムに1つ選択
        String randomFolderName =
            currentLoopList[DateTime.now().millisecond %
                currentLoopList.length];
        List<SongModel> randomFolderSongs = folderMap[randomFolderName] ?? [];
        if (randomFolderSongs.isNotEmpty) {
          // そのフォルダの中からランダムに1曲選択
          SongModel target =
              randomFolderSongs[DateTime.now().microsecond %
                  randomFolderSongs.length];
          // フォルダが移動する場合は状態を更新
          if (playingFolderName != randomFolderName) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              setState(() {
                playingFolderName = randomFolderName;
                playlistSongs = randomFolderSongs;
                if (currentFolderName != null) {
                  currentFolderName = randomFolderName;
                  displayedSongs = randomFolderSongs;
                }
              });
            });
          }
          return target;
        }
      }
    }

    // 同一フォルダ内でのインデックス計算（通常）
    int targetIndex = isNext ? (currentSongIndex + 1) : (currentSongIndex - 1);

    // シャッフルモードの次曲計算（跨ぎOFFの時）
    if (!isFolderBridgeEnabled && isNext && playMode == 3) {
      targetIndex =
          (currentSongIndex +
              1 +
              (DateTime.now().millisecond % (playlistSongs.length - 1))) %
          playlistSongs.length;
    }

    // フォルダの境界を越えたかどうかの判定
    bool isOutOfBounds = isNext
        ? (targetIndex >= playlistSongs.length)
        : (targetIndex < 0);

    // ---以下フォルダの選択--- //

    if (isOutOfBounds) {
      // 跨ぎが無効、または個別ループ設定なら、今のフォルダ内でループ(手動)
      if (!isFolderBridgeEnabled || playMode == 2) {
        return playlistSongs[isNext ? 0 : playlistSongs.length - 1];
      }
      // 再生順を決定する「LoopList」の作成
      List<String> currentLoopList;
      if (currentParentName == "All Songs") {
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
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() {
              playingFolderName = targetFolderName; // 再生中リストを更新
              playlistSongs = nextSongs; // 再生リストを入替え
              // ユーザがフォルダ画面を開いているなら、表示も追従させる
              if (currentFolderName != null) {
                currentFolderName = targetFolderName;
                displayedSongs = nextSongs;
              }
            });
          });
          // 次のフォルダの「最初の曲」または「最後の曲」を返す
          return nextSongs[isNext ? 0 : nextSongs.length - 1];
        }
      }
      // 目録外だった場合や次のフォルダが空だった場合は、今のフォルダ内でループ
      if (!isAutomatic || playMode == 1) {
        return playlistSongs[isNext ? 0 : playlistSongs.length - 1];
      }
      return null;
    }
    // 境界を越えていない場合は、そのまま同じリスト内の曲を返す
    return playlistSongs[targetIndex];
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
    _executePlay(_getTargetSong(true, isAutomatic: isAutomatic));
  }

  /*
    前の曲に戻る関数
  */
  void playPreviousSong() {
    // 前を再生する
    _executePlay(_getTargetSong(false, isAutomatic: false));
  }

  /*
    曲を再生する関数
  */
  void _executePlay(SongModel? target) {
    if (target != null) {
      setState(() {
        selectSong = target;
        status = "play";
        // フォルダを跨いだ場合、playlistSongsは_getTargetSong内で更新済み
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
    権限エラー画面
  */
  Widget _buildPermissionError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lock_outline, size: 80, color: Colors.amber),
          const SizedBox(height: 20),
          const Text(
            "音楽ファイルへのアクセス権限が必要です",
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () async {
              await openAppSettings(); // 直接スマホの設定画面を開きます
            },
            child: const Text("設定画面を開いて許可する"),
          ),
        ],
      ),
    );
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
    // アプリが立ち上がった瞬間に、設定読み込みと権限チェックから
    _initializeHOS();

    // 監視役を登録して、変数に代入しておく
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
  }

  /*
    HOSの起動シーケンス：読み込みが終わってから権限確認・スキャンに進む
  */
  Future<void> _initializeHOS() async {
    await _loadAllSettings();
    await requestPermission();
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
          onTypeChanged: (type) => setState(() => drawerType = type), // 切り替えを記録する
          currentTheme: widget.currentTheme,
          onThemeChanged: widget.onThemeChanged,
          onScanPressed: () {
            Navigator.pop(context); // メニューを閉じる
            scanDevice();
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
                onModeToggle: () =>
                    setState(() => playMode = (playMode + 1) % 4),
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
                    currentParentName == null
                        ? _buildParentFolderList() // 1.最初は「まとめ一覧」を表示
                        : (currentFolderName == null
                              ? _buildFolderList() // 2.まとめを選んだら、「その中のフォルダを表示」
                              : _buildSongList()), // 3.フォルダを選んだら、「その中の曲一覧」
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
