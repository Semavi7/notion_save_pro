/// Web makale modeli
class Article {
  final String url;
  final String title;
  final String? description;
  final String? imageUrl;
  final List<Map<String, dynamic>> blocks;

  Article({
    required this.url,
    required this.title,
    this.description,
    this.imageUrl,
    this.blocks = const [],
  });

  @override
  String toString() => 'Article(url: $url, title: $title, blocks: ${blocks.length})';
}
