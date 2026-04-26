import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';
import 'dart:convert';

// 階層を判別するための「印」(親・まとめ・曲フォルダ)
enum ViewLevel { parent, sub, song }

void main() async {
  // Flutterのエンジンと通信するための初期化
  WidgetsFlutterBinding.ensureInitialized();

  // 画面の向きを「縦（上向き）」のみに指定する
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false, //デバッグリボンを非表示
      home: const MusicApp(),
    ),
  );
}

// テーマ状態を保存するためのラッパー
class MusicApp extends StatefulWidget {
  const MusicApp({super.key});
  @override
  State<MusicApp> createState() => _MusicAppState();
}

class _MusicAppState extends State<MusicApp> {
  ThemeMode _themeMode = ThemeMode.dark; // デフォルトはダーク

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final String? themeStr = prefs.getString('theme_mode');
    setState(() {
      if (themeStr == 'light') {
        _themeMode = ThemeMode.light;
      } else if (themeStr == 'dark') {
        _themeMode = ThemeMode.dark;
      } else {
        _themeMode = ThemeMode.system;
      }
    });
  }

  void _updateTheme(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', mode.name);
    setState(() => _themeMode = mode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      // ライトテーマ用
      theme: ThemeData(
        brightness: Brightness.light,
        useMaterial3: true,
        // 波紋の広がり方
        splashFactory: InkRipple.splashFactory,
        splashColor: const Color(0x332196F3),
        highlightColor: Colors.transparent, // 押しっぱなしの色
      ),
      // ダークテーマ用
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        splashFactory: InkRipple.splashFactory,
        splashColor: const Color.fromARGB(51, 170, 210, 243),
        highlightColor: Colors.transparent, // 押しっぱなしの色
      ),
      home: MusicScanner(
        onThemeChanged: _updateTheme,
        currentTheme: _themeMode,
      ),
    );
  }
}

// アプリのテーマ設定クラス
class AppTheme {
  final BuildContext context;
  AppTheme(this.context);

  // 現在がダークモードかどうかを判定するセンサー
  bool get isDark => Theme.of(context).brightness == Brightness.dark;

  // --- 配色レシピ ---

  // 画面全体の色設定
  Color get mainBackground => isDark
      ? Color.fromARGB(255, 15, 15, 15)
      : Colors.white60; //.fromARGB(255, 250, 250, 250);

  // 一瞬ぱっと光るための色
  Color get flashColor => isDark
      ? Colors.cyanAccent.withValues(alpha: 0.25)
      : Colors.blue.withValues(alpha: 0.15);

  // 曲・フォルダリストの背景色
  Color get listBackground =>
      isDark ? Color.fromARGB(255, 30, 30, 30) : Colors.white;
  // 曲・フォルダリストの文字色
  Color get listText => isDark ? Colors.white : Colors.black87;
  // 曲・フォルダリスト間のボーダーラインの色
  Color get listBorder => isDark
      ? Color.fromARGB(255, 50, 50, 50)
      : Color.fromARGB(255, 190, 190, 190);
  // 曲・フォルダリスト内の再生中アイテムのハイライト
  List<Color> get playingListTileGradient => isDark
      ? [
          Colors.blue.withValues(alpha: 0.3),
          Colors.blue.withValues(alpha: 0.05),
          Colors.transparent,
        ]
      : [
          Colors.blue.withValues(alpha: 0.2),
          Colors.blue.withValues(alpha: 0.05),
          Colors.transparent,
        ];
  // 曲・フォルダリスト内の再生中アイテムの文字色
  Color get playingText => isDark ? Colors.cyanAccent : Colors.cyan[600]!;
  // 曲数の文字色
  Color get songCount => isDark ? Colors.grey : Colors.black45;
  // 曲リスト上部のフォルダ名ヘッダーの背景色
  Color get folderHeaderBackground => isDark
      ? Color.fromARGB(255, 15, 15, 15)
      : Color.fromARGB(255, 240, 240, 240);
  // 曲リスト上部のフォルダ名（青）の色
  Color get folderHeaderText => isDark ? Colors.blue : Color(0xFF0056B3);
  // 曲リスト上部のフォルダ名ヘッダーの設定ボタンの色
  Color get folderHeaderSetting => isDark
      ? Color.fromARGB(125, 255, 255, 255)
      : Color.fromARGB(150, 0, 0, 0);
  // アーティスト名の文字色
  Color get artistText => isDark ? Colors.white60 : Colors.black54;

  // 再生画面のフォルダ名の色
  Color get playerFolderText => isDark ? Colors.grey : Colors.black45;
  // 再生画面の曲名の色
  Color get playerSongsText => isDark ? Colors.blue : Colors.lightBlue;
  // 再生画面の再生モードの色(色なし)
  Color get playerModeOffIcon => isDark ? Colors.white60 : Colors.white;
  // 再生画面の再生モードの色(色あり)
  Color get playerModeOnIcon => isDark ? Colors.blueAccent : Colors.blueAccent;
  // 再生画面のアイコンの色
  Color get playerIcon => isDark ? Colors.white : Colors.black;
  // 再生画面のアイコンの影色
  Color get playerIconShade => isDark ? Colors.white : Colors.black;
  // 再生時間の文字色
  Color get playerTimeText => isDark ? Colors.white : Colors.black;
  // シークバーの再生済みの色
  Color get sliderAlreadyplayed => isDark
      ? Colors.blueAccent.withValues(alpha: 0.6)
      : Colors.blue.withValues(alpha: 0.5);
  // シークバーの再生前の色
  Color get sliderBeforePlay => isDark ? Colors.white24 : Colors.black26;
  // シークバーのつまみの色
  Color get sliderHandle => isDark ? Colors.lightBlue : Colors.lightBlueAccent;

  // 「フォルダループ設定」（青）の色
  Color get sequenceHeaderText => isDark ? Colors.blue : Colors.lightBlueAccent;
  // フォルダループ設定全体の背景色
  Color get sequenceBackground =>
      isDark ? Colors.grey[800]! : Colors.grey[700]!;
  // フォルダループ設定(括弧内)の文字色
  Color get sequenceText => isDark ? Colors.grey : Colors.grey[400]!;

