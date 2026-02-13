import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/article.dart';
import '../utils/app_config.dart';

/// Notion API ile iletişim servisi
class NotionService {
  static const String baseUrl = 'https://api.notion.com/v1';
  static const int maxBlocksPerRequest = 100;

  /// Sayfa kaydeder (Varsayılan şablon ile)
  Future<bool> savePage({
    required Article article,
  }) async {
    try {
      print('🚀 Creating page with default template');

      // 1. Varsayılan template ile sayfa oluştur
      final pageId = await _createPageWithDefaultTemplate(
        article: article,
      );

      if (pageId == null) {
        print('❌ Failed to create page');
        return false;
      }

      print('✅ Page created: $pageId');
      print('⏳ Waiting for template to be applied asynchronously...');

      // 2. Şablonun uygulanması için bekleme (asenkron işlem)
      await Future.delayed(const Duration(seconds: 3));

      // 3. Makale bloklarını ekle (eğer varsa)
      if (article.blocks.isNotEmpty) {
        print('📝 Appending ${article.blocks.length} article blocks...');

        // Ayırıcı ekle
        final blocksToAdd = [
          {"object": "block", "type": "divider", "divider": {}},
          ...article.blocks,
        ];

        final success = await _appendBlocks(pageId, blocksToAdd);

        if (success) {
          print('✅ Article content added successfully');
        } else {
          print('⚠️ Failed to add article content, but page was created');
        }
      }

      print('✅ Page saved successfully: $pageId');
      return true;
    } catch (e) {
      print('❌ Save page exception: $e');
      return false;
    }
  }

  /// Notion'da varsayılan template ile sayfa oluşturur
  Future<String?> _createPageWithDefaultTemplate({
    required Article article,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/pages');

      print('📤 Creating page with default template');

      final body = jsonEncode({
        "parent": {
          "type": "data_source_id",
          "data_source_id": AppConfig.targetDatabaseId,
        },
        // Varsayılan template kullan
        "template": {
          "type": "default",
        },
        // Override edilecek property'ler
        "properties": {
          "İsim": {
            "title": [
              {
                "type": "text",
                "text": {"content": article.title}
              }
            ]
          },
          "URL": {"url": article.url},
        },
      });

      print(
          '📤 Request body: ${body.substring(0, body.length > 300 ? 300 : body.length)}...');

      final response = await http
          .post(
            url,
            headers: AppConfig.headers,
            body: body,
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['id'] as String;
      } else {
        print('❌ Create page error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('❌ Create page exception: $e');
      return null;
    }
  }

  /// Var olan sayfaya blok ekler
  Future<bool> _appendBlocks(
    String pageId,
    List<Map<String, dynamic>> blocks,
  ) async {
    try {
      // Blokları 100'er 100'er ekle
      for (int i = 0; i < blocks.length; i += maxBlocksPerRequest) {
        final batch = blocks.skip(i).take(maxBlocksPerRequest).toList();

        final url = Uri.parse('$baseUrl/blocks/$pageId/children');

        final body = jsonEncode({
          "children": batch,
        });

        final response = await http
            .patch(
              url,
              headers: AppConfig.headers,
              body: body,
            )
            .timeout(const Duration(seconds: 30));

        if (response.statusCode != 200) {
          print('Append blocks error: ${response.statusCode} - ${response.body}');
          return false;
        }

        // Rate limiting için kısa bekleme
        if (i + maxBlocksPerRequest < blocks.length) {
          await Future.delayed(const Duration(milliseconds: 334)); // ~3 req/sec
        }
      }

      return true;
    } catch (e) {
      print('Append blocks exception: $e');
      return false;
    }
  }
}
