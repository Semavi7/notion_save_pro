import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/notion_template.dart';
import '../models/article.dart';
import '../utils/app_config.dart';

/// Notion API ile iletişim servisi
class NotionService {
  static const String baseUrl = 'https://api.notion.com/v1';
  static const int maxBlocksPerRequest = 100;

  /// Şablonları listeler (ARTİK KULLANILMIYOR - varsayılan template kullanılıyor)
  @Deprecated('Default template kullanılıyor, template seçimi kaldırıldı')
  Future<List<NotionTemplate>> getTemplates() async {
    try {
      // Önce Notion'un resmi template endpoint'ini dene (2025-09-03+ gerektirir)
      final templatesUrl =
          Uri.parse('$baseUrl/data_sources/${AppConfig.templatesDatabaseId}/templates');

      final templateResponse = await http
          .get(
            templatesUrl,
            headers: AppConfig.headers,
          )
          .timeout(const Duration(seconds: 10));

      if (templateResponse.statusCode == 200) {
        final data = jsonDecode(templateResponse.body);
        final templates = data['templates'] as List;

        print('🎯 Found ${templates.length} official templates');

        return templates
            .map((json) => NotionTemplate(
                  id: json['id'],
                  name: json['name'],
                ))
            .toList();
      }

      // Template endpoint çalışmadıysa, database'deki sayfaları template olarak kullan
      print(
          '⚠️ Template API not available (${templateResponse.statusCode}), fetching database pages...');

      final dbUrl =
          Uri.parse('$baseUrl/databases/${AppConfig.templatesDatabaseId}/query');

      final dbResponse = await http
          .post(
            dbUrl,
            headers: AppConfig.headers,
            body: jsonEncode({
              "page_size": 100,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (dbResponse.statusCode == 200) {
        final data = jsonDecode(dbResponse.body);
        final results = data['results'] as List;

        print('📋 Found ${results.length} pages to use as templates');

        return results.map((json) => NotionTemplate.fromJson(json)).toList();
      } else {
        print('❌ Database query error: ${dbResponse.statusCode} - ${dbResponse.body}');
        return [];
      }
    } catch (e) {
      print('❌ Templates fetch exception: $e');
      return [];
    }
  }

  /// Şablon sayfasının tüm bilgilerini getirir (properties dahil)
  Future<Map<String, dynamic>?> getTemplatePage(String pageId) async {
    try {
      final url = Uri.parse('$baseUrl/pages/$pageId');

      final response = await http
          .get(
            url,
            headers: AppConfig.headers,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        print('Template page fetch error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Template page fetch exception: $e');
      return null;
    }
  }

  /// Şablon içeriğini (bloklarını) getirir
  Future<List<Map<String, dynamic>>> getTemplateBlocks(String pageId) async {
    try {
      final url = Uri.parse('$baseUrl/blocks/$pageId/children');

      final response = await http
          .get(
            url,
            headers: AppConfig.headers,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final results = data['results'] as List;

        // Blokları temizle (ID'leri ve meta verileri kaldır)
        return results
            .map((block) => _cleanBlock(block))
            .where((block) => block != null)
            .cast<Map<String, dynamic>>()
            .toList();
      } else {
        print('Template blocks fetch error: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Template blocks fetch exception: $e');
      return [];
    }
  }

  /// Bloğu temizler (Notion'un kabul etmediği alanları kaldırır)
  Map<String, dynamic>? _cleanBlock(Map<String, dynamic> block) {
    try {
      final type = block['type'] as String;

      // Unsupported blokları atla
      if (type == 'unsupported') {
        print('⚠️ Skipping unsupported block');
        return null;
      }

      final content = Map<String, dynamic>.from(block[type] ?? {});

      // Notion'un yeni sayfa oluştururken kabul etmediği alanları sil
      content.remove('id');
      content.remove('created_time');
      content.remove('last_edited_time');
      content.remove('created_by');
      content.remove('last_edited_by');
      content.remove('has_children');
      content.remove('archived');
      content.remove('parent');

      // Child bloklarını da temizle (recursive)
      if (content['children'] != null) {
        final children = content['children'] as List;
        content['children'] = children
            .map((child) => _cleanBlock(child))
            .where((child) => child != null)
            .toList();
      }

      return {
        "object": "block",
        "type": type,
        type: content,
      };
    } catch (e) {
      print('Block cleaning error: $e');
      return null;
    }
  }

  /// Property'yi temizler (Notion'un kabul etmediği alanları kaldırır)
  Map<String, dynamic> _cleanProperty(Map<String, dynamic> property) {
    final cleaned = Map<String, dynamic>.from(property);

    // Meta verileri kaldır
    cleaned.remove('id');
    cleaned.remove('created_time');
    cleaned.remove('last_edited_time');
    cleaned.remove('created_by');
    cleaned.remove('last_edited_by');

    return cleaned;
  }

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

  /// Notion'da template kullanarak sayfa oluşturur (DEPRECATED - Manuel kopyalama)
  @Deprecated('Use _createPageWithDefaultTemplate instead')
  Future<String?> _createPageFromTemplate({
    required Article article,
    required String templateId,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/pages');

      print('🚀 Creating page with template: $templateId');

      // Template sayfasını al
      final templatePage = await getTemplatePage(templateId);

      // Şablon property'lerini hazırla
      Map<String, dynamic> properties = {};

      if (templatePage != null && templatePage['properties'] != null) {
        final templateProps = templatePage['properties'] as Map<String, dynamic>;

        // Template property'lerini kopyala
        templateProps.forEach((key, value) {
          if (key != 'İsim' && key != 'URL') {
            properties[key] = _cleanProperty(value);
          }
        });

        print('📋 Copied ${properties.length} properties from template');
      }

      // Kullanıcı property'lerini ekle
      properties['İsim'] = {
        "title": [
          {
            "type": "text",
            "text": {"content": article.title}
          }
        ]
      };

      properties['URL'] = {"url": article.url};

      final body = jsonEncode({
        "parent": {"database_id": AppConfig.targetDatabaseId},
        "properties": properties,
        // İlk önce boş sayfa oluştur, sonra blokları ekleyeceğiz
      });

      print('📤 Creating page...');

      final response = await http
          .post(
            url,
            headers: AppConfig.headers,
            body: body,
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final pageId = data['id'] as String;

        // Template bloklarını ekle
        final templateBlocks = await getTemplateBlocks(templateId);
        if (templateBlocks.isNotEmpty) {
          print('📦 Adding ${templateBlocks.length} template blocks...');
          await _appendBlocks(pageId, templateBlocks);
        }

        return pageId;
      } else {
        print('❌ Create page error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('❌ Create page exception: $e');
      return null;
    }
  }

  /// Notion'da sayfa oluşturur (eski metot - artık kullanılmıyor)
  @Deprecated('Use _createPageFromTemplate instead')
  Future<String?> _createPage(
    Article article,
    List<Map<String, dynamic>> blocks,
    Map<String, dynamic>? templatePage,
  ) async {
    try {
      final url = Uri.parse('$baseUrl/pages');

      print('🚀 Creating page with ${blocks.length} blocks');

      // Şablon property'lerini al ve temizle
      Map<String, dynamic> properties = {};

      if (templatePage != null && templatePage['properties'] != null) {
        final templateProps = templatePage['properties'] as Map<String, dynamic>;

        // Template property'lerini kopyala (read-only olanları atla)
        templateProps.forEach((key, value) {
          // İsim ve URL dışındaki property'leri kopyala
          if (key != 'İsim' && key != 'URL') {
            properties[key] = _cleanProperty(value);
          }
        });

        print('📋 Copied ${properties.length} properties from template');
      }

      // Kullanıcı tarafından sağlanan property'leri ekle (override)
      properties['İsim'] = {
        "title": [
          {
            "type": "text",
            "text": {"content": article.title}
          }
        ]
      };

      properties['URL'] = {"url": article.url};

      final body = jsonEncode({
        "parent": {"database_id": AppConfig.targetDatabaseId},
        "properties": properties,
        "children": blocks,
      });

      // DEBUG: İstek body'sini logla (kısaltılmış)
      print(
          'Request body (first 500 chars): ${body.substring(0, body.length > 500 ? 500 : body.length)}...');

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
        print('Create page error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('Create page exception: $e');
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

  /// API bağlantısını test eder
  Future<bool> testConnection() async {
    try {
      final templates = await getTemplates();
      return templates.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
}
