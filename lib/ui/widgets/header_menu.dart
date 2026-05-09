/* * ファイル名: header_menu.dart
 * 役割: ヘッダーから展開される操作ボタンのグリッド表示
 */

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class HeaderMenu extends StatelessWidget {
  final List<HeaderMenuItem> items;

  const HeaderMenu({
    super.key,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    // ヘッダーメニューを作成
    return Container(
      color: AppTheme(context).sequenceBackground.withValues(alpha: 0.5),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: GridView.count(
        shrinkWrap: true, // 内容量に合わせる
        physics: const NeverScrollableScrollPhysics(), // スクロールさせない
        crossAxisCount: 4, // 4列
        mainAxisSpacing: 6, // 縦の隙間
        crossAxisSpacing: 8, // 横の隙間
        childAspectRatio: 1.0, // ボタンの形を少し横長にして高さを抑える
        // 実際のメニューの内容
        children: items.map((item) => _buildIconButton(context, item)).toList(),
      ),
    );
  }

  // ヘッダーメニュー内、各項目ごとのアイコンボタンを作成
  Widget _buildIconButton(BuildContext context, HeaderMenuItem item) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: (item.color ?? Colors.blueAccent).withValues(alpha: 0.3),
              width: 1,
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(item.icon, size: 20, color: item.color ?? Colors.blueAccent),
              const SizedBox(height: 2),
              Expanded(
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      item.label,
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

}

// ボタンの情報をまとめるクラス
class HeaderMenuItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  HeaderMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });
}