import 'package:flutter/material.dart';

class ConfirmationDialog extends StatelessWidget {
  final String title;
  final String content;
  final String confirmText;
  final String cancelText;
  final VoidCallback onConfirm;
  final Color? confirmColor;
  final bool isDestructive;

  const ConfirmationDialog({
    super.key,
    required this.title,
    required this.content,
    this.confirmText = 'CONFIRMER',
    this.cancelText = 'ANNULER',
    required this.onConfirm,
    this.confirmColor,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: Text(content),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(cancelText),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            onConfirm();
          },
          style: TextButton.styleFrom(
            foregroundColor:
                confirmColor ??
                (isDestructive ? Colors.red : Theme.of(context).primaryColor),
          ),
          child: Text(confirmText),
        ),
      ],
    );
  }

  static Future<bool> show({
    required BuildContext context,
    required String title,
    required String content,
    String confirmText = 'CONFIRMER',
    String cancelText = 'ANNULER',
    Color? confirmColor,
    bool isDestructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(title),
            content: Text(content),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(cancelText),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(
                  foregroundColor:
                      confirmColor ??
                      (isDestructive
                          ? Colors.red
                          : Theme.of(context).primaryColor),
                ),
                child: Text(confirmText),
              ),
            ],
          ),
    );

    return result ?? false;
  }
}
