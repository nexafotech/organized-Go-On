class UserModel {
  final int id;
  final String username;
  final String email;
  final String role; // "STUDENT", "FACULTY", "ADMIN"
  final bool isActive;
  final String fullName;
  final int? facultyProfileId;
  final bool forcePasswordChange;
  final bool isClassAdvisor;
  final int? advisedClassId;
  final String? advisedClassName;
  final String? department;
  final String? employeeId;
  final String? avatarId;
  final String? phone;

  UserModel({
    required this.id,
    required this.username,
    required this.email,
    required this.role,
    required this.isActive,
    required this.fullName,
    this.facultyProfileId,
    this.forcePasswordChange = false,
    this.isClassAdvisor = false,
    this.advisedClassId,
    this.advisedClassName,
    this.department,
    this.employeeId,
    this.avatarId,
    this.phone,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as int? ?? 0,
      username: json['username'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: json['role'] as String? ?? '',
      isActive: json['is_active'] as bool? ?? true,
      fullName: json['full_name'] as String? ?? '',
      facultyProfileId: json['faculty_profile_id'] as int?,
      forcePasswordChange: json['force_password_change'] as bool? ?? false,
      isClassAdvisor: json['is_class_advisor'] as bool? ?? false,
      advisedClassId: json['advised_class_id'] as int?,
      advisedClassName: json['advised_class_name'] as String?,
      department: json['department'] as String?,
      employeeId: json['employee_id'] as String?,
      avatarId: json['avatar_id'] as String?,
      phone: json['phone'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'role': role,
      'is_active': isActive,
      'full_name': fullName,
      'faculty_profile_id': facultyProfileId,
      'force_password_change': forcePasswordChange,
      'is_class_advisor': isClassAdvisor,
      'advised_class_id': advisedClassId,
      'advised_class_name': advisedClassName,
      'department': department,
      'employee_id': employeeId,
      'avatar_id': avatarId,
      'phone': phone,
    };
  }

  UserModel copyWith({
    int? id,
    String? username,
    String? email,
    String? role,
    bool? isActive,
    String? fullName,
    int? facultyProfileId,
    bool? forcePasswordChange,
    bool? isClassAdvisor,
    int? advisedClassId,
    String? advisedClassName,
    String? department,
    String? employeeId,
    String? avatarId,
    String? phone,
  }) {
    return UserModel(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      fullName: fullName ?? this.fullName,
      facultyProfileId: facultyProfileId ?? this.facultyProfileId,
      forcePasswordChange: forcePasswordChange ?? this.forcePasswordChange,
      isClassAdvisor: isClassAdvisor ?? this.isClassAdvisor,
      advisedClassId: advisedClassId ?? this.advisedClassId,
      advisedClassName: advisedClassName ?? this.advisedClassName,
      department: department ?? this.department,
      employeeId: employeeId ?? this.employeeId,
      avatarId: avatarId ?? this.avatarId,
      phone: phone ?? this.phone,
    );
  }

  bool get isStudent => role == 'STUDENT';
  bool get isFaculty => role == 'FACULTY' || role == 'ADMIN';
  bool get isAdmin => role == 'ADMIN';
}
