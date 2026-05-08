/* * ファイル名: app_drawer.dart
 * 役割: システムメニューと設定画面を切り替えるサイドメニュー（ドロワー）
 */

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AppDrawer extends StatelessWidget {
  final String drawerType; // メイン画面から受け取る
  final Function(String) onTypeChanged; // メイン画面へ報告する
  final ThemeMode currentTheme;
  final Function(ThemeMode) onThemeChanged;
  final VoidCallback onScanPressed;

  const AppDrawer({
    super.key,
    required this.drawerType,
    required this.onTypeChanged,
    required this.currentTheme,
    required this.onThemeChanged,
    required this.onScanPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme(context);

    return Drawer(
      backgroundColor: theme.menuBackground,
      child: Stack(
        children: [
          // メインコンテンツ
          Positioned.fill(
            right: 3,
            // PopScopeで包んでバックボタンを監視
            child: PopScope(
              // settingsモードの時は、バックボタンで戻る
              canPop: false,
              onPopInvokedWithResult: (didPop, result) {
                if (didPop) return; // 既に閉じているなら何もしない
                // settingsの時にバックボタンが押されたらmenuに戻す
                if (drawerType == "settings") {
                  onTypeChanged("menu");
                } else {
                  Navigator.pop(context);
                }
              },
              child: drawerType == "menu"
                  ? _buildSystemMenu(theme)
                  : _buildSettingsMenu(theme),
            ),
          ),
          // 右端の光る縦グラデーションのエフェクト
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: 3.8, // 縁取りの太さ
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: theme.menuGradientColors,
                  stops: const [0, 0.5, 1],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- システムメニュー（最初の画面）---
  Widget _buildSystemMenu(AppTheme theme) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        DrawerHeader(
          decoration: BoxDecoration(color: theme.menuBackground),
          child: Text(
            "SYSTEM MENU",
            style: TextStyle(
              color: theme.menuHeader,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
        ListTile(
          leading: Icon(Icons.refresh, color: theme.menuIcon),
          title: Text("全曲スキャン（更新）", style: TextStyle(color: theme.menuText)),
          onTap: onScanPressed,
        ),
        ListTile(
          leading: Icon(Icons.settings, color: theme.menuIcon),
          title: Text("設定", style: TextStyle(color: theme.menuText)),
          onTap: () => onTypeChanged("settings"), // メイン画面へ報告
        ),
      ],
    );
  }

  // --- 設定メニュー ---
  Widget _buildSettingsMenu(AppTheme theme) {
    return Column(
      children: [
        DrawerHeader(
          decoration: BoxDecoration(color: theme.menuBackground),
          child: Container(
            alignment: Alignment.bottomLeft,
            child: Text(
              "設定",
              style: TextStyle(
                color: theme.menuHeader,
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
                    color: theme.menuText,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
              _buildThemeOption(theme, ThemeMode.system, "システム設定に準拠"),
              _buildThemeOption(theme, ThemeMode.light, "ホワイトパターン"),
              _buildThemeOption(theme, ThemeMode.dark, "ダークパターン"),
            ],
          ),
        ),
        const Divider(color: Colors.white24),
        // システムメニューに戻るためのボタン
        ListTile(
          leading: Icon(Icons.arrow_back, color: theme.menuIcon),
          title: const Text("メニューに戻る", style: TextStyle(color: Colors.grey)),
          onTap: () => onTypeChanged("menu"), // メイン画面へ報告
        ),
      ],
    );
  }

  // --- ラジオボタンの各項目を作る補助関数 ---
  Widget _buildThemeOption(AppTheme theme, ThemeMode mode, String label) {
    return RadioListTile<ThemeMode>(
      title: Text(label, style: TextStyle(color: theme.listText, fontSize: 15)),
      value: mode,
      groupValue: currentTheme,
      activeColor: theme.sequenceHeaderText, // 選択時の色
      onChanged: (val) => onThemeChanged(val!),
    );
  }
}
