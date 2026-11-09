import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/persistence/demo_persistence.dart';

class DemoDataControls extends ConsumerStatefulWidget {
  const DemoDataControls({super.key});

  @override
  ConsumerState<DemoDataControls> createState() => _DemoDataControlsState();
}

class _DemoDataControlsState extends ConsumerState<DemoDataControls> {
  bool _resetDialogOpen = false;

  Future<void> _confirmReset() async {
    if (_resetDialogOpen) {
      return;
    }
    setState(() => _resetDialogOpen = true);
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('重置演示数据？'),
          content: const Text('将清除当前浏览器或会话中的演示修改，恢复初始数据。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              key: const Key('confirm_reset_demo_data'),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('确认重置'),
            ),
          ],
        ),
      );
      if (!mounted || confirmed != true) {
        return;
      }
      ref.read(demoPersistenceProvider).clear();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('演示数据已重置')));
      }
    } finally {
      if (mounted) {
        setState(() => _resetDialogOpen = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final durable = ref.watch(demoPersistenceProvider).isDurable;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          durable ? '演示数据保存在当前浏览器，标签页同步；不同设备不共享。' : '当前环境的演示数据仅保存在本次会话。',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        TextButton.icon(
          key: const Key('reset_demo_data'),
          onPressed: _resetDialogOpen ? null : _confirmReset,
          icon: const Icon(Icons.restart_alt),
          label: const Text('重置演示数据'),
        ),
      ],
    );
  }
}
