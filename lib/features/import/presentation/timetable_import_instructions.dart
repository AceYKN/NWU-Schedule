import 'package:flutter/material.dart';

Future<bool?> showTimetableImportInstructions(
  BuildContext context, {
  bool initial = false,
}) =>
    showDialog<bool>(
      context: context,
      barrierDismissible: !initial,
      builder: (dialogContext) => AlertDialog(
        title: const Text('课表导入说明'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _InstructionStep(
                title: '1. 登录教务系统',
                content: Text('使用你的教务系统账号和密码，在即将打开的教务系统页面登录。'),
              ),
              SizedBox(height: 16),
              _InstructionStep(
                title: '2. 选择学年、学期并查询',
                content: Text.rich(
                  TextSpan(children: [
                    TextSpan(text: '选择要导入的学年和学期后，'),
                    TextSpan(
                      text: '务必点击「查询」按钮',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    TextSpan(text: '，等待课表刷新。'),
                  ]),
                ),
              ),
              SizedBox(height: 16),
              _InstructionStep(
                title: '3. 读取课表',
                content: Text('课表显示后，点击本页面右上角的「读取课表」，核对预览内容，再确认导入。'),
              ),
              SizedBox(height: 16),
              Divider(),
              SizedBox(height: 8),
              _InstructionStep(
                title: '隐私说明',
                content: Text('应用不收集、上传或保存你的账号密码；导入的课表仅保存在本机。'),
              ),
            ],
          ),
        ),
        actions: [
          if (initial)
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(initial ? '开始导入' : '知道了'),
          ),
        ],
      ),
    );

class _InstructionStep extends StatelessWidget {
  const _InstructionStep({required this.title, required this.content});

  final String title;
  final Widget content;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          content,
        ],
      );
}
