import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/features/account/presentation/widgets/help_support/help_support_header.dart';
import 'package:mobile/features/account/presentation/widgets/help_support/help_support_menu_item.dart';

const _items = [
  'Câu hỏi thường gặp',
  'Liên hệ hỗ trợ',
  'Chính sách quyền riêng tư',
  'Điều khoản dịch vụ',
  'Đối tác',
  'Tuyển dụng',
  'Trợ năng',
  'Góp ý',
  'Về chúng tôi',
  'Đánh giá ứng dụng',
  'Truy cập website',
  'Theo dõi trên mạng xã hội',
];

class HelpSupportPage extends StatelessWidget {
  const HelpSupportPage({super.key});

  void _showComingSoonSnackBar(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Tính năng này sẽ được kết nối sau.')),
      );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            const HelpSupportHeader(),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 20),
                itemCount: _items.length,
                itemBuilder: (context, index) {
                  final label = _items[index];
                  return HelpSupportMenuItem(
                    label: label,
                    onTap: () {
                      if (label == 'Câu hỏi thường gặp') {
                        context.push('/faq');
                      } else if (label == 'Chính sách quyền riêng tư') {
                        context.push('/privacy-policy');
                      } else {
                        _showComingSoonSnackBar(context);
                      }
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
