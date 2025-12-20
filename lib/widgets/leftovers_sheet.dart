import 'package:flutter/material.dart';
import 'package:recette_magique/theme.dart';

/// Feuille modale pour éditer les "restes" (ingrédients dispo)
class LeftoversSheet extends StatefulWidget {
  final List<String> initialItems;

  const LeftoversSheet({super.key, required this.initialItems});

  @override
  State<LeftoversSheet> createState() => _LeftoversSheetState();
}

class _LeftoversSheetState extends State<LeftoversSheet> {
  late List<String> _items;
  final TextEditingController _textCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _items = [...widget.initialItems];
  }

  void _addCurrent() {
    final raw = _textCtrl.text.trim();
    if (raw.isEmpty) return;
    final parts = raw
        .split(RegExp(r'[;,\n]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    setState(() {
      _items = {..._items, ...parts}.toList();
      _textCtrl.clear();
    });
  }

  void _remove(String v) => setState(() => _items.remove(v));

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: AppSpacing.paddingMd,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.kitchen, color: cs.primary),
                const SizedBox(width: AppSpacing.sm),
                Text('Mes restes', style: context.textStyles.titleLarge?.bold),
                const Spacer(),
                IconButton(
                  tooltip: 'Fermer',
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                )
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Ajoutez les ingrédients restants dans votre frigo. Séparez par virgules.',
              style: context.textStyles.bodyMedium?.withColor(cs.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _textCtrl,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _addCurrent(),
              decoration: InputDecoration(
                hintText: 'Ex: tomates, carottes, oeufs',
                prefixIcon: const Icon(Icons.add_circle_outline, color: Colors.green),
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                suffixIcon: IconButton(
                  onPressed: _addCurrent,
                  icon: const Icon(Icons.check_circle, color: Colors.blue),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (_items.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _items
                    .map((e) => Chip(
                          label: Text(e),
                          deleteIcon: const Icon(Icons.close, size: 16),
                          onDeleted: () => _remove(e),
                        ))
                    .toList(),
              ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () => setState(() => _items.clear()),
                  icon: const Icon(Icons.delete_sweep, color: Colors.red),
                  label: const Text('Vider'),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: () => Navigator.pop(context, _items),
                  icon: const Icon(Icons.restaurant_menu),
                  label: const Text('Enregistrer et proposer'),
                )
              ],
            )
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }
}