  // フォルダループ設定リスト上段の背景色
  Color get sequenceTopBackground => isDark ? Colors.black : Colors.grey[900]!;
  // フォルダループ設定リスト上段の文字色
  Color get sequenceTopListText => isDark ? Colors.white : Colors.white;
  // フォルダループ設定上段の再生中の文字色
  Color get sequenceTopSelectedText =>
      isDark ? Colors.cyanAccent : Colors.cyan[600]!;
  // フォルダループ設定上段の再生中アイテムのハイライト
  List<Color> get sequenceTopSelectedGradient => isDark
      ? [
          Colors.blue.withValues(alpha: 0.3),
          Colors.blue.withValues(alpha: 0.1),
          Colors.transparent,
        ]
      : [
          Colors.blue.withValues(alpha: 0.20),
          Colors.blue.withValues(alpha: 0.1),
          Colors.transparent,
        ];
  // フォルダループ設定上段のボーダーラインの色
  Color get sequenceTopBorder => isDark ? Colors.white24 : Colors.white30;
  // リストを持ち上げた際の色の変化
  Color get sequenceTopHaveList => isDark
      ? Colors.white.withValues(alpha: 0.3)
      : Colors.white.withValues(alpha: 0.2);

  // フォルダループ設定リスト下段の背景色
  Color get sequenceUnderBackground =>
      isDark ? Colors.black : Colors.grey[900]!;
  // フォルダループ設定下段リストの文字色
  Color get sequenceUnderListText => isDark ? Colors.white70 : Colors.white70;
  // フォルダループ設定下段の再生中の文字色
  Color get sequenceUnderSelectedText =>
      isDark ? Colors.cyanAccent : Colors.cyan[500]!;
  // フォルダループ設定下段の再生中アイテムのハイライト
  List<Color> get sequenceUnderSelectedeGradient => isDark
      ? [
          Colors.cyanAccent.withValues(alpha: 0.17), // 左：控えめな発光
          Colors.cyanAccent.withValues(alpha: 0.1),
          Colors.transparent, // 右：完全に溶け込む
        ]
      : [
          Colors.blue.withValues(alpha: 0.15),
          Colors.blue.withValues(alpha: 0.1),
          Colors.transparent,
        ];
  // フォルダループ設定下段のボーダーラインの色
  Color get sequenceUnderBorder => isDark ? Colors.white12 : Colors.white24;

  // 左から出てくるメニューの文字色
  Color get menuText => isDark ? Colors.white : Colors.black87;
  // メニュー内のヘッダーの文字色
  Color get menuHeader => isDark ? Colors.blue : Colors.lightBlueAccent;
  // メニューの背景色
  Color get menuBackground => isDark ? Colors.black : Colors.white;
  // メニュー内のアイコン色
  Color get menuIcon => isDark ? Colors.white70 : Colors.black54;
  // 戻るボタンと三本線の色
  Color get backAndMenuIcon => isDark
      ? Colors.lightBlueAccent.withValues(alpha: 0.7)
      : Colors.lightBlueAccent.withValues(alpha: 0.5);
  // ドロワー右端のグラデーション（発光）エフェクトの色
  List<Color> get menuGradientColors => isDark
      ? [
          Colors.blue.withValues(alpha: 0.1), // 上は透明
          Colors.cyanAccent, // 中央は発光するシアン
          Colors.blue.withValues(alpha: 0.1), // 下は透明
        ]
      : [
          Colors.blueAccent.withValues(alpha: 0.25),
          Colors.blue,
          Colors.blueAccent.withValues(alpha: 0.25),
        ];

