import 'dart:ui';
import 'package:flutter/material.dart';

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
