import 'package:flutter/material.dart';
import 'package:recette_magique/screens/cgu/legal_texts.dart';

class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Informations légales'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'CGU'),
              Tab(text: 'Confidentialité'),
              Tab(text: 'Mentions légales'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _LegalText(title: 'Conditions Générales d’Utilisation', text: cguText),
            _LegalText(title: 'Politique de confidentialité', text: privacyText),
            _LegalText(title: 'Mentions légales', text: legalNoticeText),
          ],
        ),
      ),
    );
  }
}

class _LegalText extends StatelessWidget {
  final String title;
  final String text;

  const _LegalText({required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SelectableText(
        text,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}
