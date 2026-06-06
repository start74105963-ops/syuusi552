import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format_utils.dart';

class ProfitChip extends StatelessWidget {
  final int profit;
  final double fontSize;

  const ProfitChip({super.key, required this.profit, this.fontSize = 14});

  @override
  Widget build(BuildContext context) {
    final color = profit > 0 ? AppColors.win : profit < 0 ? AppColors.loss : AppColors.even;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        formatProfit(profit),
        style: TextStyle(color: color, fontSize: fontSize, fontWeight: FontWeight.bold),
      ),
    );
  }
}
