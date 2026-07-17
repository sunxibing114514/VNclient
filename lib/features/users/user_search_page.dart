import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/endpoints_provider.dart';

/// A page to look up VNDB users by id or username.
class UserSearchPage extends ConsumerStatefulWidget {
  const UserSearchPage({super.key});

  @override
  ConsumerState<UserSearchPage> createState() => _UserSearchPageState();
}

class _UserSearchPageState extends ConsumerState<UserSearchPage> {
  final _controller = TextEditingController();
  bool _loading = false;
  Object? _error;
  dynamic _result;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final term = _controller.text.trim();
    if (term.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });
    try {
      final user = await ref.read(userEndpointProvider).get(term);
      setState(() {
        _result = user;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Users')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: '输入用户名或 ID (如 yorhel)',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _search,
                ),
              ),
              onSubmitted: (_) => _search(),
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 12),
            Text('$_error'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _search,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }
    if (_result == null) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.group, size: 48),
            SizedBox(height: 12),
            Text('输入用户名或 ID 查找用户'),
          ],
        ),
      );
    }
    if (_result.id.isEmpty) {
      return const Center(child: Text('未找到该用户'));
    }
    return ListView(
      children: [
        Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text(_result.username.isEmpty
                ? _result.id
                : _result.username),
            subtitle: Text(_result.id),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/user/${_result.id}'),
          ),
        ),
      ],
    );
  }
}
