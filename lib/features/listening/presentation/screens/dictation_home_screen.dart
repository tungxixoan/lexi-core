import 'package:flutter/material.dart';
import '../../../../core/theme/bloom/bloom.dart';
import '../widgets/dictation_options.dart';

class DictationHomeScreen extends StatelessWidget {
  const DictationHomeScreen({super.key});

  @override
  Widget build(BuildContext context) => BloomScaffold(
        appBar: const BloomAppBar(
          title: 'Nghe chép',
          automaticallyImplyLeading: false,
        ),
        body: const SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: DictationOptions(),
        ),
      );
}
