class Link {
  final String name;
  final String category;
  final String url;

  Link({required this.name, required this.category, required this.url});

  factory Link.fromJson(Map<String, dynamic> json) {
    return Link(
      name: json['name']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
    );
  }
}
