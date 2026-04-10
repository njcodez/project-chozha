// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/settings_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/api_provider.dart';
import '../widgets/error_snackbar.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _urlCtrl = TextEditingController();
  bool _saving = false;
  bool _testing = false;
  bool? _healthy; // null = untested

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final current = ref.read(backendUrlProvider).valueOrNull;
      if (current != null) _urlCtrl.text = current;
    });
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) return;
    setState(() => _saving = true);
    try {
      await saveBackendUrl(url);
      if (mounted) showSuccessSnackbar(context, 'URL updated');
    } catch (e) {
      if (mounted) showErrorSnackbar(context, 'Failed: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _test() async {
    setState(() {
      _testing = true;
      _healthy = null;
    });
    try {
      final api = ref.read(apiServiceProvider).valueOrNull;
      if (api == null) {
        setState(() => _healthy = false);
        return;
      }
      final ok = await api.checkHealth();
      if (mounted) setState(() => _healthy = ok);
    } catch (_) {
      if (mounted) setState(() => _healthy = false);
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _changeUsername() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change username?'),
        content: const Text(
            'Your current username will be cleared. You\'ll be asked to enter a new one.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Continue')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(authProvider.notifier).clearUsername();
    if (mounted) context.go('/username');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final username = ref.watch(usernameProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Backend URL ──────────────────────────────────────
          Text('Backend URL',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          TextField(
            controller: _urlCtrl,
            decoration: const InputDecoration(
              labelText: 'URL',
              hintText: 'https://xxx.trycloudflare.com',
              prefixIcon: Icon(Icons.link),
            ),
            keyboardType: TextInputType.url,
            onChanged: (_) => setState(() => _healthy = null),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Update'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _testing ? null : _test,
                  icon: _testing
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : _healthy == null
                          ? const Icon(Icons.wifi_find_outlined)
                          : Icon(
                              _healthy!
                                  ? Icons.check_circle_outline
                                  : Icons.cancel_outlined,
                              color: _healthy! ? Colors.green : cs.error,
                            ),
                  label: Text(_healthy == null
                      ? 'Test'
                      : _healthy!
                          ? 'OK'
                          : 'Failed'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // ── Account ──────────────────────────────────────────
          Text('Account', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: cs.primaryContainer,
              child: Text(
                (username ?? '?')[0].toUpperCase(),
                style: TextStyle(color: cs.onPrimaryContainer),
              ),
            ),
            title: Text(username ?? 'Unknown'),
            subtitle: const Text('Current username'),
            trailing: TextButton(
              onPressed: _changeUsername,
              child: const Text('Change'),
            ),
          ),
        ],
      ),
    );
  }
}
