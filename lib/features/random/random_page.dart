import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/endpoints_provider.dart';

/// 随机 VN 页面 — 参照 VNDB 轮盘 HTML 实现。
///
/// 筛选条件使用 VNDB Kana API 原生 filter 语法:
/// - 包含语言: OR 组合 `['lang','=',code]`
/// - 排除语言: AND 组合 `['lang','!=',code]`
/// - 引擎: `['release','=',['engine','=',name]]`
/// - 免费: `['release','=',['freeware','=',bool]]`
/// - R18: `['release','=',['or',['minage','>=',18],['has_ero','=',true]]]`
///         非 R18 用 `['release','!=',...]`
/// - 平台/标签/评分/年份/开发商: 标准 VN filter
class RandomPage extends ConsumerStatefulWidget {
  const RandomPage({super.key});

  @override
  ConsumerState<RandomPage> createState() => _RandomPageState();
}

class _RandomPageState extends ConsumerState<RandomPage> {
  // --- 包含语言 (OR) ---
  final Set<String> _incLangs = {'en'}; // 默认英语

  // --- 排除语言 (AND of !=) ---
  final Set<String> _excLangs = {};

  // --- 平台 ---
  String? _platform;

  // --- 标签 ---
  String? _tagMode; // null=无, 'has'=含有, 'not'=不含有
  final _tagController = TextEditingController();

  // --- 评分 ---
  double _minRating = 0;

  // --- 发行年份 ---
  final _releasedFromController = TextEditingController();
  final _releasedToController = TextEditingController();

  // --- 开发商 ---
  final _devController = TextEditingController();

  // --- R18: 0=全部, 1=仅R18, 2=非R18 ---
  int _r18 = 0;

  // --- 免费: 0=全部, 1=仅免费, 2=非免费 ---
  int _free = 0;

  // --- 引擎 ---
  final _engineController = TextEditingController();

  // --- 状态 ---
  bool _rolling = false;
  String? _error;

  static const _languages = <_LangOption>[
    _LangOption('英语', 'en'),
    _LangOption('日语', 'ja'),
    _LangOption('中文', 'zh'),
    _LangOption('韩语', 'ko'),
    _LangOption('法语', 'fr'),
    _LangOption('德语', 'de'),
    _LangOption('俄语', 'ru'),
    _LangOption('西班牙语', 'es'),
  ];

  static const _platforms = <_LangOption>[
    _LangOption('Windows', 'win'),
    _LangOption('Linux', 'lin'),
    _LangOption('macOS', 'mac'),
    _LangOption('Android', 'and'),
    _LangOption('iOS', 'ios'),
    _LangOption('PS2', 'ps2'),
    _LangOption('PSP', 'psp'),
    _LangOption('PS Vita', 'psv'),
    _LangOption('PS3', 'ps3'),
    _LangOption('PS4', 'ps4'),
    _LangOption('Nintendo Switch', 'swi'),
    _LangOption('Nintendo DS', 'nds'),
    _LangOption('Nintendo 3DS', 'n3ds'),
    _LangOption('Wii', 'wii'),
    _LangOption('Wii U', 'wiu'),
    _LangOption('Xbox 360', 'x360'),
    _LangOption('Xbox One', 'xbo'),
    _LangOption('Web', 'web'),
  ];

  @override
  void dispose() {
    _tagController.dispose();
    _releasedFromController.dispose();
    _releasedToController.dispose();
    _devController.dispose();
    _engineController.dispose();
    super.dispose();
  }

