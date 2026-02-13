import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:app_links/app_links.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../services/auth_service.dart';

/// Notion OAuth login ekranı
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  final AppLinks _appLinks = AppLinks();
  StreamSubscription? _linkSubscription;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _handleOAuthCallback();
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  /// OAuth callback'i dinle
  void _handleOAuthCallback() {
    // İlk deep link'i kontrol et
    _appLinks.getInitialLink().then((Uri? uri) {
      if (uri != null && uri.scheme == 'notionsavepro') {
        print('📲 Initial OAuth callback in LoginScreen: $uri');
        _processOAuthCallback(uri);
      }
    });

    // Uygulama açıkken gelen deep link'leri dinle
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (Uri uri) {
        if (uri.scheme == 'notionsavepro') {
          print('📲 OAuth callback in LoginScreen: $uri');
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
      print('🔑 Authorization code: $code');
      Fluttertoast.showToast(msg: '🔑 Code: ${code.substring(0, 8)}...');

      setState(() => _isLoading = true);

      // Token exchange
      final success = await _authService.exchangeCodeForToken(code);

      if (success && mounted) {
        print('✅ Token exchange successful');
        Fluttertoast.showToast(msg: '✅ Login successful!');
        Navigator.pushReplacementNamed(context, '/database-selection');
      } else {
        print('❌ Token exchange failed');
        Fluttertoast.showToast(msg: '❌ Login failed!');
        setState(() => _isLoading = false);
      }
    }
  }

  /// Notion OAuth sayfasını açar
  Future<void> _startOAuthFlow() async {
    final clientId = _authService.clientId;
    final redirectUri = _authService.redirectUri;

    if (clientId.isEmpty || clientId == 'your_client_id_here') {
      _showError('.env dosyasında NOTION_CLIENT_ID ayarlanmamış!');
      return;
    }

    // OAuth URL'i oluştur
    final authUrl = Uri.https('api.notion.com', '/v1/oauth/authorize', {
      'client_id': clientId,
      'response_type': 'code',
      'owner': 'user',
      'redirect_uri': redirectUri,
    });

    // Tarayıcıda OAuth sayfasını aç
    if (await canLaunchUrl(authUrl)) {
      await launchUrl(authUrl, mode: LaunchMode.externalApplication);

      // Kullanıcıya bilgi ver
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notion\'da izin verdikten sonra uygulamaya geri döneceksiniz'),
            duration: Duration(seconds: 5),
          ),
        );
      }
    } else {
      _showError('OAuth sayfası açılamadı');
    }
  }

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('❌ $message'),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black,
              Colors.grey[900]!,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo/Icon
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(
                    Icons.bookmarks_rounded,
                    size: 60,
                    color: Colors.black,
                  ),
                ),

                const SizedBox(height: 32),

                // Başlık
                const Text(
                  'Notion Save Pro',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: 12),

                // Alt başlık
                Text(
                  'Web içeriklerini Notion\'a kaydet',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[400],
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 48),

                // Özellikler
                _buildFeature(Icons.link, 'URL\'leri kolayca paylaş'),
                const SizedBox(height: 16),
                _buildFeature(Icons.description, 'Kendi template\'lerini kullan'),
                const SizedBox(height: 16),
                _buildFeature(Icons.storage, 'Database\'lerini yönet'),

                const Spacer(),

                // Login butonu
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _startOAuthFlow,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.asset(
                                'assets/notion_icon.png',
                                width: 24,
                                height: 24,
                                errorBuilder: (_, __, ___) => const Icon(Icons.login),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Notion ile Giriş Yap',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),

                const SizedBox(height: 24),

                // Bilgilendirme
                Text(
                  'Notion hesabınıza güvenli bir şekilde bağlanacaksınız',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeature(IconData icon, String text) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.grey[800],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 20,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 16),
        Text(
          text,
          style: TextStyle(
            fontSize: 15,
            color: Colors.grey[300],
          ),
        ),
      ],
    );
  }
}
