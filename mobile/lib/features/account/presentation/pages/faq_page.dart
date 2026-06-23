import 'package:flutter/material.dart';
import 'package:mobile/core/utils/app_colors.dart';
import 'package:mobile/features/account/data/faq_markdown_parser.dart';
import 'package:mobile/features/account/presentation/widgets/faq/faq_category_chips.dart';
import 'package:mobile/features/account/presentation/widgets/faq/faq_empty_state.dart';
import 'package:mobile/features/account/presentation/widgets/faq/faq_header.dart';
import 'package:mobile/features/account/presentation/widgets/faq/faq_question_card.dart';
import 'package:mobile/features/account/presentation/widgets/faq/faq_search_field.dart';

class FaqPage extends StatefulWidget {
  const FaqPage({super.key});

  @override
  State<FaqPage> createState() => _FaqPageState();
}

class _FaqPageState extends State<FaqPage> {
  static const String _allCategory = 'Tất cả';

  List<FaqItem>? _allItems;
  bool _isLoading = true;
  bool _hasError = false;

  String _searchQuery = '';
  String _selectedCategory = _allCategory;
  int? _expandedIndex;

  @override
  void initState() {
    super.initState();
    _loadFaq();
  }

  Future<void> _loadFaq() async {
    final items = await FaqMarkdownParser.parse();
    if (!mounted) return;

    if (items.isEmpty) {
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    } else {
      setState(() {
        _allItems = items;
        _isLoading = false;
        _expandedIndex = 0; // Expand first item by default
      });
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
      _expandedIndex = 0; // Reset expansion when filtering
    });
  }

  void _onCategorySelected(String category) {
    setState(() {
      _selectedCategory = category;
      _expandedIndex = 0; // Reset expansion when filtering
    });
  }

  void _toggleExpanded(int index) {
    setState(() {
      if (_expandedIndex == index) {
        _expandedIndex = null;
      } else {
        _expandedIndex = index;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget body;

    if (_isLoading) {
      body = const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    } else if (_hasError || _allItems == null) {
      body = const Center(
        child: FaqEmptyState(
          title: 'Không thể tải FAQ',
          subtitle: 'Vui lòng thử lại sau.',
        ),
      );
    } else {
      // 1. Extract distinct categories (plus "Tất cả")
      final categories = [_allCategory];
      categories.addAll(_allItems!.map((e) => e.category).toSet());

      // 2. Filter items
      final filteredItems = _allItems!.where((item) {
        final matchesCategory =
            _selectedCategory == _allCategory ||
            item.category == _selectedCategory;
        if (!matchesCategory) return false;

        if (_searchQuery.isEmpty) return true;

        return item.question.toLowerCase().contains(_searchQuery) ||
            item.answer.toLowerCase().contains(_searchQuery);
      }).toList();

      body = Column(
        children: [
          FaqSearchField(onChanged: _onSearchChanged),
          const SizedBox(height: 16),
          FaqCategoryChips(
            categories: categories,
            selectedCategory: _selectedCategory,
            onCategorySelected: _onCategorySelected,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: filteredItems.isEmpty
                ? const SingleChildScrollView(
                    child: FaqEmptyState(
                      title: 'Không tìm thấy câu hỏi',
                      subtitle:
                          'Thử nhập từ khóa khác hoặc chọn danh mục khác.',
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 60),
                    itemCount: filteredItems.length,
                    itemBuilder: (context, index) {
                      final item = filteredItems[index];
                      return FaqQuestionCard(
                        item: item,
                        isExpanded: _expandedIndex == index,
                        onTap: () => _toggleExpanded(index),
                      );
                    },
                  ),
          ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            const FaqHeader(),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}
