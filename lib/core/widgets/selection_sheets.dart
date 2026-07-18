// lib/core/widgets/selection_sheets.dart
import 'package:flutter/material.dart';

/// A single choice in a selection bottom sheet.
class SelectOption<T> {
  const SelectOption({required this.value, required this.label, this.emoji});
  final T value;
  final String label;
  final String? emoji;

  String get display => emoji == null ? label : '$emoji  $label';
}

/// Shows a bottom sheet letting the user pick multiple values from [options].
/// Returns the confirmed selection, or null if dismissed without confirming.
///
/// Pass [maxSelected] to cap how many can be checked at once (further
/// checkboxes disable once the cap is hit); pass [confirmLabel] to customize
/// the confirm button text (receives the current selection count).
Future<Set<T>?> showMultiSelectSheet<T>({
  required BuildContext context,
  required String title,
  required List<SelectOption<T>> options,
  required Set<T> initialSelected,
  int? maxSelected,
  String Function(int count)? confirmLabel,
}) {
  return showModalBottomSheet<Set<T>>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _MultiSelectSheet<T>(
      title: title,
      options: options,
      initialSelected: initialSelected,
      maxSelected: maxSelected,
      confirmLabel: confirmLabel,
    ),
  );
}

/// Shows a bottom sheet letting the user pick a single value from [options].
/// Returns the picked option, or null if dismissed without picking.
///
/// Returns the whole [SelectOption] (not just its `.value`) so callers can
/// tell "dismissed without picking" (null) apart from "explicitly picked an
/// option whose value happens to be null" (e.g. a nullable T's "Tất cả"
/// entry) — both would otherwise collapse to the same `T?` under generics.
Future<SelectOption<T>?> showSingleSelectSheet<T>({
  required BuildContext context,
  required String title,
  required List<SelectOption<T>> options,
  required T selected,
}) {
  return showModalBottomSheet<SelectOption<T>>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(title, style: Theme.of(ctx).textTheme.titleLarge),
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: options
                  .map((o) => RadioListTile<T>(
                        value: o.value,
                        groupValue: selected,
                        title: Text(o.display),
                        onChanged: (_) => Navigator.pop(ctx, o),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

class _MultiSelectSheet<T> extends StatefulWidget {
  const _MultiSelectSheet({
    required this.title,
    required this.options,
    required this.initialSelected,
    this.maxSelected,
    this.confirmLabel,
  });
  final String title;
  final List<SelectOption<T>> options;
  final Set<T> initialSelected;
  final int? maxSelected;
  final String Function(int count)? confirmLabel;

  @override
  State<_MultiSelectSheet<T>> createState() => _MultiSelectSheetState<T>();
}

class _MultiSelectSheetState<T> extends State<_MultiSelectSheet<T>> {
  late final Set<T> _selected = {...widget.initialSelected};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final atMax =
        widget.maxSelected != null && _selected.length >= widget.maxSelected!;
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 8, 8),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.title, style: theme.textTheme.titleLarge),
                    if (widget.maxSelected != null)
                      Text(
                        'Tối đa ${widget.maxSelected}',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.outline),
                      ),
                  ],
                ),
                const Spacer(),
                TextButton(
                  onPressed:
                      _selected.isEmpty ? null : () => setState(_selected.clear),
                  child: const Text('Bỏ chọn hết'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              controller: scrollController,
              children: widget.options.map((o) {
                final isSelected = _selected.contains(o.value);
                return CheckboxListTile(
                  value: isSelected,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(o.display),
                  onChanged: (!isSelected && atMax)
                      ? null
                      : (v) => setState(() {
                            if (v == true) {
                              _selected.add(o.value);
                            } else {
                              _selected.remove(o.value);
                            }
                          }),
                );
              }).toList(),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, _selected),
                  child: Text(
                    widget.confirmLabel?.call(_selected.length) ??
                        (_selected.isEmpty
                            ? 'Xem tất cả'
                            : 'Áp dụng (${_selected.length})'),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
