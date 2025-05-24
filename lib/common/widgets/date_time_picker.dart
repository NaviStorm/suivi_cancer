import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'custom_text_field.dart';
import 'package:suivi_cancer/utils/fctDate.dart';

import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'custom_text_field.dart';
import 'package:suivi_cancer/utils/fctDate.dart';

class DateTimePicker extends StatelessWidget {
  final String label;
  final DateTime? initialValue;
  final Function(DateTime) onDateTimeSelected;
  final bool showTime;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final SelectableDayPredicate? selectableDayPredicate; // Paramètre ajouté
  final String? Function(DateTime?)? validator;

  const DateTimePicker({
    super.key,
    required this.label,
    this.initialValue,
    required this.onDateTimeSelected,
    this.showTime = true,
    this.firstDate,
    this.lastDate,
    this.selectableDayPredicate, // Paramètre ajouté
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
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

        // Gérer le cas où la date initiale ne respecte pas le selectableDayPredicate
        DateTime? validInitialDate = initialValue;
        if (selectableDayPredicate != null && validInitialDate != null) {
          if (!selectableDayPredicate!(validInitialDate)) {
            // Trouver la prochaine date valide
            validInitialDate = _findNextValidDate(validInitialDate, selectableDayPredicate!);
          }
        }

        final DateTime? pickedDate = await showDatePicker(
          context: context,
          initialDate: validInitialDate ?? now,
          firstDate: firstDate ?? DateTime(now.year - 5),
          lastDate: lastDate ?? DateTime(now.year + 5),
          selectableDayPredicate: selectableDayPredicate, // Utiliser le paramètre ici
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

  // Fonction helper pour trouver la prochaine date valide
  DateTime _findNextValidDate(DateTime startDate, SelectableDayPredicate predicate) {
    DateTime currentDate = startDate;
    int attempts = 0;
    const maxAttempts = 365; // Éviter une boucle infinie

    while (attempts < maxAttempts) {
      if (predicate(currentDate)) {
        return currentDate;
      }
      currentDate = currentDate.add(Duration(days: 1));
      attempts++;
    }

    // Si aucune date valide n'est trouvée, retourner la date originale
    return startDate;
  }
}
