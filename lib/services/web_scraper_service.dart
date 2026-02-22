import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart';
import '../models/article.dart';

/// Web scraping servisi - Makaleleri parse eder
class WebScraperService {
  static const int maxBlocks = 200; // _appendBlocks zaten sayfalıyor, API limiti bu değil
  static const int maxTextLength = 1900; // Notion limit: 2000, güvenli marj

  /// URL'den makale içeriğini çeker ve Notion bloklarına çevirir
  Future<Article?> scrapeArticle(String url) async {
    // LinkedIn için ayrı route: oEmbed + HTML birleştirme
    if (_isLinkedInUrl(url)) {
      return _scrapeLinkedIn(url);
    }

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
          'Accept-Language': 'tr-TR,tr;q=0.9,en-US;q=0.8,en;q=0.7',
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
    // og:image ve twitter:image'ı kontrol et ama avatar değilse kullan
    final metaSelectors = [
      'meta[property="og:image"]',
      'meta[name="twitter:image"]',
    ];

    for (final selector in metaSelectors) {
      final meta = document.querySelector(selector);
      if (meta != null) {
        final url = meta.attributes['content'];
        if (url != null && url.isNotEmpty && !_isMediumAvatarUrl(url)) {
          return _resolveUrl(url, baseUrl);
        }
      }
    }

    // Meta etiketinde avatar varsa veya etiket yoksa:
    // Ham HTML'den ilk büyük miro.medium.com içerik görselini bul
    final html = document.body?.innerHtml ?? '';
    final contentImageRegex = RegExp(
      r'https://miro\.medium\.com/v2/resize:fit:(\d+)/[^\s"]+',
    );
    final matches = contentImageRegex.allMatches(html);
    for (final match in matches) {
      final width = int.tryParse(match.group(1) ?? '0') ?? 0;
      // Sadece 200px'den büyük içerik görsellerini al (avatarlar genelde <100)
      if (width >= 200) {
        return match.group(0)!;
      }
    }

    return null;
  }

  /// Medium avatar URL'si mi kontrol eder
  /// Avatar'lar fill: veya çok küçük fit: boyutları kullanır
  bool _isMediumAvatarUrl(String url) {
    if (!url.contains('miro.medium.com')) return false;
    // resize:fill: → avatar (profil fotoğrafı, dairesel kırpma)
    if (url.contains('resize:fill:')) return true;
    // resize:fit:N:M şeklinde iki boyut verildiyse avatar'dır
    // (içerik görselleri genelde tek boyut: resize:fit:783)
    if (RegExp(r'resize:fit:\d{1,3}:\d{1,3}').hasMatch(url)) return true;
    return false;
  }

