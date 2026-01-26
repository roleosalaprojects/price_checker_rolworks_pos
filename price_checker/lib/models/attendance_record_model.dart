double parseDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}

class AttendanceRecord {
  final int id;
  final String uuid;
  final int employeeId;
  final int storeId;
  final DateTime date;
  final DateTime? timeIn;
  final DateTime? timeOut;
  final double hoursRendered;
  final String status;
  final String? remarks;
  final Employee? employee;
  final Store? store;

  AttendanceRecord({
    required this.id,
    required this.uuid,
    required this.employeeId,
    required this.storeId,
    required this.date,
    this.timeIn,
    this.timeOut,
    required this.hoursRendered,
    required this.status,
    this.remarks,
    this.employee,
    this.store,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    // Handle both user_id and employee_id from API
    final employeeData = json['user'] ?? json['employee'];

    return AttendanceRecord(
      id: json['id'],
      uuid: json['uuid'] ?? '',
      employeeId: json['user_id'] ?? json['employee_id'] ?? 0,
      storeId: json['store_id'] ?? 0,
      date: DateTime.parse(json['date']),
      timeIn: json['time_in'] != null ? DateTime.parse(json['time_in']) : null,
      timeOut:
          json['time_out'] != null ? DateTime.parse(json['time_out']) : null,
      hoursRendered: parseDouble(json['hours_rendered']),
      status: json['status'] ?? 'absent',
      remarks: json['remarks'],
      employee: employeeData != null ? Employee.fromJson(employeeData) : null,
      store: json['store'] != null ? Store.fromJson(json['store']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'uuid': uuid,
      'employee_id': employeeId,
      'store_id': storeId,
      'date': date.toIso8601String(),
      'time_in': timeIn?.toIso8601String(),
      'time_out': timeOut?.toIso8601String(),
      'hours_rendered': hoursRendered,
      'status': status,
      'remarks': remarks,
    };
  }

  bool get hasTimedIn => timeIn != null;
  bool get hasTimedOut => timeOut != null;
  bool get isComplete => hasTimedIn && hasTimedOut;
}

class Employee {
  final int id;
  final String? name;
  final String? firstName;
  final String? lastName;

  Employee({
    required this.id,
    this.name,
    this.firstName,
    this.lastName,
  });

  factory Employee.fromJson(Map<String, dynamic> json) {
    return Employee(
      id: json['id'],
      name: json['name'],
      firstName: json['first_name'],
      lastName: json['last_name'],
    );
  }

  String get displayName {
    if (name != null && name!.isNotEmpty) return name!;
    if (firstName != null || lastName != null) {
      return '${firstName ?? ''} ${lastName ?? ''}'.trim();
    }
    return 'Unknown';
  }
}

class Store {
  final int id;
  final String? name;

  Store({
    required this.id,
    this.name,
  });

  factory Store.fromJson(Map<String, dynamic> json) {
    return Store(
      id: json['id'],
      name: json['name'],
    );
  }
}

class AttendanceSummary {
  final int month;
  final int year;
  final int totalDaysPresent;
  final int totalDaysAbsent;
  final double totalHoursRendered;

  AttendanceSummary({
    required this.month,
    required this.year,
    required this.totalDaysPresent,
    required this.totalDaysAbsent,
    required this.totalHoursRendered,
  });

  factory AttendanceSummary.fromJson(Map<String, dynamic> json) {
    return AttendanceSummary(
      month: json['month'],
      year: json['year'],
      totalDaysPresent: json['total_days_present'] ?? 0,
      totalDaysAbsent: json['total_days_absent'] ?? 0,
      totalHoursRendered: parseDouble(json['total_hours_rendered']),
    );
  }
}
