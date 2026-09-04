import 'package:flutter/material.dart';
import '../../../../core/theme/bloom/bloom.dart';
import '../widgets/comprehension_options.dart';

class ComprehensionHomeScreen extends StatelessWidget {
  const ComprehensionHomeScreen({super.key});

  @override
  Widget build(BuildContext context) => BloomScaffold(
        appBar: const BloomAppBar(
          title: 'Nghe hiểu',
          automaticallyImplyLeading: false,
        ),
        body: const SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: ComprehensionOptions(),
        ),
      );
}
