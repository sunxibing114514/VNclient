import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/endpoints_provider.dart';

/// A lightweight dialog for casting or updating a rating on a single VN.
///
/// VNDB implements per-entry ratings through `PATCH /ulist/<vnId>` with the
/// `vote` field (an integer 10–100). Casting a vote automatically adds the
/// "Voted" label and the VN to the user's list if it isn't there already.
class VoteDialog extends ConsumerStatefulWidget {
  const VoteDialog({super.key, required this.vnId, required this.vnTitle});

  final String vnId;
  final String vnTitle;

  @override
  ConsumerState<VoteDialog> createState() => _VoteDialogState();
}

class _VoteDialogState extends ConsumerState<VoteDialog> {
  double _vote = 7.0;
  bool _saving = false;

  Future<void> _submit() async {
    setState(() => _saving = true);
    try {
      await ref.read(listEndpointProvider).patchList(
            widget.vnId,
            vote: (_vote * 10).round(),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已投票 ${_vote.toStringAsFixed(1)} 分')),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('投票失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _removeVote() async {
    setState(() => _saving = true);
    try {
      await ref.read(listEndpointProvider).patchList(widget.vnId, vote: null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已撤销投票')),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('撤销失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('投票评分'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.vnTitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                _vote.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Slider(
              value: _vote,
              min: 1,
              max: 10,
              divisions: 90,
              label: _vote.toStringAsFixed(1),
              onChanged: (v) => setState(() => _vote = v),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('1', style: Theme.of(context).textTheme.bodySmall),
                Text('10', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '投票会将该作品加入你的列表并自动添加「已投票」标签。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : _removeVote,
          child: const Text('撤销投票'),
        ),
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('投票'),
        ),
      ],
    );
  }
}
