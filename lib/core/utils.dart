/* 
 * ファイル名: utils.dart
 * 役割: 時間変換や文字列操作などの便利な共通関数
 */

class AppUtils {
  // 時間(Duration)を "0:00" 形式の文字列に変換[分：秒]
  static String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${duration.inMinutes}：$twoDigitSeconds";
  }

  // ファイルパスから最後のフォルダ名だけを抜き出す
  static String getFolderNameFromPath(String path) {
    List<String> parts = path.split("/");
    if (parts.length >= 2) {
      return parts[parts.length - 2];
    }
    return "Unknown Folder";
  }
}