// lib/screens/result_screen.dart
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../providers/jobs_provider.dart';
import '../providers/api_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/status_stepper.dart';
import '../widgets/image_slider.dart';
import '../widgets/error_snackbar.dart';

class ResultScreen extends ConsumerStatefulWidget {
  final String jobId;
  const ResultScreen({super.key, required this.jobId});

  @override
  ConsumerState<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends ConsumerState<ResultScreen> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _isPublic = true;
  bool _metaSaving = false;
  bool _downloading = false;
  bool _metaLoaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(jobDetailProvider.notifier).load(widget.jobId);
    });
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _syncMeta(job) {
    if (!_metaLoaded) {
      _titleCtrl.text = job.title ?? '';
      _descCtrl.text = job.description ?? '';
      _isPublic = job.isPublic;
      _metaLoaded = true;
    }
  }

  Future<void> _saveMeta() async {
    setState(() => _metaSaving = true);
    try {
      await ref.read(jobDetailProvider.notifier).saveMetadata(
            title: _titleCtrl.text.trim().isEmpty
                ? null
                : _titleCtrl.text.trim(),
            description: _descCtrl.text.trim().isEmpty
                ? null
                : _descCtrl.text.trim(),
            isPublic: _isPublic,
          );
      if (mounted) showSuccessSnackbar(context, 'Saved');
    } catch (e) {
      if (mounted) showErrorSnackbar(context, 'Save failed: $e');
    } finally {
      if (mounted) setState(() => _metaSaving = false);
    }
  }

  Future<void> _download(String baseUrl) async {
    setState(() => _downloading = true);
    try {
      final status = await Permission.photos.request();
      if (!status.isGranted) {
        if (mounted) showErrorSnackbar(context, 'Permission denied');
        return;
      }
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/${widget.jobId}_output.jpg';
      await ref
          .read(apiServiceProvider)
          .requireValue
          .downloadOutputImage(widget.jobId, path);
      await Gal.putImage(path);
      await File(path).delete();
      if (mounted) showSuccessSnackbar(context, 'Saved to gallery');
    } catch (e) {
      if (mounted) showErrorSnackbar(context, 'Download failed: $e');
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _confirmDelete() async {
    final pwCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete job'),
        content: TextField(
          controller: pwCtrl,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Master password'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref
          .read(jobDetailProvider.notifier)
          .deleteJob(pwCtrl.text);
      if (mounted) context.go('/home');
    } catch (e) {
      if (mounted) showErrorSnackbar(context, 'Delete failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final jobAsync = ref.watch(jobDetailProvider);
    final urlAsync = ref.watch(backendUrlProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Result'),
        actions: [
          IconButton(
            icon: Icon(Icons.delete_outline, color: cs.error),
            onPressed: _confirmDelete,
          ),
        ],
      ),
      body: jobAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (job) {
          _syncMeta(job);
          final baseUrl = urlAsync.valueOrNull ?? '';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Status stepper ──────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: StatusStepper(job.status),
                ),
                const SizedBox(height: 20),

                // ── Image area ──────────────────────────────────
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    height: 320,
                    child: job.isDone && job.outputImageUrl != null
                        ? ImageComparisonSlider(
                            inputUrl: '$baseUrl/jobs/${job.jobId}/input',
                            outputUrl: '$baseUrl/jobs/${job.jobId}/output',
                          )
                        : Stack(
                            fit: StackFit.expand,
                            children: [
                              CachedNetworkImage(
                                imageUrl:
                                    '$baseUrl/jobs/${job.jobId}/input',
                                fit: BoxFit.cover,
                              ),
                              if (!job.isTerminal)
                                _PulsingOverlay(),
                              if (job.isFailed)
                                Container(
                                  color: Colors.black54,
                                  child: Center(
                                    child: Text(
                                      job.errorMessage ?? 'Processing failed',
                                      style: const TextStyle(
                                          color: Colors.white),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Download button ─────────────────────────────
                if (job.isDone)
                  OutlinedButton.icon(
                    onPressed: _downloading
                        ? null
                        : () => _download(baseUrl),
                    icon: _downloading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child:
                                CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.download_outlined),
                    label: const Text('Save to Gallery'),
                  ),
                if (job.isDone) const SizedBox(height: 20),

                // ── Metadata form ───────────────────────────────
                TextField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _descCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Description'),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  value: _isPublic,
                  onChanged: (v) => setState(() => _isPublic = v),
                  title: const Text('Public'),
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _metaSaving ? null : _saveMeta,
                  child: _metaSaving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child:
                              CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Save'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PulsingOverlay extends StatefulWidget {
  @override
  State<_PulsingOverlay> createState() => _PulsingOverlayState();
}

class _PulsingOverlayState extends State<_PulsingOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 1))
      ..repeat(reverse: true);
    _anim = Tween(begin: 0.3, end: 0.6).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _anim,
        builder: (_, __) => Container(
          color:
              Theme.of(context).colorScheme.primary.withOpacity(_anim.value),
        ),
      );
}