  // アプリ終了確認画面の背景色
  Color get exitBackground => isDark ? Colors.grey[800]! : Colors.grey[100]!;
  // アプリ終了確認画面の大文字
  Color get exitBigText => isDark ? Colors.white : Colors.black;
  //アプリ終了確認画面の小文字
  Color get exitSmallText => isDark ? Colors.white70 : Colors.black87;
}

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
  final AudioPlayer _audioPlayer = AudioPlayer();

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
  // メニューの開閉状態（まとめ一覧にて）
  bool _isFolderMenuOpen = false;
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

  // アプリ内でのフォルダの仮想名（名前変更に対応）
  Map<String, String> folderNicknames = {}; // {"物理名": "仮想名"}
  // アプリ内での曲ファイルの仮想名（名前変更に対応）
  Map<String, String> songNicknames = {}; // {"ファイルパス": "仮想曲名"}

  // 検索用の道具
  final OnAudioQuery _audioQuery = OnAudioQuery();
  List<SongModel> musicFiles = [];
  // 現在の曲名を保存する箱
  SongModel? selectSong;

  // ヘッダーでフォルダ名の部分が開いているかどうか
  bool isHeaderExpanded = false;

  // Scaffoldを外部から操作するための「鍵」(ドロワー)
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  // ドロワーにどちらを表示するかを判定するフラグ
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

  // 連続スキップ用のタイマー
  Timer? _continuousSkipTimer;

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
    final prefs = await SharedPreferences.getInstance();
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

    // 曲のリストを保存
    await prefs.setStringList("favorite_songs", favoriteSongs.toList());
    // フォルダのリストも保存
    await prefs.setStringList("favorite_folders", favoriteFolders.toList());
    // 跨ぎのON/OFFを保存
    await prefs.setBool("is_folder_bridge_enabled", isFolderBridgeEnabled);
    // シーケンスの保存(フォルダ跨ぎの)
    await prefs.setStringList("folder_sequence", folderSequence);
    // 上位フォルダの地図を保存
    String parentFoldersJson = jsonEncode(parentFolderMap);
    await prefs.setString("parent_folder_map", parentFoldersJson);
    // 上位フォルダの並び順を保存
    await prefs.setStringList("parent_folder_order", parentFolderOrder);
    // フォルダのニックネームMapをJSON形式で保存
    await prefs.setString("folder_nicknames", jsonEncode(folderNicknames));
    // 曲ファイルのニックネームMapをJSON形式で保存
    await prefs.setString("song_nicknames", jsonEncode(songNicknames));
    // 仮想フォルダのパス一覧を保存
    await prefs.setString(
      "virtual_folder_paths",
      jsonEncode(virtualFolderPaths),
    );
  }

  /* 
    保存されたさまざまな設定を読み込む関数
  */
  Future<void> _loadAllSettings() async {
    final prefs = await SharedPreferences.getInstance();
    // お気に入り曲の読み込み
    final savedSongs = prefs.getStringList('favorite_songs');
    // お気に入りフォルダの読み込み
    final savedFolders = prefs.getStringList('favorite_folders');
    // 跨ぎのON/OFFを読み込み
    final bool bridgeEnabled =
        prefs.getBool("is_folder_bridge_enabled") ?? false;
    // シーケンスの読み込み(フォルダ跨ぎの)
    final savedSequence = prefs.getStringList("folder_sequence") ?? [];
    // 上位フォルダ地図 (parentFolderMap) の復元
    Map<String, List<String>> loadedMap = {};
    String? jsonStr = prefs.getString("parent_folder_map");
    // フォルダのニックネームMapの復元
    String? folderNickStr = prefs.getString("folder_nicknames");
    // 曲ファイルのニックネームMapの復元
    String? songNickStr = prefs.getString("song_nicknames");
    // 仮想フォルダのパス一覧を復元
    String? vPathStr = prefs.getString("virtual_folder_paths");
    if (vPathStr != null) {
      setState(() {
        Map<String, dynamic> decode = jsonDecode(vPathStr);
        virtualFolderPaths = decode.map(
          (k, v) => MapEntry(k, List<String>.from(v as Iterable)),
        );
      });
    }

    if (jsonStr != null) {
      try {
        Map<String, dynamic> decoded = jsonDecode(jsonStr);
        loadedMap = decoded.map(
          (key, value) => MapEntry(key, List<String>.from(value as Iterable)),
        );
      } catch (e) {
        debugPrint("JSON Decode Error: $e");
      }
    }

    // 初回起動時などでデータが空、またはAll Songsがない場合の初期化
    if (loadedMap.isEmpty || !loadedMap.containsKey("All Songs")) {
      loadedMap = {"All Songs": [], "好きな曲の入ったフォルダをまとめよう！": []};
    }

    // 非同期処理(await)が終わった後、setStateを呼ぶ前に必ずチェック
    if (!mounted) return;

    // まとめてState（画面）に反映
    setState(() {
      parentFolderMap = loadedMap;

      if (savedSongs != null) {
        favoriteSongs = savedSongs.toSet();
      }
      if (savedFolders != null) {
        favoriteFolders = savedFolders.toSet();
      }
      isFolderBridgeEnabled = bridgeEnabled;
      folderSequence = savedSequence;
      // 上位フォルダの並び順を読み込み
      parentFolderOrder = prefs.getStringList("parent_folder_order") ?? [];
      if (folderNickStr != null) {
        folderNicknames = Map<String, String>.from(jsonDecode(folderNickStr));
      }
      if (songNickStr != null) {
        songNicknames = Map<String, String>.from(jsonDecode(songNickStr));
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
    再生モードの文字を返す関数
  */
  String _getPlayModeText() {
    switch (playMode) {
      case 0:
        return "順次再生";
      case 1:
        return "全曲リピート";
      case 2:
        return "1曲リピート";
      case 3:
        return "シャッフル";
      default:
        return "";
    }
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
    共通部品：一行分のタイル（親・まとめ・曲の3つ）関数
  */
  Widget _buildUniversalTile({
    required ViewLevel level,
    required String id, // フォルダ名やファイルパス
    required int index, // 並べ替え用のインデックス
    SongModel? song, // 曲階層の時だけ渡す
    bool isManager = false, // All Songs管理画面かどうか
  }) {
    // 再生中かどうかの判定
    final bool isSelected = (level == ViewLevel.song)
        ? selectSong?.data == id
        : playingFolderName == id;

    // 表示名の決定（ニックネームがあれば優先、曲ならファイル名）
    String displayName;
    if (level == ViewLevel.song) {
      displayName = songNicknames[id] ?? song?.displayNameWOExt ?? "不明な曲";
    } else {
      // ニックネームがあればそれを使い、無ければ物理名を使う
      // もしニックネームが無ければIDを表示（物理フォルダの場合はパスの一部など）
      displayName = folderNicknames[id] ?? id;

      if (displayName.startsWith("VIRTUAL_")) {
        displayName = "名称未設定フォルダ";
      }
    }

    // サブタイトルの決定（曲ならアーティスト名,まとめフォルダ内なら中の曲数）
    Widget? subTitle;
    if (level == ViewLevel.sub) {
      subTitle = Text(
        "(${folderMap[id]?.length ?? 0})",
        style: TextStyle(color: AppTheme(context).songCount, fontSize: 12),
      );
    } else if (level == ViewLevel.song) {
      subTitle = Text(
        song?.artist ?? "不明なアーティスト",
        style: TextStyle(color: AppTheme(context).artistText, fontSize: 12),
      );
    }

    return Material(
      key: ValueKey("${level.name}_$id"), // ReorderableListViewに必須
      color: Colors.transparent,
      child: InkWell(
        // タイルタップ処理
        onTap: () {
          // チェックボックスがある状態ならチェック処理をさせる
          if (isSelectionMode) {
            // TODO
          }

          if (level == ViewLevel.parent) {
            _resetModes();
            setState(() => currentParentName = id);
          }
          if (level == ViewLevel.sub) {
            _resetModes();
            enterFolder(id);
          }
          if (level == ViewLevel.song) {
            if (isDeleteMode || isSortMode || isRenameMode) return;
            // 曲の再生処理
            setState(() {
              playlistSongs = List.from(displayedSongs);
              playingFolderName = currentFolderName;
            });
            _executePlay(song);
          }
        },
        child: Ink(
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: AppTheme(context).playingListTileGradient,
                    stops: const [0.0, 0.4, 1.0],
                  )
                : null,
            color: isSelected ? null : AppTheme(context).listBackground,
            border: Border(
              bottom: BorderSide(
                color: AppTheme(context).listBorder,
                width: 0.5, // 線の太さ
              ),
            ),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 0,
            ),

            // 左側
            leading: (isSelectionMode)
                ? Checkbox(
                    value: (level == ViewLevel.song)
                        ? selectedSongPaths.contains(id)
                        : selectedFolders.contains(id),
                    activeColor: Colors.blueAccent,
                    onChanged: (val) {
                      setState(() {
                        if (level == ViewLevel.song) {
                          val!
                              ? selectedSongPaths.add(id)
                              : selectedSongPaths.remove(id);
                        } else {
                          val!
                              ? selectedFolders.add(id)
                              : selectedFolders.remove(id);
                        }
                      });
                    },
                  )
                : _buildLeadingIcon(level, id, isSelected, index),

            // 中央タイトル
            title: Text(
              displayName,
              maxLines: level == ViewLevel.parent ? 2 : 1, // 親なら2行、それ以外は1行
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isSelected
                    ? AppTheme(context).playingText
                    : AppTheme(context).listText,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            subtitle: subTitle,

            // 右側
            trailing: _buildTrailingWidget(level, id, index, song: song),
          ),
        ),
      ),
    );
  }

  /*
    共通部品：タイルの左側のアイコン生成関数
  */
  Widget _buildLeadingIcon(
    ViewLevel level,
    String id,
    bool isPlaying,
    int index,
  ) {
    // 曲階層の場合
    if (level == ViewLevel.song) {
      return Container(
        width: 35,
        alignment: Alignment.center,
        child: Text(
          "${index + 1}.",
          style: TextStyle(
            color: isPlaying
                ? AppTheme(context).playingText
                : AppTheme(context).listText,
            fontWeight: FontWeight.bold,
            fontFamily: "monospace",
          ),
        ),
      );
    }
    // フォルダ階層（親・物理）の場合はアイコンを表示
    IconData icon = (id == "⭐ お気に入り") ? Icons.star_sharp : Icons.folder;
    Color color = isPlaying
        ? AppTheme(context).playingText
        : (id == "⭐ お気に入り"
              ? Colors.yellow
              : Colors.amber.withValues(alpha: 0.8));
    return Icon(icon, color: color, size: 35);
  }

  /*
    共通部品：タイルの右側のアイコンを、モード別で生成する補助関数
  */
  Widget _buildTrailingWidget(
    ViewLevel level,
    String id,
    int index, {
    SongModel? song,
  }) {
    // All Songs は移動も削除もできない
    if (id == "All Songs")
      return const Icon(Icons.lock_outlined, size: 18, color: Colors.white10);

    // 並べ替えモード
    if (isSortMode) {
      return ReorderableDragStartListener(
        index: index,
        child: const Icon(Icons.menu, color: Colors.blue),
      );
    }
    // 名前変更モード
    if (isRenameMode) {
      return IconButton(
        icon: const Icon(Icons.edit_note, color: Colors.blueAccent),
        onPressed: () => level == ViewLevel.parent
            ? _showRenameParentFolderDialog(id)
            : _showRenamePhysicalFolderDialog(id),
      );
    }
    // 削除・除外モード
    if (isDeleteMode) {
      IconData delIcon = (level == ViewLevel.parent)
          ? Icons.delete
          : Icons.playlist_remove;
      Color delColor = (level == ViewLevel.parent)
          ? Colors.redAccent
          : Colors.orangeAccent;
      return IconButton(
        icon: Icon(delIcon, color: delColor),
        onPressed: () => level == ViewLevel.parent
            ? _confirmDeleteParentFolder(id)
            : _confirmRemoveFromSummary(id),
      );
    }
    // 通常時かつ曲階層でのお気に入りボタン
    if (level == ViewLevel.song && song != null) {
      final bool isFav = favoriteSongs.contains(song.data);
      return IconButton(
        icon: Icon(
          isFav ? Icons.star : Icons.star_border,
          color: isFav ? Colors.yellow : Colors.white60,
        ),
        onPressed: () {
          setState(() {
            if (isFav) {
              favoriteSongs.remove(song.data);
            } else {
              favoriteSongs.add(song.data);
            }
          });
          _saveAllSettings();
        },
      );
    }
    // 通常時
    return const Icon(Icons.chevron_right, color: Colors.white24);
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
            color: Colors.blue.withValues(alpha: 0.3), // 浮いているときの色
            shadowColor: Colors.black54,
            child: child,
          ),
        );
      },
    );
  }

  /*
    共通部品：モード終了ボタン関数（ヘッダー部分）
  */
  Widget _buildModeEndButton() {
    // どのモードでもなければ、何も表示しない
    if (!isDeleteMode && !isSortMode && !isRenameMode) {
      return const SizedBox.shrink();
    }

    String label = isSortMode
        ? "並べ替え終了"
        : (isRenameMode ? "名前変更終了" : "削除モード終了");
    Color color = (isSortMode || isRenameMode) ? Colors.blue : Colors.redAccent;

    return InkWell(
      onTap: _resetModes, // ここでリセット
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: color.withValues(alpha: 0.6), width: 1.5),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
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
          //_showAddSongsFromAllSongsDialog();
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
      _isFolderMenuOpen = false;
      isHeaderExpanded = false;
      isCopyMode = false;
      isMoveMode = false;
      selectedSongPaths.clear();
      selectedFolders.clear();
    });
  }

  /*
    時間を「分：秒」に直す関数
  */
  String _formatDuration(Duration d) {
    // 分と秒を２桁ずつにして合体させる
    String minutes = d.inMinutes.toString();
    String seconds = (d.inSeconds % 60).toString().padLeft(2, "0");
    return "$minutes:$seconds";
  }

  /*
    上位フォルダ一覧を表示する関数
  */
  Widget _buildParentFolderList() {
    return Column(
      children: [
        // ヘッダーエリア
        InkWell(
          onTap: () {
            setState(() {
              _isFolderMenuOpen = !_isFolderMenuOpen; // 開閉の切り替え
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: AppTheme(context).folderHeaderBackground,
            child: Row(
              children: [
                Text(
                  "まとめフォルダ一覧",
                  style: TextStyle(
                    color: AppTheme(context).folderHeaderText,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  _isFolderMenuOpen
                      ? Icons.arrow_drop_up
                      : Icons.arrow_drop_down,
                  color: Colors.blue,
                  size: 20,
                ),
                const Spacer(),
                // 各モードの終了ボタン
                _buildModeEndButton(),
              ],
            ),
          ),
        ),
        // ポップダウン・メニューエリア
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          child: _isFolderMenuOpen
              ? _buildHeaderPopDownMenu()
              : const SizedBox(width: double.infinity, height: 3),
        ),

        const Divider(height: 1, color: Colors.white24),

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
              return _buildUniversalTile(
                level: ViewLevel.parent,
                id: parentName,
                index: index,
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
                _showEmptyError("フォルダ名を入力してください");
                return;
              }
              if (inputName.isNotEmpty) {
                // 重複チェック回路
                if (parentFolderMap.containsKey(inputName)) {
                  // 既に同じ名前が存在する場合：警告を出して作成させない
                  _showDuplicateWarning(inputName);
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
    名前が空文字の際の警告用関数
  */
  void _showEmptyError(String message) {
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

  /*
    名前が重複時の警告用サブ・ダイアログ
  */
  void _showDuplicateWarning(String name) {
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
                _showEmptyError("名前を空にはできません");
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
                  _showDuplicateWarning(newName);
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
          // 削除して続ける
          TextButton(
            onPressed: () {
              setState(() {
                parentFolderMap.remove(name);
                parentFolderOrder.remove(name);
              });
              _saveAllSettings();
              Navigator.pop(context);
            },
            child: const Text("削除して続ける"),
          ),
          // 削除して終了
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              setState(() {
                parentFolderMap.remove(name);
                parentFolderOrder.remove(name);
                isDeleteMode = false;
              });
              _saveAllSettings();
              Navigator.pop(context);
            },
            child: const Text("削除して終了", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  /*
    All Songs 内の各フォルダに対して「移動先を選択」する処理用の関数
  */
  void _showBatchAssignmentDialog() {
    String newParentName = "";

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme(context).sequenceBackground,
        title: const Text("仕分け先を選択"),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 新規作成用の入力欄
              TextField(
                decoration: const InputDecoration(
                  hintText: "新規まとめフォルダを作成...",
                  prefixIcon: Icon(Icons.add),
                ),
                onChanged: (val) => newParentName = val,
              ),
              const Divider(),
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
                          title: Text(target),
                          onTap: () => _executeAssign(target),
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
            child: const Text("キャンセル"),
          ),
          ElevatedButton(
            onPressed: () {
              if (newParentName.isNotEmpty) _executeAssign(newParentName);
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
      if (!parentFolderMap.containsKey(targetParent)) {
        parentFolderMap[targetParent] = [];
      }

      for (var physicalName in selectedFolders) {
        // ニックネームの決定
        String newNickname = _generateUniqueNicknameInParent(
          physicalName,
          targetParent,
        );
        // 固有IDの発行
        String uniqueId =
            "VIRTUAL_${DateTime.now().microsecondsSinceEpoch}_$physicalName";

        // 元の physicalName をキーにして、folderMap から曲リストを取得してディープコピー
        List<SongModel> songs = folderMap[physicalName] ?? [];
        folderMap[uniqueId] = List<SongModel>.from(songs); // 参照ではなく新しいリストを作成

        // パス一覧を保存
        virtualFolderPaths[uniqueId] = songs.map((s) => s.data).toList();

        folderNicknames[uniqueId] = newNickname;
        parentFolderMap[targetParent]!.add(uniqueId);
      }
      isSelectionMode = false;
      selectedFolders.clear();
      _isFolderMenuOpen = false; // 処理が終わったらメニューも閉じる
    });

    _saveAllSettings();
    if (Navigator.canPop(context)) Navigator.pop(context);
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
    List<String> folders = folderMap.keys.toList();

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          color: AppTheme(context).folderHeaderBackground,
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: backToFolders,
              ),
              Expanded(
                child: Text(
                  "All Songs(フォルダ一覧)",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppTheme(context).folderHeaderText,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Spacer(),
              // 一括振り分けボタン
              IconButton(
                icon: Icon(
                  isSelectionMode ? Icons.check_circle : Icons.rule_rounded,
                ),
                color: isSelectionMode ? Colors.greenAccent : Colors.blue,
                onPressed: () {
                  if (isSelectionMode && selectedFolders.isNotEmpty) {
                    _showBatchAssignmentDialog();
                  } else {
                    setState(() => isSelectionMode = !isSelectionMode);
                  }
                },
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Colors.white24),
        Expanded(
          child: ReorderableListView(
            buildDefaultDragHandles: false,
            proxyDecorator: _buildProxyDecorator,
            onReorder: (oldIdx, newIdx) {
              // 並び順の関数
              setState(() {
                if (oldIdx < newIdx) newIdx -= 1;
                // 注意：folderMap.keys は固定的なので、
                // 並び順を保持するなら physicalFolderOrder 等の別リストが必要です
              });
            },
            children: folders.asMap().entries.map((entry) {
              return _buildUniversalTile(
                level: ViewLevel.sub,
                id: entry.value,
                index: entry.key,
                isManager: true, // All Songs であることを明示
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
        // ヘッダーエリア
        InkWell(
          onTap: () => setState(() => _isFolderMenuOpen = !_isFolderMenuOpen),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            color: AppTheme(context).folderHeaderBackground,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: backToFolders,
                ),
                Expanded(
                  child: Text(
                    currentParentName ?? "",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppTheme(context).folderHeaderText,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Icon(
                  _isFolderMenuOpen
                      ? Icons.arrow_drop_up
                      : Icons.arrow_drop_down,
                  color: Colors.blue,
                  size: 20,
                ),
                const Spacer(),
                if (isDeleteMode || isSortMode || isRenameMode)
                  _buildModeEndButton(), // 終了ボタン
                if (!isDeleteMode && !isSortMode && !isRenameMode)
                  IconButton(
                    icon: const Icon(
                      Icons.add_box_outlined,
                      color: Colors.blue,
                    ),
                    onPressed: () => _showAddFoldersToSummaryDialog(),
                  ),
              ],
            ),
          ),
        ),

        // ポップダウンメニュー
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          child: _isFolderMenuOpen
              ? _buildHeaderPopDownMenu()
              : const SizedBox(width: double.infinity, height: 0),
        ),
        const Divider(height: 1, color: Colors.white24),

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
                    return _buildUniversalTile(
                      level: ViewLevel.sub, // 階層
                      id: folderName, // フォルダ名
                      index: index, // 並び順
                      isManager: false,
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
                _showEmptyError("名前を入力してください");
                return;
              }
              // 重複チェック
              bool isDuplicate = folderMap.keys.any(
                (k) => (folderNicknames[k] ?? k) == name,
              );
              if (isDuplicate) {
                _showDuplicateWarning(name);
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
                _showEmptyError("名前を入力してください");
                return;
              }
              // 重複チェック
              bool isDuplicate = folderMap.keys.any(
                (k) => k != id && (folderNicknames[k] ?? k) == newName,
              );
              if (isDuplicate) {
                _showDuplicateWarning(newName);
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
    まとめから特定のフォルダを外す際の確認用関数
  */
  void _confirmRemoveFromSummary(String id) {
    String displayName = folderNicknames[id] ?? id;
    if (displayName.startsWith("VIRTUAL_")) displayName = "(名称未設定)";

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme(context).exitBackground,
        title: const Text("まとめから解除", style: TextStyle(fontSize: 17)),
        content: Text("「$displayName」をこのまとめから外しますか？\n※フォルダ内の曲は削除されません。"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("キャンセル"),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                parentFolderMap[currentParentName]?.remove(id);
              });
              _saveAllSettings();
              Navigator.pop(context);
            },
            child: const Text(
              "外して続ける",
              style: TextStyle(color: Colors.orangeAccent),
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                parentFolderMap[currentParentName]?.remove(id);
                _resetModes();
              });
              _saveAllSettings();
              Navigator.pop(context);
            },
            child: const Text(
              "外して終了",
              style: TextStyle(color: Colors.orangeAccent),
            ),
          ),
        ],
      ),
    );
  }

  /*
    曲のパスからフォルダ名だけを抜き出す関数
  */
  String _getFolderNameFromPath(String path) {
    List<String> pathParts = path.split("/");
    return pathParts.length > 1 ? pathParts[pathParts.length - 2] : "不明なフォルダ";
  }

  /*
    フォルダ内の曲を表示する関数
  */
  Widget _buildSongList() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 4.0), // 上下の微調整
          color: AppTheme(context).folderHeaderBackground, // ヘッダー自体の色
          // 戻るボタン
          child: Row(
            children: [
              IconButton(
                padding: EdgeInsets.zero, // paddingをゼロにし、左端へ
                constraints: const BoxConstraints(), // アイコン自体のサイズに凝縮
                icon: Icon(
                  Icons.arrow_back,
                  color: AppTheme(context).backAndMenuIcon,
                  size: 30,
                ),
                onPressed: backToFolders,
              ),

              // 矢印とフォルダアイコンの間の最小限の隙間
              const SizedBox(width: 4),

              // 中央：フォルダ名エリア（タップで展開）
              Expanded(
                child: InkWell(
                  onTap: () {
                    setState(() {
                      isHeaderExpanded = !isHeaderExpanded; // タップで展開/省略を切り替え
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      folderNicknames[currentFolderName] ??
                          currentFolderName ??
                          "",
                      maxLines: isHeaderExpanded ? null : 1,
                      overflow: isHeaderExpanded
                          ? TextOverflow.visible
                          : TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppTheme(context).folderHeaderText,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),
              if (currentFolderName != "⭐ お気に入り")
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
                ),
              IconButton(
                icon: Icon(
                  _isFolderMenuOpen ? Icons.close : Icons.edit_note,
                  color: _isFolderMenuOpen
                      ? Colors.orangeAccent
                      : AppTheme(context).folderHeaderSetting,
                  size: 28,
                ),
                onPressed: () {
                  setState(() {
                    _isFolderMenuOpen = !_isFolderMenuOpen;
                    if (!_isFolderMenuOpen) _resetModes(); //閉じるときはモードをリセット
                  });
                },
              ),
            ],
          ),
        ),
        const Divider(color: Colors.white24, height: 1),

        // メニューパネル
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          child: _isFolderMenuOpen
              ? _buildHeaderPopDownMenu()
              : const SizedBox(width: double.infinity, height: 0),
        ),
        if (_isFolderMenuOpen) const Divider(color: Colors.white24, height: 1),

        _buildModeEndButton(),
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

              return _buildUniversalTile(
                level: ViewLevel.song,
                id: song.data,
                index: index,
                song: song,
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
        isHeaderExpanded = false; // フォルダから出る時にフォルダ名の展開状態をリセット
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
      List<String> currentLoopList = (currentParentName == "All Songs")
          ? folderSequence
          : (parentFolderMap[currentParentName] ?? []);
      if (currentLoopList.isNotEmpty) {
        // 対象フォルダ群からランダムに1つ選択
        String randomFolderName =
            currentLoopList[DateTime.now().millisecond %
                currentLoopList.length];
        List<SongModel> randomFolderSongs = folderMap[randomFolderName] ?? [];
        if (randomFolderSongs.isNotEmpty) {
          // そのドルだの中からランダムに1曲選択
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
        currentLoopList = parentFolderMap[currentParentName] ?? [];
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
    連続スキップ用の関数
  */
  void _startContinuousSkip(bool isNext) {
    // 既にタイマーが動いていたら一度止めるための（安全策）
    _stopContinuousSkip();

    // 1回目は即実行（タップ）
    isNext ? playNextSong() : playPreviousSong();

    // 2回目以降、一定間隔で実行
    _continuousSkipTimer = Timer.periodic(const Duration(milliseconds: 300), (
      timer,
    ) {
      if (isNext) {
        playNextSong();
      } else {
        playPreviousSong();
      }
    });
  }

  /* 
    操作パネル内のボタン用共通ウィジェット（波紋＋長押し）
  */
  Widget _buildTransportButton({
    required IconData icon,
    required VoidCallback onTap,
    required Function(bool) onLongPressStart,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        // 指が触れた瞬間（長押しの判定開始）
        onLongPress: () => onLongPressStart(true),
        // 指が離れた時
        onTapUp: (_) => _stopContinuousSkip(),
        // 画面外に指がズレてキャンセルされた時
        onTapCancel: () => _stopContinuousSkip(),
        borderRadius: BorderRadius.circular(50),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Icon(icon, size: 40, color: AppTheme(context).playerIcon),
        ),
      ),
    );
  }

  /*
    連続スキップを止める関数
  */
  void _stopContinuousSkip() {
    _continuousSkipTimer?.cancel();
    _continuousSkipTimer = null;
  }

  /* 
    次の曲を再生する関数
  */
  void playNextSong({bool isAutomatic = false}) {
    // 1曲リピートのみの自動遷移時のみ
    if (isAutomatic && playMode == 2 && selectSong != null) {
      _audioPlayer.play(DeviceFileSource(selectSong!.data));
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
      _audioPlayer.play(DeviceFileSource(target.data));
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
      _audioPlayer.stop();
      setState(() => status = "stop");
    }
  }

  /*
    サイドメニュー全体のドロワー用の関数
  */
  Widget _buildSystemMenu() {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        DrawerHeader(
          decoration: BoxDecoration(color: AppTheme(context).menuBackground),
          child: Text(
            "SYSTEM MENU",
            style: TextStyle(
              color: AppTheme(context).menuHeader,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
        ListTile(
          leading: Icon(Icons.refresh, color: AppTheme(context).menuIcon),
          title: Text(
            "全曲スキャン（更新）",
            style: TextStyle(color: AppTheme(context).menuText),
          ),
          onTap: () async {
            // 波紋が広がる時間を稼ぐ
            await Future.delayed(const Duration(milliseconds: 150));
            if (!mounted) return; // もし await の間にユーザーがメニューを閉じていたら、ここで処理を中断する
            scanDevice(); // スキャン実行
            Navigator.pop(context); // メニューを閉じる
          },
        ),
        ListTile(
          leading: Icon(Icons.settings, color: AppTheme(context).menuIcon),
          title: Text(
            "設定",
            style: TextStyle(color: AppTheme(context).menuText),
          ),
          onTap: () async {
            // 波紋が広がる時間を稼ぐ
            await Future.delayed(const Duration(milliseconds: 150));
            if (!mounted) return;
            setState(() => drawerType = "settings");
            _scaffoldKey.currentState?.openDrawer();
          },
        ),
      ],
    );
  }

  /*
    設定メニューのドロワー用の関数
  */
  Widget _buildSettingsMenu() {
    return Column(
      children: [
        DrawerHeader(
          decoration: BoxDecoration(color: AppTheme(context).menuBackground),
          child: Container(
            alignment: Alignment.bottomLeft,
            child: Text(
              "設定",
              style: TextStyle(
                color: AppTheme(context).menuHeader,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  "カラーテーマ",
                  style: TextStyle(
                    color: AppTheme(context).menuText,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
              RadioGroup<ThemeMode>(
                groupValue: widget.currentTheme,
                onChanged: (ThemeMode? value) {
                  if (value != null) {
                    widget.onThemeChanged(value);
                  }
                },
                child: Column(
                  children: [
                    _buildThemeOption(ThemeMode.system, "システム設定に準拠"),
                    _buildThemeOption(ThemeMode.light, "ホワイトパターン"),
                    _buildThemeOption(ThemeMode.dark, "ダークパターン"),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(color: Colors.white24),
        // システムメニューに戻るためのボタン
        ListTile(
          leading: Icon(Icons.arrow_back, color: AppTheme(context).menuIcon),
          title: Text("メニューに戻る", style: TextStyle(color: Colors.grey)),
          onTap: () async {
            // 波紋が広がる時間を稼ぐ
            await Future.delayed(const Duration(milliseconds: 150));
            if (!mounted) return;
            setState(() => drawerType = "menu");
          },
        ),
      ],
    );
  }

  /*
    ラジオボタンの各項目を作る補助関数
  */
  Widget _buildThemeOption(ThemeMode mode, String label) {
    return RadioListTile<ThemeMode>(
      title: Text(
        label,
        style: TextStyle(color: AppTheme(context).listText, fontSize: 15),
      ),
      value: mode,
      activeColor: AppTheme(context).sequenceHeaderText, // 選択時の色
      contentPadding: EdgeInsets.zero,
    );
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
              _audioPlayer.stop(); // ダイアログを閉じるだけ
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
    _completeSubscription = _audioPlayer.onPlayerComplete.listen((event) {
      playNextSong(isAutomatic: true); // 自動であることの証明
    });
    _durationSubscription = _audioPlayer.onDurationChanged.listen((
      newDuration,
    ) {
      setState(() => duration = newDuration);
    });
    _positionSubscription = _audioPlayer.onPositionChanged.listen((
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

  @override // 画面の見た目の処理
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // 勝手にアプリが閉じないようにする「関所」
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        if (_scaffoldKey.currentState?.isDrawerOpen ?? false) return;

        // もし下位フォルダまたは、上位フォルダの中にいるなら
        if (currentFolderName != null || currentParentName != null) {
          _resetModes();
          backToFolders();
        } else {
          // 既にトップ（一覧）にいるなら、確認ダイアログを出す
          _showExitDialog();
        }
      },
      child: Scaffold(
        key: _scaffoldKey, // 鍵を接続
        // 画面全体の背景色の設定
        backgroundColor: AppTheme(context).mainBackground,

        // --- 左から出てくるメニュー（ドロワー） ---
        drawer: Drawer(
          backgroundColor: AppTheme(context).menuBackground, // メニューの背景色
          // PopScopeで包んでバックボタンを監視
          child: Stack(
            children: [
              Positioned.fill(
                right: 3,
                child: PopScope(
                  // settingsモードの時は、バックボタンで戻る
                  canPop: false,
                  onPopInvokedWithResult: (didPop, result) {
                    if (didPop) return; // 既に閉じているなら何もしない
                    // settingsの時にバックボタンが押されたらmenuに戻す
                    if (drawerType == "settings") {
                      setState(() => drawerType = "menu");
                    } else {
                      Navigator.pop(context);
                    }
                  },
                  child: drawerType == "menu"
                      ? _buildSystemMenu()
                      : _buildSettingsMenu(),
                ),
              ),
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                width: 3.8, // 縁取りの太さ
                child: Container(
                  decoration: BoxDecoration(
                    // 縦方向（上から下）のグラデーション
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: AppTheme(context).menuGradientColors, // テーマから取得
                      stops: const [0, 0.5, 1], // 透明 -> 発光 -> 透明 の切り替わり位置
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        body: SafeArea(
          child: Column(
            children: [
              // 再生パネル全体を不透明な Container で包む
              Container(
                width: double.infinity,
                color: AppTheme(context).mainBackground,
                child: Stack(
                  children: [
                    // メインの表示・操作エリア
                    Column(
                      children: [
                        Padding(
                          // 再生中の曲名を表示するテキスト
                          // ボタンと重ならないよう、上(top)に30の隙間を作りました
                          padding: const EdgeInsets.only(
                            top: 18.0,
                            bottom: 5.0,
                            left: 60.0,
                            right: 60.0,
                          ),
                          child: Column(
                            // Columnにして情報を縦に並べる
                            children: [
                              SizedBox(
                                height: 20,
                                child: Text(
                                  // statusの状態に合わせて表示を切り替える
                                  selectSong == null
                                      ? "～NO DATA～"
                                      : "📂 ${_getFolderNameFromPath(selectSong!.data)}",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppTheme(context).playerFolderText,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),

                              const SizedBox(height: 6),

                              // 曲名エリア
                              Container(
                                height: 70, // 2行分のおおよその高さを指定
                                alignment: Alignment.center, // 中身を上下左右の中央に配置
                                child: Text(
                                  selectSong?.displayNameWOExt ?? "曲を選択してください",
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme(context).playerSongsText,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 1),

                              // 何曲目かを表示
                              SizedBox(
                                height: 20,
                                child: selectSong != null
                                    ? Text(
                                        "(${playlistSongs.indexOf(selectSong!) + 1} / ${playlistSongs.length} 曲目)",
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Colors.blueGrey,
                                        ),
                                      )
                                    : Text(
                                        "(0 / 0 曲目)",
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Colors.blueGrey,
                                        ),
                                      ), // 曲が無いときの処理
                              ),
                            ],
                          ),
                        ),

                        // シークバー
                        SizedBox(
                          height: 24,
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 3.0, // バーの太さ
                              activeTrackColor: AppTheme(
                                context,
                              ).sliderAlreadyplayed, // 再生済みの線の色
                              inactiveTrackColor: AppTheme(
                                context,
                              ).sliderBeforePlay, // 未再生の線の色（暗めの白）
                              thumbColor: AppTheme(
                                context,
                              ).sliderHandle, // つまみの丸の色
                              overlayColor: Colors.blue.withValues(
                                alpha: 0.6,
                              ), // つまみを触った時の影の色
                              overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 12.5,
                              ), // つまみを触った時の影の半径
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 5.5,
                              ), // つまみの大きさ
                            ),
                            child: Slider(
                              min: 0,
                              // 最大値を「曲の全秒数」に設定（0以下の場合はエラー回避のため0.0にする）
                              max: duration.inSeconds.toDouble() > 0
                                  ? duration.inSeconds.toDouble()
                                  : 0.0,
                              // 現在の位置
                              value: position.inSeconds.toDouble().clamp(
                                0.0,
                                duration.inSeconds.toDouble() > 0
                                    ? duration.inSeconds.toDouble()
                                    : 0.0,
                              ),
                              // つまみを動かした時の処理
                              onChanged: (value) async {
                                await _audioPlayer.seek(
                                  Duration(seconds: value.toInt()),
                                ); // 指定した時間にジャンプ
                              },
                            ),
                          ),
                        ),

                        // 時間の数字表示
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            mainAxisAlignment:
                                MainAxisAlignment.start, // 左側に寄せる
                            children: [
                              // 時間表示("0:00"/0:00)
                              Text(
                                _formatDuration(position),
                                style: TextStyle(
                                  color: AppTheme(context).playerTimeText,
                                  fontSize: 11,
                                  fontFamily: "monospace", // 数字の幅を一定にしてがたつきを防ぐ
                                ),
                              ),
                              const SizedBox(width: 2),
                              Text(
                                "/",
                                style: TextStyle(
                                  color: AppTheme(context).playerTimeText,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(width: 2),
                              // 時間表示(0:00/"0:00")
                              Text(
                                _formatDuration(duration),
                                style: TextStyle(
                                  color: AppTheme(context).playerTimeText,
                                  fontSize: 11,
                                  fontFamily: "monospace", // 数字の幅を一定にしてがたつきを防ぐ
                                ),
                              ),
                              const SizedBox(width: 14),

                              // ステータス表示(再生モード・跨ぎON/OFF)
                              Text(
                                "(${_getPlayModeText()} / ${isFolderBridgeEnabled ? "フォルダループ:ON" : "フォルダループ:OFF"})",
                                style: const TextStyle(
                                  color: Colors.blueGrey,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 5),

                        SizedBox(
                          height: 50,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center, // 中央寄せ
                            children: [
                              // 再生モードを切り替えるボタン
                              IconButton(
                                icon: Icon(
                                  playMode == 0
                                      ? Icons.trending_flat
                                      : playMode == 1
                                      ? Icons.repeat
                                      : playMode == 2
                                      ? Icons.repeat_one
                                      : Icons.shuffle, // playMode=3の時
                                  color: playMode == 0
                                      ? AppTheme(context).playerModeOffIcon
                                      : AppTheme(context).playerModeOnIcon,
                                ),
                                onPressed: () => setState(() {
                                  playMode =
                                      (playMode + 1) % 4; // 0→1→2→3→0 とループ
                                }),
                              ),

                              const SizedBox(width: 20),

                              // 前の曲へのボタン
                              _buildTransportButton(
                                icon: Icons.skip_previous,
                                onTap: playPreviousSong,
                                onLongPressStart: (_) =>
                                    _startContinuousSkip(false),
                              ),

                              const SizedBox(width: 10),

                              // 一時停止・再開ボタン
                              IconButton(
                                onPressed: () async {
                                  if (status == "play") {
                                    await _audioPlayer.pause(); // 再生中なら一時停止
                                    setState(() => status = "pause"); // 状態を停止中に
                                  } else {
                                    // 再生中でない場合
                                    // もし曲が選ばれてないなら、リストの１曲目を選択する
                                    if (selectSong == null &&
                                        displayedSongs.isNotEmpty) {
                                      setState(() {
                                        // 画面のリストを再生用リストとしてコピー
                                        playlistSongs = List.from(
                                          displayedSongs,
                                        );
                                        playingFolderName = currentFolderName;
                                      });
                                      _executePlay(playlistSongs[0]);
                                    } else if (selectSong != null) {
                                      if (status == "pause") {
                                        // 一時停止からの再開
                                        await _audioPlayer.resume();
                                      } else {
                                        // 停止状態または未選択から新規再生
                                        _executePlay(selectSong);
                                      }
                                      setState(() => status = "play");
                                    }
                                  }
                                },
                                // ボタンの文字を切り替える
                                icon: Icon(
                                  (status == "pause" || status == "stop")
                                      ? Icons.play_arrow
                                      : Icons.pause,
                                  size: 40, // アイコンの大きさを調整
                                  color: AppTheme(context).playerIcon,
                                ),
                              ),

                              const SizedBox(width: 10),

                              // 次の曲へボタン
                              _buildTransportButton(
                                icon: Icons.skip_next,
                                onTap: () => playNextSong(isAutomatic: false),
                                onLongPressStart: (_) =>
                                    _startContinuousSkip(true),
                              ),

                              const SizedBox(width: 20),

                              // フォルダ跨ぎ切り替えボタン
                              IconButton(
                                icon: Icon(
                                  Icons.account_tree, // フォルダを跨ぐイメージのアイコン
                                  color: isFolderBridgeEnabled
                                      ? Colors.greenAccent
                                      : Colors.white24,
                                ),
                                onPressed: () {
                                  setState(() {
                                    isFolderBridgeEnabled =
                                        !isFolderBridgeEnabled;
                                  });
                                  _saveAllSettings(); // 切り替えた瞬間に保存
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10), // 再生ボタン等と下の線の隙間
                      ],
                    ),

                    // 左上の三本線（ハンバーガーメニュー）ボタン
                    Positioned(
                      left: 5,
                      top: 5,
                      child: Builder(
                        builder: (context) => IconButton(
                          icon: Icon(
                            Icons.menu,
                            color: AppTheme(context).backAndMenuIcon,
                          ),
                          onPressed: () {
                            setState(() => drawerType = "menu"); // メニューモードに設定
                            Scaffold.of(context).openDrawer(); // ドロワーを開く
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, color: Colors.white24), // 境界線

              Expanded(
                child: currentParentName == null
                    ? _buildParentFolderList() // 1.最初は「まとめ一覧」を表示
                    : (currentFolderName == null
                          ? _buildFolderList() // 2.まとめを選んだら、「その中のフォルダを表示」
                          : _buildSongList()), // 3.フォルダを選んだら、「その中の曲一覧」
              ),
            ],
          ),
        ),
        floatingActionButton: (isSelectionMode && selectedSongPaths.isNotEmpty)
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
    // タイマーが裏で暴走しないように
    _stopContinuousSkip();

    // 耳(listen)を閉じる
    _completeSubscription.cancel();
    _durationSubscription.cancel();
    _positionSubscription.cancel();

    _audioPlayer.dispose(); // アプリ終了時にプレイヤーを解体してメモリを解放する

    dialogUpdater = null;

    super.dispose();
  }
}
