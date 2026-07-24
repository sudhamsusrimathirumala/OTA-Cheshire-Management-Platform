import 'package:flutter/material.dart';

class UnsavedChangesGuard extends StatefulWidget {
  const UnsavedChangesGuard({
    required this.isDirty,
    required this.child,
    this.isSaving = false,
    this.controller,
    super.key,
  });

  final bool Function() isDirty;
  final bool isSaving;
  final Widget child;
  final UnsavedChangesController? controller;

  static Future<void> requestClose(BuildContext context) async {
    await context
        .findAncestorStateOfType<_UnsavedChangesGuardState>()
        ?.requestClose();
  }

  @override
  State<UnsavedChangesGuard> createState() => _UnsavedChangesGuardState();
}

class _UnsavedChangesGuardState extends State<UnsavedChangesGuard> {
  bool _allowPop = false;
  bool _prompting = false;

  @override
  void initState() {
    super.initState();
    widget.controller?._requestClose = requestClose;
  }

  @override
  void didUpdateWidget(UnsavedChangesGuard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._requestClose = null;
      widget.controller?._requestClose = requestClose;
    }
  }

  @override
  void dispose() {
    widget.controller?._requestClose = null;
    super.dispose();
  }

  Future<void> requestClose() async {
    if (widget.isSaving || _prompting || !mounted) return;
    var discard = !widget.isDirty();
    if (!discard) {
      _prompting = true;
      discard =
          await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text('Discard changes?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Keep Editing'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Discard'),
                ),
              ],
            ),
          ) ??
          false;
      _prompting = false;
    }
    if (!discard || !mounted) return;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) => PopScope<void>(
    canPop: _allowPop,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) requestClose();
    },
    child: widget.child,
  );
}

class UnsavedChangesController {
  Future<void> Function()? _requestClose;

  Future<void> requestClose() async => _requestClose?.call();
}
