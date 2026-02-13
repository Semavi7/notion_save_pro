import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/article.dart';
import '../models/notion_database.dart';
import '../models/notion_template.dart';
import 'auth_service.dart';

/// Notion API ile iletişim servisi
class NotionService {
  static const String baseUrl = 'https://api.notion.com/v1';
  static const int maxBlocksPerRequest = 100;

  final AuthService _authService = AuthService();

  /// OAuth token kullanarak headers oluştur
  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getAccessToken();

    if (token == null) {
      throw Exception('Kullanıcı giriş yapmamış!');
    }

    return {
      'Authorization': 'Bearer $token',
      'Notion-Version': '2025-09-03',
      'Content-Type': 'application/json',
    };
  }

  /// Kullanıcının database'lerini listeler
  Future<List<NotionDatabase>> searchDatabases() async {
    try {
      final url = Uri.parse('$baseUrl/search');
      final headers = await _getHeaders();

      final response = await http
          .post(
            url,
            headers: headers,
            body: jsonEncode({
              'page_size': 100,
              // Filter kaldırıldı - tüm sonuçları alıp client-side filtreleyeceğiz
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final results = data['results'] as List;

        print('🔍 Search API returned ${results.length} total results');

        // Debug: İlk birkaç sonucu göster
        for (var i = 0; i < (results.length > 3 ? 3 : results.length); i++) {
          print(
              '  Result $i: ${results[i]['object']} - ${results[i]['title'] ?? results[i]['properties']?['title'] ?? 'no title'}');
        }

        // Sadece database'leri filtrele (Notion API v2025-09-03'te data_source olarak döner)
        final databases = results
            .where((item) => item['object'] == 'data_source')
            .map((json) => NotionDatabase.fromJson(json))
            .toList();

        print('✅ Found ${databases.length} databases');
        return databases;
      } else {
        print('❌ Search databases error: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      print('❌ Search databases exception: $e');
      return [];
    }
  }

  /// Database'in template'lerini listeler
  Future<List<NotionTemplate>> getDatabaseTemplates(String databaseId) async {
    try {
      final url = Uri.parse('$baseUrl/data_sources/$databaseId/templates');
      final headers = await _getHeaders();

      final response =
          await http.get(url, headers: headers).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final templates = data['templates'] as List?;

        if (templates != null) {
          return templates
              .map((json) => NotionTemplate(
                    id: json['id'],
                    name: json['name'] ?? 'İsimsiz Template',
                  ))
              .toList();
        }
        return [];
      } else {
        print('❌ Get templates error: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      print('❌ Get templates exception: $e');
      return [];
    }
  }

  /// Sayfa kaydeder (Kullanıcının seçtiği database ve template ile)
  Future<bool> savePage({
    required Article article,
  }) async {
    try {
      // Kullanıcının tercihlerini al
      final databaseId = await _authService.getSelectedDatabaseId();
      final templateId = await _authService.getSelectedTemplateId();

      if (databaseId == null) {
        print('❌ Database seçilmemiş!');
        return false;
      }

      print('🚀 Creating page in database: $databaseId');
      if (templateId != null && templateId != 'no_template') {
        print('📋 Using template: $templateId');
      }

      // 1. Sayfa oluştur
      final pageId = await _createPage(
        article: article,
        databaseId: databaseId,
        templateId: templateId,
      );

      if (pageId == null) {
        print('❌ Failed to create page');
        return false;
      }

      print('✅ Page created: $pageId');

      // 2. Template kullanıldıysa biraz bekle
      if (templateId != null && templateId != 'no_template') {
        print('⏳ Waiting for template to be applied...');
        await Future.delayed(const Duration(seconds: 3));
      }

      // 3. Makale bloklarını ekle
      if (article.blocks.isNotEmpty) {
        print('📝 Adding ${article.blocks.length} article blocks...');

        final blocksToAdd = [
          {"object": "block", "type": "divider", "divider": {}},
          ...article.blocks,
          {"object": "block", "type": "divider", "divider": {}},
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

  /// Notion'da sayfa oluşturur (template ile veya template'siz)
  Future<String?> _createPage({
    required Article article,
    required String databaseId,
    String? templateId,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/pages');
      final headers = await _getHeaders();

      print('📤 Creating page in database: $databaseId');

      // Template seçilmişse ve "no_template" değilse template kullan
      final useTemplate = templateId != null && templateId != 'no_template';

      final Map<String, dynamic> requestBody = {
        "parent": {
          "type": "data_source_id",
          "data_source_id": databaseId,
        },
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
      };

      // Template kullanılacaksa ekle
      if (useTemplate) {
        requestBody["template"] = {
          "type": "template_id",
          "template_id": templateId,
        };
      }

      final body = jsonEncode(requestBody);

      print('📤 Request: ${body.substring(0, body.length > 300 ? 300 : body.length)}...');

      final response = await http
          .post(
            url,
            headers: headers,
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
      final headers = await _getHeaders();

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
              headers: headers,
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
