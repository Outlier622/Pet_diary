import 'dart:io';
import 'package:flutter/material.dart';

class PetProfilePage extends StatelessWidget {
  final File? bgImageFile;
  final String? breedText;

  const PetProfilePage({
    super.key,
    this.bgImageFile,
    this.breedText,
  });

  @override
  Widget build(BuildContext context) {
    final hasBg = bgImageFile != null;
    final showBreed = (breedText != null && breedText!.trim().isNotEmpty);

    return Scaffold(
      appBar: AppBar(title: const Text('Pet Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            height: 180,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: Colors.grey.shade200,
              image: hasBg
                  ? DecorationImage(
                      image: FileImage(bgImageFile!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: !hasBg
                ? const Center(
                    child: Text(
                      'No background image set yet.\nGo back to the home screen and long-press the pet area to choose one.',
                      textAlign: TextAlign.center,
                    ),
                  )
                : null,
          ),

          const SizedBox(height: 14),

          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const Icon(Icons.pets, size: 28),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      showBreed
                          ? breedText!
                          : 'Breed not identified yet.',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 14),

          const Text(
            'Features',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),

          _EntryTile(
            icon: Icons.shower_outlined,
            title: 'Hygiene',
            subtitle: 'Bathing, grooming, parasite control, and reminders',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Hygiene feature coming soon')),
              );
            },
          ),
          _EntryTile(
            icon: Icons.restaurant_outlined,
            title: 'Nutrition',
            subtitle: 'Diet logs, allergies, and preferences',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Nutrition feature coming soon')),
              );
            },
          ),
          _EntryTile(
            icon: Icons.favorite_border,
            title: 'Health',
            subtitle: 'Weight, symptoms, and medication tracking',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Health feature coming soon')),
              );
            },
          ),
          _EntryTile(
            icon: Icons.photo_library_outlined,
            title: 'Growth Album',
            subtitle: 'Timeline-based photo records',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Album feature coming soon')),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _EntryTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
