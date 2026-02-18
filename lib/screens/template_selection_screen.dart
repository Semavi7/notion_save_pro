import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/notion_service.dart';
import '../models/notion_template.dart';
import '../utils/locator.dart';

/// Template seçim ekranı
class TemplateSelectionScreen extends StatefulWidget {
  const TemplateSelectionScreen({super.key});

  @override
  State<TemplateSelectionScreen> createState() => _TemplateSelectionScreenState();
}

class _TemplateSelectionScreenState extends State<TemplateSelectionScreen> {
  final AuthService _authService = locator<AuthService>();
  final NotionService _notionService = locator<NotionService>();

  List<NotionTemplate> _templates = [];
  bool _isLoading = true;
  String? _error;
  String? _databaseTitle;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final databaseId = await _authService.getSelectedDatabaseId();
      _databaseTitle = await _authService.getSelectedDatabaseTitle();

      if (databaseId == null) {
        setState(() {
          _error = 'Database seçilmemiş!';
          _isLoading = false;
        });
        return;
      }

      final templates = await _notionService.getDatabaseTemplates(databaseId);

      if (!mounted) return;

      setState(() {
        _templates = templates;
        _isLoading = false;
      });

      if (templates.isEmpty) {
        setState(() {
          _error =
              'Bu database\'de hiç template bulunamadı.\n"Template yok" seçeneğiyle devam edebilirsiniz.';
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = 'Template\'ler yüklenirken hata: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _selectTemplate(NotionTemplate? template) async {
    if (template != null) {
      await _authService.saveSelectedTemplate(template.id, template.name);
    } else {
      // Template yok seçeneği
      await _authService.saveSelectedTemplate('no_template', 'Template Yok');
    }

    if (!mounted) return;

    // Ana ekrana git (setup tamamlandı)
    Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Template Seç'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Database bilgisi
          if (_databaseTitle != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.grey[100],
              child: Row(
                children: [
                  const Icon(Icons.storage, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _databaseTitle!,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // İçerik
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_error != null && _templates.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.info_outline,
                size: 64,
                color: Colors.orange,
              ),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => _selectTemplate(null),
                child: const Text('Template Olmadan Devam Et'),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: _loadTemplates,
                icon: const Icon(Icons.refresh),
                label: const Text('Tekrar Dene'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _templates.length + 1, // +1 for "no template" option
      itemBuilder: (context, index) {
        if (index == _templates.length) {
          // "Template yok" seçeneği
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            color: Colors.grey[100],
            child: ListTile(
              leading: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.block,
                  color: Colors.grey,
                ),
              ),
              title: const Text(
                'Template Kullanma',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                ),
              ),
              subtitle: const Text(
                'Sayfalar template olmadan oluşturulacak',
                style: TextStyle(fontSize: 12),
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => _selectTemplate(null),
            ),
          );
        }

        final template = _templates[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.description_outlined,
                color: Colors.blue,
              ),
            ),
            title: Text(
              template.name,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            subtitle: Text(
              template.id,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => _selectTemplate(template),
          ),
        );
      },
    );
  }
}
