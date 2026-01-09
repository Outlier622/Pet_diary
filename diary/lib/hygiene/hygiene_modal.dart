import 'package:flutter/material.dart';

import '../center_modal.dart';
import 'bath_log_modal.dart';
import 'groom_log_modal.dart';
import 'deworm_log_modal.dart';
import 'clean_reminder_modal.dart';

class HygieneModal extends StatelessWidget {
  const HygieneModal({super.key});

  @override
  Widget build(BuildContext context) {
    return _Grid(
      children: [
        _Entry(
          icon: Icons.shower_outlined,
          title: 'Bath Logs',
          onTap: () {
            CenterModal.show(
              context,
              title: 'Bath Logs',
              child: const BathLogModal(),
            );
          },
        ),
        _Entry(
          icon: Icons.brush_outlined,
          title: 'Grooming',
          onTap: () {
            CenterModal.show(
              context,
              title: 'Grooming',
              child: const GroomLogModal(),
            );
          },
        ),
        _Entry(
          icon: Icons.bug_report_outlined,
          title: 'Deworming Logs',
          onTap: () {
            CenterModal.show(
              context,
              title: 'Deworming Logs',
              child: const DewormLogModal(),
            );
          },
        ),
        _Entry(
          icon: Icons.alarm_outlined,
          title: 'Cleaning Reminders',
          onTap: () => _openCleanReminderBottomSheet(context),
        ),
      ],
    );
  }

  void _openCleanReminderBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: const CleanReminderModal(),
        );
      },
    );
  }
}

class _Grid extends StatelessWidget {
  final List<Widget> children;

  const _Grid({required this.children});

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
        children: children,
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
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
