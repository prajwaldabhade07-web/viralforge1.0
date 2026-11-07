import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../theme.dart';
import '../util/platform.dart';
import '../util/report_export.dart';
import 'common.dart';

enum _Action { share, copy, html, text, print }

/// "Share or download" menu for a finished report. Works entirely in the browser from the report
/// the app has already loaded: no new server calls and no public links are created.
class ShareReportButton extends StatelessWidget {
  final Report report;
  final String? projectName;
  const ShareReportButton({super.key, required this.report, this.projectName});

  Future<void> _copy(BuildContext context) async {
    var copied = true;
    try {
      await Clipboard.setData(ClipboardData(text: reportShareText(report, projectName: projectName)));
    } catch (_) {
      copied = false; // the browser can refuse clipboard access
    }
    if (!context.mounted) return;
    toast(context, copied ? 'Summary copied. Paste it anywhere.' : "Couldn't copy here. Try Download report instead.");
  }

  Future<void> _run(BuildContext context, _Action a) async {
    switch (a) {
      case _Action.share:
        final result = await shareText('ViralForge report', reportShareText(report, projectName: projectName));
        if (!context.mounted) return;
        if (result == ShareResult.unsupported) {
          await _copy(context);
          if (context.mounted) toast(context, "This browser can't open a share sheet, so the summary was copied instead.");
        }
        break;
      case _Action.copy:
        await _copy(context);
        break;
      case _Action.html:
        final ok = await downloadTextFile(
          reportFileName(report, projectName: projectName, ext: 'html'),
          reportHtml(report, projectName: projectName),
          'text/html',
        );
        if (context.mounted) toast(context, ok ? 'Report downloaded. Open it in any browser.' : 'Download is not available here.');
        break;
      case _Action.text:
        final ok = await downloadTextFile(
          reportFileName(report, projectName: projectName, ext: 'txt'),
          reportFullText(report, projectName: projectName),
          'text/plain',
        );
        if (context.mounted) toast(context, ok ? 'Text report downloaded.' : 'Download is not available here.');
        break;
      case _Action.print:
        final ok = openPrintableHtml(reportHtml(report, projectName: projectName, autoPrint: true));
        if (!ok && context.mounted) toast(context, 'Your browser blocked the new tab. Allow pop-ups, or download the report instead.');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return PopupMenuButton<_Action>(
      tooltip: 'Share or download report',
      icon: Icon(Icons.ios_share, color: p.mute),
      onSelected: (a) => _run(context, a),
      itemBuilder: (_) => const [
        PopupMenuItem(value: _Action.share, child: _Item(Icons.ios_share, 'Share summary')),
        PopupMenuItem(value: _Action.copy, child: _Item(Icons.copy_outlined, 'Copy summary')),
        PopupMenuDivider(),
        PopupMenuItem(value: _Action.html, child: _Item(Icons.download_outlined, 'Download report (HTML)')),
        PopupMenuItem(value: _Action.text, child: _Item(Icons.description_outlined, 'Download as text')),
        PopupMenuItem(value: _Action.print, child: _Item(Icons.picture_as_pdf_outlined, 'Print or save as PDF')),
      ],
    );
  }
}

class _Item extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Item(this.icon, this.label);

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 20),
        const SizedBox(width: 12),
        Flexible(child: Text(label)),
      ]);
}