  /// İçeriği parse edip Notion bloklarına çevirir
  List<Map<String, dynamic>> _parseContent(Document document, String baseUrl) {
    // Site'e özel parser'lar
    if (_isLinkedInUrl(baseUrl)) {
      return _parseLinkedInContent(document, baseUrl);
    }

    List<Map<String, dynamic>> blocks = [];

    // Önce article veya main etiketini bulmaya çalış
    // Medium'a özel seçiciler eklendi (section[data-field="body"])
    Element? mainContent = document.querySelector('article') ??
        document.querySelector('section[data-field="body"]') ??
        document.querySelector('main') ??
        document.querySelector('[role="main"]') ??
        document.querySelector('.post-content') ??
        document.querySelector('.article-content') ??
        document.querySelector('.entry-content');

    // Bulunamazsa body kullan
    mainContent ??= document.body;

    if (mainContent == null) return blocks;

    // İçerik elementlerini al
    // NOT: 'code' kasıtlı olarak çıkarıldı — <pre><code> yapısında her blok
    // iki kez sayılıyordu. Block kod pre ile, inline kod p içinde yakalanır.
    var elements = mainContent.querySelectorAll(
        'p, h1, h2, h3, h4, blockquote, ul, ol, img, figure, noscript, pre');

    int blockCount = 0;
    for (var element in elements) {
      if (blockCount >= maxBlocks) break;

      // ul/ol: tüm li'leri doğrudan işle, _elementToNotionBlock'u atla
      if (element.localName == 'ul' || element.localName == 'ol') {
        final listBlocks = _createAllListBlocks(element);
        blocks.addAll(listBlocks);
        blockCount += listBlocks.length;
        continue;
      }

      final block = _elementToNotionBlock(element, baseUrl);
      if (block != null) {
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
    // img, figure ve noscript için text kontrolü yapma (içleri görsel barındırır)
    final isMediaElement = element.localName == 'img' ||
        element.localName == 'figure' ||
        element.localName == 'noscript';
    if (!isMediaElement && (text.isEmpty || text.length < 10)) {
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
        // Tüm li'leri ayrı bloklar olarak döndürmek için null dön,
        // üst döngüde _createListBlocks ile işlenecek
        return _createListBlock(element);

      case 'img':
        // Önce src, sonra lazy-load için data-src varyantlarını dene
        final imgSrc = element.attributes['src'];
        final dataSrc = element.attributes['data-src'] ??
            element.attributes['data-lazy-src'] ??
            element.attributes['data-original'] ??
            element.attributes['data-actualsrc'];
        final srcset = element.attributes['srcset'];

        String? resolvedSrc;

        // data:// placeholder'ları atla (base64 thumbnails)
        if (imgSrc != null && imgSrc.isNotEmpty && !imgSrc.startsWith('data:')) {
          resolvedSrc = imgSrc;
        } else if (dataSrc != null &&
            dataSrc.isNotEmpty &&
            !dataSrc.startsWith('data:')) {
          resolvedSrc = dataSrc;
        } else if (srcset != null && srcset.isNotEmpty) {
          // En yüksek genişliğe sahip URL'yi seç
          resolvedSrc = _bestUrlFromSrcset(srcset);
        }

        if (resolvedSrc != null) {
          final fullUrl = _resolveUrl(resolvedSrc, baseUrl);
          if (fullUrl.startsWith('http')) {
            return _createImageBlock(fullUrl);
          }
        }
        return null;

      case 'figure':
        // Medium görselleri <figure> içinde <img> veya <noscript><img> olarak gelir
        return _extractImageFromFigure(element, baseUrl);

      case 'noscript':
        // Medium lazy-load: gerçek <img> noscript içinde saklı
        return _extractImageFromNoscript(element, baseUrl);

      case 'pre':
      case 'code':
        return _createCodeBlock(text);

      default:
        return null;
    }
  }

  // ─────────────────────────────────────────────
  // LinkedIn özel parser
  // ─────────────────────────────────────────────

  /// URL'nin LinkedIn'e ait olup olmadığını kontrol eder
  bool _isLinkedInUrl(String url) => url.contains('linkedin.com');

  /// LinkedIn scraper:
  ///   1. oEmbed API → tam post metni + küçük resim
  ///   2. Ana sayfa HTML → og:title, og:image (yüksek çözünürlüklü)
  Future<Article?> _scrapeLinkedIn(String url) async {
    try {
      // ── Paralel istek: oEmbed + Ana sayfa ───────────────────────────────
      final oembedUrl =
          'https://www.linkedin.com/oembed?url=${Uri.encodeComponent(url)}&format=json';

      final results = await Future.wait([
        http.get(Uri.parse(oembedUrl), headers: {
          'User-Agent':
              'Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)',
        }).timeout(const Duration(seconds: 15)),
        http.get(Uri.parse(url), headers: {
          'User-Agent':
              'Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)',
          'Accept': 'text/html,application/xhtml+xml,*/*;q=0.8',
        }).timeout(const Duration(seconds: 15)),
      ]);

      final oembedResponse = results[0];
      final htmlResponse = results[1];

      // ── oEmbed verisini regex ile parse et ──────────────────────────────
      String? postText;
      String? oembedImage;
      String? authorName;

      if (oembedResponse.statusCode == 200) {
        final json = oembedResponse.body;
        // Tam post metni "description" alanında
        final descMatch =
            RegExp(r'"description"\s*:\s*"((?:[^"\\]|\\.)*)"').firstMatch(json);
        if (descMatch != null) {
          postText = _unescapeJson(descMatch.group(1)!);
        }
        // Küçük resim fallback için
        final thumbMatch =
            RegExp(r'"thumbnail_url"\s*:\s*"((?:[^"\\]|\\.)*)"').firstMatch(json);
        if (thumbMatch != null) {
          oembedImage = _unescapeJson(thumbMatch.group(1)!);
        }
        // Yazar adı
        final authorMatch =
            RegExp(r'"author_name"\s*:\s*"((?:[^"\\]|\\.)*)"').firstMatch(json);
        if (authorMatch != null) {
          authorName = _unescapeJson(authorMatch.group(1)!);
        }
        print('✅ LinkedIn oEmbed başarılı: ${postText?.length ?? 0} karakter');
      } else {
        print('⚠️ LinkedIn oEmbed başarısız: ${oembedResponse.statusCode}');
      }

      // ── Ana sayfa HTML'inden başlık ve resim ────────────────────────────
      String title = 'LinkedIn Post';
      String? imageUrl;

      if (htmlResponse.statusCode == 200) {
        final document = html_parser.parse(htmlResponse.body);

        // Başlık: og:title
        final ogTitle =
            document.querySelector('meta[property="og:title"]')?.attributes['content'];
        if (ogTitle != null && ogTitle.isNotEmpty) {
          title = ogTitle;
        } else if (authorName != null) {
          title = "$authorName'ın LinkedIn Paylaşımı";
        }

        // Resim: og:image (static.licdn.com hariç)
        for (final meta in document.querySelectorAll('meta[property="og:image"]')) {
          final u = meta.attributes['content'];
          if (u != null && u.startsWith('http') && !u.contains('static.licdn.com')) {
            imageUrl = u;
            break;
          }
        }

        // og:image bulunamazsa oEmbed thumbnail kullan
        imageUrl ??= oembedImage;

        // postText hala yoksa og:description'ı son çare olarak kullan
        if (postText == null || postText.isEmpty) {
          postText = document
                  .querySelector('meta[property="og:description"]')
                  ?.attributes['content'] ??
              document.querySelector('meta[name="description"]')?.attributes['content'];
          if (postText != null) {
            print('⚠️ LinkedIn: oEmbed boş, og:description kullanıldı (kesik olabilir)');
          }
        }
      }

      // ── Notion bloklarını oluştur ────────────────────────────────────────
      final blocks = <Map<String, dynamic>>[];

      if (postText != null && postText.isNotEmpty) {
        final lines =
            postText.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
        for (final line in lines) {
          for (final chunk in _chunkText(line)) {
            blocks.add(_createParagraphBlock(chunk));
          }
        }
      }

      // Görseli blok olarak da ekle (cover görseline ek)
      if (imageUrl != null) {
        blocks.add({"object": "block", "type": "divider", "divider": {}});
        blocks.add(_createImageBlock(imageUrl));
      }

      return Article(
        url: url,
        title: title,
        description: postText?.substring(0, postText.length.clamp(0, 200)),
        imageUrl: imageUrl,
        blocks: blocks,
      );
    } catch (e) {
      print('❌ LinkedIn scrape error: $e');
      return null;
    }
  }

  /// JSON escape karakterlerini düzeltir
  String _unescapeJson(String s) => s
      .replaceAll(r'\n', '\n')
      .replaceAll(r'\r', '')
      .replaceAll(r'\"', '"')
      .replaceAll(r'\\', r'\')
      .replaceAll(r'\/', '/');

  /// LinkedIn post içeriğini meta etiketler ve JSON-LD'den çıkarır (fallback).
  List<Map<String, dynamic>> _parseLinkedInContent(Document document, String baseUrl) {
    final blocks = <Map<String, dynamic>>[];

    // JSON-LD'den tam post metni
    String? postText;
    final jsonLdScripts = document.querySelectorAll('script[type="application/ld+json"]');
    for (final script in jsonLdScripts) {
      final raw = script.text.trim();
      if (raw.isEmpty) continue;
      for (final field in ['text', 'articleBody', 'description']) {
        final m = RegExp('"$field"\\s*:\\s*"((?:[^"\\\\]|\\\\.)*)"').firstMatch(raw);
        if (m != null) {
          postText = _unescapeJson(m.group(1)!);
          break;
        }
      }
      if (postText != null) break;
    }

    postText ??=
        document.querySelector('meta[property="og:description"]')?.attributes['content'];
    postText ??=
        document.querySelector('meta[name="description"]')?.attributes['content'];

    if (postText != null && postText.isNotEmpty) {
      final lines =
          postText.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
      for (final line in lines) {
        for (final chunk in _chunkText(line)) {
          blocks.add(_createParagraphBlock(chunk));
        }
      }
    }

    final seenImages = <String>{};
    for (final meta in document.querySelectorAll('meta[property="og:image"]')) {
      final imgUrl = meta.attributes['content'];
      if (imgUrl == null || imgUrl.isEmpty) continue;
      if (!imgUrl.startsWith('http')) continue;
      if (imgUrl.contains('static.licdn.com')) continue;
      if (!seenImages.add(imgUrl)) continue;
      blocks.add(_createImageBlock(imgUrl));
    }

    return blocks;
  }

  /// Uzun metni maxTextLength parçalarına böler
  List<String> _chunkText(String text) {
    if (text.length <= maxTextLength) return [text];
    final chunks = <String>[];
    int start = 0;
    while (start < text.length) {
      int end = start + maxTextLength;
      if (end >= text.length) {
        chunks.add(text.substring(start).trim());
        break;
      }
      // Kelime ortasında kesme
      final lastSpace = text.lastIndexOf(' ', end);
      if (lastSpace > start) end = lastSpace;
      chunks.add(text.substring(start, end).trim());
      start = end + 1;
    }
    return chunks.where((c) => c.isNotEmpty).toList();
  }

  // ─────────────────────────────────────────────

  /// İstenmeyen içerik kontrolü
  bool _isUnwantedContent(String className, String text) {
    final unwantedPatterns = [
      'nav',
      'menu',
      'header',
      'footer',
      'sidebar',
      'advertisement',
      'ad-',
      'cookie',
      'subscribe',
      'newsletter',
      'social',
      'share'
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
          {
            "type": "text",
            "text": {"content": _truncateText(text)}
          }
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
          {
            "type": "text",
            "text": {"content": _truncateText(text)}
          }
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
          {
            "type": "text",
            "text": {"content": _truncateText(text)}
          }
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
          {
            "type": "text",
            "text": {"content": _truncateText(text)}
          }
        ],
        "language": "plain text"
      }
    };
  }

  /// Liste bloğu oluşturur (sadece ilk li - _createAllListBlocks için fallback)
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
          {
            "type": "text",
            "text": {"content": _truncateText(firstItem)}
          }
        ]
      }
    };
  }

  /// Tüm li elemanlarını ayrı Notion blokları olarak döndürür
  List<Map<String, dynamic>> _createAllListBlocks(Element listElement) {
    final items = listElement.querySelectorAll('li');
    if (items.isEmpty) return [];

    final isBulleted = listElement.localName == 'ul';
    final type = isBulleted ? 'bulleted_list_item' : 'numbered_list_item';

    final blocks = <Map<String, dynamic>>[];
    for (final item in items) {
      final text = item.text.trim();
      if (text.isEmpty) continue;
      blocks.add({
        "object": "block",
        "type": type,
        type: {
          "rich_text": [
            {
              "type": "text",
              "text": {"content": _truncateText(text)}
            }
          ]
        }
      });
    }
    return blocks;
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

  /// <figure> elementinden görsel URL'sini çıkarır (Medium için)
  Map<String, dynamic>? _extractImageFromFigure(Element figure, String baseUrl) {
    // ── 1. <img src> veya <img data-src> ────────────────────────────────────
    final img = figure.querySelector('img');
    if (img != null) {
      final src = img.attributes['src'];
      final dataSrc = img.attributes['data-src'] ?? img.attributes['data-lazy-src'];
      final candidate =
          (dataSrc != null && dataSrc.isNotEmpty && !dataSrc.startsWith('data:'))
              ? dataSrc
              : (src != null && src.isNotEmpty && !src.startsWith('data:') ? src : null);
      if (candidate != null) {
        final fullUrl = _resolveUrl(candidate, baseUrl);
        if (fullUrl.startsWith('http')) return _createImageBlock(fullUrl);
      }
    }

    // ── 2. <picture> içindeki <source srcset> ───────────────────────────────
    // Medium: <source data-testid="og" srcset="...640w, ...1400w"> → PNG, yüksek çözünürlük
    // Önce data-testid="og" olan kaynağı dene (webp değil, orijinal format)
    final picture = figure.querySelector('picture');
    if (picture != null) {
      // Öncelik: data-testid="og" → orijinal PNG
      final ogSource = picture.querySelector('source[data-testid="og"]');
      final srcsetUrl = _bestUrlFromSrcset(ogSource?.attributes['srcset']);
      if (srcsetUrl != null) {
        final fullUrl = _resolveUrl(srcsetUrl, baseUrl);
        if (fullUrl.startsWith('http')) return _createImageBlock(fullUrl);
      }
      // Fallback: herhangi bir <source srcset>
      for (final source in picture.querySelectorAll('source')) {
        final u = _bestUrlFromSrcset(source.attributes['srcset']);
        if (u != null) {
          final fullUrl = _resolveUrl(u, baseUrl);
          if (fullUrl.startsWith('http')) return _createImageBlock(fullUrl);
        }
      }
    }

    // ── 3. <noscript> içindeki img ───────────────────────────────────────────
    final noscript = figure.querySelector('noscript');
    if (noscript != null) {
      return _extractImageFromNoscript(noscript, baseUrl);
    }
    return null;
  }

  /// srcset string'inden en yüksek genişlikli (son) URL'yi çıkarır.
  /// Örnek: "https://...640w, https://...1400w" → "https://...1400w"
  String? _bestUrlFromSrcset(String? srcset) {
    if (srcset == null || srcset.isEmpty) return null;
    String? best;
    int bestWidth = 0;
    for (final part in srcset.split(',')) {
      final tokens = part.trim().split(RegExp(r'\s+'));
      if (tokens.isEmpty) continue;
      final url = tokens[0];
      if (!url.startsWith('http')) continue;
      // Genişlik descriptor: "640w" → 640
      int width = 0;
      if (tokens.length > 1) {
        final w = tokens[1].replaceAll('w', '');
        width = int.tryParse(w) ?? 0;
      }
      if (best == null || width > bestWidth) {
        best = url;
        bestWidth = width;
      }
    }
    return best;
  }

  /// <noscript> içindeki HTML'yi parse edip görsel URL'sini çıkarır (Medium lazy-load)
  Map<String, dynamic>? _extractImageFromNoscript(Element noscript, String baseUrl) {
    try {
      final innerHtml = noscript.innerHtml.trim();
      if (innerHtml.isEmpty) return null;
      // noscript içeriğini mini HTML olarak parse et
      final fragment = html_parser.parseFragment(innerHtml);
      final img = fragment.querySelector('img');
      if (img == null) return null;
      final src = img.attributes['src'] ?? img.attributes['data-src'];
      if (src != null && src.isNotEmpty && !src.startsWith('data:')) {
        final fullUrl = _resolveUrl(src, baseUrl);
        if (fullUrl.startsWith('http')) return _createImageBlock(fullUrl);
      }
    } catch (_) {}
    return null;
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
            {
              "type": "text",
              "text": {"content": chunk}
            }
          ]
        }
      });

      start = end + 1;
    }

    return blocks;
  }
}
