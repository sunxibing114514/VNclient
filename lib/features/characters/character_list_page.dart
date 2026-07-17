import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/endpoints/character_endpoint.dart';
import '../../core/providers/endpoints_provider.dart';

/// A searchable, paginated list of all characters with advanced filtering.
class CharacterListPage extends ConsumerStatefulWidget {
  const CharacterListPage({super.key});

  @override
  ConsumerState<CharacterListPage> createState() => _CharacterListPageState();
}

class _CharacterListPageState extends ConsumerState<CharacterListPage> {
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
  String? _role; // main / primary / side / appears
  String? _bloodType; // a / b / ab / o
  String? _sex; // m / f / b / n
  String? _gender; // m / f / o / a
  String? _cup; // AA, A, B, ...
  int? _heightMin;
  int? _heightMax;
  int? _weightMin;
  int? _weightMax;
  int? _bustMin;
  int? _waistMin;
  int? _hipsMin;
  int? _ageMin;
  int? _ageMax;
  int? _birthdayMonth; // 1-12
  final _traitController = TextEditingController(); // e.g. i123
  int _traitSpoiler = 0; // 0/1/2
  final _seiyuuController = TextEditingController(); // staff id e.g. s123
  final _vnController = TextEditingController(); // vn id e.g. v123

  final _heightMinCtrl = TextEditingController();
  final _heightMaxCtrl = TextEditingController();
  final _weightMinCtrl = TextEditingController();
  final _weightMaxCtrl = TextEditingController();
  final _bustMinCtrl = TextEditingController();
  final _waistMinCtrl = TextEditingController();
  final _hipsMinCtrl = TextEditingController();
  final _ageMinCtrl = TextEditingController();
  final _ageMaxCtrl = TextEditingController();

  static const _roles = <_DropdownOption>[
    _DropdownOption(label: '全部', value: null),
    _DropdownOption(label: '主角', value: 'main'),
    _DropdownOption(label: '主要', value: 'primary'),
    _DropdownOption(label: '次要', value: 'side'),
    _DropdownOption(label: '客串', value: 'appears'),
  ];

  static const _bloodTypes = <_DropdownOption>[
    _DropdownOption(label: '全部', value: null),
    _DropdownOption(label: 'A', value: 'a'),
    _DropdownOption(label: 'B', value: 'b'),
    _DropdownOption(label: 'AB', value: 'ab'),
    _DropdownOption(label: 'O', value: 'o'),
  ];

  static const _sexes = <_DropdownOption>[
    _DropdownOption(label: '全部', value: null),
    _DropdownOption(label: '男', value: 'm'),
    _DropdownOption(label: '女', value: 'f'),
    _DropdownOption(label: '双性', value: 'b'),
    _DropdownOption(label: '无性', value: 'n'),
  ];

  static const _genders = <_DropdownOption>[
    _DropdownOption(label: '全部', value: null),
    _DropdownOption(label: '男', value: 'm'),
    _DropdownOption(label: '女', value: 'f'),
    _DropdownOption(label: '非二元', value: 'o'),
    _DropdownOption(label: '模糊', value: 'a'),
  ];

  static final _cups = <_DropdownOption>[
    const _DropdownOption(label: '全部', value: null),
    const _DropdownOption(label: 'AAA', value: 'AAA'),
    const _DropdownOption(label: 'AA', value: 'AA'),
    for (var c = 'A'.codeUnitAt(0); c <= 'Z'.codeUnitAt(0); c++)
      _DropdownOption(
          label: String.fromCharCode(c), value: String.fromCharCode(c)),
  ];

  static const _months = <_DropdownOption>[
    _DropdownOption(label: '全部', value: null),
    _DropdownOption(label: '1月', value: '1'),
    _DropdownOption(label: '2月', value: '2'),
    _DropdownOption(label: '3月', value: '3'),
    _DropdownOption(label: '4月', value: '4'),
    _DropdownOption(label: '5月', value: '5'),
    _DropdownOption(label: '6月', value: '6'),
    _DropdownOption(label: '7月', value: '7'),
    _DropdownOption(label: '8月', value: '8'),
    _DropdownOption(label: '9月', value: '9'),
    _DropdownOption(label: '10月', value: '10'),
    _DropdownOption(label: '11月', value: '11'),
    _DropdownOption(label: '12月', value: '12'),
  ];

