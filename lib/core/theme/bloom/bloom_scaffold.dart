import 'package:flutter/material.dart';
import '../bloom_tokens.dart';

/// The Bloom page frame: a soft radial wash over `surface2`, with the usual
/// scaffold slots. Use instead of `Scaffold` on every screen.
class BloomScaffold extends StatelessWidget {
  const BloomScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.bottomNavigationBar,
    this.floatingActionButton,
  });

  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    final c = context.bloom;
    return Scaffold(
      backgroundColor: c.surface2,
      appBar: appBar,
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: BloomGradients.pageBackground(c)),
        child: body,
      ),
    );
  }
}