  /// 构建 VNDB API filter 树 (参照 HTML buildFilters)。
  Object? _buildFilters() {
    final parts = <List<dynamic>>[];

    // --- 包含语言 (OR) ---
    if (_incLangs.isNotEmpty) {
      if (_incLangs.length == 1) {
        parts.add(['lang', '=', _incLangs.first]);
      } else {
        parts.add(['or', ..._incLangs.map((l) => ['lang', '=', l])]);
      }
    }

    // --- 排除语言 (AND of !=) ---
    if (_excLangs.isNotEmpty) {
      if (_excLangs.length == 1) {
        parts.add(['lang', '!=', _excLangs.first]);
      } else {
        parts.add(['and', ..._excLangs.map((l) => ['lang', '!=', l])]);
      }
    }

    // --- 平台 ---
    if (_platform != null) {
      parts.add(['platform', '=', _platform!]);
    }

    // --- 标签 ---
    final tagTerm = _tagController.text.trim();
    if (_tagMode != null && tagTerm.isNotEmpty) {
      final op = _tagMode == 'has' ? '=' : '!=';
      parts.add(['tag', op, tagTerm]);
    }

    // --- 评分 ---
    if (_minRating > 0) {
      parts.add(['rating', '>=', (_minRating * 10).round()]);
    }

    // --- 发行年份 ---
    final fromYear = _releasedFromController.text.trim();
    final toYear = _releasedToController.text.trim();
    if (fromYear.isNotEmpty) parts.add(['released', '>=', fromYear]);
    if (toYear.isNotEmpty) parts.add(['released', '<=', toYear]);

    // --- 开发商 ---
    final devTerm = _devController.text.trim();
    if (devTerm.isNotEmpty) parts.add(['developer', '=', devTerm]);

    // --- R18 (release 嵌套过滤) ---
    // R18 = release 中 minage>=18 或 has_ero=true
    final r18Inner = ['or', ['minage', '>=', 18], ['has_ero', '=', true]];
    if (_r18 == 1) {
      // 仅 R18: VN 至少有一个 R18 release
      parts.add(['release', '=', r18Inner]);
    } else if (_r18 == 2) {
      // 非 R18: VN 没有任何 R18 release
      parts.add(['release', '!=', r18Inner]);
    }

    // --- 免费 (release 嵌套过滤) ---
    if (_free == 1) {
      parts.add(['release', '=', ['freeware', '=', true]]);
    } else if (_free == 2) {
      parts.add(['release', '=', ['freeware', '=', false]]);
    }

    // --- 引擎 (release 嵌套过滤) ---
    final engineTerm = _engineController.text.trim();
    if (engineTerm.isNotEmpty) {
      parts.add(['release', '=', ['engine', '=', engineTerm]]);
    }

    if (parts.isEmpty) return null;
    if (parts.length == 1) return parts.first;
    return ['and', ...parts];
  }

