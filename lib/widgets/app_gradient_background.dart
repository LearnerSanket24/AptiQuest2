import 'package:flutter/material.dart';

import '../config/app_constants.dart';

class AppGradientBackground extends StatelessWidget {
  final Widget child;

  const AppGradientBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppGradients.home,
      ),
      child: child,
    );
  }
}
