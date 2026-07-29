import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/providers/detail_providers.dart';
import '../../core/providers/endpoints_provider.dart';

/// 编辑/新增列表条目对话框。打开时会预填当前 VN 已有的 vote /
/// notes / started / finished / labels，并在标题处显示已有的评分与标签。
class ListEditDialog extends ConsumerStatefulWidget {
  const ListEditDialog({super.key, required this.vnId});

  final String vnId;

  @override
  ConsumerState<ListEditDialog> createState() => _ListEditDialogState();
}

class _ListEditDialogState extends ConsumerState<ListEditDialog> {
  double _vote = 0;
  final _notesController = TextEditingController();
  final _startedController = TextEditingController();
  final _finishedController = TextEditingController();
  final Set<int> _selectedLabels = {};
  bool _saving = false;
  bool _loaded = false; // 是否已从服务器预填

  @override
  void dispose() {
    _notesController.dispose();
    _startedController.dispose();
    _finishedController.dispose();
    super.dispose();
  }

  /// 从服务器读取该 VN 当前的列表记录并预填表单。
  Future<void> _prefill() async {
    if (_loaded) return;
    final entry = await ref.read(userVnListEntryProvider(widget.vnId).future);
    if (!mounted || entry == null) {
      _loaded = true;
      return;
    }
    setState(() {
      _loaded = true;
      if (entry.vote != null && entry.vote! > 0) {
        _vote = (entry.vote! / 10).clamp(0.0, 10.0);
      }
      if (entry.notes != null) _notesController.text = entry.notes!;
      if (entry.started != null) _startedController.text = entry.started!;
      if (entry.finished != null) _finishedController.text = entry.finished!;
      _selectedLabels
        ..clear()
        ..addAll(entry.labels.where((l) => l.id != 0).map((l) => l.id));
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final endpoint = ref.read(listEndpointProvider);
    try {
      await endpoint.patchList(
        widget.vnId,
        vote: _vote > 0 ? (_vote * 10).round() : null,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        started: _startedController.text.trim().isEmpty
            ? null
            : _startedController.text.trim(),
        finished: _finishedController.text.trim().isEmpty
            ? null
            : _finishedController.text.trim(),
        labelsSet: _selectedLabels.toList(),
      );
      // 刷新当前 VN 的列表记录缓存。
      ref.invalidate(userVnListEntryProvider(widget.vnId));
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('移除'),
        content: const Text('确定从列表中移除这个 VN 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('移除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _saving = true);
    try {
      await ref.read(listEndpointProvider).deleteList(widget.vnId);
      ref.invalidate(userVnListEntryProvider(widget.vnId));
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final labels = ref.watch(userLabelsProvider);
    final entryAsync = ref.watch(userVnListEntryProvider(widget.vnId));
    // 首次构建时拉取已有记录。
    entryAsync.whenData((_) => _prefill());

    return AlertDialog(
      title: const Text('编辑列表条目'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 若该 VN 已加入列表，显示已有评分与标签摘要。
              entryAsync.when(
                data: (entry) => entry == null
                    ? const SizedBox.shrink()
                    : Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color:
                              Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '已在列表中',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            if (entry.vote != null && entry.vote! > 0)
                              Text('已有评分: ${(entry.vote! / 10).toStringAsFixed(1)} / 10'),
                            if (entry.labels.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Wrap(
                                  spacing: 4,
                                  children: entry.labels
                                      .where((l) => l.id != 0)
                                      .map((l) => Chip(
                                            materialTapTargetSize:
                                                MaterialTapTargetSize
                                                    .shrinkWrap,
                                            padding: EdgeInsets.zero,
                                            label: Text(l.label,
                                                style: const TextStyle(
                                                    fontSize: 10)),
                                          ))
                                      .toList(),
                                ),
                              ),
                          ],
                        ),
                      ),
                loading: () => const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: LinearProgressIndicator(),
                ),
                error: (_, __) => const SizedBox.shrink(),
              ),
              Text('投票: ${_vote.toStringAsFixed(1)} / 10'),
              Slider(
                value: _vote,
                min: 0,
                max: 10,
                divisions: 100,
                label: _vote.toStringAsFixed(1),
                onChanged: (v) => setState(() => _vote = v),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: '笔记',
                  isDense: true,
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _startedController,
                decoration: const InputDecoration(
                  labelText: '开始日期 (YYYY-MM-DD)',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _finishedController,
                decoration: const InputDecoration(
                  labelText: '完成日期 (YYYY-MM-DD)',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              const Text('标签'),
              labels.when(
                data: (list) => Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: list
                      .where((l) => l.id != 0 && l.id != AppConstants.labelVoted)
                      .map((l) {
                    final selected = _selectedLabels.contains(l.id);
                    return FilterChip(
                      label: Text(l.label),
                      selected: selected,
                      onSelected: (v) => setState(() {
                        if (v) {
                          _selectedLabels.add(l.id);
                        } else {
                          _selectedLabels.remove(l.id);
                        }
                      }),
                    );
                  }).toList(),
                ),
                loading: () => const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                error: (_, __) => const Text('标签加载失败'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : _delete,
          child: const Text('移除'),
        ),
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('保存'),
        ),
      ],
    );
  }
}
