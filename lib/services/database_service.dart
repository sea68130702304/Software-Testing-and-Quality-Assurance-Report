import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';

class DatabaseService {
  final FirebaseFirestore _db;

  DatabaseService({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  // ── Dashboard (per-user) ────────────────────────────────────────────────

  DocumentReference _dashboardDoc(String uid) =>
      _db.collection('users').doc(uid).collection('data').doc('dashboard');

  Future<Map<String, dynamic>?> loadDashboard(String uid) async {
    final doc = await _dashboardDoc(uid).get();
    if (!doc.exists) return null;
    return doc.data() as Map<String, dynamic>;
  }

  Future<void> saveDashboard(String uid, Map<String, dynamic> data) =>
      _dashboardDoc(uid).set(data);

  // ── Objectives ──────────────────────────────────────────────────────────

  CollectionReference get _objectives => _db.collection('objectives');

  Stream<List<Objective>> objectivesStream() => _objectives
      .orderBy('title')
      .snapshots()
      .map((s) => s.docs.map(Objective.fromDoc).toList());

  Future<void> createObjective(Objective objective) =>
      _objectives.add(objective.toMap());

  Future<void> deleteObjective(String objectiveId) =>
      _objectives.doc(objectiveId).delete();

  // ── Key Results ─────────────────────────────────────────────────────────

  CollectionReference _keyResults(String objectiveId) =>
      _objectives.doc(objectiveId).collection('keyResults');

  Stream<List<KeyResult>> keyResultsStream(String objectiveId) =>
      _keyResults(objectiveId)
          .orderBy('title')
          .snapshots()
          .map((s) => s.docs.map(KeyResult.fromDoc).toList());

  Future<void> createKeyResult({
    required String objectiveId,
    required KeyResult keyResult,
  }) =>
      _keyResults(objectiveId).add(keyResult.toMap());

  Future<void> updateKeyResultProgress({
    required String objectiveId,
    required String keyResultId,
    required double progress,
  }) =>
      _keyResults(objectiveId).doc(keyResultId).update({'progress': progress});

  Future<void> deleteKeyResult({
    required String objectiveId,
    required String keyResultId,
  }) =>
      _keyResults(objectiveId).doc(keyResultId).delete();

  // ── Tasks ───────────────────────────────────────────────────────────────
  // Stored under users/{uid}/objectives/{objectiveId}/keyResults/{krId}/tasks
  // so standard auth-based Firestore rules allow the write.

  CollectionReference _tasks(
          String uid, String objectiveId, String keyResultId) =>
      _db
          .collection('users')
          .doc(uid)
          .collection('objectives')
          .doc(objectiveId)
          .collection('keyResults')
          .doc(keyResultId)
          .collection('tasks');

  Stream<List<Task>> tasksStream({
    required String uid,
    required String objectiveId,
    required String keyResultId,
  }) =>
      _tasks(uid, objectiveId, keyResultId)
          .orderBy('createdAt')
          .snapshots()
          .map((s) => s.docs.map(Task.fromDoc).toList());

  Future<void> createTask({
    required String uid,
    required String objectiveId,
    required Task task,
  }) =>
      _tasks(uid, objectiveId, task.keyResultId).add(task.toMap());

  Future<void> updateTask({
    required String uid,
    required String objectiveId,
    required Task task,
  }) =>
      _tasks(uid, objectiveId, task.keyResultId)
          .doc(task.id)
          .update(task.toMap()..['updatedAt'] = FieldValue.serverTimestamp());

  Future<void> deleteTask({
    required String uid,
    required String objectiveId,
    required String keyResultId,
    required String taskId,
  }) =>
      _tasks(uid, objectiveId, keyResultId).doc(taskId).delete();
}
