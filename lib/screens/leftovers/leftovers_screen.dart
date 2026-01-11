import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:recette_magique/providers/auth_provider.dart';
import 'package:recette_magique/providers/leftovers_provider.dart';
import 'package:recette_magique/theme.dart';

class LeftoversScreen extends StatefulWidget {
  const LeftoversScreen({super.key});

  @override
  State<LeftoversScreen> createState() => _LeftoversScreenState();
}

class _LeftoversScreenState extends State<LeftoversScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _loaded = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _loaded) return;

      final auth = context.read<AuthProvider>();
      final uid = auth.currentUser?.uid;
      if (uid == null) return;

      _loaded = true;
      await context.read<LeftoversProvider>().load(uid);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final auth = context.read<AuthProvider>();
    final uid = auth.currentUser?.uid;
    if (uid == null) return;

    final prov = context.read<LeftoversProvider>();
    final ok = await prov.save(uid, prov.leftovers);

    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Restes enregistrés'),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  void _addItemFromField() {
    final raw = _controller.text.trim();
    if (raw.isEmpty) return;

    final prov = context.read<LeftoversProvider>();
    final list = [...prov.leftovers];

    for (final token in raw.split(RegExp(r'[;,\n]'))) {
      final t = token.trim();
      if (t.isNotEmpty && !list.contains(t)) list.add(t);
    }

    prov.setLocal(list);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<LeftoversProvider>();
    final items = prov.leftovers;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text('Mes restes', style: context.textStyles.titleLarge?.bold),
        actions: [
          IconButton(
            onPressed: prov.isLoading ? null : _save,
            icon: const Icon(Icons.save_alt),
          ),
        ],
      ),
      body: Padding(
        padding: AppSpacing.paddingMd,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              onSubmitted: (_) => _addItemFromField(),
              decoration: InputDecoration(
                hintText: 'Ajouter un ingrédient (ex: tomates, carottes)',
                prefixIcon: const Icon(Icons.add),
                suffixIcon: IconButton(
                  onPressed: _addItemFromField,
                  icon: const Icon(Icons.check_circle),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (prov.errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Text(
                  prov.errorMessage!,
                  style: context.textStyles.bodyMedium?.withColor(
                    Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            if (prov.isLoading) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: AppSpacing.md),
            ],
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final it in items)
                  Chip(
                    label: Text(it),
                    onDeleted: () {
                      final list = [...items]..remove(it);
                      prov.setLocal(list);
                    },
                  ),
              ],
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: prov.isLoading ? null : _save,
                icon: const Icon(Icons.save),
                label: const Text('Enregistrer'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
