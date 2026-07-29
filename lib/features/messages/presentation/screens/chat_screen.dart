import 'dart:async';

import 'package:dio/dio.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/routes/routes.dart';
import '../../../../core/theme/colors.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../cart/presentation/cubit/cart_cubit.dart';
import '../../../shop/presentation/cubit/products_cubit.dart';
import '../../data/message_models.dart';
import '../../data/message_service.dart';
import '../message_unread_controller.dart';

class ChatScreen extends StatefulWidget {
  final int? conversationId;
  final int? vendorId;
  final int? productId;
  final String title;
  final String productName;

  const ChatScreen({
    super.key,
    this.conversationId,
    this.vendorId,
    this.productId,
    this.title = 'محادثة',
    this.productName = '',
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final MessageService _service = MessageService(sl<Dio>());
  final _imagePicker = ImagePicker();
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  List<PrivateMessageModel> _messages = const [];
  Timer? _timer;
  int? _conversationId;
  int? _vendorId;
  late String _productName;
  bool _loading = true;
  bool _sending = false;
  bool _uploading = false;
  int? _processingOfferId;
  bool _loadingMessages = false;
  bool _loadingOlder = false;
  bool _hasMore = true;
  int _oldestPage = 1;
  String? _error;

  @override
  void initState() {
    super.initState();
    _conversationId = widget.conversationId;
    _vendorId = widget.vendorId;
    _productName = widget.productName;
    _scrollController.addListener(_onScroll);
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      if (_conversationId == null) {
        if (widget.vendorId == null || widget.productId == null) {
          throw Exception('بيانات المحادثة غير مكتملة');
        }
        _conversationId = await _service.startConversation(
          vendorId: widget.vendorId!,
          productId: widget.productId!,
        );
      }
      if (_conversationId == 0) throw Exception('تعذر بدء المحادثة');
      if (_vendorId == null || _productName.isEmpty) {
        final conversation = await _service.getConversation(_conversationId!);
        if (conversation != null) {
          _vendorId = conversation.vendorId;
          _productName = conversation.productName;
          if (mounted) setState(() {});
        }
      }
      await _loadMessages();
      _timer = Timer.periodic(
        const Duration(seconds: 8),
        (_) => _loadMessages(silent: true),
      );
    } catch (e) {
      if (mounted) setState(() => _error = 'تعذر فتح المحادثة: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMessages({bool silent = false}) async {
    final id = _conversationId;
    if (id == null || _loadingMessages) return;
    _loadingMessages = true;
    try {
      final messages = await _service.getMessages(id, page: 1);
      await MessageUnreadController.instance.refresh(sl<Dio>());
      if (!mounted) return;
      final byId = <int, PrivateMessageModel>{
        for (final message in _messages) message.id: message,
        for (final message in messages) message.id: message,
      };
      final merged = byId.values.toList()..sort((a, b) => a.id.compareTo(b.id));
      final changed =
          merged.length != _messages.length ||
          (merged.isNotEmpty &&
              _messages.isNotEmpty &&
              merged.last.id != _messages.last.id);
      if (changed) {
        setState(() => _messages = merged);
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    } catch (e) {
      if (!silent && mounted) {
        setState(() => _error = 'تعذر تحميل الرسائل');
      }
    } finally {
      _loadingMessages = false;
    }
  }

  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.pixels <= 120) {
      _loadOlderMessages();
    }
  }

  Future<void> _loadOlderMessages() async {
    final id = _conversationId;
    if (id == null || _loadingOlder || !_hasMore) return;
    _loadingOlder = true;
    try {
      final nextPage = _oldestPage + 1;
      final older = await _service.getMessages(id, page: nextPage);
      if (!mounted) return;
      final previousExtent = _scrollController.hasClients
          ? _scrollController.position.maxScrollExtent
          : 0.0;
      final byId = <int, PrivateMessageModel>{
        for (final message in older) message.id: message,
        for (final message in _messages) message.id: message,
      };
      final merged = byId.values.toList()..sort((a, b) => a.id.compareTo(b.id));
      setState(() {
        _messages = merged;
        _oldestPage = nextPage;
        _hasMore = older.length == 100;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          final addedExtent =
              _scrollController.position.maxScrollExtent - previousExtent;
          _scrollController.jumpTo(addedExtent);
        }
      });
    } finally {
      _loadingOlder = false;
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    final id = _conversationId;
    if (text.isEmpty || id == null || _sending) return;
    setState(() => _sending = true);
    try {
      await _service.sendMessage(id, text);
      _controller.clear();
      await _loadMessages();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تعذر إرسال الرسالة')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pickAndSendAttachment() async {
    final id = _conversationId;
    if (id == null || _uploading) return;
    setState(() => _uploading = true);
    try {
      // Lock before opening Android's picker. Without this, a rapid second tap
      // can start another picker while the first platform activity is active.
      final file = await _imagePicker.pickMedia();
      if (file == null || !mounted) return;

      await _service.sendAttachment(
        id,
        filePath: file.path,
        fileName: file.name,
      );
      await _loadMessages();
    } on PlatformException catch (error) {
      if (mounted) {
        final message = error.code == 'already_active'
            ? 'منتقي الصور مفتوح بالفعل'
            : 'تعذر فتح الصور أو الفيديو';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر إرسال المرفق. الحد الأقصى 15 ميجابايت'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _showPrivateOfferDialog() async {
    final amount = await showDialog<double>(
      context: context,
      builder: (_) => const _PrivateOfferDialog(),
    );
    if (amount == null || _conversationId == null || !mounted) return;

    setState(() => _sending = true);
    try {
      await _service.sendPrivateOffer(_conversationId!, amount);
      await _loadMessages();
    } on DioException catch (error) {
      if (mounted) {
        final data = error.response?.data;
        final code = data is Map ? data['code']?.toString() : '';
        final message = switch (code) {
          'sale_already_finalized' => 'تم بيع هذا الإعلان بالفعل',
          'invalid_offer_product' => 'الإعلان المرتبط بالمحادثة غير متاح',
          'vendor_only' => 'البائع فقط يمكنه إرسال عرض السعر',
          'invalid_offer_amount' => 'أدخل سعراً صحيحاً أكبر من صفر',
          _ => 'تعذر إرسال عرض السعر الخاص',
        };
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _acceptPrivateOffer(PrivateMessageModel message) async {
    final conversationId = _conversationId;
    if (conversationId == null ||
        message.offerAmount == null ||
        _processingOfferId != null) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('قبول العرض الخاص'),
        content: Text(
          'سيُضاف الإعلان إلى السلة بسعر '
          '${message.offerAmount!.toStringAsFixed(2)} ر.س، ثم تنتقل للدفع.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('قبول والشراء'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _processingOfferId = message.id);
    try {
      final accepted = await _service.acceptPrivateOffer(
        conversationId,
        message.id,
      );
      final product = await sl<ProductsCubit>().getProductById(
        accepted.productId,
      );
      if (product == null || !mounted) throw Exception('Product not found');
      final cart = context.read<CartCubit>();
      cart.replaceWithAgreement(
        product.copyWith(price: accepted.amount.toStringAsFixed(2)),
        privateOfferMessageId: accepted.messageId,
        privateConversationId: accepted.conversationId,
      );
      await _loadMessages();
      if (mounted) Navigator.pushNamed(context, Routes.checkout);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر قبول العرض والانتقال للدفع')),
        );
      }
    } finally {
      if (mounted) setState(() => _processingOfferId = null);
    }
  }

  Future<void> _openAttachment(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تعذر فتح المرفق')));
      }
    }
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userId = context.read<AuthCubit>().currentUser?.id ?? 0;
    final isVendor = _vendorId != null && _vendorId == userId;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            Text(widget.title),
            if (_productName.isNotEmpty)
              Text(_productName, style: TextStyle(fontSize: 11.sp)),
          ],
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(child: Text(_error!))
                : RefreshIndicator(
                    onRefresh: _loadMessages,
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: EdgeInsets.all(16.w),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final item = _messages[index];
                        final mine = item.senderId == userId;
                        return Align(
                          alignment: mine
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            constraints: BoxConstraints(maxWidth: 285.w),
                            margin: EdgeInsets.only(bottom: 10.h),
                            padding: EdgeInsets.symmetric(
                              horizontal: 14.w,
                              vertical: 10.h,
                            ),
                            decoration: BoxDecoration(
                              color: mine
                                  ? AppColors.primary
                                  : Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(16.r),
                              border: mine
                                  ? null
                                  : Border.all(color: AppColors.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (item.hasAttachment)
                                  _buildAttachment(item, mine),
                                if (item.hasAttachment &&
                                    item.message != '📎 مرفق')
                                  SizedBox(height: 8.h),
                                if (!item.hasAttachment ||
                                    item.message != '📎 مرفق')
                                  Text(
                                    item.message,
                                    style: TextStyle(
                                      color: mine ? Colors.white : null,
                                    ),
                                  ),
                                SizedBox(height: 4.h),
                                Text(
                                  DateFormat(
                                    'HH:mm',
                                  ).format(item.createdAt.toLocal()),
                                  style: TextStyle(
                                    fontSize: 9.sp,
                                    color: mine
                                        ? Colors.white70
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(12.w, 8.h, 12.w, 10.h),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'إرسال صورة أو فيديو',
                    onPressed: _uploading ? null : _pickAndSendAttachment,
                    icon: _uploading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.attach_file_rounded),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        hintText: 'اكتب رسالتك...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22.r),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachment(PrivateMessageModel item, bool mine) {
    if (item.isImage) {
      return GestureDetector(
        onTap: () => _openAttachment(item.attachmentUrl),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12.r),
          child: CachedNetworkImage(
            imageUrl: item.attachmentUrl,
            width: 240.w,
            height: 180.h,
            fit: BoxFit.cover,
            placeholder: (_, __) => const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            ),
            errorWidget: (_, __, ___) => const SizedBox(
              height: 100,
              child: Icon(Icons.broken_image_outlined),
            ),
          ),
        ),
      );
    }
    return InkWell(
      onTap: () => _openAttachment(item.attachmentUrl),
      child: Row(
        children: [
          Icon(
            item.attachmentMime.startsWith('video/')
                ? Icons.play_circle_outline
                : Icons.insert_drive_file_outlined,
            color: mine ? Colors.white : AppColors.primary,
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              item.attachmentName.isEmpty ? 'فتح المرفق' : item.attachmentName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: mine ? Colors.white : AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivateOfferCard(
    PrivateMessageModel item, {
    required bool mine,
    required bool isVendor,
  }) {
    final canAccept = !isVendor && item.offerStatus == 'pending';
    final statusText = switch (item.offerStatus) {
      'accepted' => 'تم قبول العرض الخاص',
      'purchased' => 'تم إنشاء الطلب',
      'superseded' => 'تم استبدال هذا العرض',
      _ => 'عرض سعر خاص',
    };
    return Container(
      padding: EdgeInsets.all(10.w),
      decoration: BoxDecoration(
        color: mine
            ? Colors.white.withValues(alpha: .14)
            : AppColors.primary.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${item.offerAmount!.toStringAsFixed(2)} ر.س',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: mine ? Colors.white : AppColors.primary,
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            statusText,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: mine ? Colors.white70 : AppColors.textSecondary,
              fontSize: 11.sp,
            ),
          ),
          if (canAccept) ...[
            SizedBox(height: 8.h),
            FilledButton(
              onPressed: _processingOfferId == null
                  ? () => _acceptPrivateOffer(item)
                  : null,
              child: _processingOfferId == item.id
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('قبول والشراء الآن'),
            ),
          ],
        ],
      ),
    );
  }
}

class _PrivateOfferDialog extends StatefulWidget {
  const _PrivateOfferDialog();

  @override
  State<_PrivateOfferDialog> createState() => _PrivateOfferDialogState();
}

class _PrivateOfferDialogState extends State<_PrivateOfferDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = double.tryParse(_controller.text.trim());
    if (value == null || value <= 0) {
      setState(() => _error = 'أدخل سعراً صحيحاً أكبر من صفر');
      return;
    }
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('إرسال عرض سعر خاص'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'هذا العرض خاص بهذه المحادثة، ولن يظهر في التعليقات العامة.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            SizedBox(height: 12.h),
            TextField(
              controller: _controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: 'السعر النهائي الخاص',
                suffixText: 'ر.س',
                errorText: _error,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        FilledButton(onPressed: _submit, child: const Text('إرسال العرض')),
      ],
    );
  }
}
