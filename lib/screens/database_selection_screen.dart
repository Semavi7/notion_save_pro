import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/notion_service.dart';
import '../models/notion_database.dart';

/// Database seçim ekranı
class DatabaseSelectionScreen extends StatefulWidget {
  const DatabaseSelectionScreen({super.key});

  @override
  State<DatabaseSelectionScreen> createState() => _DatabaseSelectionScreenState();
}

class _DatabaseSelectionScreenState extends State<DatabaseSelectionScreen> {
  final AuthService _authService = AuthService();
  final NotionService _notionService = NotionService();

  List<NotionDatabase> _databases = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDatabases();
  }

  Future<void> _loadDatabases() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final databases = await _notionService.searchDatabases();

      if (!mounted) return;

      setState(() {
        _databases = databases;
        _isLoading = false;
      });

      if (databases.isEmpty) {
        setState(() {
          _error =
              'Notion hesabınızda hiç database bulunamadı.\nÖnce Notion\'da bir database oluşturun.';
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = 'Database\'ler yüklenirken hata: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _selectDatabase(NotionDatabase database) async {
    await _authService.saveSelectedDatabase(database.id, database.title);

    if (!mounted) return;

    // Template seçim ekranına git
    Navigator.pushReplacementNamed(context, '/template-selection');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Database Seç'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _buildDatabaseList(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadDatabases,
              icon: const Icon(Icons.refresh),
              label: const Text('Tekrar Dene'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDatabaseList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _databases.length,
      itemBuilder: (context, index) {
        final database = _databases[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  database.icon ?? '📊',
                  style: const TextStyle(fontSize: 24),
                ),
              ),
            ),
            title: Text(
              database.title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            subtitle: Text(
              database.id,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => _selectDatabase(database),
          ),
        );
      },
    );
  }
}
