import 'package:flutter/cupertino.dart' as cupertino;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter/widgets.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;

bool get ios => defaultTargetPlatform == TargetPlatform.iOS;
bool get windows => defaultTargetPlatform == TargetPlatform.windows;

class AdaptiveApp extends StatelessWidget {
  const AdaptiveApp({super.key, required this.home});
  final Widget home;

  @override
  Widget build(BuildContext context) => ios
      ? cupertino.CupertinoApp(title: 'Mistake Loop', home: home)
      : windows
      ? fluent.FluentApp(title: 'Mistake Loop', home: home)
      : material.MaterialApp(
          title: 'Mistake Loop',
          theme: material.ThemeData(
            useMaterial3: true,
            colorScheme: material.ColorScheme.fromSeed(
              seedColor: material.Colors.indigo,
            ),
          ),
          home: home,
        );
}

class AdaptiveShell extends StatelessWidget {
  const AdaptiveShell({super.key, required this.body, this.actions});
  final Widget body;
  final Widget? actions;

  @override
  Widget build(BuildContext context) {
    if (windows) {
      return fluent.NavigationView(
        pane: fluent.NavigationPane(
          displayMode: fluent.PaneDisplayMode.compact,
          items: [
            fluent.PaneItem(
              icon: const Icon(fluent.FluentIcons.book_answers),
              title: const Text('Journal'),
              body: body,
            ),
          ],
        ),
        paneBodyBuilder: (_, item) => LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 650;
            final actionPanel = actions == null
                ? null
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: actions,
                  );
            return SafeArea(
              child: narrow
                  ? Column(
                      children: [
                        Expanded(child: body),
                        if (actionPanel != null)
                          SizedBox(height: 116, child: actionPanel),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(child: body),
                        if (actionPanel != null)
                          SizedBox(width: 240, child: actionPanel),
                      ],
                    ),
            );
          },
        ),
      );
    }
    if (ios) {
      return cupertino.CupertinoPageScaffold(
        navigationBar: const cupertino.CupertinoNavigationBar(
          middle: Text('Mistake Loop'),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(child: body),
              if (actions != null)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.all(8),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: actions!,
                  ),
                ),
            ],
          ),
        ),
      );
    }
    return material.Scaffold(
      appBar: material.AppBar(title: const Text('Mistake Loop')),
      body: body,
      bottomNavigationBar: actions == null
          ? null
          : SafeArea(
              child: Padding(padding: const EdgeInsets.all(12), child: actions),
            ),
    );
  }
}

class AdaptiveButton extends StatelessWidget {
  const AdaptiveButton({
    super.key,
    required this.label,
    this.onPressed,
    this.primary = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) => ios
      ? cupertino.CupertinoButton(onPressed: onPressed, child: Text(label))
      : windows
      ? primary
            ? fluent.FilledButton(onPressed: onPressed, child: Text(label))
            : fluent.Button(onPressed: onPressed, child: Text(label))
      : primary
      ? material.FilledButton(onPressed: onPressed, child: Text(label))
      : material.OutlinedButton(onPressed: onPressed, child: Text(label));
}

class AdaptiveDialog extends StatelessWidget {
  const AdaptiveDialog({
    super.key,
    required this.title,
    required this.actions,
    this.content,
  });
  final String title;
  final Widget? content;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => ios
      ? cupertino.CupertinoAlertDialog(
          title: Text(title),
          content: content,
          actions: actions,
        )
      : windows
      ? fluent.ContentDialog(
          title: Text(title),
          content: content,
          actions: actions,
        )
      : material.AlertDialog(
          title: Text(title),
          content: content,
          actions: actions,
        );
}

class AdaptiveField extends StatelessWidget {
  const AdaptiveField({
    super.key,
    required this.label,
    required this.controller,
    this.validator,
    this.maxLines = 1,
  });
  final String label;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    if (!ios && !windows) {
      return material.TextFormField(
        key: key,
        controller: controller,
        maxLines: maxLines,
        decoration: material.InputDecoration(labelText: label),
        validator: validator,
      );
    }
    return FormField<String>(
      validator: (_) => validator?.call(controller.text),
      builder: (field) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label),
            if (ios)
              cupertino.CupertinoTextField(
                key: key,
                controller: controller,
                maxLines: maxLines,
                onChanged: field.didChange,
                placeholder: label,
              )
            else
              fluent.TextBox(
                key: key,
                controller: controller,
                maxLines: maxLines,
                onChanged: field.didChange,
                placeholder: label,
              ),
            if (field.hasError)
              Text(
                field.errorText!,
                style: const TextStyle(color: Color(0xffb00020)),
              ),
          ],
        ),
      ),
    );
  }
}

class AdaptiveFilter extends StatelessWidget {
  const AdaptiveFilter({
    super.key,
    required this.label,
    required this.selected,
    required this.onPressed,
  });
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => ios || windows
      ? AdaptiveButton(
          label: '${selected ? '✓ ' : ''}$label',
          onPressed: onPressed,
        )
      : material.FilterChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) => onPressed(),
        );
}

class AdaptiveToggle extends StatelessWidget {
  const AdaptiveToggle({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => ios
      ? Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Show resolved'),
            const SizedBox(width: 8),
            cupertino.CupertinoSwitch(value: value, onChanged: onChanged),
          ],
        )
      : windows
      ? Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Show resolved'),
            const SizedBox(width: 8),
            fluent.ToggleSwitch(checked: value, onChanged: onChanged),
          ],
        )
      : material.SwitchListTile(
          title: const Text('Show resolved'),
          value: value,
          onChanged: onChanged,
        );
}

class AdaptiveEntry extends StatelessWidget {
  const AdaptiveEntry({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
  });
  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => ios || windows
      ? _NativeEntry(title: title, subtitle: subtitle, children: children)
      : material.Card(
          child: material.ExpansionTile(
            title: Text(title),
            subtitle: Text(subtitle),
            childrenPadding: const EdgeInsets.all(12),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        );
}

class _NativeEntry extends StatefulWidget {
  const _NativeEntry({
    required this.title,
    required this.subtitle,
    required this.children,
  });
  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  State<_NativeEntry> createState() => _NativeEntryState();
}

class _NativeEntryState extends State<_NativeEntry> {
  bool expanded = false;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      AdaptiveButton(
        label: widget.title,
        onPressed: () => setState(() => expanded = !expanded),
      ),
      Text(widget.subtitle),
      if (expanded)
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: widget.children,
          ),
        ),
    ],
  );
}
