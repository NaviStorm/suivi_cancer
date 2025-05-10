import 'package:flutter/material.dart';

enum CustomButtonType {
  primary,
  secondary,
  outline,
  text,
  danger
}

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final CustomButtonType type;
  final bool isLoading;
  final bool isFullWidth;
  final IconData? icon;
  final double? width;
  final double height;

  const CustomButton({
    Key? key,
    required this.text,
    required this.onPressed,
    this.type = CustomButtonType.primary,
    this.isLoading = false,
    this.isFullWidth = false,
    this.icon,
    this.width,
    this.height = 48,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // Définir les couleurs en fonction du type de bouton
    Color backgroundColor;
    Color textColor;
    Color borderColor;
    
    switch (type) {
      case CustomButtonType.primary:
        backgroundColor = theme.colorScheme.primary;
        textColor = Colors.white;
        borderColor = Colors.transparent;
        break;
      case CustomButtonType.secondary:
        backgroundColor = theme.colorScheme.secondary;
        textColor = Colors.white;
        borderColor = Colors.transparent;
        break;
      case CustomButtonType.outline:
        backgroundColor = Colors.transparent;
        textColor = theme.colorScheme.primary;
        borderColor = theme.colorScheme.primary;
        break;
      case CustomButtonType.text:
        backgroundColor = Colors.transparent;
        textColor = theme.colorScheme.primary;
        borderColor = Colors.transparent;
        break;
      case CustomButtonType.danger:
        backgroundColor = theme.colorScheme.error;
        textColor = Colors.white;
        borderColor = Colors.transparent;
        break;
    }

    // Construire le contenu du bouton
    Widget buttonContent;
    if (isLoading) {
      buttonContent = SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(textColor),
        ),
      );
    } else if (icon != null) {
      buttonContent = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: textColor),
          SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      );
    } else {
      buttonContent = Text(
        text,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.bold,
        ),
      );
    }

    // Construire le bouton
    return Container(
      width: isFullWidth ? double.infinity : width,
      height: height,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: textColor,
          disabledBackgroundColor: backgroundColor.withOpacity(0.6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: borderColor),
          ),
          elevation: type == CustomButtonType.text || type == CustomButtonType.outline ? 0 : 2,
        ),
        child: buttonContent,
      ),
    );
  }
}

