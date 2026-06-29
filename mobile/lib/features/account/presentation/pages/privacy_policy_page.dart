import 'package:flutter/material.dart';
import 'package:mobile/core/utils/app_colors.dart';
import 'package:mobile/features/account/data/privacy_policy_markdown_parser.dart';
import 'package:mobile/features/account/presentation/widgets/legal/legal_document_block_widget.dart';
import 'package:mobile/features/account/presentation/widgets/legal/legal_document_header.dart';
import 'package:mobile/features/account/presentation/widgets/legal/legal_empty_state.dart';

class PrivacyPolicyPage extends StatefulWidget {
  const PrivacyPolicyPage({super.key});

  @override
  State<PrivacyPolicyPage> createState() => _PrivacyPolicyPageState();
}

class _PrivacyPolicyPageState extends State<PrivacyPolicyPage> {
  List<LegalDocumentBlock>? _blocks;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadDocument();
  }

  Future<void> _loadDocument() async {
    final blocks = await PrivacyPolicyMarkdownParser.parse();
    if (!mounted) return;

    if (blocks.isEmpty) {
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    } else {
      setState(() {
        _blocks = blocks;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget body;

    if (_isLoading) {
      body = const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    } else if (_hasError || _blocks == null) {
      body = const Center(
        child: LegalEmptyState(
          title: 'Không thể tải chính sách',
          subtitle: 'Vui lòng thử lại sau.',
        ),
      );
    } else {
      body = ListView.builder(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 60),
        itemCount: _blocks!.length,
        itemBuilder: (context, index) {
          return LegalDocumentBlockWidget(block: _blocks![index]);
        },
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            const LegalDocumentHeader(title: 'Chính sách quyền riêng tư'),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}
