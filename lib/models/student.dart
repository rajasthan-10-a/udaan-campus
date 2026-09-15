// Student Model
class Student {
  final String id;
  final String name;
  final String email;
  final String rollNumber;
  final String department;
  final String semester;
  final double cgpa;
  final String? profileImage;
  final String? classId;
  final String? section;
  final String? parentName;
  final String? parentPhone;
  final String? fatherName;
  final String? motherName;
  final String? srNumber;
  final String? dateOfBirth;
  final String? dateOfBirthWords;
  final bool rte;
  final double? fees;
  final String? fatherOccupation;
  final String? qrToken;
  final bool active;

  Student({
    required this.id,
    required this.name,
    required this.email,
    required this.rollNumber,
    required this.department,
    required this.semester,
    required this.cgpa,
    this.profileImage,
    this.classId,
    this.section,
    this.parentName,
    this.parentPhone,
    this.fatherName,
    this.motherName,
    this.srNumber,
    this.dateOfBirth,
    this.dateOfBirthWords,
    this.rte = false,
    this.fees,
    this.fatherOccupation,
    this.qrToken,
    this.active = true,
  });

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      rollNumber: json['rollNumber'] ?? '',
      department: json['department'] ?? '',
      semester: json['semester'] ?? '',
      cgpa: (json['cgpa'] ?? 0).toDouble(),
      profileImage: json['profileImage'],
      classId: json['classId'] as String?,
      section: json['section'] as String?,
      parentName: json['parentName'] as String?,
      parentPhone: json['parentPhone'] as String?,
      fatherName: json['fatherName'] as String? ?? json['parentName'] as String?,
      motherName: json['motherName'] as String?,
      srNumber: json['srNumber'] as String?,
      dateOfBirth: json['dateOfBirth'] as String?,
      dateOfBirthWords: json['dateOfBirthWords'] as String?,
      rte: json['rte'] == true,
      fees: json['fees'] is num ? (json['fees'] as num).toDouble() : double.tryParse(json['fees']?.toString() ?? ''),
      fatherOccupation: json['fatherOccupation'] as String?,
      qrToken: json['qrToken'] as String?,
      active: json['active'] is bool ? json['active'] as bool : true,
    );
  }

  Map<String, dynamic> toJson() {
    final data = {
      'id': id,
      'name': name,
      'email': email,
      'rollNumber': rollNumber,
      'department': department,
      'semester': semester,
      'cgpa': cgpa,
      'profileImage': profileImage,
    };
    if (classId != null) data['classId'] = classId;
    if (section != null) data['section'] = section;
    if (parentName != null) data['parentName'] = parentName;
    if (parentPhone != null) data['parentPhone'] = parentPhone;
    if (fatherName != null) data['fatherName'] = fatherName;
    if (motherName != null) data['motherName'] = motherName;
    if (srNumber != null) data['srNumber'] = srNumber;
    if (dateOfBirth != null) data['dateOfBirth'] = dateOfBirth;
    if (dateOfBirthWords != null) data['dateOfBirthWords'] = dateOfBirthWords;
    data['rte'] = rte;
    if (fees != null) data['fees'] = fees;
    if (fatherOccupation != null) data['fatherOccupation'] = fatherOccupation;
    if (qrToken != null) data['qrToken'] = qrToken;
    data['active'] = active;
    return data;
  }
}

// Attendance Model
class Attendance {
  final String courseId;
  final String courseName;
  final int totalClasses;
  final int classesAttended;
  final double percentage;

  Attendance({
    required this.courseId,
    required this.courseName,
    required this.totalClasses,
    required this.classesAttended,
    required this.percentage,
  });

  factory Attendance.fromJson(Map<String, dynamic> json) {
    return Attendance(
      courseId: json['courseId'] ?? '',
      courseName: json['courseName'] ?? '',
      totalClasses: json['totalClasses'] ?? 0,
      classesAttended: json['classesAttended'] ?? 0,
      percentage: (json['percentage'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'courseId': courseId,
      'courseName': courseName,
      'totalClasses': totalClasses,
      'classesAttended': classesAttended,
      'percentage': percentage,
    };
  }
}

// Course Model
class Course {
  final String id;
  final String name;
  final String code;
  final String instructor;
  final double credits;
  final String schedule;

  Course({
    required this.id,
    required this.name,
    required this.code,
    required this.instructor,
    required this.credits,
    required this.schedule,
  });

  factory Course.fromJson(Map<String, dynamic> json) {
    return Course(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      code: json['code'] ?? '',
      instructor: json['instructor'] ?? '',
      credits: (json['credits'] ?? 0).toDouble(),
      schedule: json['schedule'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'instructor': instructor,
      'credits': credits,
      'schedule': schedule,
    };
  }
}
