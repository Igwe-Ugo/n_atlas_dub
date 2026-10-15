class DubSegment {
  final int index;
  final double start;
  final double end;
  final String originalText;
  final String translatedText;
  final String editedText;
  final String finalText;
  final String status;
  final List<dynamic> flags;
  final List<dynamic> warnings;

  const DubSegment({
    required this.index,
    required this.start,
    required this.end,
    required this.originalText,
    required this.translatedText,
    required this.editedText,
    required this.finalText,
    required this.status,
    this.flags = const [],
    this.warnings = const [],
  });

  factory DubSegment.fromJson(Map<String, dynamic> json) {
    double number(dynamic value) => value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '') ?? 0;
    String string(dynamic value) => value?.toString() ?? '';
    return DubSegment(
      index: (json['index'] as num?)?.toInt() ?? 0,
      start: number(json['start']),
      end: number(json['end']),
      originalText: string(json['original_text']),
      translatedText: string(json['translated_text']),
      editedText: string(json['edited_text']),
      finalText: string(json['final_text']),
      status: string(json['status']),
      flags: json['flags'] is List
          ? List<dynamic>.from(json['flags'])
          : const [],
      warnings: json['warnings'] is List
          ? List<dynamic>.from(json['warnings'])
          : const [],
    );
  }

  DubSegment copyWith({
    String? editedText,
    String? finalText,
    String? status,
  }) => DubSegment(
    index: index,
    start: start,
    end: end,
    originalText: originalText,
    translatedText: translatedText,
    editedText: editedText ?? this.editedText,
    finalText: finalText ?? this.finalText,
    status: status ?? this.status,
    flags: flags,
    warnings: warnings,
  );
}
