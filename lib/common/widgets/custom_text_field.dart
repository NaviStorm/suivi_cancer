// lib/common/widgets/custom_text_field.dart
import 'package:flutter/material.dart';

class CustomTextField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool obscureText;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final int maxLines;
  final bool enabled;
  final String? placeholder; // Au lieu de hintText
  final Widget? suffix;
  final Widget? prefix;
  final Function()? onTap;
  final Function(String)? onChanged;
  final bool readOnly;
  final AutovalidateMode autovalidateMode;
  final FocusNode? focusNode;

  const CustomTextField({
    super.key,
    required this.label,
    required this.controller,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.maxLines = 1,
    this.enabled = true,
    this.placeholder, // Utiliser placeholder au lieu de hintText
    this.suffix,
    this.prefix,
    this.onTap,
    this.onChanged,
    this.readOnly = false,
    this.autovalidateMode = AutovalidateMode.onUserInteraction,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      maxLines: maxLines,
      enabled: enabled,
      readOnly: readOnly,
      onTap: onTap,
      onChanged: onChanged,
      autovalidateMode: autovalidateMode,
      focusNode: focusNode,
      decoration: InputDecoration(
        labelText: label,
        hintText: placeholder, // Utilisé ici comme hintText
        suffixIcon: suffix,
        prefixIcon: prefix,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: maxLines > 1 ? 16 : 8,
        ),
      ),
    );
  }
}
