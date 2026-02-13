/// Notion Database modeli
class NotionDatabase {
  final String id;
  final String title;
  final String? icon;

  NotionDatabase({
    required this.id,
    required this.title,
    this.icon,
  });

  factory NotionDatabase.fromJson(Map<String, dynamic> json) {
    // Title'ı parse et
    String title = 'Untitled Database';

    if (json['title'] != null && json['title'] is List) {
      final titleList = json['title'] as List;
      if (titleList.isNotEmpty) {
        final firstTitle = titleList[0];
        if (firstTitle['plain_text'] != null) {
          title = firstTitle['plain_text'];
        }
      }
    }

    // Icon'u parse et
    String? icon;
    if (json['icon'] != null) {
      final iconData = json['icon'];
      if (iconData['type'] == 'emoji') {
        icon = iconData['emoji'];
      }
    }

    return NotionDatabase(
      id: json['id'],
      title: title,
      icon: icon,
    );
  }

  @override
  String toString() => 'NotionDatabase(id: $id, title: $title)';
}
