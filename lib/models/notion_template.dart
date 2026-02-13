/// Notion şablon modeli
class NotionTemplate {
  final String id;
  final String name;

  NotionTemplate({
    required this.id,
    required this.name,
  });

  factory NotionTemplate.fromJson(Map<String, dynamic> json) {
    String name = "İsimsiz Şablon";

    try {
      // Notion'da title property'si genelde "Name", "Title" veya "İsim" olur
      final properties = json['properties'];

      if (properties['İsim']?['title'] != null &&
          properties['İsim']['title'].isNotEmpty) {
        name = properties['İsim']['title'][0]['text']['content'];
      } else if (properties['Name']?['title'] != null &&
          properties['Name']['title'].isNotEmpty) {
        name = properties['Name']['title'][0]['text']['content'];
      } else if (properties['Title']?['title'] != null &&
          properties['Title']['title'].isNotEmpty) {
        name = properties['Title']['title'][0]['text']['content'];
      }
    } catch (e) {
      print('⚠️ Template name parse error: $e');
    }

    return NotionTemplate(
      id: json['id'],
      name: name,
    );
  }

  @override
  String toString() => 'NotionTemplate(id: $id, name: $name)';
}
