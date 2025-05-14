import 'dart:io' show Platform;
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'custom_text_field.dart';
import 'package:suivi_cancer/utils/logger.dart';
import 'package:suivi_cancer/utils/fctDate.dart';

class DateTimePicker extends StatelessWidget {
  final String label;
  final DateTime? initialValue;
  final Function(DateTime) onDateTimeSelected;
  final bool showTime;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final String? Function(DateTime?)? validator;

  const DateTimePicker({
    Key? key,
    required this.label,
    this.initialValue,
    required this.onDateTimeSelected,
    this.showTime = true,
    this.firstDate,
    this.lastDate,
    this.validator,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {

    Log.d('Création écran DateTimePicker ${this.label}');

    final TextEditingController controller = TextEditingController(
      text: initialValue != null
          ? showTime
              ? DateFormat(getFmtDateTime()).format(initialValue!)
              : DateFormat(getFmtDate()).format(initialValue!)
          : '',
    );

    return CustomTextField(
      label: label,
      controller: controller,
      readOnly: true,
      validator: (value) {
        if (validator != null && initialValue != null) {
          return validator!(initialValue);
        }
        return null;
      },
      onTap: () async {
        final DateTime now = DateTime.now();
        final DateTime? pickedDate = await showDatePicker(
          context: context,
          initialDate: initialValue ?? now,
          firstDate: firstDate ?? DateTime(now.year - 5),
          lastDate: lastDate ?? DateTime(now.year + 5),
        );

        if (pickedDate != null) {
          DateTime selectedDateTime = pickedDate;

          if (showTime) {
            final TimeOfDay? pickedTime = await showTimePicker(
              context: context,
              initialTime: initialValue != null
                  ? TimeOfDay.fromDateTime(initialValue!)
                  : TimeOfDay.now(),
            );

            if (pickedTime != null) {
              selectedDateTime = DateTime(
                pickedDate.year,
                pickedDate.month,
                pickedDate.day,
                pickedTime.hour,
                pickedTime.minute,
              );
            } else {
              return; // L'utilisateur a annulé la sélection de l'heure
            }
          }

          controller.text = showTime
              ? getLocalizedDateTimeFormat(selectedDateTime)
              : DateFormat(getFmtDate()).format(selectedDateTime);

          onDateTimeSelected(selectedDateTime);
        }
      },
    );
  }

}

