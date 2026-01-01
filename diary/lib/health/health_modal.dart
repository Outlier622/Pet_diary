import 'package:flutter/material.dart';

import '../center_modal.dart';
import 'weight_log_modal.dart';
import 'med_log_modal.dart';
import 'visit_vax_log_modal.dart';

class HealthModal extends StatelessWidget {
  const HealthModal({super.key});

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
            icon: Icons.monitor_weight_outlined,
            title: '体重记录',
            onTap: () {
              CenterModal.show(
                context,
                title: '体重记录',
                child: const WeightLogModal(),
              );
            },
          ),
          _Entry(
            icon: Icons.medication_outlined,
            title: '用药记录',
            onTap: () {
              CenterModal.show(
                context,
                title: '用药记录',
                child: const MedLogModal(),
              );
            },
          ),
          _Entry(
            icon: Icons.local_hospital_outlined,
            title: '就医与疫苗',
            onTap: () {
              CenterModal.show(
                context,
                title: '就医与疫苗',
                child: const VisitVaxLogModal(),
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
