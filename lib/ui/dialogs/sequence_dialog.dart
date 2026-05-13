/* * ファイル名: sequence_dialog.dart
 * 役割: All Songsでの、フォルダループ（シーケンス）の並べ替え・追加・削除を行うダイアログ
 */

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SequenceDialog {
  static void show({
    required BuildContext context,
    required List<String> folderSequence,
    required Map<String, dynamic> folderMap,
    required String? playingFolderName,
    required Function(StateSetter?) onStateSetterCreated, // 再生状態のリアルタイム更新用
    required Function(List<String>) onSave, // 保存実行用
  }) {
    List<String> tempSequence = List.from(folderSequence);
    // 上段リストの初期高さ
    double topListHeight = 220.0;
    // 上段のリストを操作するためのリモコン
    final ScrollController topScrollController = ScrollController();

    // 下までスクロールさせるヘルパー
    void scrollToBottom() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (topScrollController.hasClients) {
          topScrollController.animateTo(
            topScrollController.position.maxScrollExtent, // 一番下
            duration: const Duration(milliseconds: 250), // 時間をかけて
            curve: Curves.easeOut, // 滑らかに
          );
        }
      });
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          // メイン画面側に更新用関数を渡す
          onStateSetterCreated(setDialogState);

          final theme = AppTheme(context);
          List<String> availableFolders = folderMap.keys
              .where((f) => !tempSequence.contains(f))
              .toList();

          return AlertDialog(
            backgroundColor: theme.sequenceBackground,
            titlePadding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            actionsPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            title: Text(
              "フォルダループ設定",
              style: TextStyle(color: theme.sequenceHeaderText, fontSize: 18),
            ),
            content: SizedBox(
              width: double.maxFinite,
              height: 600,
              child: Column(
                children: [
                  // --- 上段ラベル ---
                  _buildLabel("(長押しで曲順を入替え / タップで削除)", theme),

                  // --- 上段：現在のシーケンスリスト ---
                  SizedBox(
                    height: topListHeight,
                    child: Container(
                      decoration: BoxDecoration(
                        color: theme.sequenceTopBackground,
                        borderRadius: BorderRadius.circular(0), // 枠の角の丸み
                      ),
                      child: ReorderableListView(
                        scrollController: topScrollController, // リモコンを接続
                        // 持ち上げたときの見た目を定義する装飾ユニット
                        proxyDecorator: (child, index, animation) =>
                            _buildProxyDecorator(context, child, animation),
                        onReorder: (oldIdx, newIdx) {
                          setDialogState(() {
                            if (oldIdx < newIdx) newIdx -= 1;
                            final item = tempSequence.removeAt(oldIdx);
                            tempSequence.insert(newIdx, item);
                          });
                        },
                        children: tempSequence
                            .map(
                              (folder) => _buildSequenceTile(
                                context,
                                folder,
                                folder == playingFolderName,
                                () async {
                                  await Future.delayed(
                                    const Duration(milliseconds: 90),
                                  );
                                  setDialogState(
                                    () => tempSequence.remove(folder),
                                  );
                                },
                                tempSequence.indexOf(folder),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ),

                  // --- 境界線（ドラッグで高さ調節） ---
                  _buildDraggableDivider(setDialogState, (delta) {
                    // ドラッグ量に合わせて高さを増減（最小80px、最大450pxに制限）
                    topListHeight = (topListHeight + delta).clamp(80.0, 450.0);
                  }),

                  // --- 下段ラベル ---
                  _buildLabel("(フォルダ名をタップしてループに追加)", theme),

                  // --- 下段：追加可能なフォルダリスト ---
                  Expanded(
                    child: Container(
                      color: theme.sequenceUnderBackground,
                      child: ListView.builder(
                        itemCount: availableFolders.length,
                        itemBuilder: (context, index) {
                          final folder = availableFolders[index];
                          return _buildAvailableTile(
                            context,
                            folder,
                            folder == playingFolderName,
                            () async {
                              await Future.delayed(
                                const Duration(milliseconds: 90),
                              );
                              if (!context.mounted) return;
                              setDialogState(() => tempSequence.add(folder));
                              scrollToBottom();
                            },
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
                      await Future.delayed(const Duration(microseconds: 90));
                      if (!context.mounted) return;
                      onSave(tempSequence);
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
    ).then((_) {
      // ダイアログが閉じたら、メイン画面側の保持変数を null でクリアする
      onStateSetterCreated(null); 
      topScrollController.dispose();
    }); // リモコンを片付ける
  }

  // --- 補助パーツ：ラベル ---
  static Widget _buildLabel(String text, AppTheme theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0), // 下のリストとの間に隙間を追加
      child: SizedBox(
        width: double.infinity,
        child: FittedBox(
          fit: BoxFit.scaleDown, // はみ出す時だけ小さくする
          alignment: Alignment.center,
          child: Text(
            text,
            style: TextStyle(color: theme.sequenceText, fontSize: 11),
          ),
        ),
      ),
    );
  }

  // --- 補助パーツ：ドラッグ可能な仕切り ---
  static Widget _buildDraggableDivider(
    StateSetter setDialogState,
    Function(double) onDrag,
  ) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: (details) =>
          // ドラッグ量に合わせて高さを増減
          setDialogState(() => onDrag(details.delta.dy)),
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
    );
  }

  // --- 補助パーツ：上部タイル類・装飾 ---
  static Widget _buildSequenceTile(
    BuildContext context,
    String folder,
    bool isPlaying,
    VoidCallback onRemove,
    int index,
  ) {
    final theme = AppTheme(context);
    return ReorderableDelayedDragStartListener(
      key: ValueKey("seq_$folder"),
      index: index,
      child: Material(
        color: Colors.transparent,
        child: Theme(
          data: Theme.of(context).copyWith(highlightColor: theme.flashColor),
          child: Ink(
            decoration: BoxDecoration(
              gradient: isPlaying
                  ? LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: theme.sequenceTopSelectedGradient,
                      stops: const [0.0, 0.6, 1.0],
                    )
                  : null,
              color: isPlaying ? null : theme.sequenceTopBackground,
              border: Border(
                bottom: BorderSide(
                  color: theme.sequenceTopBorder, // 線の色
                  width: 0.5, // 線の太さ
                ),
              ),
            ),
            child: ListTile(
              dense: true, // 全体の隙間をギュッと凝縮
              visualDensity: const VisualDensity(
                vertical: -2,
              ), // さらに上下の余白を削る（-4まで設定可能）
              title: Text(
                folder,
                maxLines: 2, // 上段は最大2行
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isPlaying
                      ? theme.sequenceTopSelectedText
                      : theme.sequenceTopListText,
                  fontSize: 14,
                ),
              ),
              trailing: IconButton(
                icon: const Icon(
                  Icons.remove_circle_outline,
                  color: Color.fromARGB(174, 255, 82, 82),
                  size: 20,
                ),
                onPressed: onRemove,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- 補助パーツ：下部タイル類・装飾 ---
  static Widget _buildAvailableTile(
    BuildContext context,
    String folder,
    bool isPlaying,
    VoidCallback onTap,
  ) {
    final theme = AppTheme(context);
    return Material(
      color: Colors.transparent,
      child: Theme(
        data: Theme.of(context).copyWith(highlightColor: theme.flashColor),
        child: Ink(
          decoration: BoxDecoration(
            gradient: isPlaying
                ? LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: theme.sequenceUnderSelectedeGradient,
                    stops: const [0.0, 0.6, 1.0],
                  )
                : null,
            color: isPlaying ? null : theme.sequenceUnderBackground,
            border: Border(
              bottom: BorderSide(
                color: theme.sequenceUnderBorder, // 線の色
                width: 0.5, // 線の太さ
              ),
            ),
          ),
          child: ListTile(
            dense: true, // 全体の隙間をギュッと凝縮
            visualDensity: const VisualDensity(
              vertical: -2,
            ), // さらに上下の余白を削る（-4まで設定可能
            title: Text(
              folder,
              maxLines: 3, // 下段は最大3行
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isPlaying
                    ? theme.sequenceUnderSelectedText
                    : theme.sequenceUnderListText,
                fontSize: 13,
              ),
            ),
            onTap: onTap,
          ),
        ),
      ),
    );
  }

  // --- 持ち上げた際の装飾 ---
  static Widget _buildProxyDecorator(
    BuildContext context,
    Widget child,
    Animation<double> animation,
  ) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        // 持ち上げに合わせて 0.0 から 1.0 に変化する値
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
            color: Color.lerp(
              Colors.transparent, // 持ち上げ前は、背景色はもとのものに任せる
              AppTheme(context).sequenceTopHaveList, // 持ち上げた際の色
              animValue,
            ),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
