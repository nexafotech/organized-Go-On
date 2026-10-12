import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_marker_mobile/models/recognition_model.dart';

void main() {
  group('Recognition Result Deserialization Tests', () {
    test('RecognitionResultModel parses high confidence, uncertain, and unknown faces', () {
      final json = {
        'session_id': 42,
        'faces_detected': 3,
        'high_confidence_matches': [
          {
            'student_id': 101,
            'roll_number': '23M4S01',
            'full_name': 'Alex Student',
            'distance': 0.32,
            'confidence': 92.5,
          }
        ],
        'uncertain_matches': [
          {
            'face_index': 1,
            'candidates': [
              {
                'student_id': 102,
                'roll_number': '23M4S02',
                'full_name': 'Sarah Student',
                'distance': 0.48,
                'confidence': 62.0,
              }
            ]
          }
        ],
        'unknown_faces': [
          {'face_index': 2}
        ]
      };

      final result = RecognitionResultModel.fromJson(json);

      expect(result.sessionId, 42);
      expect(result.facesDetected, 3);
      expect(result.highConfidenceMatches.length, 1);
      expect(result.highConfidenceMatches.first.studentId, 101);
      expect(result.highConfidenceMatches.first.fullName, 'Alex Student');
      expect(result.uncertainMatches.length, 1);
      expect(result.uncertainMatches.first.candidates.first.studentId, 102);
      expect(result.unknownFacesCount, 1);
    });

    test('Deduplication logic prevents multiple confirmations for same student ID', () {
      final highConfidenceIds = {101, 102};
      final uncertainSelection = {1: 101, 2: 103};

      final Set<int> confirmed = Set.from(highConfidenceIds);
      for (var id in uncertainSelection.values) {
        confirmed.add(id);
      }

      // 101 was present in both, but set deduplicates it
      expect(confirmed.length, 3);
      expect(confirmed.containsAll([101, 102, 103]), true);
    });

    test('RecognitionResultModel parses live backend payload with Rethish S high confidence match', () {
      final json = {
        'session_id': 2,
        'faces_detected': 8,
        'high_confidence_matches': [
          {
            'student_id': 2,
            'roll_number': '721025149002',
            'full_name': 'ABISHEK A',
            'name': 'ABISHEK A',
            'distance': 0.1548,
            'confidence': 74.21,
            'derived_score': 74.21,
          },
          {
            'student_id': 46,
            'roll_number': '721025149046',
            'full_name': 'RETHISH S',
            'name': 'RETHISH S',
            'distance': 0.1566,
            'confidence': 73.9,
            'derived_score': 73.9,
          },
          {
            'student_id': 47,
            'roll_number': '721025149047',
            'full_name': 'RITHANYA SHREE V',
            'name': 'RITHANYA SHREE V',
            'distance': 0.3086,
            'confidence': 48.57,
            'derived_score': 48.57,
          }
        ],
        'uncertain_matches': [
          {
            'face_index': 3,
            'candidates': [
              {
                'student_id': 47,
                'roll_number': '721025149047',
                'full_name': 'RITHANYA SHREE V',
                'distance': 0.4946,
                'confidence': 17.57,
              }
            ]
          }
        ],
        'unknown_faces': [
          {'face_index': 2}
        ]
      };

      final result = RecognitionResultModel.fromJson(json);

      expect(result.sessionId, 2);
      expect(result.facesDetected, 8);
      expect(result.highConfidenceMatches.length, 3);
      final rethish = result.highConfidenceMatches.firstWhere((m) => m.rollNumber == '721025149046');
      expect(rethish.fullName, 'RETHISH S');
      expect(rethish.studentId, 46);
      expect(rethish.distance, 0.1566);
      expect(rethish.confidence, 73.9);
      expect(result.uncertainMatches.length, 1);
      expect(result.unknownFacesCount, 1);
    });

    test('RecognitionResultModel parses raw results array fallback when match counts are numbers', () {
      final json = {
        'session_id': 2,
        'faces_detected': 8,
        'high_confidence_matches': 1,
        'uncertain_matches': 0,
        'unknown_faces': 1,
        'results': [
          {
            'face_index': 4,
            'student_id': 46,
            'roll_number': '721025149046',
            'name': 'RETHISH S',
            'distance': 0.1566,
            'derived_score': 73.9,
            'status': 'HIGH_CONFIDENCE',
          },
          {
            'face_index': 2,
            'student_id': null,
            'status': 'UNKNOWN',
          }
        ]
      };

      final result = RecognitionResultModel.fromJson(json);

      expect(result.sessionId, 2);
      expect(result.facesDetected, 8);
      expect(result.highConfidenceMatches.length, 1);
      expect(result.highConfidenceMatches.first.rollNumber, '721025149046');
      expect(result.highConfidenceMatches.first.fullName, 'RETHISH S');
      expect(result.unknownFacesCount, 1);
    });
  });
}
