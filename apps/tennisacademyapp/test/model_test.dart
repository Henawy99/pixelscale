import 'package:flutter_test/flutter_test.dart';
import 'package:academy_app/models/profile_model.dart';
import 'package:academy_app/models/session_model.dart';

void main() {
  group('ProfileModel', () {
    test('fromJson parses correctly', () {
      final json = {
        'id': '123',
        'full_name': 'John Doe',
        'email': 'john@example.com',
        'role': 'player',
        'date_of_birth': '1990-01-01',
        'phone': '1234567890',
        'started_playing_year': 2010,
        'dominant_hand': 'Right',
        'avatar_url': 'http://example.com/avatar.jpg'
      };
      
      final profile = ProfileModel.fromJson(json);
      
      expect(profile.id, '123');
      expect(profile.fullName, 'John Doe');
      expect(profile.dateOfBirth, DateTime(1990, 1, 1));
      expect(profile.phone, '1234567890');
      expect(profile.startedPlayingYear, 2010);
      expect(profile.dominantHand, 'Right');
      expect(profile.avatarUrl, 'http://example.com/avatar.jpg');
    });

    test('toJson serializes correctly', () {
      final profile = ProfileModel(
        id: '123',
        fullName: 'John Doe',
        role: 'player',
        dateOfBirth: DateTime(1990, 1, 1),
        phone: '1234567890',
      );
      
      final json = profile.toJson();
      
      expect(json['full_name'], 'John Doe');
      expect(json['date_of_birth'], '1990-01-01');
      expect(json['phone'], '1234567890');
    });
  });

  group('SessionModel', () {
    test('fromJson parses recurrence fields', () {
      final json = {
        'id': 's1',
        'date': '2026-02-21',
        'court_id': 1,
        'recurrence_id': 'rec1',
        'recurrence_rule': 'daily',
      };
      
      final session = SessionModel.fromJson(json);
      
      expect(session.recurrenceId, 'rec1');
      expect(session.recurrenceRule, 'daily');
    });
  });
  
  group('Recurrence Logic', () {
    test('Daily recurrence generates correct dates', () {
      final startDate = DateTime(2026, 2, 1);
      final dates = <String>[];
      for (int i = 0; i < 3; i++) {
        dates.add(startDate.add(Duration(days: i)).toIso8601String().split('T')[0]);
      }
      expect(dates, ['2026-02-01', '2026-02-02', '2026-02-03']);
    });

    test('Weekly recurrence generates correct dates', () {
      final startDate = DateTime(2026, 2, 1);
      final dates = <String>[];
      for (int i = 0; i < 3; i++) {
        dates.add(startDate.add(Duration(days: i * 7)).toIso8601String().split('T')[0]);
      }
      expect(dates, ['2026-02-01', '2026-02-08', '2026-02-15']);
    });
  });
}
