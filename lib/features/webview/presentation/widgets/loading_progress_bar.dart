import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

class LoadingProgressBar extends StatelessWidget {
  const LoadingProgressBar({super.key, required this.progress});

  /// 0.0 - 1.0 (a value >= 1.0 hides the bar).
  final double progress;

  @override
  Widget build(BuildContext context) {
    if (progress >= 1.0) return const SizedBox.shrink();
    return SizedBox(
      height: 2.5,
      child: LinearProgressIndicator(
        value: progress,
        backgroundColor: Colors.transparent,
        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
      ),
    );
  }
}
