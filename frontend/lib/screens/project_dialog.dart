import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../models.dart';
import '../state/providers.dart';
import '../theme.dart';
import '../util/format.dart';
import '../widgets/common.dart';

/// Create (existing == null) or edit a project. Returns the saved project, or null if cancelled.
Future<Project?> showProjectDialog(BuildContext context, {Project? existing}) {
  return showDialog<Project>(context: context, builder: (_) => _ProjectDialog(existing: existing));
}

class _ProjectDialog extends ConsumerStatefulWidget {
  final Project? existing;
  const _ProjectDialog({this.existing});

  @override
  ConsumerState<_ProjectDialog> createState() => _ProjectDialogState();
}

class _ProjectDialogState extends ConsumerState<_ProjectDialog> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _niche = TextEditingController(text: widget.existing?.niche ?? '');
  late final _audience = TextEditingController(text: widget.existing?.targetAudience ?? '');
  late String? _platform = widget.existing?.platform;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _niche.dispose();
    _audience.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final body = <String, dynamic>{
      'name': _name.text.trim(),
      'niche': _niche.text.trim().isEmpty ? null : _niche.text.trim(),
      'target_audience': _audience.text.trim().isEmpty ? null : _audience.text.trim(),
      'platform': _platform,
    };
    try {
      final api = ref.read(apiProvider);
      final saved = widget.existing == null
          ? await api.createProject(body)
          : await api.updateProject(widget.existing!.id, body);
      if (mounted) Navigator.pop(context, saved);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    return AlertDialog(
      title: Text(editing ? 'Edit project' : 'New project'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (_error != null) ...[InlineMessage(MsgKind.error, _error!), const SizedBox(height: 12)],
              TextFormField(
                controller: _name,
                autofocus: true,
                maxLength: 100,
                decoration: fieldDecoration('Project name', hint: 'Spring recipe series'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Give the project a name.' : null,
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String?>(
                value: _platform,
                decoration: fieldDecoration('Main platform (optional)'),
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text('Not set')),
                  for (final e in platformLabels.entries) DropdownMenuItem<String?>(value: e.key, child: Text(e.value)),
                ],
                onChanged: (v) => setState(() => _platform = v),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _niche,
                maxLength: 100,
                decoration: fieldDecoration('Niche (optional)', hint: 'Budget cooking'),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _audience,
                maxLength: 200,
                decoration: fieldDecoration('Target audience (optional)', hint: 'College students'),
              ),
            ]),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: _busy
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
              : Text(editing ? 'Save changes' : 'Create project'),
        ),
      ],
    );
  }
}
