class HeadPoseModel {
  final double yaw;
  final double pitch;
  final double roll;

  const HeadPoseModel({
    required this.yaw,
    required this.pitch,
    required this.roll,
  });

  factory HeadPoseModel.fromJson(Map<String, dynamic> json) {
    return HeadPoseModel(
      yaw: (json['yaw'] as num?)?.toDouble() ?? 0.0,
      pitch: (json['pitch'] as num?)?.toDouble() ?? 0.0,
      roll: (json['roll'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'yaw': yaw,
        'pitch': pitch,
        'roll': roll,
      };
}

class FaceBoxModel {
  final int top;
  final int right;
  final int bottom;
  final int left;
  final int width;
  final int height;

  const FaceBoxModel({
    required this.top,
    required this.right,
    required this.bottom,
    required this.left,
    required this.width,
    required this.height,
  });

  factory FaceBoxModel.fromJson(Map<String, dynamic> json) {
    return FaceBoxModel(
      top: json['top'] as int? ?? 0,
      right: json['right'] as int? ?? 0,
      bottom: json['bottom'] as int? ?? 0,
      left: json['left'] as int? ?? 0,
      width: json['width'] as int? ?? 0,
      height: json['height'] as int? ?? 0,
    );
  }
}

class PoseValidationResultModel {
  final bool valid;
  final String status;
  final String message;
  final List<String> guidance;
  final String step;
  final HeadPoseModel? pose;
  final FaceBoxModel? faceBox;
  final double? confidence;
  final double? qualityScore;
  final String? lighting;
  final double? brightness;
  final double? blurScore;

  const PoseValidationResultModel({
    required this.valid,
    required this.status,
    required this.message,
    required this.guidance,
    required this.step,
    this.pose,
    this.faceBox,
    this.confidence,
    this.qualityScore,
    this.lighting,
    this.brightness,
    this.blurScore,
  });

  factory PoseValidationResultModel.fromJson(Map<String, dynamic> json) {
    final List<String> guidanceList = [];
    if (json['guidance'] is List) {
      for (var item in json['guidance']) {
        guidanceList.add(item.toString());
      }
    }

    return PoseValidationResultModel(
      valid: json['valid'] as bool? ?? false,
      status: json['status']?.toString() ?? 'UNKNOWN',
      message: json['message']?.toString() ?? '',
      guidance: guidanceList,
      step: json['step']?.toString() ?? 'FRONTAL',
      pose: json['pose'] is Map<String, dynamic>
          ? HeadPoseModel.fromJson(json['pose'])
          : null,
      faceBox: json['face_box'] is Map<String, dynamic>
          ? FaceBoxModel.fromJson(json['face_box'])
          : null,
      confidence: (json['confidence'] as num?)?.toDouble(),
      qualityScore: (json['quality_score'] as num?)?.toDouble(),
      lighting: json['lighting']?.toString(),
      brightness: (json['brightness'] as num?)?.toDouble(),
      blurScore: (json['blur_score'] as num?)?.toDouble(),
    );
  }

  bool get isReady => status == 'READY' && valid;
}

class EnrollmentStatusModel {
  final String status;
  final int templatesCount;
  final int requiredTemplates;
  final List<String> completedSteps;
  final String? nextStep;
  final String message;
  final int? studentId;
  final String? registerNumber;
  final String? fullName;

  const EnrollmentStatusModel({
    required this.status,
    required this.templatesCount,
    required this.requiredTemplates,
    required this.completedSteps,
    this.nextStep,
    required this.message,
    this.studentId,
    this.registerNumber,
    this.fullName,
  });

  factory EnrollmentStatusModel.fromJson(Map<String, dynamic> json) {
    final List<String> completed = [];
    if (json['completed_steps'] is List) {
      for (var s in json['completed_steps']) {
        completed.add(s.toString());
      }
    }

    return EnrollmentStatusModel(
      status: json['status']?.toString() ?? 'ENROLLMENT_INCOMPLETE',
      templatesCount: json['templates_count'] as int? ?? 0,
      requiredTemplates: json['required_templates'] as int? ?? 3,
      completedSteps: completed,
      nextStep: json['next_step']?.toString(),
      message: json['message']?.toString() ?? '',
      studentId: json['student_id'] as int?,
      registerNumber: json['register_number']?.toString(),
      fullName: json['full_name']?.toString(),
    );
  }

  bool get isFullyEnrolled => status == 'ENROLLED' && templatesCount >= 3;
  double get progress => (templatesCount / requiredTemplates).clamp(0.0, 1.0);
}
