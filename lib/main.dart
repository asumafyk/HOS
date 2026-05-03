import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

import 'ui/screens/main_screen.dart';

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

