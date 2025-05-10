import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'custom_text_field.dart';

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
    final TextEditingController controller = TextEditingController(
      text: initialValue != null
          ? showTime
              ? DateFormat('dd/MM/yyyy HH:mm').format(initialValue!)
              : DateFormat('dd/MM/yyyy').format(initialValue!)
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
              ? DateFormat('dd/MM/yyyy HH:mm').format(selectedDateTime)
              : DateFormat('dd/MM/yyyy').format(selectedDateTime);

          onDateTimeSelected(selectedDateTime);
        }
      },
    );
  }
}

