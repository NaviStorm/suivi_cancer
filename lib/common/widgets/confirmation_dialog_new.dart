// lib/common/widgets/confirmation_dialog.dart
import 'package:flutter/material.dart';

class ConfirmationDialog extends StatelessWidget {
  final String title;
  final String content;
  final String confirmText;
  final String cancelText;
  final bool isDestructive;

  const ConfirmationDialog({
    Key? key,
    required this.title,
    required this.content,
    this.confirmText = 'Confirmer',
    this.cancelText = 'Annuler',
    this.isDestructive = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: Text(content),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(false);
          },
          child: Text(cancelText),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(true);
          },
          style: isDestructive
              ? TextButton.styleFrom(
                  foregroundColor: Colors.red,
                )
              : null,
          child: Text(confirmText),
        ),
      ],
    );
  }
}
