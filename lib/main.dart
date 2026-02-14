import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:app_links/app_links.dart';

import 'services/notion_service.dart';
import 'services/web_scraper_service.dart';
import 'services/auth_service.dart';
import 'screens/login_screen.dart';
import 'screens/database_selection_screen.dart';
import 'screens/template_selection_screen.dart';

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
      // Routes
      routes: {
        '/home': (context) => const SaveHandler(),
        '/login': (context) => const LoginScreen(),
        '/database-selection': (context) => const DatabaseSelectionScreen(),
        '/template-selection': (context) => const TemplateSelectionScreen(),
      },
      home: const SplashScreen(),
    );
  }
}

/// Splash screen - Kullanıcıyı uygun sayfaya yönlendirir
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final AuthService _authService = AuthService();
  final AppLinks _appLinks = AppLinks();

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    // Önce OAuth callback'i kontrol et
    final initialUri = await _appLinks.getInitialLink();

    if (initialUri != null && initialUri.scheme == 'notionsavepro') {
      Fluttertoast.showToast(msg: '📲 OAuth callback detected');

      final code = initialUri.queryParameters['code'];

      if (code != null) {
        Fluttertoast.showToast(msg: '🔑 Code received: ${code.substring(0, 8)}...');

        // Token exchange yap
        final success = await _authService.exchangeCodeForToken(code);

        if (success && mounted) {
          Fluttertoast.showToast(msg: '✅ Login successful!');
          // Token alındı, database selection'a git
          await Future.delayed(const Duration(milliseconds: 500));
          Navigator.pushReplacementNamed(context, '/database-selection');
          return;
        } else {
          Fluttertoast.showToast(msg: '❌ Login failed!');
        }
      }
    }

    // OAuth callback yoksa normal akışı sürdür
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    await Future.delayed(const Duration(seconds: 1)); // Splash göster

    final isLoggedIn = await _authService.isLoggedIn();

    if (!mounted) return;

    if (!isLoggedIn) {
      // Giriş yapmamış -> Login ekranına
      Navigator.pushReplacementNamed(context, '/login');
    } else {
      final isSetupComplete = await _authService.isSetupComplete();

      if (!isSetupComplete) {
        // Setup tamamlanmamış -> Database seçimine
        Navigator.pushReplacementNamed(context, '/database-selection');
      } else {
        // Her şey tamam -> Ana ekrana
        Navigator.pushReplacementNamed(context, '/home');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black, Colors.grey[900]!],
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.bookmarks_rounded, size: 80, color: Colors.white),
              SizedBox(height: 16),
              CircularProgressIndicator(color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ana ekran - URL paylaşımını handle eder
class SaveHandler extends StatefulWidget {
  const SaveHandler({super.key});

  @override
  State<SaveHandler> createState() => _SaveHandlerState();
}

class _SaveHandlerState extends State<SaveHandler> {
  late StreamSubscription _intentSubscription;
  late StreamSubscription? _uriLinkSubscription;
  late AppLinks _appLinks;

  final AuthService _authService = AuthService();
  final NotionService _notionService = NotionService();
  final WebScraperService _scraperService = WebScraperService();

  final TextEditingController _titleController = TextEditingController();

  String? _sharedUrl;
  bool _isSaving = false;

  String? _selectedDatabaseTitle;
  String? _selectedTemplateName;

  @override
  void initState() {
    super.initState();
    _appLinks = AppLinks();
    _loadUserPreferences();
    _setupSharingIntent();
    _handleOAuthCallback();
  }

  /// Kullanıcı tercihlerini yükle
  Future<void> _loadUserPreferences() async {
    final dbTitle = await _authService.getSelectedDatabaseTitle();
    final templateName = await _authService.getSelectedTemplateName();

    if (mounted) {
      setState(() {
        _selectedDatabaseTitle = dbTitle;
        _selectedTemplateName = templateName;
      });
    }
  }

  /// OAuth callback'i dinle
  void _handleOAuthCallback() {
    // İlk deep link'i kontrol et (uygulama kapalıyken açılmışsa)
    _appLinks.getInitialLink().then((Uri? uri) {
      if (uri != null && uri.scheme == 'notionsavepro') {
        _processOAuthCallback(uri);
      }
    });

    // Uygulama açıkken gelen deep link'leri dinle
    _uriLinkSubscription = _appLinks.uriLinkStream.listen(
      (Uri uri) async {
        if (uri.scheme == 'notionsavepro') {
          _processOAuthCallback(uri);
        }
      },
      onError: (err) {
        print('❌ URI link error: $err');
      },
    );
  }

  /// OAuth callback'i işle
  Future<void> _processOAuthCallback(Uri uri) async {
    final code = uri.queryParameters['code'];
    if (code != null) {
      // Token exchange
      final success = await _authService.exchangeCodeForToken(code);

      if (success && mounted) {
        // Database seçimine yönlendir
        Navigator.pushReplacementNamed(context, '/database-selection');
      } else {
        _showToast('❌ Giriş başarısız!');
      }
    }
  }

  /// Paylaşım intent'lerini ayarlar
  void _setupSharingIntent() {
    // Uygulama açıkken gelen paylaşımlar
    _intentSubscription = ReceiveSharingIntent.instance.getMediaStream().listen(
      (List<SharedMediaFile> files) {
        if (files.isNotEmpty) {
          final file = files.first;
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
        if (file.type == SharedMediaType.text || file.type == SharedMediaType.url) {
          _handleSharedUrl(file.path);
        }
      }
    });
  }

  /// URL paylaşıldığında çağrılır
  Future<void> _handleSharedUrl(String url) async {
    setState(() {
      _sharedUrl = url;
    });

    // Başlığı scrape et
    final article = await _scraperService.scrapeArticle(url);
    if (article != null && mounted) {
      setState(() {
        _titleController.text = article.title;
      });
    } else if (mounted) {
      setState(() {
        _titleController.text = 'Web Makalesi';
      });
    }
  }

  /// Kaydetme işlemi
  Future<void> _saveToNotion() async {
    if (_sharedUrl == null) return;

    setState(() => _isSaving = true);

    // Dialog'u kapat
    if (mounted) Navigator.of(context).pop();

    try {
      // Makaleyi scrape et
      Fluttertoast.showToast(msg: "🔍 Sayfa içeriği çekiliyor...");

      final article = await _scraperService.scrapeArticle(_sharedUrl!);

      if (article == null) {
        _showToast("❌ Sayfa içeriği alınamadı");
        _closeApp();
        return;
      }

      Fluttertoast.showToast(msg: "💾 Notion'a kaydediliyor...");

      // Notion'a kaydet
      final success = await _notionService.savePage(article: article);

      if (success) {
        _showToast("✅ Başarıyla kaydedildi!");
      } else {
        _showToast("❌ Kaydetme başarısız");
      }

      await Future.delayed(const Duration(milliseconds: 1500));
      _closeApp();
    } catch (e) {
      _showToast("❌ Hata: ${e.toString()}");
      _closeApp();
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _intentSubscription.cancel();
    _uriLinkSubscription?.cancel();
    _titleController.dispose();
    super.dispose();
  }

  void _showToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      backgroundColor: Colors.black87,
      textColor: Colors.white,
    );
  }

  void _closeApp() {
    SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _sharedUrl == null ? _buildWelcomeScreen() : _buildSaveDialog(),
    );
  }

  Widget _buildWelcomeScreen() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black, Colors.grey[900]!],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.share, size: 80, color: Colors.white),
              const SizedBox(height: 24),
              const Text(
                'Bir sayfa paylaşın',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Tarayıcıdan "Paylaş" yapınca buraya gelecek',
                style: TextStyle(fontSize: 16, color: Colors.grey[400]),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              if (_selectedDatabaseTitle != null && _selectedTemplateName != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[850],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      _buildInfo('Database:', _selectedDatabaseTitle!),
                      const SizedBox(height: 8),
                      _buildInfo('Template:', _selectedTemplateName!),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(context, '/database-selection');
                  },
                  icon: const Icon(Icons.settings, color: Colors.white70),
                  label: const Text(
                    'Ayarları Değiştir',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfo(String label, String value) {
    return Row(
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildSaveDialog() {
    // URL paylaşılınca otomatik dialog göster
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_sharedUrl != null && !_isSaving) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => _buildDialog(),
        );
      }
    });

    return Container(); // Dialog gösterilecek
  }

  Widget _buildDialog() {
    return AlertDialog(
      title: const Text('Notion\'a Kaydet'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Başlık',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: _isSaving ? null : _closeApp, child: const Text('İptal')),
        ElevatedButton(
          onPressed: _isSaving ? null : _saveToNotion,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Kaydet'),
        ),
      ],
    );
  }
}
