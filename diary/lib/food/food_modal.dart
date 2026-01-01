import 'package:flutter/material.dart';

import '../center_modal.dart';
import 'feed_log_modal.dart';
import 'water_log_modal.dart';
import 'allergy_pref_modal.dart';

class FoodModal extends StatelessWidget {
  const FoodModal({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 360,
      child: GridView.count(
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        padding: const EdgeInsets.all(4),
        childAspectRatio: 1.1,
        children: [
          _Entry(
            icon: Icons.restaurant_outlined,
            title: '喂食记录',
            onTap: () {
              CenterModal.show(
                context,
                title: '喂食记录',
                child: const FeedLogModal(),
              );
            },
          ),
          _Entry(
            icon: Icons.water_drop_outlined,
            title: '饮水记录',
            onTap: () {
              CenterModal.show(
                context,
                title: '饮水记录',
                child: const WaterLogModal(),
              );
            },
          ),
          _Entry(
            icon: Icons.favorite_border,
            title: '过敏与偏好',
            onTap: () {
              CenterModal.show(
                context,
                title: '过敏与偏好',
                child: const AllergyPrefModal(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Entry extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _Entry({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(18),
        ),
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
