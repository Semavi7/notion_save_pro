import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Uygulama konfigürasyonu yöneticisi
class AppConfig {
  static String get notionApiKey => dotenv.env['NOTION_API_KEY'] ?? '';
  static String get targetDatabaseId => dotenv.env['TARGET_DATABASE_ID'] ?? '';
  static String get templatesDatabaseId => dotenv.env['TEMPLATES_DATABASE_ID'] ?? '';

  /// Konfigürasyonun geçerli olup olmadığını kontrol eder
  static bool get isValid {
    return notionApiKey.isNotEmpty &&
        targetDatabaseId.isNotEmpty &&
        templatesDatabaseId.isNotEmpty;
  }

  /// HTTP header'ları döndürür
  static Map<String, String> get headers => {
        'Authorization': 'Bearer $notionApiKey',
        'Notion-Version': '2025-09-03',
        'Content-Type': 'application/json',
      };

  /// Hata mesajı döndürür
  static String get configErrorMessage {
    if (notionApiKey.isEmpty) return 'NOTION_API_KEY eksik!';
    if (targetDatabaseId.isEmpty) return 'TARGET_DATABASE_ID eksik!';
    if (templatesDatabaseId.isEmpty) return 'TEMPLATES_DATABASE_ID eksik!';
    return 'Konfigürasyon hatası!';
  }
}
