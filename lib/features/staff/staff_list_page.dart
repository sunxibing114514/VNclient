import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/endpoints/staff_endpoint.dart';
import '../../core/providers/endpoints_provider.dart';

/// A searchable, paginated list of all staff with advanced filtering.
class StaffListPage extends ConsumerStatefulWidget {
  const StaffListPage({super.key});

  @override
  ConsumerState<StaffListPage> createState() => _StaffListPageState();
}

class _StaffListPageState extends ConsumerState<StaffListPage> {
  final _controller = TextEditingController();
  String _term = '';
  int _page = 1;
  final _items = <dynamic>[];
  bool _hasMore = true;
  bool _loading = false;
  bool _fetched = false;
  Object? _error;

  // Advanced filter state
  bool _showAdvanced = false;
  String? _lang; // e.g. 'en', 'ja'
  String? _gender; // 'm' / 'f'
  String _role = ''; // staff_role or 'seiyuu'
  final _roleController = TextEditingController();
  final _extlinkController = TextEditingController(); // site name or URL
  bool _ismain = true; // default to main only to deduplicate

  static const _langs = <_DropdownOption>[
    _DropdownOption(label: '全部', value: null),
    _DropdownOption(label: '英语', value: 'en'),
    _DropdownOption(label: '日语', value: 'ja'),
    _DropdownOption(label: '中文', value: 'zh'),
    _DropdownOption(label: '韩语', value: 'ko'),
    _DropdownOption(label: '法语', value: 'fr'),
    _DropdownOption(label: '德语', value: 'de'),
    _DropdownOption(label: '西班牙语', value: 'es'),
    _DropdownOption(label: '俄语', value: 'ru'),
    _DropdownOption(label: '意大利语', value: 'it'),
    _DropdownOption(label: '葡萄牙语', value: 'pt'),
  ];

  static const _genders = <_DropdownOption>[
    _DropdownOption(label: '全部', value: null),
    _DropdownOption(label: '男', value: 'm'),
    _DropdownOption(label: '女', value: 'f'),
  ];

  /// Common staff_role values plus the special "seiyuu" value.
  static const _roles = <_DropdownOption>[
    _DropdownOption(label: '全部', value: null),
    _DropdownOption(label: '配音 (seiyuu)', value: 'seiyuu'),
    _DropdownOption(label: '编剧 (script)', value: 'script'),
    _DropdownOption(label: '导演 (director)', value: 'director'),
    _DropdownOption(label: '原画 (art)', value: 'art'),
    _DropdownOption(label: '音乐 (music)', value: 'music'),
    _DropdownOption(label: '歌曲 (songs)', value: 'songs'),
    _DropdownOption(label: '员工 (staff)', value: 'staff'),
    _DropdownOption(label: '编辑 (editor)', value: 'editor'),
    _DropdownOption(label: '设计 (designer)', value: 'designer'),
    _DropdownOption(label: '测试 (qa)', value: 'qa'),
    _DropdownOption(label: '程序 (code)', value: 'code'),
    _DropdownOption(label: '支持 (support)', value: 'support'),
    _DropdownOption(label: '翻译 (translator)', value: 'translator'),
    _DropdownOption(label: '协调 (coordinator)', value: 'coordinator'),
    _DropdownOption(label: '演唱 (singer)', value: 'singer'),
  ];

