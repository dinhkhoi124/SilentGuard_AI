import 'dart:developer' as developer;
import 'package:flutter/services.dart';

enum LegalDocumentBlockType {
  metadata,
  heading,
  subheading,
  paragraph,
  bullet,
  table,
  contact,
}

class LegalDocumentBlock {
  const LegalDocumentBlock({
    required this.type,
    required this.text,
    this.tableRows = const [],
  });

  final LegalDocumentBlockType type;
  final String text;
  final List<List<String>> tableRows;
}

class PrivacyPolicyMarkdownParser {
  static const String _assetPath = 'privacy-policy.md';

  static Future<List<LegalDocumentBlock>> parse() async {
    try {
      final content = await rootBundle.loadString(_assetPath);
      return _parseContent(content);
    } catch (e, st) {
      developer.log(
        'Failed to load/parse privacy-policy.md',
        error: e,
        stackTrace: st,
      );
      return [];
    }
  }

  static List<LegalDocumentBlock> _parseContent(String content) {
    final lines = content.split('\n');
    final blocks = <LegalDocumentBlock>[];

    bool inVietnameseSection = false;
    bool collectingTable = false;
    List<List<String>> currentTableRows = [];

    void flushTable() {
      if (collectingTable && currentTableRows.isNotEmpty) {
        // Assume first row is header, which we might skip or keep, but standard markdown table has header, `|---|`, then rows.
        // Let's filter out `|---|` rows
        final cleanedRows = currentTableRows.where((row) {
          return !row.every((cell) => cell.replaceAll('-', '').trim().isEmpty);
        }).toList();

        if (cleanedRows.isNotEmpty) {
          blocks.add(
            LegalDocumentBlock(
              type: LegalDocumentBlockType.table,
              text: '',
              tableRows: cleanedRows,
            ),
          );
        }
      }
      collectingTable = false;
      currentTableRows = [];
    }

    for (var i = 0; i < lines.length; i++) {
      var line = lines[i].trim();

      // Top-level Metadata (before languages)
      if (!inVietnameseSection &&
          line.startsWith('**SilentGuard AI**') &&
          line.contains('Phiên bản')) {
        blocks.add(
          LegalDocumentBlock(
            type: LegalDocumentBlockType.metadata,
            text: line.replaceAll('**', '').trim(),
          ),
        );
        continue;
      }

      // Handle Section Boundaries
      if (line.startsWith('## 🇻🇳 Tiếng Việt')) {
        inVietnameseSection = true;
        continue;
      }
      if (line.startsWith('## 🇬🇧 English')) {
        break; // Stop parsing when reaching English section
      }

      if (!inVietnameseSection) continue;

      // Ignore horizontal rules and empty lines
      if (line.startsWith('---') || line.isEmpty) {
        flushTable();
        continue;
      }

      // Check Table
      if (line.startsWith('|') && line.endsWith('|')) {
        collectingTable = true;
        final cells = line
            .substring(1, line.length - 1)
            .split('|')
            .map((e) => e.trim())
            .toList();
        currentTableRows.add(cells);
        continue;
      } else {
        flushTable();
      }

      // Check Headings
      if (line.startsWith('### ')) {
        blocks.add(
          LegalDocumentBlock(
            type: LegalDocumentBlockType.heading,
            text: line.substring(4).trim(),
          ),
        );
        continue;
      }

      if (line.startsWith('#### ')) {
        blocks.add(
          LegalDocumentBlock(
            type: LegalDocumentBlockType.subheading,
            text: line.substring(5).trim(),
          ),
        );
        continue;
      }

      // Check Bullets
      if (line.startsWith('- ')) {
        blocks.add(
          LegalDocumentBlock(
            type: LegalDocumentBlockType.bullet,
            text: line.substring(2).trim(),
          ),
        );
        continue;
      }

      // Check Contact lines
      if (line.startsWith('**Email:**') || line.startsWith('**Địa chỉ:**')) {
        blocks.add(
          LegalDocumentBlock(type: LegalDocumentBlockType.contact, text: line),
        );
        continue;
      }

      // Paragraphs
      blocks.add(
        LegalDocumentBlock(type: LegalDocumentBlockType.paragraph, text: line),
      );
    }

    flushTable(); // Flush if ends with table

    return blocks;
  }
}