  @override
  void initState() {
    super.initState();
    _fetch(reset: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    _traitController.dispose();
    _seiyuuController.dispose();
    _vnController.dispose();
    _heightMinCtrl.dispose();
    _heightMaxCtrl.dispose();
    _weightMinCtrl.dispose();
    _weightMaxCtrl.dispose();
    _bustMinCtrl.dispose();
    _waistMinCtrl.dispose();
    _hipsMinCtrl.dispose();
    _ageMinCtrl.dispose();
    _ageMaxCtrl.dispose();
    super.dispose();
  }

  /// Builds the VNDB API filter tree from the current advanced filter state.
  Object? _buildFilters() {
    final parts = <List<dynamic>>[];
    final term = _term.trim();
    if (term.isNotEmpty) parts.add(['search', '=', term]);
    if (_role != null) parts.add(['role', '=', _role!]);
    if (_bloodType != null) parts.add(['blood_type', '=', _bloodType!]);
    if (_sex != null) parts.add(['sex', '=', _sex!]);
    if (_gender != null) parts.add(['gender', '=', _gender!]);
    if (_cup != null) parts.add(['cup', '=', _cup!]);
    if (_heightMin != null) parts.add(['height', '>=', _heightMin!]);
    if (_heightMax != null) parts.add(['height', '<=', _heightMax!]);
    if (_weightMin != null) parts.add(['weight', '>=', _weightMin!]);
    if (_weightMax != null) parts.add(['weight', '<=', _weightMax!]);
    if (_bustMin != null) parts.add(['bust', '>=', _bustMin!]);
    if (_waistMin != null) parts.add(['waist', '>=', _waistMin!]);
    if (_hipsMin != null) parts.add(['hips', '>=', _hipsMin!]);
    if (_ageMin != null) parts.add(['age', '>=', _ageMin!]);
    if (_ageMax != null) parts.add(['age', '<=', _ageMax!]);
    if (_birthdayMonth != null) {
      parts.add(['birthday', '=', [_birthdayMonth, 0]]);
    }
    final traitId = _traitController.text.trim();
    if (traitId.isNotEmpty) {
      // trait accepts [id, spoiler] form to control spoiler level.
      parts.add(['trait', '=', [traitId, _traitSpoiler]]);
    }
    final seiyuuId = _seiyuuController.text.trim();
    if (seiyuuId.isNotEmpty) {
      parts.add(['seiyuu', '=', ['id', '=', seiyuuId]]);
    }
    final vnId = _vnController.text.trim();
    if (vnId.isNotEmpty) {
      parts.add(['vn', '=', ['id', '=', vnId]]);
    }
    if (parts.isEmpty) return null;
    if (parts.length == 1) return parts.first;
    return ['and', ...parts];
  }

  bool get _hasAdvancedFilters =>
      _role != null ||
      _bloodType != null ||
      _sex != null ||
      _gender != null ||
      _cup != null ||
      _heightMin != null ||
      _heightMax != null ||
      _weightMin != null ||
      _weightMax != null ||
      _bustMin != null ||
      _waistMin != null ||
      _hipsMin != null ||
      _ageMin != null ||
      _ageMax != null ||
      _birthdayMonth != null ||
      _traitController.text.trim().isNotEmpty ||
      _seiyuuController.text.trim().isNotEmpty ||
      _vnController.text.trim().isNotEmpty;

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
      final result = await ref.read(characterEndpointProvider).query(
            filters: filters,
            fields: CharacterEndpoint.listFields,
            sort: filters == null ? 'name' : 'searchrank',
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
      _role = null;
      _bloodType = null;
      _sex = null;
      _gender = null;
      _cup = null;
      _heightMin = null;
      _heightMax = null;
      _weightMin = null;
      _weightMax = null;
      _bustMin = null;
      _waistMin = null;
      _hipsMin = null;
      _ageMin = null;
      _ageMax = null;
      _birthdayMonth = null;
      _traitSpoiler = 0;
      _traitController.clear();
      _seiyuuController.clear();
      _vnController.clear();
      _heightMinCtrl.clear();
      _heightMaxCtrl.clear();
      _weightMinCtrl.clear();
      _weightMaxCtrl.clear();
      _bustMinCtrl.clear();
      _waistMinCtrl.clear();
      _hipsMinCtrl.clear();
      _ageMinCtrl.clear();
      _ageMaxCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Characters')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    hintText: '搜索角色…',
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
            // Role + Blood type
            Row(
              children: [
                Expanded(
                  child: _dropdown('角色类型', _roles, _role,
                      (v) => setState(() => _role = v)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _dropdown('血型', _bloodTypes, _bloodType,
                      (v) => setState(() => _bloodType = v)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Sex + Gender
            Row(
              children: [
                Expanded(
                  child: _dropdown('性别 (sex)', _sexes, _sex,
                      (v) => setState(() => _sex = v)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _dropdown('性别 (gender)', _genders, _gender,
                      (v) => setState(() => _gender = v)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Cup + Birthday month
            Row(
              children: [
                Expanded(
                  child: _dropdown('罩杯', _cups, _cup,
                      (v) => setState(() => _cup = v)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _dropdown('生日月份', _months, _birthdayMonth?.toString(),
                      (v) => setState(() => _birthdayMonth = int.tryParse(v ?? ''))),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Height range
            _rangeRow('身高 (cm)', _heightMinCtrl, _heightMaxCtrl,
                (v) => _heightMin = v, (v) => _heightMax = v),
            const SizedBox(height: 8),
            // Weight range
            _rangeRow('体重 (kg)', _weightMinCtrl, _weightMaxCtrl,
                (v) => _weightMin = v, (v) => _weightMax = v),
            const SizedBox(height: 8),
            // Bust / Waist / Hips (min only)
            Row(
              children: [
                Expanded(
                  child: _numField('胸围 ≥', _bustMinCtrl,
                      (v) => _bustMin = v),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _numField('腰围 ≥', _waistMinCtrl,
                      (v) => _waistMin = v),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _numField('臀围 ≥', _hipsMinCtrl,
                      (v) => _hipsMin = v),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Age range
            _rangeRow('年龄', _ageMinCtrl, _ageMaxCtrl,
                (v) => _ageMin = v, (v) => _ageMax = v),
            const SizedBox(height: 8),
            // Trait + spoiler level
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _traitController,
                    decoration: const InputDecoration(
                      labelText: '特质 ID (如 i1)',
                      isDense: true,
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.label),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  value: _traitSpoiler,
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('无剧透')),
                    DropdownMenuItem(value: 1, child: Text('轻微剧透')),
                    DropdownMenuItem(value: 2, child: Text('全部剧透')),
                  ],
                  onChanged: (v) =>
                      setState(() => _traitSpoiler = v ?? 0),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Seiyuu (staff id)
            TextField(
              controller: _seiyuuController,
              decoration: const InputDecoration(
                labelText: '配音演员 ID (如 s81)',
                isDense: true,
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.record_voice_over),
              ),
            ),
            const SizedBox(height: 8),
            // VN id (nested vn filter)
            TextField(
              controller: _vnController,
              decoration: const InputDecoration(
                labelText: '关联 VN ID (如 v17)',
                isDense: true,
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.book),
              ),
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

  Widget _numField(
    String label,
    TextEditingController ctrl,
    void Function(int?) onChanged,
  ) {
    return TextField(
      controller: ctrl,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
      keyboardType: TextInputType.number,
      onChanged: (v) => onChanged(int.tryParse(v.trim())),
    );
  }

  Widget _rangeRow(
    String label,
    TextEditingController minCtrl,
    TextEditingController maxCtrl,
    void Function(int?) onMin,
    void Function(int?) onMax,
  ) {
    return Row(
      children: [
        Expanded(
          child: _numField('$label ≥', minCtrl, onMin),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _numField('$label ≤', maxCtrl, onMax),
        ),
      ],
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
      return const Center(child: Text('未找到角色'));
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
          final c = _items[i];
          return Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(8),
              leading: c.image?.url != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: CachedNetworkImage(
                        imageUrl: c.image!.url!,
                        width: 48,
                        height: 64,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          width: 48,
                          height: 64,
                          color: Theme.of(context).colorScheme.surface,
                        ),
                        errorWidget: (_, __, ___) => Container(
                          width: 48,
                          height: 64,
                          color: Theme.of(context).colorScheme.surface,
                          child: const Icon(Icons.person, size: 20),
                        ),
                      ),
                    )
                  : Container(
                      width: 48,
                      height: 64,
                      color: Theme.of(context).colorScheme.surface,
                      child: const Icon(Icons.person),
                    ),
              title: Text(
                c.name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                [
                  if (c.original != null) c.original,
                  if (c.vns.isNotEmpty) c.vns.first.title,
                ].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/character/${c.id}'),
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
