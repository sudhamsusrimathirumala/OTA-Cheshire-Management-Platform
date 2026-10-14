import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/performance_diagnostics.dart';
import '../services/performance_event_buffer.dart';

/// The launcher is compiled out unless both Web and the explicit flag are true.
class PerformanceDiagnosticsOverlay extends StatefulWidget {
  const PerformanceDiagnosticsOverlay({required this.child, super.key});
  final Widget child;

  @override
  State<PerformanceDiagnosticsOverlay> createState() =>
      _PerformanceDiagnosticsOverlayState();
}

class _PerformanceDiagnosticsOverlayState
    extends State<PerformanceDiagnosticsOverlay> {
  bool _open = false;
  late final OverlayEntry _entry;

  @override
  void initState() {
    super.initState();
    _entry = OverlayEntry(builder: _buildContents);
  }

  @override
  void didUpdateWidget(PerformanceDiagnosticsOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_entry.mounted) _entry.markNeedsBuild();
  }

  @override
  void dispose() {
    if (_entry.mounted) _entry.remove();
    _entry.dispose();
    super.dispose();
  }

  void _setOpen(bool open) {
    _open = open;
    _entry.markNeedsBuild();
  }

  @override
  Widget build(BuildContext context) {
    if (!PerformanceDiagnostics.viewerEnabled) return widget.child;
    // Provides an Overlay ancestor for selectable-text handles. The app's
    // Navigator is below MaterialApp.builder and is not the panel's ancestor.
    return Overlay(initialEntries: [_entry]);
  }

  Widget _buildContents(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        Positioned(
          top: 0,
          right: 8,
          child: SafeArea(
            child: Material(
              elevation: 3,
              borderRadius: BorderRadius.circular(12),
              child: TextButton.icon(
                onPressed: () => _setOpen(true),
                icon: const Icon(Icons.timer_outlined, size: 18),
                label: const Text('Timings'),
              ),
            ),
          ),
        ),
        if (_open)
          Positioned.fill(
            child: Material(
              color: Colors.black54,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: PerformanceDiagnosticsPanel(
                        buffer: PerformanceDiagnostics.viewerBuffer,
                        onClose: () => _setOpen(false),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class PerformanceDiagnosticsPanel extends StatefulWidget {
  const PerformanceDiagnosticsPanel({
    required this.buffer,
    required this.onClose,
    super.key,
  });

  final PerformanceEventBuffer buffer;
  final VoidCallback onClose;

  @override
  State<PerformanceDiagnosticsPanel> createState() =>
      _PerformanceDiagnosticsPanelState();
}

class _PerformanceDiagnosticsPanelState
    extends State<PerformanceDiagnosticsPanel> {
  Timer? _ticker;
  String? _copyStatus;

  @override
  void initState() {
    super.initState();
    // Viewer-only live clock. It never starts/retries any app operation.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _copy() async {
    try {
      await Clipboard.setData(ClipboardData(text: widget.buffer.exportText));
      if (mounted) setState(() => _copyStatus = 'Copied');
    } catch (_) {
      if (mounted) {
        setState(
          () => _copyStatus = 'Clipboard unavailable. Select text below.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      textStyle: const TextStyle(fontSize: 12, color: Colors.black87),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: ValueListenableBuilder<int>(
        valueListenable: widget.buffer.revision,
        builder: (context, _, child) {
          final elapsed = widget.buffer.createElapsed(
            PerformanceDiagnostics.journeyElapsedMilliseconds,
          );
          return Padding(
            padding: const EdgeInsets.all(12),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Expanded(child: Text('Local performance timings')),
                      IconButton(
                        tooltip: 'Close timings',
                        onPressed: widget.onClose,
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const Text(
                    '+ms = since Create Profiles. journey = since journey start. '
                    'duration = individual operation. Latest 300 events; local only.',
                  ),
                  if (elapsed != null) Text('Since press: $elapsed ms (live)'),
                  Wrap(
                    spacing: 8,
                    children: [
                      TextButton.icon(
                        onPressed: _copy,
                        icon: const Icon(Icons.copy, size: 18),
                        label: const Text('Copy diagnostics'),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          widget.buffer.clear();
                          setState(() => _copyStatus = null);
                        },
                        icon: const Icon(Icons.clear_all, size: 18),
                        label: const Text('Clear / reset'),
                      ),
                    ],
                  ),
                  if (_copyStatus != null) Text(_copyStatus!),
                  const Divider(),
                  SizedBox(
                    width: double.infinity,
                    child: SelectableText(
                      widget.buffer.events.isEmpty
                          ? 'No timings yet. Close this panel and press Create Profiles.'
                          : widget.buffer.exportText,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
