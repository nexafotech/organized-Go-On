class AdminStudentBioModel {
  final int studentId;
  final String rollNumber;
  final String fullName;
  final String? className;
  final bool enrolled;
  final int templateCount;
  final String? modelName;
  final String? detectorName;
  final String? lastEnrollmentAt;

  AdminStudentBioModel({
    required this.studentId,
    required this.rollNumber,
    required this.fullName,
    this.className,
    required this.enrolled,
    required this.templateCount,
    this.modelName,
    this.detectorName,
    this.lastEnrollmentAt,
  });

  factory AdminStudentBioModel.fromJson(Map<String, dynamic> json) {
    return AdminStudentBioModel(
      studentId: json['student_id'] as int? ?? 0,
      rollNumber: json['roll_number']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      className: json['class_name']?.toString(),
      enrolled: json['enrolled'] as bool? ?? false,
      templateCount: json['template_count'] as int? ?? 0,
      modelName: json['model_name']?.toString(),
      detectorName: json['detector_name']?.toString(),
      lastEnrollmentAt: json['last_enrollment_at']?.toString(),
    );
  }
}

class AdminBioOverviewModel {
  final int totalStudents;
  final int enrolledCount;
  final int pendingCount;
  final String modelName;
  final String detectorName;
  final int dimension;

  AdminBioOverviewModel({
    required this.totalStudents,
    required this.enrolledCount,
    required this.pendingCount,
    required this.modelName,
    required this.detectorName,
    required this.dimension,
  });

  factory AdminBioOverviewModel.fromJson(Map<String, dynamic> json) {
    return AdminBioOverviewModel(
      totalStudents: json['total_students'] as int? ?? 0,
      enrolledCount: json['enrolled_count'] as int? ?? 0,
      pendingCount: json['pending_count'] as int? ?? 0,
      modelName: json['model_name']?.toString() ?? 'dlib_resnet',
      detectorName: json['detector_name']?.toString() ?? 'dlib_hog',
      dimension: json['dimension'] as int? ?? 128,
    );
  }
}

class AdminStudentBioDetailModel {
  final int studentId;
  final String fullName;
  final String rollNumber;
  final String? className;
  final bool enrolled;
  final int templateCount;
  final int requiredTemplates;
  final String? lastEnrollmentTime;

  AdminStudentBioDetailModel({
    required this.studentId,
    required this.fullName,
    required this.rollNumber,
    this.className,
    required this.enrolled,
    required this.templateCount,
    required this.requiredTemplates,
    this.lastEnrollmentTime,
  });

  factory AdminStudentBioDetailModel.fromJson(Map<String, dynamic> json) {
    return AdminStudentBioDetailModel(
      studentId: json['student_id'] as int? ?? 0,
      fullName: json['full_name']?.toString() ?? '',
      rollNumber: json['roll_number']?.toString() ?? '',
      className: json['class_name']?.toString(),
      enrolled: json['enrolled'] as bool? ?? false,
      templateCount: json['template_count'] as int? ?? 0,
      requiredTemplates: json['required_templates'] as int? ?? 3,
      lastEnrollmentTime: json['last_enrollment_time']?.toString(),
    );
  }
}

// Phase 7.8: Canonical Student Face Dataset Models
class StudentPhotoItemModel {
  final int embeddingId;
  final String filename;
  final String imagePath;
  final String? createdAt;
  final double? qualityScore;

  StudentPhotoItemModel({
    required this.embeddingId,
    required this.filename,
    required this.imagePath,
    this.createdAt,
    this.qualityScore,
  });

  factory StudentPhotoItemModel.fromJson(Map<String, dynamic> json) {
    return StudentPhotoItemModel(
      embeddingId: json['embedding_id'] as int? ?? 0,
      filename: json['filename']?.toString() ?? '',
      imagePath: json['image_path']?.toString() ?? '',
      createdAt: json['created_at']?.toString(),
      qualityScore: (json['quality_score'] as num?)?.toDouble(),
    );
  }
}

class StudentDatasetViewModel {
  final int studentId;
  final String rollNumber;
  final String fullName;
  final String? className;
  final bool enrolled;
  final int photoCount;
  final int templateCount;
  final List<StudentPhotoItemModel> photos;

  StudentDatasetViewModel({
    required this.studentId,
    required this.rollNumber,
    required this.fullName,
    this.className,
    required this.enrolled,
    required this.photoCount,
    required this.templateCount,
    required this.photos,
  });

  factory StudentDatasetViewModel.fromJson(Map<String, dynamic> json) {
    final rawPhotos = json['photos'] as List? ?? [];
    return StudentDatasetViewModel(
      studentId: json['student_id'] as int? ?? 0,
      rollNumber: json['roll_number']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      className: json['class_name']?.toString(),
      enrolled: json['enrolled'] as bool? ?? false,
      photoCount: json['photo_count'] as int? ?? 0,
      templateCount: json['template_count'] as int? ?? 0,
      photos: rawPhotos
          .map((p) => StudentPhotoItemModel.fromJson(Map<String, dynamic>.from(p as Map)))
          .toList(),
    );
  }
}

class MultiPhotoResultItemModel {
  final String filename;
  final String status;
  final String? reason;
  final int facesDetected;
  final int? embeddingId;
  final String? savedPath;

  MultiPhotoResultItemModel({
    required this.filename,
    required this.status,
    this.reason,
    required this.facesDetected,
    this.embeddingId,
    this.savedPath,
  });

  factory MultiPhotoResultItemModel.fromJson(Map<String, dynamic> json) {
    return MultiPhotoResultItemModel(
      filename: json['filename']?.toString() ?? '',
      status: json['status']?.toString() ?? 'UNKNOWN',
      reason: json['reason']?.toString(),
      facesDetected: json['faces_detected'] as int? ?? 0,
      embeddingId: json['embedding_id'] as int?,
      savedPath: json['saved_path']?.toString(),
    );
  }
}

class MultiPhotoEnrollResponseModel {
  final int studentId;
  final String rollNumber;
  final String fullName;
  final int totalFiles;
  final int validEnrolled;
  final int rejected;
  final int replacedOldCount;
  final String message;
  final List<MultiPhotoResultItemModel> items;

  MultiPhotoEnrollResponseModel({
    required this.studentId,
    required this.rollNumber,
    required this.fullName,
    required this.totalFiles,
    required this.validEnrolled,
    required this.rejected,
    required this.replacedOldCount,
    required this.message,
    required this.items,
  });

  factory MultiPhotoEnrollResponseModel.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List? ?? [];
    return MultiPhotoEnrollResponseModel(
      studentId: json['student_id'] as int? ?? 0,
      rollNumber: json['roll_number']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      totalFiles: json['total_files'] as int? ?? 0,
      validEnrolled: json['valid_enrolled'] as int? ?? 0,
      rejected: json['rejected'] as int? ?? 0,
      replacedOldCount: json['replaced_old_count'] as int? ?? 0,
      message: json['message']?.toString() ?? '',
      items: rawItems
          .map((i) => MultiPhotoResultItemModel.fromJson(Map<String, dynamic>.from(i as Map)))
          .toList(),
    );
  }
}
