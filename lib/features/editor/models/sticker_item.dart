class StickerItem {
  final String id;
  final String title;
  final String previewUrl; // small, for the grid
  final String fullUrl; // full-size, downloaded on tap

  const StickerItem({
    required this.id,
    required this.title,
    required this.previewUrl,
    required this.fullUrl,
  });

  factory StickerItem.fromGiphy(Map<String, dynamic> j) {
    final images = j['images'] as Map<String, dynamic>;
    return StickerItem(
      id: j['id'] as String,
      title: (j['title'] as String?) ?? '',
      previewUrl: images['fixed_width_small']['url'] as String,
      fullUrl: images['original']['url'] as String,
    );
  }
}

class StickerPage {
  final List<StickerItem> items;
  final int nextOffset;
  final bool hasMore;
  const StickerPage(this.items, this.nextOffset, this.hasMore);
}