import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/staff.dart';
import '../../core/providers/detail_providers.dart';
import '../../core/providers/endpoints_provider.dart';
import '../../widgets/async_value_widget.dart';
import '../../widgets/section_header.dart';

final _staffProvider =
    FutureProvider.autoDispose.family<Staff, String>((ref, id) {
  return ref.watch(staffEndpointProvider).getById(id);
});

class StaffDetailPage extends ConsumerWidget {
  const StaffDetailPage({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staff = ref.watch(_staffProvider(id));
    return Scaffold(
      appBar: AppBar(title: const Text('制作人员')),
      body: AsyncValueWidget(
        value: staff,
        data: (s) => _StaffBody(staff: s, staffId: id),
        errorRetry: () => ref.invalidate(_staffProvider(id)),
      ),
    );
  }
}

class _StaffBody extends ConsumerWidget {
  const _StaffBody({required this.staff, required this.staffId});
  final Staff staff;
  final String staffId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vns = ref.watch(vnsByStaffProvider(staffId));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Name header
        Text(staff.name, style: Theme.of(context).textTheme.headlineSmall),
        if (staff.original != null && staff.original!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(staff.original!,
                style: Theme.of(context).textTheme.bodyMedium),
          ),
        const SizedBox(height: 12),
        // Info chips
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            if (staff.lang != null) Chip(label: Text(staff.lang!)),
            Chip(label: Text(staff.genderLabel)),
            if (staff.ismain) const Chip(label: Text('Main alias')),
          ],
        ),
        // Aliases
        if (staff.aliases.isNotEmpty) ...[
          const SizedBox(height: 16),
          const SectionHeader(
              title: '别名', icon: Icons.label_outline, padding: EdgeInsets.zero),
          const SizedBox(height: 4),
          for (final a in staff.aliases)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(a.name),
              subtitle: Text(a.latin ?? ''),
              trailing: a.ismain
                  ? const Chip(label: Text('main'))
                  : null,
            ),
        ],
        // Description
        if (staff.description != null && staff.description!.isNotEmpty) ...[
          const SizedBox(height: 16),
          const SectionHeader(
              title: '简介',
              icon: Icons.description_outlined,
              padding: EdgeInsets.zero),
          const SizedBox(height: 4),
          Text(staff.description!,
              style: Theme.of(context).textTheme.bodyMedium),
        ],
        // Credited works
        const SizedBox(height: 16),
        AsyncValueWidget(
          value: vns,
          data: (list) => _StaffVnsSection(vns: list),
        ),
        // External links
        if (staff.extlinks.isNotEmpty) ...[
          const SizedBox(height: 16),
          const SectionHeader(
              title: '外部链接', icon: Icons.link, padding: EdgeInsets.zero),
          for (final link in staff.extlinks)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(link.label),
              trailing: const Icon(Icons.open_in_new, size: 18),
              onTap: () => context.push(
                  '/webview?url=${Uri.encodeComponent(link.url)}&title=${Uri.encodeComponent(link.label)}'),
            ),
        ],
        const SizedBox(height: 24),
      ],
    );
  }
}

/// Displays the staff member's credited VNs, grouped by role.
class _StaffVnsSection extends StatelessWidget {
  const _StaffVnsSection({required this.vns});
  final List<StaffVn> vns;

  @override
  Widget build(BuildContext context) {
    if (vns.isEmpty) {
      return const SizedBox.shrink();
    }

    // Group by role.
    final byRole = <String, List<StaffVn>>{};
    for (final v in vns) {
      final role = v.role.isEmpty ? '其他' : v.role;
      byRole.putIfAbsent(role, () => []).add(v);
    }
    final roles = byRole.keys.toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: '参与作品 (${vns.length})',
          icon: Icons.book_outlined,
          padding: EdgeInsets.zero,
        ),
        const SizedBox(height: 8),
        for (final role in roles) ...[
          // Role header with subtle background
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            margin: const EdgeInsets.only(top: 8, bottom: 4),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .primaryContainer
                  .withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$role (${byRole[role]!.length})',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
          ),
          // VN items
          for (final v in byRole[role]!)
            Card(
              margin: const EdgeInsets.only(bottom: 4),
              child: ListTile(
                dense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                title: Text(
                  v.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14),
                ),
                subtitle: v.note != null && v.note!.isNotEmpty
                    ? Text(v.note!, maxLines: 1, overflow: TextOverflow.ellipsis)
                    : null,
                trailing: const Icon(Icons.chevron_right, size: 18),
                onTap: () => context.push('/vn/${v.id}'),
              ),
            ),
        ],
      ],
    );
  }
}
