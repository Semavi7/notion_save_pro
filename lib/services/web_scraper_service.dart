import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart';
import '../models/article.dart';

/// Web scraping servisi - Makaleleri parse eder
class WebScraperService {
  static const int maxBlocks = 80; // Şablon için yer bırakıyoruz (toplam max 100)
  static const int maxTextLength = 1900; // Notion limit: 2000, güvenli marj

  /// URL'den makale içeriğini çeker ve Notion bloklarına çevirir
  Future<Article?> scrapeArticle(String url) async {
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        print('HTTP Error: ${response.statusCode}');
        return null;
      }

      final document = html_parser.parse(response.body);
      
      // Başlık ve açıklama meta verilerini al
      final title = _extractTitle(document);
      final description = _extractDescription(document);
      final imageUrl = _extractImage(document, url);
      
      // Makale içeriğini parse et
      final blocks = _parseContent(document, url);

      return Article(
        url: url,
        title: title,
        description: description,
        imageUrl: imageUrl,
        blocks: blocks,
      );
    } catch (e) {
      print('Scraping error: $e');
      return null;
    }
  }

  /// Sayfa başlığını çıkarır
  String _extractTitle(Document document) {
    // 1. Open Graph title
    var ogTitle = document.querySelector('meta[property="og:title"]');
    if (ogTitle != null) {
      final content = ogTitle.attributes['content'];
      if (content != null && content.isNotEmpty) return content;
    }

    // 2. Twitter title
    var twitterTitle = document.querySelector('meta[name="twitter:title"]');
    if (twitterTitle != null) {
      final content = twitterTitle.attributes['content'];
      if (content != null && content.isNotEmpty) return content;
    }

    // 3. <title> etiketi
    var titleElement = document.querySelector('title');
    if (titleElement != null && titleElement.text.isNotEmpty) {
      return titleElement.text.trim();
    }

    // 4. İlk h1
    var h1 = document.querySelector('h1');
    if (h1 != null && h1.text.isNotEmpty) {
      return h1.text.trim();
    }

    return 'Web Makalesi';
  }

  /// Sayfa açıklamasını çıkarır
  String? _extractDescription(Document document) {
    var ogDesc = document.querySelector('meta[property="og:description"]');
    if (ogDesc != null) {
      return ogDesc.attributes['content'];
    }

    var metaDesc = document.querySelector('meta[name="description"]');
    if (metaDesc != null) {
      return metaDesc.attributes['content'];
    }

    return null;
  }

  /// Sayfa görselini çıkarır
  String? _extractImage(Document document, String baseUrl) {
    var ogImage = document.querySelector('meta[property="og:image"]');
    if (ogImage != null) {
      var url = ogImage.attributes['content'];
      if (url != null) return _resolveUrl(url, baseUrl);
    }

    var twitterImage = document.querySelector('meta[name="twitter:image"]');
    if (twitterImage != null) {
      var url = twitterImage.attributes['content'];
      if (url != null) return _resolveUrl(url, baseUrl);
    }

    return null;
  }

  /// İçeriği parse edip Notion bloklarına çevirir
  List<Map<String, dynamic>> _parseContent(Document document, String baseUrl) {
    List<Map<String, dynamic>> blocks = [];

    // Önce article veya main etiketini bulmaya çalış
    Element? mainContent = document.querySelector('article') ??
                           document.querySelector('main') ??
                           document.querySelector('[role="main"]') ??
                           document.querySelector('.post-content') ??
                           document.querySelector('.article-content') ??
                           document.querySelector('.entry-content');

    // Bulunamazsa body kullan
    mainContent ??= document.body;

    if (mainContent == null) return blocks;

    // İçerik elementlerini al
    var elements = mainContent.querySelectorAll(
      'p, h1, h2, h3, h4, blockquote, ul, ol, img, pre, code'
    );

    int blockCount = 0;
    for (var element in elements) {
      if (blockCount >= maxBlocks) break;

      final block = _elementToNotionBlock(element, baseUrl);
      if (block != null) {
        // Uzun metinleri böl
        if (_isTextBlock(block)) {
          final textBlocks = _splitLongText(block);
          blocks.addAll(textBlocks);
          blockCount += textBlocks.length;
        } else {
          blocks.add(block);
          blockCount++;
        }
      }
    }

    return blocks;
  }

  /// HTML elementini Notion bloğuna çevirir
  Map<String, dynamic>? _elementToNotionBlock(Element element, String baseUrl) {
    final text = element.text.trim();
    
    // Boş veya çok kısa içerikleri atla
    if (text.isEmpty || (text.length < 10 && element.localName != 'img')) {
      return null;
    }

    // Navigasyon, reklam gibi istenmeyen içerikleri filtrele
    final className = element.attributes['class'] ?? '';
    if (_isUnwantedContent(className, text)) {
      return null;
    }

    switch (element.localName) {
      case 'h1':
      case 'h2':
        return _createHeadingBlock(text, 2);
      
      case 'h3':
      case 'h4':
        return _createHeadingBlock(text, 3);
      
      case 'p':
        return _createParagraphBlock(text);
      
      case 'blockquote':
        return _createQuoteBlock(text);
      
      case 'ul':
      case 'ol':
        return _createListBlock(element);
      
      case 'img':
        final src = element.attributes['src'];
        if (src != null && src.isNotEmpty) {
          final fullUrl = _resolveUrl(src, baseUrl);
          if (fullUrl.startsWith('http')) {
            return _createImageBlock(fullUrl);
          }
        }
        return null;
      
      case 'pre':
      case 'code':
        return _createCodeBlock(text);
      
      default:
        return null;
    }
  }

  /// İstenmeyen içerik kontrolü
  bool _isUnwantedContent(String className, String text) {
    final unwantedPatterns = [
      'nav', 'menu', 'header', 'footer', 'sidebar', 'advertisement',
      'ad-', 'cookie', 'subscribe', 'newsletter', 'social', 'share'
    ];
    
    final lowerClass = className.toLowerCase();
    final lowerText = text.toLowerCase();

    for (var pattern in unwantedPatterns) {
      if (lowerClass.contains(pattern)) return true;
    }

    // Çok kısa veya spam içerik
    if (text.split(' ').length < 5 && 
        (lowerText.contains('click') || lowerText.contains('subscribe'))) {
      return true;
    }

    return false;
  }

  /// Heading bloğu oluşturur
  Map<String, dynamic> _createHeadingBlock(String text, int level) {
    final type = 'heading_$level';
    return {
      "object": "block",
      "type": type,
      type: {
        "rich_text": [
          {"type": "text", "text": {"content": _truncateText(text)}}
        ]
      }
    };
  }

  /// Paragraph bloğu oluşturur
  Map<String, dynamic> _createParagraphBlock(String text) {
    return {
      "object": "block",
      "type": "paragraph",
      "paragraph": {
        "rich_text": [
          {"type": "text", "text": {"content": _truncateText(text)}}
        ]
      }
    };
  }

  /// Quote bloğu oluşturur
  Map<String, dynamic> _createQuoteBlock(String text) {
    return {
      "object": "block",
      "type": "quote",
      "quote": {
        "rich_text": [
          {"type": "text", "text": {"content": _truncateText(text)}}
        ]
      }
    };
  }

  /// Code bloğu oluşturur
  Map<String, dynamic> _createCodeBlock(String text) {
    return {
      "object": "block",
      "type": "code",
      "code": {
        "rich_text": [
          {"type": "text", "text": {"content": _truncateText(text)}}
        ],
        "language": "plain text"
      }
    };
  }

  /// Liste bloğu oluşturur
  Map<String, dynamic>? _createListBlock(Element listElement) {
    final items = listElement.querySelectorAll('li');
    if (items.isEmpty) return null;

    final firstItem = items.first.text.trim();
    if (firstItem.isEmpty) return null;

    final isBulleted = listElement.localName == 'ul';
    final type = isBulleted ? 'bulleted_list_item' : 'numbered_list_item';

    return {
      "object": "block",
      "type": type,
      type: {
        "rich_text": [
          {"type": "text", "text": {"content": _truncateText(firstItem)}}
        ]
      }
    };
  }

  /// Image bloğu oluşturur
  Map<String, dynamic> _createImageBlock(String url) {
    return {
      "object": "block",
      "type": "image",
      "image": {
        "type": "external",
        "external": {"url": url}
      }
    };
  }

  /// Göreceli URL'yi tam URL'ye çevirir
  String _resolveUrl(String url, String baseUrl) {
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }

    try {
      final baseUri = Uri.parse(baseUrl);
      if (url.startsWith('//')) {
        return '${baseUri.scheme}:$url';
      }
      if (url.startsWith('/')) {
        return '${baseUri.scheme}://${baseUri.host}$url';
      }
      // Göreceli yol
      return '${baseUri.scheme}://${baseUri.host}/${baseUri.pathSegments.join('/')}/$url';
    } catch (e) {
      return url;
    }
  }

  /// Metni kısaltır
  String _truncateText(String text) {
    if (text.length <= maxTextLength) return text;
    return '${text.substring(0, maxTextLength - 3)}...';
  }

  /// Text bloğu mu kontrol eder
  bool _isTextBlock(Map<String, dynamic> block) {
    final type = block['type'];
    return type == 'paragraph' || 
           type == 'heading_2' || 
           type == 'heading_3' ||
           type == 'quote';
  }

  /// Uzun metni birden fazla bloğa böler
  List<Map<String, dynamic>> _splitLongText(Map<String, dynamic> block) {
    final type = block['type'] as String;
    final richText = block[type]['rich_text'] as List;
    
    if (richText.isEmpty) return [block];
    
    final content = richText[0]['text']['content'] as String;
    
    if (content.length <= maxTextLength) return [block];

    // Metni parçalara böl
    List<Map<String, dynamic>> blocks = [];
    int start = 0;
    
    while (start < content.length) {
      int end = start + maxTextLength;
      if (end > content.length) end = content.length;
      
      // Kelime ortasında kesme, son boşluğu bul
      if (end < content.length) {
        int lastSpace = content.lastIndexOf(' ', end);
        if (lastSpace > start) end = lastSpace;
      }
      
      final chunk = content.substring(start, end).trim();
      
      blocks.add({
        "object": "block",
        "type": type,
        type: {
          "rich_text": [
            {"type": "text", "text": {"content": chunk}}
          ]
        }
      });
      
      start = end + 1;
    }
    
    return blocks;
  }
}
