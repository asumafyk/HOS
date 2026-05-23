// 階層を判別するための「印」(親・まとめ・曲フォルダ)
enum ViewLevel { parent, sub, song }

// HOSの編集・一括操作モードを管理する印
enum OperationMode {
  none, // 通常時
  delete, // 削除（除外）モード
  sort, // 並び替えモード
  rename, // 名前変更モード
  copy, // コピーモード
  move, // 移動モード
  assign, // 仕分けモード
}
