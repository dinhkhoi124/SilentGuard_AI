import 'dart:developer' as developer;
import 'package:flutter/services.dart';

class FaqItem {
  const FaqItem({
    required this.category,
    required this.question,
    required this.answer,
  });

  final String category;
  final String question;
  final String answer;
}

class FaqMarkdownParser {
  static const String _assetPath = 'faq.md';

  /// Map internal heading strings to clean UI categories
  static final Map<String, String> _categoryMap = {
    'Về sản phẩm': 'Sản phẩm',
    'Về tính năng': 'Tính năng',
    'Về lắp đặt & chi phí': 'Lắp đặt',
    'Về quyền riêng tư': 'Quyền riêng tư',
    'Về hỗ trợ': 'Hỗ trợ',
  };

  static Future<List<FaqItem>> parse() async {
    try {
      final content = await rootBundle.loadString(_assetPath);
      return _parseContent(content);
    } catch (e, st) {
      developer.log('Failed to load/parse faq.md', error: e, stackTrace: st);
      return [];
    }
  }

  static List<FaqItem> _parseContent(String content) {
    final lines = content.split('\n');
    final items = <FaqItem>[];

    bool inVietnameseSection = false;
    String currentCategory = 'Khác';
    String? currentQuestion;
    final currentAnswer = StringBuffer();

    void flushItem() {
      if (currentQuestion != null && currentAnswer.isNotEmpty) {
        items.add(
          FaqItem(
            category: currentCategory,
            question: currentQuestion!,
            answer: currentAnswer.toString().trim(),
          ),
        );
      }
      currentQuestion = null;
      currentAnswer.clear();
    }

    for (var i = 0; i < lines.length; i++) {
      var line = lines[i].trim();

      // Handle Section Boundaries
      if (line.startsWith('## 🇻🇳 Tiếng Việt')) {
        inVietnameseSection = true;
        continue;
      }
      if (line.startsWith('## 🇬🇧 English')) {
        break; // Stop parsing when reaching English section
      }

      if (!inVietnameseSection) continue;

      // Ignore horizontal rules and empty lines if not collecting answer
      if (line.startsWith('---')) continue;
      if (line.isEmpty) {
        if (currentQuestion != null) {
          currentAnswer.writeln();
        }
        continue;
      }

      // Check Category Heading
      if (line.startsWith('### ')) {
        flushItem();
        final rawCat = line.substring(4).trim();
        currentCategory = _categoryMap[rawCat] ?? rawCat;
        continue;
      }

      // Check Question
      if (line.startsWith('**') && line.endsWith('**')) {
        flushItem();
        currentQuestion = line.substring(2, line.length - 2).trim();
        continue;
      }

      // Check alternative Question formatting without closing **
      if (line.startsWith('**')) {
        // Some markdown parsers handle newlines inside bold. Let's assume standard single-line bold for questions.
        // Or just fallback to normal string replacement
        if (line.contains('**', 2)) {
          flushItem();
          final qEnd = line.lastIndexOf('**');
          currentQuestion = line.substring(2, qEnd).trim();
          // Anything after might be answer? Let's assume it's just a question line
          continue;
        }
      }

      // Collect Answer
      if (currentQuestion != null) {
        currentAnswer.writeln(line);
      }
    }

    flushItem(); // Flush the last item

    return items;
  }
}
