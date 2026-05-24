import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:okr_application_1/models/models.dart';

void main() {
  // ── TaskStatus ────────────────────────────────────────────────────────────

  group('TaskStatus', () {
    test('todo label', () => expect(TaskStatus.todo.label, 'To Do'));
    test('inProgress label', () => expect(TaskStatus.inProgress.label, 'In Progress'));
    test('done label', () => expect(TaskStatus.done.label, 'Done'));
  });

  // ── Task ──────────────────────────────────────────────────────────────────

  group('Task', () {
    late Task base;

    setUp(() {
      base = Task(
        id: 'task1',
        keyResultId: 'kr1',
        title: 'Write unit tests',
        completionPercentage: 50,
        status: TaskStatus.inProgress,
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 2),
      );
    });

    group('copyWith', () {
      test('returns new instance with updated fields', () {
        final updated = base.copyWith(title: 'Updated title', completionPercentage: 100);
        expect(updated.title, 'Updated title');
        expect(updated.completionPercentage, 100);
      });

      test('does not mutate the original instance', () {
        base.copyWith(title: 'Changed');
        expect(base.title, 'Write unit tests');
      });

      test('preserves untouched fields', () {
        final updated = base.copyWith(title: 'New');
        expect(updated.keyResultId, base.keyResultId);
        expect(updated.status, base.status);
        expect(updated.createdAt, base.createdAt);
        expect(updated.dueDate, isNull);
      });
    });

    group('isOverdue', () {
      test('true when due date is in the past and status is not done', () {
        final t = base.copyWith(dueDate: DateTime(2000, 1, 1), status: TaskStatus.inProgress);
        expect(t.isOverdue, isTrue);
      });

      test('false when due date is in the past but status is done', () {
        final t = base.copyWith(dueDate: DateTime(2000, 1, 1), status: TaskStatus.done);
        expect(t.isOverdue, isFalse);
      });

      test('false when no due date', () {
        expect(base.isOverdue, isFalse);
      });

      test('false when due date is in the future', () {
        final t = base.copyWith(dueDate: DateTime(2099, 12, 31));
        expect(t.isOverdue, isFalse);
      });
    });

    group('toMap / fromDoc roundtrip', () {
      test('preserves all fields', () async {
        final fakeFs = FakeFirebaseFirestore();
        final ref = fakeFs.collection('tasks').doc('task1');
        await ref.set(base.toMap());

        final doc = await ref.get();
        final restored = Task.fromDoc(doc);

        expect(restored.title, base.title);
        expect(restored.keyResultId, base.keyResultId);
        expect(restored.completionPercentage, base.completionPercentage);
        expect(restored.status, base.status);
        expect(restored.dueDate, isNull);
      });

      test('fromDoc uses default values for missing fields', () async {
        final fakeFs = FakeFirebaseFirestore();
        final ref = fakeFs.collection('tasks').doc('minimal');
        await ref.set({'title': 'Minimal task'});

        final task = Task.fromDoc(await ref.get());

        expect(task.title, 'Minimal task');
        expect(task.completionPercentage, 0);
        expect(task.status, TaskStatus.todo);
        expect(task.keyResultId, '');
      });

      test('unknown status string falls back to todo', () async {
        final fakeFs = FakeFirebaseFirestore();
        final ref = fakeFs.collection('tasks').doc('badstatus');
        await ref.set({'title': 'X', 'status': 'INVALID_STATUS'});

        final task = Task.fromDoc(await ref.get());
        expect(task.status, TaskStatus.todo);
      });

      test('preserves optional dueDate when set', () async {
        final due = DateTime(2025, 6, 30);
        final withDue = base.copyWith(dueDate: due);

        final fakeFs = FakeFirebaseFirestore();
        final ref = fakeFs.collection('tasks').doc('duetask');
        await ref.set(withDue.toMap());

        final restored = Task.fromDoc(await ref.get());
        expect(restored.dueDate!.year, due.year);
        expect(restored.dueDate!.month, due.month);
        expect(restored.dueDate!.day, due.day);
      });
    });

    test('toMap does not include the document id field', () {
      final map = base.toMap();
      expect(map.containsKey('id'), isFalse);
    });

    test('toMap serialises status as its name string', () {
      expect(base.toMap()['status'], 'inProgress');
    });

    test('toMap uses Timestamp for date fields', () {
      final map = base.toMap();
      expect(map['createdAt'], isA<Timestamp>());
      expect(map['updatedAt'], isA<Timestamp>());
    });
  });

  // ── KeyResult ─────────────────────────────────────────────────────────────

  group('KeyResult', () {
    const kr = KeyResult(
      id: 'kr1',
      title: 'Increase coverage',
      description: 'Reach 80% test coverage',
      progress: 0.6,
    );

    group('toMap / fromDoc roundtrip', () {
      test('preserves all fields', () async {
        final fakeFs = FakeFirebaseFirestore();
        final ref = fakeFs.collection('keyResults').doc('kr1');
        await ref.set(kr.toMap());

        final restored = KeyResult.fromDoc(await ref.get());
        expect(restored.title, kr.title);
        expect(restored.description, kr.description);
        expect(restored.progress, kr.progress);
        expect(restored.dueDate, isNull);
      });

      test('fromDoc uses defaults for missing fields', () async {
        final fakeFs = FakeFirebaseFirestore();
        final ref = fakeFs.collection('keyResults').doc('minimal');
        await ref.set({'title': 'Minimal KR'});

        final restored = KeyResult.fromDoc(await ref.get());
        expect(restored.title, 'Minimal KR');
        expect(restored.description, '');
        expect(restored.progress, 0.0);
        expect(restored.dueDate, isNull);
      });

      test('progress stored as double can be read back without precision loss', () async {
        const precise = KeyResult(id: 'x', title: 'x', progress: 0.333);
        final fakeFs = FakeFirebaseFirestore();
        final ref = fakeFs.collection('keyResults').doc('precise');
        await ref.set(precise.toMap());

        final restored = KeyResult.fromDoc(await ref.get());
        expect(restored.progress, closeTo(0.333, 0.001));
      });
    });
  });

  // ── Objective ─────────────────────────────────────────────────────────────

  group('Objective', () {
    const obj = Objective(
      id: 'obj1',
      title: 'Ship v1.0',
      description: 'Complete and release the first version',
    );

    test('toMap / fromDoc roundtrip preserves all fields', () async {
      final fakeFs = FakeFirebaseFirestore();
      final ref = fakeFs.collection('objectives').doc('obj1');
      await ref.set(obj.toMap());

      final restored = Objective.fromDoc(await ref.get());
      expect(restored.title, obj.title);
      expect(restored.description, obj.description);
    });

    test('fromDoc uses empty string for missing description', () async {
      final fakeFs = FakeFirebaseFirestore();
      final ref = fakeFs.collection('objectives').doc('nodesc');
      await ref.set({'title': 'No desc objective'});

      final restored = Objective.fromDoc(await ref.get());
      expect(restored.description, '');
    });

    test('toMap does not include the document id field', () {
      expect(obj.toMap().containsKey('id'), isFalse);
    });
  });
}
