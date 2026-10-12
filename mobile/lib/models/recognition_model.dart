class HighConfidenceMatch {
  final int studentId;
  final String rollNumber;
  final String fullName;
  final double distance;
  final double confidence;

  HighConfidenceMatch({
    required this.studentId,
    required this.rollNumber,
    required this.fullName,
    required this.distance,
    required this.confidence,
  });

  factory HighConfidenceMatch.fromJson(Map<String, dynamic> json) {
    return HighConfidenceMatch(
      studentId: json['student_id'] as int? ?? 0,
      rollNumber: json['roll_number'] as String? ?? '',
      fullName: (json['full_name'] ?? json['name']) as String? ?? '',
      distance: (json['distance'] as num?)?.toDouble() ?? 0.0,
      confidence: (json['confidence'] ?? json['derived_score'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class CandidateStudent {
  final int studentId;
  final String rollNumber;
  final String fullName;
  final double distance;
  final double confidence;

  CandidateStudent({
    required this.studentId,
    required this.rollNumber,
    required this.fullName,
    required this.distance,
    required this.confidence,
  });

  factory CandidateStudent.fromJson(Map<String, dynamic> json) {
    return CandidateStudent(
      studentId: json['student_id'] as int? ?? 0,
      rollNumber: json['roll_number'] as String? ?? '',
      fullName: (json['full_name'] ?? json['name']) as String? ?? '',
      distance: (json['distance'] as num?)?.toDouble() ?? 0.0,
      confidence: (json['confidence'] ?? json['derived_score'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class UncertainMatch {
  final int faceIndex;
  final List<CandidateStudent> candidates;

  UncertainMatch({
    required this.faceIndex,
    required this.candidates,
  });

  factory UncertainMatch.fromJson(Map<String, dynamic> json) {
    final rawCandidates = json['candidates'] as List? ?? [];
    return UncertainMatch(
      faceIndex: json['face_index'] as int? ?? 0,
      candidates: rawCandidates
          .whereType<Map<String, dynamic>>()
          .map((c) => CandidateStudent.fromJson(c))
          .toList(),
    );
  }
}

class RecognitionResultModel {
  final int sessionId;
  final int facesDetected;
  final List<HighConfidenceMatch> highConfidenceMatches;
  final List<UncertainMatch> uncertainMatches;
  final int unknownFacesCount;

  RecognitionResultModel({
    required this.sessionId,
    required this.facesDetected,
    required this.highConfidenceMatches,
    required this.uncertainMatches,
    required this.unknownFacesCount,
  });

  factory RecognitionResultModel.fromJson(Map<String, dynamic> json) {
    List<HighConfidenceMatch> highList = [];
    List<UncertainMatch> uncertainList = [];
    int unknownCount = 0;

    // 1. If high_confidence_matches is provided as a list
    if (json['high_confidence_matches'] is List) {
      final rawHigh = json['high_confidence_matches'] as List;
      highList = rawHigh
          .whereType<Map<String, dynamic>>()
          .map((m) => HighConfidenceMatch.fromJson(m))
          .toList();
    }

    // 2. If uncertain_matches is provided as a list
    if (json['uncertain_matches'] is List) {
      final rawUncertain = json['uncertain_matches'] as List;
      uncertainList = rawUncertain
          .whereType<Map<String, dynamic>>()
          .map((u) => UncertainMatch.fromJson(u))
          .toList();
    }

    // 3. If unknown_faces is provided as a list or count
    if (json['unknown_faces'] is List) {
      unknownCount = (json['unknown_faces'] as List).length;
    } else if (json['unknown_faces'] is num) {
      unknownCount = (json['unknown_faces'] as num).toInt();
    }

    // 4. Fallback from results array if list fields were not present/empty
    if (json['results'] is List && (highList.isEmpty && uncertainList.isEmpty)) {
      final results = json['results'] as List;
      for (var r in results) {
        if (r is Map<String, dynamic>) {
          final status = r['status']?.toString();
          if (status == 'HIGH_CONFIDENCE') {
            highList.add(HighConfidenceMatch.fromJson(r));
          } else if (status == 'UNCERTAIN') {
            uncertainList.add(UncertainMatch.fromJson(r));
          } else if (status == 'UNKNOWN' && json['unknown_faces'] == null) {
            unknownCount++;
          }
        }
      }
    }

    final facesDetected = json['faces_detected'] as int? ??
        (highList.length + uncertainList.length + unknownCount);

    return RecognitionResultModel(
      sessionId: json['session_id'] as int? ?? 0,
      facesDetected: facesDetected,
      highConfidenceMatches: highList,
      uncertainMatches: uncertainList,
      unknownFacesCount: unknownCount,
    );
  }
}
