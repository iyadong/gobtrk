// lib/config.dart
class ApiConfig {
  /// Default awal (lokal). Bisa berubah dari LoginPage setelah user input kode ngrok.
  static String baseUrl = "http://172.27.226.6:8080";

  /// Domain ngrok free (umumnya begini)
  static String ngrokDomain = "ngrok-free.app";

  static String buildNgrokBaseUrl(String code) {
    return "https://$code.$ngrokDomain";
  }

  static String get wsBaseUrl {
    if (baseUrl.startsWith("https")) {
      return baseUrl.replaceFirst("https", "wss");
    } else if (baseUrl.startsWith("http")) {
      return baseUrl.replaceFirst("http", "ws");
    }
    return "ws://$baseUrl";
  }
}
