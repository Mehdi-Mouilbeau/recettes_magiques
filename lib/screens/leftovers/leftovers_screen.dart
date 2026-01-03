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

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    if (auth.currentUser != null) {
      context.read<LeftoversProvider>().load(auth.currentUser!.uid);
    }
  }

  Future<void> _save() async {
    final auth = context.read<AuthProvider>();
    if (auth.currentUser == null) return;
    final prov = context.read<LeftoversProvider>();
    final ok = await prov.save(auth.currentUser!.uid, prov.leftovers);
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
      appBar: AppBar(
        title: Text('Mes restes', style: context.textStyles.titleLarge?.bold),
        actions: [
          IconButton(onPressed: _save, icon: const Icon(Icons.save_alt, color: Colors.blue)),
        ],
      ),
      body: Padding(
        padding: AppSpacing.paddingMd,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: 'Ajouter un ingrédient (ex: tomates, carottes)',
                prefixIcon: const Icon(Icons.add),
                suffixIcon: IconButton(onPressed: _addItemFromField, icon: const Icon(Icons.check_circle, color: Colors.green)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              ),
              onSubmitted: (_) => _addItemFromField(),
            ),
            const SizedBox(height: AppSpacing.md),
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
                onPressed: () async {
                  final auth = context.read<AuthProvider>();
                  if (auth.currentUser == null) return;
                  final ok = await prov.save(auth.currentUser!.uid, items);
                  if (!mounted) return;
                  if (ok) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Restes enregistrés')));
                  }
                },
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
