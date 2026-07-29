import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';

/// Server-backed unread message count shared by buyer and vendor navigation.
class MessageUnreadController extends ChangeNotifier {
  MessageUnreadController._();

  static final MessageUnreadController instance = MessageUnreadController._();

  int _count = 0;
  bool _refreshing = false;

  int get count => _count;
  bool get hasUnread => _count > 0;

  Future<void> refresh(Dio dio) async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final response = await dio.get(
        '${AppConfig.conversationsEndpoint}/unread-count',
      );
      final next =
          int.tryParse(response.data?['unread_count']?.toString() ?? '') ?? 0;
      if (next != _count) {
        _count = next;
        notifyListeners();
      }
    } catch (_) {
      // Keep the last known value during a temporary network failure.
    } finally {
      _refreshing = false;
    }
  }

  void clear() {
    if (_count == 0) return;
    _count = 0;
    notifyListeners();
  }
}

class UnreadMessageIcon extends StatefulWidget {
  final Dio dio;
  final IconData icon;
  final double? size;
  final Color? color;

  const UnreadMessageIcon({
    super.key,
    required this.dio,
    this.icon = Icons.chat_bubble_outline_rounded,
    this.size,
    this.color,
  });

  @override
  State<UnreadMessageIcon> createState() => _UnreadMessageIconState();
}

class _UnreadMessageIconState extends State<UnreadMessageIcon> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      MessageUnreadController.instance.refresh(widget.dio);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: MessageUnreadController.instance,
      builder: (context, _) => Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(widget.icon, size: widget.size, color: widget.color),
          if (MessageUnreadController.instance.hasUnread)
            PositionedDirectional(
              top: -2,
              end: -4,
              child: Container(
                width: 9,
                height: 9,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
