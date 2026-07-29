import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/routes/routes.dart';
import '../../../../core/theme/colors.dart';
import '../../data/message_models.dart';
import '../../data/message_service.dart';
import '../message_unread_controller.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  late final MessageService _service = MessageService(sl<Dio>());
  late Future<List<ConversationModel>> _future = _loadConversations();

  Future<List<ConversationModel>> _loadConversations() async {
    final conversations = await _service.getConversations();
    await MessageUnreadController.instance.refresh(sl<Dio>());
    return conversations;
  }

  Future<void> _refresh() async {
    setState(() => _future = _loadConversations());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.background,
      appBar: AppBar(
        title: const Text('الرسائل'),
        centerTitle: true,
        automaticallyImplyLeading: Navigator.canPop(context),
      ),
      body: FutureBuilder<List<ConversationModel>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorState(error: snapshot.error, onRetry: _refresh);
          }
          final conversations = snapshot.data ?? const [];
          if (conversations.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                children: [
                  SizedBox(height: 180.h),
                  Icon(
                    Icons.forum_outlined,
                    size: 72.sp,
                    color: AppColors.textSecondary,
                  ),
                  SizedBox(height: 16.h),
                  const Center(child: Text('لا توجد محادثات بعد')),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              padding: EdgeInsets.all(16.w),
              itemCount: conversations.length,
              separatorBuilder: (_, __) => SizedBox(height: 8.h),
              itemBuilder: (context, index) {
                final item = conversations[index];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primary.withValues(alpha: .12),
                      child: const Icon(Icons.person_outline),
                    ),
                    title: Text(
                      item.otherUserName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      item.lastMessage.isEmpty
                          ? item.productName
                          : '${item.productName}\n${item.lastMessage}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (item.unreadCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              item.unreadCount > 99
                                  ? '99+'
                                  : '${item.unreadCount}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                              ),
                            ),
                          ),
                        Text(
                          DateFormat(
                            'MM/dd\nHH:mm',
                          ).format(item.updatedAt.toLocal()),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10.sp,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    onTap: () {
                      Navigator.pushNamed(
                        context,
                        Routes.chat,
                        arguments: {
                          'conversationId': item.id,
                          'vendorId': item.vendorId,
                          'productId': item.productId,
                          'title': item.otherUserName,
                          'productName': item.productName,
                        },
                      ).then((_) => _refresh());
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final Object? error;
  final Future<void> Function() onRetry;

  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 56, color: AppColors.error),
            const SizedBox(height: 12),
            Text(
              error is DioException &&
                      ((error as DioException).response?.statusCode == 401 ||
                          (error as DioException).response?.statusCode == 403)
                  ? 'يرجى تسجيل الدخول لعرض الرسائل'
                  : 'تعذر تحميل الرسائل',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }
}