  @override
  void initState() {
    super.initState();
    _fetch(reset: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    _roleController.dispose();
    _extlinkController.dispose();
    super.dispose();
  }

  /// Builds the VNDB API filter tree from the current advanced filter state.
  Object? _buildFilters() {
    final parts = <List<dynamic>>[];
    final term = _term.trim();
    if (term.isNotEmpty) parts.add(['search', '=', term]);
    if (_lang != null) parts.add(['lang', '=', _lang!]);
    if (_gender != null) parts.add(['gender', '=', _gender!]);
    if (_role.isNotEmpty) parts.add(['role', '=', _role]);
    final extlink = _extlinkController.text.trim();
    if (extlink.isNotEmpty) parts.add(['extlink', '=', extlink]);
    // ismain filter only accepts the value 1; we always send it to dedupe.
    parts.add(['ismain', '=', 1]);
    if (parts.length == 1) return parts.first;
    return ['and', ...parts];
  }

  bool get _hasAdvancedFilters =>
      _lang != null ||
      _gender != null ||
      _role.isNotEmpty ||
      _extlinkController.text.trim().isNotEmpty;

  Future<void> _fetch({bool reset = false}) async {
    if (_loading) return;
    if (reset) {
      _items.clear();
      _page = 1;
      _hasMore = true;
      _error = null;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final filters = _buildFilters();
      final result = await ref.read(staffEndpointProvider).query(
            filters: filters,
            fields: StaffEndpoint.listFields,
            sort: filters == null || (filters is List && filters.length <= 1)
                ? 'name'
                : 'searchrank',
            page: _page,
            results: 50,
          );
      setState(() {
        _items.addAll(result.results);
        _hasMore = result.more;
        _fetched = true;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _error = e);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _resetFilters() {
    setState(() {
      _lang = null;
      _gender = null;
      _role = '';
      _roleController.clear();
      _extlinkController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Staff')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    hintText: '搜索 Staff…',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(_showAdvanced
                              ? Icons.expand_less
                              : Icons.filter_list),
                          tooltip: '高级筛选',
                          onPressed: () => setState(
                              () => _showAdvanced = !_showAdvanced),
                        ),
                        IconButton(
                          icon: const Icon(Icons.search),
                          onPressed: () {
                            _term = _controller.text.trim();
                            _fetch(reset: true);
                          },
                        ),
                      ],
                    ),
                  ),
                  onSubmitted: (_) {
                    _term = _controller.text.trim();
                    _fetch(reset: true);
                  },
                ),
                if (_showAdvanced) _buildAdvancedFilters(),
              ],
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildAdvancedFilters() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('高级筛选',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                TextButton.icon(
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('重置'),
                  onPressed: _resetFilters,
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Language + Gender
            Row(
              children: [
                Expanded(
                  child: _dropdown('语言', _langs, _lang,
                      (v) => setState(() => _lang = v)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _dropdown('性别', _genders, _gender,
                      (v) => setState(() => _gender = v)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Role (preset dropdown) + custom role text
            Row(
              children: [
                Expanded(
                  child: _dropdown('职位 (role)', _roles, _role.isEmpty ? null : _role,
                      (v) => setState(() => _role = v ?? '')),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _roleController,
                    decoration: const InputDecoration(
                      labelText: '或自定义 role',
                      isDense: true,
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.work_outline),
                    ),
                    onChanged: (v) => setState(() => _role = v.trim()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Externlink
            TextField(
              controller: _extlinkController,
              decoration: const InputDecoration(
                labelText: '外部链接 (站点名或 URL, 如 steam)',
                isDense: true,
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.link),
              ),
            ),
            const SizedBox(height: 8),
            // ismain info
            Row(
              children: [
                const Icon(Icons.info_outline, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '仅显示主名 (ismain=1)，避免同人多条目重复',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.search),
                label: const Text('应用筛选'),
                onPressed: () => _fetch(reset: true),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dropdown(
    String label,
    List<_DropdownOption> options,
    String? current,
    void Function(String?) onChanged,
  ) {
    return DropdownButtonFormField<String?>(
      value: current,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
      items: options
          .map((e) => DropdownMenuItem<String?>(
                value: e.value,
                child: Text(e.label),
              ))
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildBody() {
    if (_error != null && _items.isEmpty && !_loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 8),
            Text('$_error'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => _fetch(reset: true),
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }
    if (_fetched && _items.isEmpty && !_loading) {
      return const Center(child: Text('未找到 Staff'));
    }
    return RefreshIndicator(
      onRefresh: () => _fetch(reset: true),
      child: ListView.builder(
        itemCount: _items.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, i) {
          if (i >= _items.length) {
            _fetch();
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final s = _items[i];
          return Card(
            child: ListTile(
              title: Text(s.name),
              subtitle: Text(
                [
                  if (s.original != null) s.original,
                  if (s.lang != null) s.lang,
                  s.genderLabel,
                ].join(' · '),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/staff/${s.id}'),
            ),
          );
        },
      ),
    );
  }
}

class _DropdownOption {
  const _DropdownOption({required this.label, required this.value});
  final String label;
  final String? value;
}
