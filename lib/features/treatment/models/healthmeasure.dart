// lib/features/treatment/models/healthmeasure.dart

enum HealthUnit {
  kilogram,
  pound,
  bpm,
  mmHg,
  percent,
  celsius,
  fahrenheit,
  hour,
  minute,
  none,
}

extension HealthUnitExtension on HealthUnit {
  String get symbol {
    switch (this) {
      case HealthUnit.kilogram: return 'kg';
      case HealthUnit.pound: return 'lb';
      case HealthUnit.bpm: return 'bpm';
      case HealthUnit.mmHg: return 'mmHg';
      case HealthUnit.percent: return '%';
      case HealthUnit.celsius: return '°C';
      case HealthUnit.fahrenheit: return '°F';
      case HealthUnit.hour: return 'h';
      case HealthUnit.minute: return 'min';
      case HealthUnit.none: return '';
    }
  }

  static HealthUnit fromSymbol(String symbol) {
    switch (symbol) {
      case 'kg': return HealthUnit.kilogram;
      case 'lb': return HealthUnit.pound;
      case 'bpm': return HealthUnit.bpm;
      case 'mmHg': return HealthUnit.mmHg;
      case '%': return HealthUnit.percent;
      case '°C': return HealthUnit.celsius;
      case '°F': return HealthUnit.fahrenheit;
      case 'h': return HealthUnit.hour;
      case 'min': return HealthUnit.minute;
      default: return HealthUnit.none;
    }
  }
}

enum HealthMeasureType {
  weight,
  bloodPressure,
  heartRate,
  spo2,
  temperature,
  sleep,
  noteOnly,
}

class HealthMeasure {
  final String id;
  final String cycleId;
  final HealthMeasureType type;
  final double? weight;
  final int? heartRate;
  final double? spo2;
  final double? temperature;
  final int? systolicBP;
  final int? diastolicBP;
  final DateTime date;
  final HealthUnit unit;
  final String? note;

  HealthMeasure({
    required this.id,
    required this.cycleId,
    required this.type,
    required this.date,
    required this.unit,
    this.weight,
    this.heartRate,
    this.spo2,
    this.temperature,
    this.systolicBP,
    this.diastolicBP,
    this.note,
  });

  HealthMeasure copyWith({
    String? id,
    String? cycleId,
    HealthMeasureType? type,
    double? weight,
    int? heartRate,
    double? spo2,
    double? temperature,
    int? systolicBP,
    int? diastolicBP,
    DateTime? date,
    HealthUnit? unit,
    String? note,
  }) {
    return HealthMeasure(
      id: id ?? this.id,
      cycleId: cycleId ?? this.cycleId,
      type: type ?? this.type,
      weight: weight ?? this.weight,
      heartRate: heartRate ?? this.heartRate,
      spo2: spo2 ?? this.spo2,
      temperature: temperature ?? this.temperature,
      systolicBP: systolicBP ?? this.systolicBP,
      diastolicBP: diastolicBP ?? this.diastolicBP,
      date: date ?? this.date,
      unit: unit ?? this.unit,
      note: note ?? this.note,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'cycleId': cycleId,
      'type': type.name,
      'weight': weight,
      'heartRate': heartRate,
      'spo2': spo2,
      'temperature': temperature,
      'systolicBP': systolicBP,
      'diastolicBP': diastolicBP,
      'date': date.toIso8601String(),
      'unit': unit.symbol,
      'note': note,
    };
  }

  factory HealthMeasure.fromMap(Map<String, dynamic> map) {
    return HealthMeasure(
      id: map['id'],
      cycleId: map['cycleId'],
      type: HealthMeasureType.values.firstWhere(
            (e) => e.name == map['type'],
        orElse: () => HealthMeasureType.noteOnly,
      ),
      weight: map['weight'] != null ? (map['weight'] as num).toDouble() : null,
      heartRate: map['heartRate'],
      spo2: map['spo2'] != null ? (map['spo2'] as num).toDouble() : null,
      temperature: map['temperature'] != null ? (map['temperature'] as num).toDouble() : null,
      systolicBP: map['systolicBP'],
      diastolicBP: map['diastolicBP'],
      date: DateTime.parse(map['date']),
      unit: HealthUnitExtension.fromSymbol(map['unit'] ?? ''),
      note: map['note'],
    );
  }

  @override
  String toString() {
    return 'HealthMeasure(id: $id, cycleId: $cycleId, type: $type, unit: ${unit.symbol}, weight: $weight, heartRate: $heartRate, spo2: $spo2, temperature: $temperature, systolicBP: $systolicBP, diastolicBP: $diastolicBP, date: $date, note: $note)';
  }
}