  Future<void> _roll() async {
    setState(() {
      _rolling = true;
      _error = null;
    });
    try {
      final vnEndpoint = ref.read(vnEndpointProvider);
      final filters = _buildFilters();
      final vn = await vnEndpoint.randomWithFilters(filters: filters);

      if (!mounted) return;
      if (vn == null) {
        setState(() {
          _rolling = false;
          _error = '未找到匹配的 VN, 请放宽筛选条件';
        });
        return;
      }
      setState(() => _rolling = false);
      context.push('/vn/${vn.id}');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _rolling = false;
        _error = '失败: $e';
      });
    }
  }

  void _reset() {
    setState(() {
      _incLangs
        ..clear()
        ..add('en');
      _excLangs.clear();
      _platform = null;
      _tagMode = null;
      _tagController.clear();
      _minRating = 0;
      _releasedFromController.clear();
      _releasedToController.clear();
      _devController.clear();
      _engineController.clear();
      _r18 = 0;
      _free = 0;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('随机 VN')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // --- 包含语言 ---
          _FilterCard(
            title: '包含语言',
            icon: Icons.language,
            hint: '至少选一项 (包含其一即可)',
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: _languages.map((o) {
                return FilterChip(
                  label: Text(o.label),
                  selected: _incLangs.contains(o.value),
                  onSelected: (sel) {
                    setState(() {
                      if (sel) {
                        _incLangs.add(o.value);
                      } else {
                        // 至少保留一项
                        if (_incLangs.length > 1) {
                          _incLangs.remove(o.value);
                        }
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ),

          // --- 排除语言 ---
          _FilterCard(
            title: '排除语言',
            icon: Icons.block,
            hint: '作品不能包含这些语言',
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: _languages.map((o) {
                return FilterChip(
                  label: Text(o.label),
                  selected: _excLangs.contains(o.value),
                  onSelected: (sel) {
                    setState(() {
                      if (sel) {
                        _excLangs.add(o.value);
                      } else {
                        _excLangs.remove(o.value);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ),

          // --- 平台 ---
          _FilterCard(
            title: '平台',
            icon: Icons.devices,
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                ChoiceChip(
                  label: const Text('全部'),
                  selected: _platform == null,
                  onSelected: (_) => setState(() => _platform = null),
                ),
                ..._platforms.map((o) => ChoiceChip(
                      label: Text(o.label),
                      selected: _platform == o.value,
                      onSelected: (_) => setState(() => _platform = o.value),
                    )),
              ],
            ),
          ),

          // --- 标签 ---
          _FilterCard(
            title: '标签',
            icon: Icons.label,
            child: Column(
              children: [
                _SegmentedBar(
                  value: _tagMode,
                  options: const [
                    _SegOption(null, '无'),
                    _SegOption('has', '含有'),
                    _SegOption('not', '不含有'),
                  ],
                  onChanged: (v) => setState(() => _tagMode = v),
                ),
                if (_tagMode != null) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: _tagController,
                    decoration: const InputDecoration(
                      hintText: '标签 ID, 如 g1',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // --- 评分 ---
          _FilterCard(
            title: '最低评分: ${(_minRating * 10).round()}',
            icon: Icons.star,
            child: Slider(
              value: _minRating,
              min: 0,
              max: 10,
              divisions: 9,
              label: '${(_minRating * 10).round()}',
              onChanged: (v) => setState(() => _minRating = v),
            ),
          ),

          // --- 发行年份 ---
          _FilterCard(
            title: '发行年份',
            icon: Icons.calendar_today,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _releasedFromController,
                    decoration: const InputDecoration(
                      labelText: '起 (YYYY)',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _releasedToController,
                    decoration: const InputDecoration(
                      labelText: '止 (YYYY)',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
          ),

          // --- 开发商 ---
          _FilterCard(
            title: '开发商',
            icon: Icons.business,
            child: TextField(
              controller: _devController,
              decoration: const InputDecoration(
                hintText: '开发商 ID, 如 p1',
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
          ),

          // --- R18 ---
          _FilterCard(
            title: 'R18 内容',
            icon: Icons.visibility,
            child: _SegmentedBar(
              value: _r18.toString(),
              options: const [
                _SegOption('0', '全部'),
                _SegOption('1', '仅 R18'),
                _SegOption('2', '非 R18'),
              ],
              onChanged: (v) => setState(() => _r18 = int.parse(v!)),
            ),
          ),

          // --- 免费 ---
          _FilterCard(
            title: '免费',
            icon: Icons.money_off,
            child: _SegmentedBar(
              value: _free.toString(),
              options: const [
                _SegOption('0', '全部'),
                _SegOption('1', '仅免费'),
                _SegOption('2', '非免费'),
              ],
              onChanged: (v) => setState(() => _free = int.parse(v!)),
            ),
          ),

          // --- 引擎 ---
          _FilterCard(
            title: '引擎',
            icon: Icons.engineering,
            hint: '留空不限, 如 Ren\'Py / KiriKiri / Unity',
            child: TextField(
              controller: _engineController,
              decoration: const InputDecoration(
                hintText: '引擎名称',
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
          ),

          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),

          const SizedBox(height: 16),

          // --- 操作按钮 ---
          Row(
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('重置'),
                onPressed: _rolling ? null : _reset,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  icon: _rolling
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.casino),
                  label: Text(_rolling ? '抽取中…' : '随机抽取'),
                  onPressed: _rolling ? null : _roll,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ---- helper widgets ----

class _LangOption {
  const _LangOption(this.label, this.value);
  final String label;
  final String value;
}

class _SegOption {
  const _SegOption(this.value, this.label);
  final String? value;
  final String label;
}

class _SegmentedBar extends StatelessWidget {
  const _SegmentedBar({
    required this.value,
    required this.options,
    required this.onChanged,
  });
  final String? value;
  final List<_SegOption> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      children: options.map((o) {
        return ChoiceChip(
          label: Text(o.label),
          selected: value == o.value,
          onSelected: (_) => onChanged(o.value),
        );
      }).toList(),
    );
  }
}

class _FilterCard extends StatelessWidget {
  const _FilterCard({
    required this.title,
    required this.icon,
    required this.child,
    this.hint,
  });
  final String title;
  final IconData icon;
  final Widget child;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 6),
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            if (hint != null) ...[
              const SizedBox(height: 4),
              Text(hint!, style: Theme.of(context).textTheme.bodySmall),
            ],
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}
