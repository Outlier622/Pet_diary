import 'package:flutter/material.dart';

class EdgeButtons extends StatelessWidget {
  final VoidCallback onHygiene;
  final VoidCallback onFood;
  final VoidCallback onHealth;
  final VoidCallback onAlbum;

  const EdgeButtons({
    super.key,
    required this.onHygiene,
    required this.onFood,
    required this.onHealth,
    required this.onAlbum,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _EdgeButton(
          alignment: Alignment.topLeft,
          icon: Icons.bathtub_outlined,
          label: 'Hygiene',
          onTap: onHygiene,
        ),
        _EdgeButton(
          alignment: Alignment.topRight,
          icon: Icons.restaurant_outlined,
          label: 'Nutrition',
          onTap: onFood,
        ),
        _EdgeButton(
          alignment: Alignment.bottomLeft,
          icon: Icons.favorite_border,
          label: 'Health',
          onTap: onHealth,
        ),
        _EdgeButton(
          alignment: Alignment.bottomRight,
          icon: Icons.photo_library_outlined,
          label: 'Album',
          onTap: onAlbum,
        ),
      ],
    );
  }
}

class _EdgeButton extends StatefulWidget {
  final Alignment alignment;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _EdgeButton({
    required this.alignment,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  State<_EdgeButton> createState() => _EdgeButtonState();
}

class _EdgeButtonState extends State<_EdgeButton> {
  bool _pressed = false;

  void _setPressed(bool v) {
    if (_pressed == v) return;
    setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: widget.alignment,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          onTapDown: (_) => _setPressed(true),
          onTapUp: (_) => _setPressed(false),
          onTapCancel: () => _setPressed(false),
          child: AnimatedScale(
            scale: _pressed ? 1.06 : 1.0,
            duration: const Duration(milliseconds: 110),
            curve: Curves.easeOut,
            child: Container(
              width: 110,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.72),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 14,
                    spreadRadius: 2,
                    color: Colors.black.withOpacity(0.15),
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(widget.icon, size: 28),
                  const SizedBox(height: 6),
                  Text(
                    widget.label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
