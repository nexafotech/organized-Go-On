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
    };
  }

  bool get isStudent => role == 'STUDENT';
  bool get isFaculty => role == 'FACULTY' || role == 'ADMIN';
  bool get isAdmin => role == 'ADMIN';
}
