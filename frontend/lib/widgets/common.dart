import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../theme.dart';
import 'fx.dart';
import 'pip.dart';

class Wordmark extends StatelessWidget {
  final Color? color;
  final double size;
  const Wordmark({super.key, this.color, this.size = 22});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    Widget frame(Color c) => Container(
          width: size * 0.34,
          height: size * 0.62,
          margin: const EdgeInsets.only(right: 2.5),
          decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2)),
        );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        frame(p.ultra),
        frame(p.ultra),
        frame(p.sodium),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            'ViralForge',
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: context.ty.heading.copyWith(fontSize: size, color: color ?? p.text, letterSpacing: -0.6),
          ),
        ),
      ],
    );
  }
}

/// Card surface. Built on Material so hover and ink effects of children are visible.
class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  final Color? borderColor;
  final bool raised;
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.color,
    this.borderColor,
    this.raised = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final r = BorderRadius.circular(kRadius);
    final card = SizedBox(
      width: double.infinity,
      child: Material(
        color: color ?? p.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: r, side: BorderSide(color: borderColor ?? p.line)),
        child: Padding(padding: padding, child: child),
      ),
    );
    return raised ? DecoratedBox(decoration: BoxDecoration(borderRadius: r, boxShadow: p.lift), child: card) : card;
  }
}

/// Centered, width-limited, scrollable page body.
class PageFrame extends StatelessWidget {
  final Widget child;
  const PageFrame({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.of(context).size.width < 700;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(narrow ? 16 : 32, narrow ? 16 : 32, narrow ? 16 : 32, 48),
      child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1040), child: child)),
    );
  }
}

class PageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  const PageHeader({super.key, required this.title, this.subtitle, this.actions = const []});

  @override
  Widget build(BuildContext context) {
    final ty = context.ty;
    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: ty.title),
        if (subtitle != null && subtitle!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(subtitle!, style: ty.body.copyWith(color: context.pal.mute)),
        ],
      ],
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: LayoutBuilder(builder: (context, c) {
        if (actions.isEmpty) return titleBlock;
        if (c.maxWidth > 720) {
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: titleBlock),
            const SizedBox(width: 16),
            Wrap(spacing: 10, runSpacing: 10, children: actions),
          ]);
        }
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          titleBlock,
          const SizedBox(height: 14),
          Wrap(spacing: 10, runSpacing: 10, children: actions),
        ]);
      }),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionTitle(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 28, bottom: 12),
        child: Row(children: [
          Expanded(child: Text(text, style: context.ty.heading)),
          if (trailing != null) trailing!,
        ]),
      );
}

enum MsgKind { error, info, success, warn }

class InlineMessage extends StatelessWidget {
  final MsgKind kind;
  final String text;
  final Widget? action;
  const InlineMessage(this.kind, this.text, {super.key, this.action});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final (bg, fg, icon) = switch (kind) {
      MsgKind.error => (p.badSoft, p.bad, Icons.error_outline),
      MsgKind.warn => (p.warnSoft, p.warn, Icons.warning_amber_rounded),
      MsgKind.success => (p.goodSoft, p.good, Icons.check_circle_outline),
      MsgKind.info => (p.ultraSoft, p.ultra, Icons.info_outline),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: fg, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: TextStyle(color: fg, fontSize: 14, height: 1.4, fontWeight: FontWeight.w500))),
        if (action != null) ...[const SizedBox(width: 8), action!],
      ]),
    );
  }
}

class StatusPill extends StatelessWidget {
  final String status;
  final bool blocked;
  const StatusPill(this.status, {super.key, this.blocked = false});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final (label, bg, fg) = blocked
        ? ('Blocked', p.badSoft, p.bad)
        : switch (status) {
            'queued' => ('Queued', p.track, p.mute),
            'processing' => ('Analysing', p.ultraSoft, p.ultra),
            'completed' => ('Complete', p.goodSoft, p.good),
            _ => ('Failed', p.badSoft, p.bad),
          };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(color: fg, fontSize: 12.5, fontWeight: FontWeight.w600)),
    );
  }
}

/// Pip plus one clear action.
class EmptyState extends StatelessWidget {
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;
  final PipMood mood;
  const EmptyState({
    super.key,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
    this.mood = PipMood.idle,
  });

  @override
  Widget build(BuildContext context) {
    final ty = context.ty;
    return Panel(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Column(children: [
        PipMark(mood: mood, size: 96),
        const SizedBox(height: 8),
        Text(title, style: ty.heading, textAlign: TextAlign.center),
        const SizedBox(height: 6),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Text(body, textAlign: TextAlign.center, style: ty.body.copyWith(color: context.pal.mute)),
        ),
        if (actionLabel != null) ...[
          const SizedBox(height: 18),
          FilledButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ]),
    );
  }
}

String errorText(Object e) => e is ApiException ? e.message : 'Something went wrong. Try again.';

class ErrorState extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;
  const ErrorState({super.key, required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: InlineMessage(
          MsgKind.error,
          errorText(error),
          action: TextButton(onPressed: onRetry, child: const Text('Try again')),
        ),
      );
}

/// Placeholder rows while a list loads.
class SkeletonList extends StatelessWidget {
  final int rows;
  const SkeletonList({super.key, this.rows = 3});

  @override
  Widget build(BuildContext context) => Panel(
        child: Column(children: [
          for (var i = 0; i < rows; i++) ...[
            if (i > 0) const SizedBox(height: 18),
            const Row(children: [
              Expanded(child: Skeleton(height: 16)),
              SizedBox(width: 24),
              Skeleton(width: 90, height: 16),
            ]),
          ],
        ]),
      );
}

class AsyncBody<T> extends StatelessWidget {
  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final VoidCallback onRetry;
  const AsyncBody({super.key, required this.value, required this.data, required this.onRetry});

  @override
  Widget build(BuildContext context) => value.when(
        skipLoadingOnReload: true,
        skipLoadingOnRefresh: true,
        data: data,
        loading: () => const SkeletonList(),
        error: (e, _) => ErrorState(error: e, onRetry: onRetry),
      );
}

/// Calls [onTick] every few seconds while [active]. Used to keep in-progress jobs live.
class LivePoller extends StatefulWidget {
  final bool active;
  final VoidCallback onTick;
  final Duration every;
  const LivePoller({super.key, required this.active, required this.onTick, this.every = const Duration(seconds: 4)});

  @override
  State<LivePoller> createState() => _LivePollerState();
}

class _LivePollerState extends State<LivePoller> {
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(LivePoller old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    _t?.cancel();
    _t = null;
    if (widget.active) _t = Timer.periodic(widget.every, (_) => widget.onTick());
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

Future<bool> confirmDialog(BuildContext context,
    {required String title, required String body, required String confirmLabel}) async {
  final res = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: ctx.pal.bad, foregroundColor: ctx.pal.onUltra),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return res ?? false;
}

void toast(BuildContext context, String message) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));