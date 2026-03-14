enum TransferItemType {
  text,
  file,
  folder,
}

class TransferItem {
  final String id;
  final TransferItemType type;
  final String title;
  final String? path;
  final String? text;

  TransferItem({
    required this.id,
    required this.type,
    required this.title,
    this.path,
    this.text,
  });
}