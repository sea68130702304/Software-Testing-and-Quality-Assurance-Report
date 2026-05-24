import 'package:cloud_firestore/cloud_firestore.dart';

// ── TaskStatus ────────────────────────────────────────────────────────────────

enum TaskStatus {
  todo,
  inProgress,
  done;

  String get label {
    switch (this) {
      case TaskStatus.todo:
        return 'To Do';
      case TaskStatus.inProgress:
        return 'In Progress';
      case TaskStatus.done:
        return 'Done';
    }
  }
}

// ── Task ──────────────────────────────────────────────────────────────────────

class Task {
  const Task({
    required this.id,
    required this.keyResultId,
    required this.title,
    required this.completionPercentage,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.dueDate,
  });

  final String id;
  final String keyResultId;
  final String title;
  final int completionPercentage;
  final TaskStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? dueDate;

  bool get isOverdue =>
      dueDate != null &&
      dueDate!.isBefore(DateTime.now()) &&
      status != TaskStatus.done;

  Task copyWith({
    String? id,
    String? keyResultId,
    String? title,
    int? completionPercentage,
    TaskStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? dueDate,
  }) {
    return Task(
      id: id ?? this.id,
      keyResultId: keyResultId ?? this.keyResultId,
      title: title ?? this.title,
      completionPercentage: completionPercentage ?? this.completionPercentage,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      dueDate: dueDate ?? this.dueDate,
    );
  }

  Map<String, dynamic> toMap() => {
        'keyResultId': keyResultId,
        'title': title,
        'completionPercentage': completionPercentage,
        'status': status.name,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
        'dueDate': dueDate != null ? Timestamp.fromDate(dueDate!) : null,
      };

  factory Task.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Task(
      id: doc.id,
      keyResultId: data['keyResultId'] as String? ?? '',
      title: data['title'] as String? ?? '',
      completionPercentage: data['completionPercentage'] as int? ?? 0,
      status: TaskStatus.values.firstWhere(
        (s) => s.name == data['status'],
        orElse: () => TaskStatus.todo,
      ),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      dueDate: (data['dueDate'] as Timestamp?)?.toDate(),
    );
  }
}

// ── KeyResult ─────────────────────────────────────────────────────────────────

class KeyResult {
  const KeyResult({
    required this.id,
    required this.title,
    this.description = '',
    this.progress = 0.0,
    this.dueDate,
  });

  final String id;
  final String title;
  final String description;
  final double progress;
  final DateTime? dueDate;

  Map<String, dynamic> toMap() => {
        'title': title,
        'description': description,
        'progress': progress,
        'dueDate': dueDate != null ? Timestamp.fromDate(dueDate!) : null,
      };

  factory KeyResult.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return KeyResult(
      id: doc.id,
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      progress: (data['progress'] as num?)?.toDouble() ?? 0.0,
      dueDate: (data['dueDate'] as Timestamp?)?.toDate(),
    );
  }
}

// ── Objective ─────────────────────────────────────────────────────────────────

class Objective {
  const Objective({
    required this.id,
    required this.title,
    this.description = '',
  });

  final String id;
  final String title;
  final String description;

  Map<String, dynamic> toMap() => {
        'title': title,
        'description': description,
      };

  factory Objective.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Objective(
      id: doc.id,
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
    );
  }
}
