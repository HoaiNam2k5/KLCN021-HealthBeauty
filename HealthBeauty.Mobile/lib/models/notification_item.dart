import 'dart:convert';

class NotificationItem {
  final int id;
  final String title;
  final String body;
  final String type;
  final String? rawData;
  final bool isRead;
  final DateTime createdAt;

  const NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.rawData,
    required this.isRead,
    required this.createdAt,
  });

  Map<String, dynamic>? get parsedData {
    if (rawData == null || rawData!.isEmpty) return null;
    try {
      return jsonDecode(rawData!) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      type: json['type'] as String? ?? 'HeThong',
      rawData: json['data'] as String?,
      isRead: json['isRead'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)?.toLocal() ??
              DateTime.now()
          : DateTime.now(),
    );
  }

  NotificationItem copyWith({
    int? id,
    String? title,
    String? body,
    String? type,
    String? rawData,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return NotificationItem(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      rawData: rawData ?? this.rawData,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
