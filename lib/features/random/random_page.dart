import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/endpoints_provider.dart';

/// 随机 VN 页面 — 点击"随机"按钮即可随机抽取一部视觉小说。
///
/// 使用 api-kana.md 文档推荐的随机算法:
///  1. 按 id 倒序取最高 id;
///  2. 在 1..最高 id 之间随机取一个数;
///  3. 取 id >= 该随机数的第一个条目(带回退)。
/// 详细筛选调节已按需求移除, 保持一键随机。
class RandomPage extends ConsumerStatefulWidget {
  const RandomPage({super.key});

  @override
  ConsumerState<RandomPage> createState() => _RandomPageState();
}

class _RandomPageState extends ConsumerState<RandomPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  )..repeat();

  bool _rolling = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _roll();
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  Future<void> _roll() async {
    if (_rolling) return;
    setState(() {
      _rolling = true;
      _error = null;
    });
    try {
      final vn = await ref.read(vnEndpointProvider).random();
      if (!mounted) return;
      setState(() => _rolling = false);
      context.push('/vn/${vn.id}');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _rolling = false;
        _error = '抽取失败: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(title: const Text('随机 VN')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // The dice keeps spinning while a VN is being picked.
            AnimatedBuilder(
              animation: _spin,
              builder: (context, child) => Transform.rotate(
                angle: _spin.value * 6.28318,
                child: child,
              ),
              child: Icon(Icons.casino, size: 96, color: primary),
            ),
            const SizedBox(height: 24),
            Text(
              _rolling ? '正在抽取一部视觉小说…' : '随机抽取一部视觉小说',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '点击下方按钮开始',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 220,
              child: FilledButton.icon(
                icon: _rolling
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.casino),
                label: Text(_rolling ? '抽取中…' : '随机'),
                onPressed: _rolling ? null : _roll,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('重试'),
                onPressed: _rolling ? null : _roll,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
