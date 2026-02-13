import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Notion OAuth ve kullanıcı verilerini yöneten servis
class AuthService {
  static const String _accessTokenKey = 'notion_access_token';
  static const String _botIdKey = 'notion_bot_id';
  static const String _workspaceNameKey = 'notion_workspace_name';
  static const String _workspaceIconKey = 'notion_workspace_icon';
  static const String _selectedDatabaseIdKey = 'selected_database_id';
  static const String _selectedDatabaseTitleKey = 'selected_database_title';
  static const String _selectedTemplateIdKey = 'selected_template_id';
  static const String _selectedTemplateNameKey = 'selected_template_name';

  final _secureStorage = const FlutterSecureStorage();

  /// OAuth bilgilerini .env'den alır
  String get clientId => dotenv.env['NOTION_CLIENT_ID'] ?? '';
  String get clientSecret => dotenv.env['NOTION_CLIENT_SECRET'] ?? '';
  String get redirectUri => dotenv.env['NOTION_REDIRECT_URI'] ?? 'notionsavepro://oauth';

  /// Kullanıcının giriş yapıp yapmadığını kontrol eder
  Future<bool> isLoggedIn() async {
    final token = await _secureStorage.read(key: _accessTokenKey);
    return token != null && token.isNotEmpty;
  }

  /// Access token'ı alır
  Future<String?> getAccessToken() async {
    return await _secureStorage.read(key: _accessTokenKey);
  }

  /// OAuth token exchange - Authorization code ile access token alır
  Future<bool> exchangeCodeForToken(String code) async {
    try {
      final credentials = base64Encode(utf8.encode('$clientId:$clientSecret'));

      final response = await http.post(
        Uri.parse('https://api.notion.com/v1/oauth/token'),
        headers: {
          'Authorization': 'Basic $credentials',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'grant_type': 'authorization_code',
          'code': code,
          'redirect_uri': redirectUri,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Token'ı güvenli sakla
        await _secureStorage.write(
          key: _accessTokenKey,
          value: data['access_token'],
        );

        await _secureStorage.write(
          key: _botIdKey,
          value: data['bot_id'],
        );

        // Workspace bilgilerini sakla
        if (data['workspace_name'] != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_workspaceNameKey, data['workspace_name']);

          if (data['workspace_icon'] != null) {
            await prefs.setString(_workspaceIconKey, data['workspace_icon']);
          }
        }

        print('✅ OAuth token exchange successful');
        return true;
      } else {
        print('❌ Token exchange error: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ Token exchange exception: $e');
      return false;
    }
  }

  /// Seçili database bilgilerini saklar
  Future<void> saveSelectedDatabase(String id, String title) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedDatabaseIdKey, id);
    await prefs.setString(_selectedDatabaseTitleKey, title);
  }

  /// Seçili database ID'sini alır
  Future<String?> getSelectedDatabaseId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_selectedDatabaseIdKey);
  }

  /// Seçili database title'ını alır
  Future<String?> getSelectedDatabaseTitle() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_selectedDatabaseTitleKey);
  }

  /// Seçili template bilgilerini saklar
  Future<void> saveSelectedTemplate(String id, String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedTemplateIdKey, id);
    await prefs.setString(_selectedTemplateNameKey, name);
  }

  /// Seçili template ID'sini alır
  Future<String?> getSelectedTemplateId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_selectedTemplateIdKey);
  }

  /// Seçili template name'ini alır
  Future<String?> getSelectedTemplateName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_selectedTemplateNameKey);
  }

  /// Workspace bilgilerini alır
  Future<Map<String, String?>> getWorkspaceInfo() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'name': prefs.getString(_workspaceNameKey),
      'icon': prefs.getString(_workspaceIconKey),
    };
  }

  /// Kullanıcının setup'ı tamamlayıp tamamlamadığını kontrol eder
  Future<bool> isSetupComplete() async {
    final databaseId = await getSelectedDatabaseId();
    final templateId = await getSelectedTemplateId();
    return databaseId != null && templateId != null;
  }

  /// Logout - Tüm verileri temizler
  Future<void> logout() async {
    await _secureStorage.deleteAll();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    print('✅ Logged out successfully');
  }
}
