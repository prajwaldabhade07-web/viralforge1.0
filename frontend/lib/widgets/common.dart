import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../theme.dart';

class Wordmark extends StatelessWidget {
  final Color color;
  final double size;
  const Wordmark({super.key, this.color = Tk.ink, this.size = 22});

  @override
  Widget build(BuildContext context) {
    Widget frame(Color c) => Container(
          width: size * 0.34,
          height: size * 0.62,
          margin: const EdgeInsets.only(right: 2.5),
          decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2)),
        );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        frame(Tk.ultra),
        frame(Tk.ultra),
        frame(Tk.sodium),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            'ViralForge',
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: display(size, color: color, spacing: -0.6),
          ),
        ),
      ],
    );
  }
}

class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  final Color? borderColor;
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(20), this.color, this.borderColor});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          color: color ?? Tk.gate,
          borderRadius: BorderRadius.circular(Tk.radius),
          border: Border.all(color: borderColor ?? Tk.line),
        ),
        child: child,
      );
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
    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: display(34, height: 1.1)),
        if (subtitle != null && subtitle!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(subtitle!, style: const TextStyle(color: Tk.mute, fontSize: 15, height: 1.4)),
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
          Expanded(child: Text(text, style: display(22))),
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
    final (bg, fg, icon) = switch (kind) {
      MsgKind.error => (Tk.badSoft, Tk.bad, Icons.error_outline),
      MsgKind.warn => (Tk.warnSoft, Tk.warn, Icons.warning_amber_rounded),
      MsgKind.success => (Tk.goodSoft, Tk.good, Icons.check_circle_outline),
      MsgKind.info => (Tk.ultraSoft, Tk.ultra, Icons.info_outline),
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
    final (label, bg, fg) = blocked
        ? ('Blocked', Tk.badSoft, Tk.bad)
        : switch (status) {
            'queued' => ('Queued', Tk.track, Tk.mute),
            'processing' => ('Analysing', Tk.ultraSoft, Tk.ultra),
            'completed' => ('Complete', Tk.goodSoft, Tk.good),
            _ => ('Failed', Tk.badSoft, Tk.bad),
          };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(color: fg, fontSize: 12.5, fontWeight: FontWeight.w600)),
    );
  }
}

class EmptyState extends StatelessWidget {
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;
  const EmptyState({super.key, required this.title, required this.body, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) => Panel(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
        child: Column(children: [
          SizedBox(
            width: 64,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (final c in [Tk.track, Tk.track, Tk.sodium])
                Container(
                    width: 14,
                    height: 24,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
            ]),
          ),
          const SizedBox(height: 18),
          Text(title, style: display(20), textAlign: TextAlign.center),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Text(body, textAlign: TextAlign.center, style: const TextStyle(color: Tk.mute, height: 1.45)),
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: 18),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ]),
      );
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

class AsyncBody<T> extends StatelessWidget {
  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final VoidCallback onRetry;
  const AsyncBody({super.key, required this.value, required this.data, required this.onRetry});

  @override
  Widget build(BuildContext context) => value.when(
        data: data,
        loading: () => const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())),
        error: (e, _) => ErrorState(error: e, onRetry: onRetry),
      );
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
          style: FilledButton.styleFrom(backgroundColor: Tk.bad),
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