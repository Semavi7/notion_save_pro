import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:fluttertoast/fluttertoast.dart';

import 'services/notion_service.dart';
import 'services/web_scraper_service.dart';
import 'utils/app_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // .env dosyasını yükle
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    print('⚠️ .env dosyası yüklenemedi: $e');
  }

  runApp(const NotionSaveProApp());
}

class NotionSaveProApp extends StatelessWidget {
  const NotionSaveProApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Notion Save Pro',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.black,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: Colors.transparent,
        dialogBackgroundColor: Colors.white,
        useMaterial3: true,
        textTheme: GoogleFonts.interTextTheme(),
      ),
      home: const SaveHandler(),
    );
  }
}

class SaveHandler extends StatefulWidget {
  const SaveHandler({super.key});

  @override
  State<SaveHandler> createState() => _SaveHandlerState();
}

class _SaveHandlerState extends State<SaveHandler> {
  late StreamSubscription _intentSubscription;
  final NotionService _notionService = NotionService();
  final WebScraperService _scraperService = WebScraperService();

  final TextEditingController _titleController = TextEditingController();

  String? _sharedUrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  /// Uygulamayı başlatır
  Future<void> _initializeApp() async {
    // Konfigürasyonu kontrol et
    if (!AppConfig.isValid) {
      _showErrorDialog(
        'Konfigürasyon Hatası',
        AppConfig.configErrorMessage,
      );
      return;
    }

    // Paylaşım intent'lerini dinle
    _setupSharingIntent();
  }

  /// Paylaşım intent'lerini ayarlar
  void _setupSharingIntent() {
    // Uygulama açıkken gelen paylaşımlar
    _intentSubscription = ReceiveSharingIntent.instance.getMediaStream().listen(
      (List<SharedMediaFile> files) {
        if (files.isNotEmpty) {
          final file = files.first;
          // Text veya URL tipindeki paylaşımları işle
          if (file.type == SharedMediaType.text || file.type == SharedMediaType.url) {
            _handleSharedUrl(file.path);
          }
        }
      },
      onError: (err) {
        print('Intent stream error: $err');
      },
    );

    // Uygulama kapalıyken yapılan paylaşım
    ReceiveSharingIntent.instance.getInitialMedia().then((List<SharedMediaFile> files) {
      if (files.isNotEmpty) {
        final file = files.first;
        // Text veya URL tipindeki paylaşımları işle
        if (file.type == SharedMediaType.text || file.type == SharedMediaType.url) {
          _handleSharedUrl(file.path);
        }
      }
    });
  }

  /// Paylaşılan URL'yi işler
  void _handleSharedUrl(String url) {
    if (!mounted) return;

    setState(() {
      _sharedUrl = url;
      _titleController.text = 'Yükleniyor...';
    });

    // Dialog'u göster
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showSaveDialog();
    });

    // Başlığı fetch et (arka planda)
    _fetchArticleTitle(url);
  }

  /// Makale başlığını getirir
  Future<void> _fetchArticleTitle(String url) async {
    try {
      final article = await _scraperService.scrapeArticle(url);

      if (!mounted) return;

      if (article != null) {
        setState(() {
          _titleController.text = article.title;
        });
      } else {
        setState(() {
          _titleController.text = 'Web Makalesi';
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _titleController.text = 'Web Makalesi';
      });
    }
  }

  /// Kaydetme işlemini başlatır
  Future<void> _saveToNotion() async {
    if (_sharedUrl == null) return;

    setState(() => _isSaving = true);

    // Dialog'u kapat
    if (mounted) Navigator.of(context).pop();

    try {
      // Makaleyi scrape et
      Fluttertoast.showToast(
        msg: "📥 Makale getiriliyor...",
        toastLength: Toast.LENGTH_SHORT,
      );

      final article = await _scraperService.scrapeArticle(_sharedUrl!);

      if (article == null) {
        _showToast("❌ Makale içeriği alınamadı");
        _closeApp();
        return;
      }

      Fluttertoast.showToast(
        msg: "💾 Notion'a kaydediliyor...",
        toastLength: Toast.LENGTH_SHORT,
      );

      // Notion'a kaydet (varsayılan şablon ile)
      final success = await _notionService.savePage(
        article: article,
      );

      if (success) {
        _showToast("✅ Başarıyla kaydedildi!");
      } else {
        _showToast("❌ Kaydetme başarısız");
      }

      // Uygulamayı kapat
      await Future.delayed(const Duration(milliseconds: 1500));
      _closeApp();
    } catch (e) {
      _showToast("❌ Hata: ${e.toString()}");
      _closeApp();
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  /// Kaydetme dialog'unu gösterir
  void _showSaveDialog() {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.bookmark_add,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Notion\'a Kaydet',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Başlık alanı
                  TextField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText: 'Başlık',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: const Icon(Icons.title),
                    ),
                    maxLines: 2,
                    minLines: 1,
                  ),

                  const SizedBox(height: 16),

                  // URL gösterimi
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.link, size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _sharedUrl ?? 'URL yok',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: _isSaving
                    ? null
                    : () {
                        Navigator.of(context).pop();
                        _closeApp();
                      },
                child: const Text('İptal'),
              ),
              ElevatedButton(
                onPressed: _isSaving ? null : _saveToNotion,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Kaydet'),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Hata dialog'u gösterir
  void _showErrorDialog(String title, String message) {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _closeApp();
            },
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  /// Toast mesajı gösterir
  void _showToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.black87,
      textColor: Colors.white,
      fontSize: 14.0,
    );
  }

  /// Uygulamayı kapatır
  void _closeApp() {
    if (mounted) {
      SystemNavigator.pop();
    }
  }

  @override
  void dispose() {
    _intentSubscription.cancel();
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Görünmez arka plan - sadece paylaşım için açılır
    return const Scaffold(
      backgroundColor: Colors.transparent,
      body: SizedBox.shrink(),
    );
  }
}
