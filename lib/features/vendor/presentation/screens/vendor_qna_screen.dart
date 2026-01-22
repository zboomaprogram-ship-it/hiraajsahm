import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/di/injection_container.dart' as di;
import '../../../../core/widgets/custom_text_field.dart';
import '../../../shop/data/models/question_model.dart';
import '../../../shop/presentation/cubit/qna_cubit.dart';

class VendorQnAScreen extends StatelessWidget {
  const VendorQnAScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => di.sl<QnACubit>()..fetchVendorQuestions(),
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('أسئلة العملاء'),
            bottom: TabBar(
              indicatorColor: AppColors.primary,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              tabs: const [
                Tab(text: 'غير مجاب'),
                Tab(text: 'تم الرد'),
              ],
            ),
          ),
          body: const TabBarView(
            children: [
              _QuestionsList(isAnswered: false),
              _QuestionsList(isAnswered: true),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuestionsList extends StatelessWidget {
  final bool isAnswered;

  const _QuestionsList({required this.isAnswered});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<QnACubit, QnAState>(
      builder: (context, state) {
        if (state is QnALoading) {
          return const Center(child: CircularProgressIndicator());
        } else if (state is QnAError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: AppColors.error),
                SizedBox(height: 16.h),
                Text(state.message),
                SizedBox(height: 16.h),
                ElevatedButton(
                  onPressed: () =>
                      context.read<QnACubit>().fetchVendorQuestions(),
                  child: const Text('إعادة المحاولة'),
                ),
              ],
            ),
          );
        } else if (state is QnALoaded) {
          final questions = state.questions
              .where((q) => q.isAnswered == isAnswered)
              .toList();

          if (questions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isAnswered
                        ? Icons.check_circle_outline
                        : Icons.question_answer_outlined,
                    size: 64,
                    color: AppColors.textSecondary.withOpacity(0.5),
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    isAnswered ? 'لا توجد أسئلة مجابة' : 'لا توجد أسئلة جديدة',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 16.sp,
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => context.read<QnACubit>().fetchVendorQuestions(),
            child: ListView.separated(
              padding: EdgeInsets.all(16.w),
              itemCount: questions.length,
              separatorBuilder: (_, __) => SizedBox(height: 12.h),
              itemBuilder: (context, index) {
                final qna = questions[index];
                return _buildQnAItem(context, qna);
              },
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildQnAItem(BuildContext context, QuestionModel qna) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    qna.productName,
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  qna.date,
                  style: TextStyle(fontSize: 12.sp, color: Colors.grey),
                ),
              ],
            ),
            Divider(height: 20.h),
            Text(
              qna.question,
              style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600),
            ),
            if (isAnswered && qna.answer != null) ...[
              SizedBox(height: 12.h),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(color: Colors.blue.withOpacity(0.1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ردك:',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(qna.answer!, style: TextStyle(fontSize: 14.sp)),
                  ],
                ),
              ),
            ],
            if (!isAnswered) ...[
              SizedBox(height: 16.h),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showReplyDialog(context, qna),
                  icon: const Icon(Icons.reply, size: 18),
                  label: const Text('رد على السؤال'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showReplyDialog(BuildContext context, QuestionModel qna) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('الرد على السؤال'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              qna.question,
              style: const TextStyle(fontWeight: FontWeight.bold),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 16.h),
            CustomTextField(
              controller: controller,
              hint: 'اكتب ردك هنا...',
              maxLines: 4,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                // Use the QnACubit from the parent context
                context.read<QnACubit>().replyToQuestion(
                  qna.id,
                  controller.text,
                );
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تم إرسال الرد بنجاح')),
                );
              }
            },
            child: const Text('إرسال'),
          ),
        ],
      ),
    );
  }
}
