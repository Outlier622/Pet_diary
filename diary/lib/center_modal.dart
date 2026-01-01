import 'package:flutter/material.dart';

class CenterModal {
  static Future<T?> show<T>(
    BuildContext context, {
    required String title,
    required Widget child,
    double widthFactor = 0.88,
    double maxWidth = 420,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: true,
      builder: (_) {
        final w = MediaQuery.of(context).size.width;
        final modalWidth = (w * widthFactor).clamp(280.0, maxWidth);

        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: modalWidth),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  child,
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
