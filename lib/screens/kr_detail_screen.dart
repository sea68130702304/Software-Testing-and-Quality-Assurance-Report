import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/database_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// KrDetailScreen
// ─────────────────────────────────────────────────────────────────────────────

/// Displays a [KeyResult]'s tasks with live % completion sliders,
/// add/delete support, and a locally-persisted Confidence Score.
class KrDetailScreen extends StatefulWidget {
  const KrDetailScreen({
    super.key,
    required this.uid,
    required this.objectiveId,
    required this.keyResult,
    this.krCurrent,
    this.krTarget,
    this.onCurrentChanged,
    this.db,
  });

  final String uid;
  final String objectiveId;
  final KeyResult keyResult;
  final int? krCurrent;
  final int? krTarget;
  final ValueChanged<int>? onCurrentChanged;
  final DatabaseService? db;

  @override
  State<KrDetailScreen> createState() => _KrDetailScreenState();
}

class _KrDetailScreenState extends State<KrDetailScreen> {
  late final _db = widget.db ?? DatabaseService();

  @override
  void initState() {
    super.initState();
  }

  // ── Task CRUD ──────────────────────────────────────────────────────────

  Future<void> _addTask(String title, {DateTime? dueDate}) async {
    final now = DateTime.now();
    final task = Task(
      id: '',
      keyResultId: widget.keyResult.id,
      title: title,
      completionPercentage: 0,
      status: TaskStatus.todo,
      createdAt: now,
      updatedAt: now,
      dueDate: dueDate,
    );
    try {
      await _db.createTask(
          uid: widget.uid, objectiveId: widget.objectiveId, task: task);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add task: $e')),
        );
      }
    }
  }

  Future<void> _updateCompletion(Task task, int percentage) async {
    final updated = task.copyWith(
      completionPercentage: percentage,
      status: percentage == 100
          ? TaskStatus.done
          : percentage > 0
              ? TaskStatus.inProgress
              : TaskStatus.todo,
    );
    try {
      await _db.updateTask(
          uid: widget.uid, objectiveId: widget.objectiveId, task: updated);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update task: $e')),
        );
      }
    }
  }

  Future<void> _updateDueDate(Task task, DateTime? dueDate) async {
    final updated = Task(
      id: task.id,
      keyResultId: task.keyResultId,
      title: task.title,
      completionPercentage: task.completionPercentage,
      status: task.status,
      createdAt: task.createdAt,
      updatedAt: DateTime.now(),
      dueDate: dueDate, // explicitly null-able
    );
    try {
      await _db.updateTask(
          uid: widget.uid, objectiveId: widget.objectiveId, task: updated);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update due date: $e')),
        );
      }
    }
  }

  Future<void> _deleteTask(Task task) async {
    try {
      await _db.deleteTask(
        uid: widget.uid,
        objectiveId: widget.objectiveId,
        keyResultId: widget.keyResult.id,
        taskId: task.id,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete task: $e')),
        );
      }
    }
  }

  // ── Dialogs ────────────────────────────────────────────────────────────

  Future<void> _showAddTaskDialog() async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    DateTime? selectedDueDate;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Text('Add Task'),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: controller,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Task title',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Title is required'
                        : null,
                    onFieldSubmitted: (_) => _submitAddTask(
                        formKey, controller, ctx,
                        dueDate: selectedDueDate),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: DateTime.now().add(const Duration(days: 7)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setDialogState(() => selectedDueDate = picked);
                      }
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: Theme.of(ctx).colorScheme.outline),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today,
                              size: 16, color: Colors.grey.shade600),
                          const SizedBox(width: 8),
                          Text(
                            selectedDueDate != null
                                ? '${selectedDueDate!.day.toString().padLeft(2, '0')}/'
                                    '${selectedDueDate!.month.toString().padLeft(2, '0')}/'
                                    '${selectedDueDate!.year}'
                                : 'Due date (optional)',
                            style: TextStyle(
                              color: selectedDueDate != null
                                  ? Theme.of(ctx).colorScheme.onSurface
                                  : Colors.grey.shade500,
                            ),
                          ),
                          if (selectedDueDate != null) ...[
                            const Spacer(),
                            GestureDetector(
                              onTap: () =>
                                  setDialogState(() => selectedDueDate = null),
                              child: Icon(Icons.close,
                                  size: 16, color: Colors.grey.shade500),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => _submitAddTask(formKey, controller, ctx,
                    dueDate: selectedDueDate),
                child: const Text('Add'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _submitAddTask(
    GlobalKey<FormState> formKey,
    TextEditingController controller,
    BuildContext ctx, {
    DateTime? dueDate,
  }) {
    if (formKey.currentState?.validate() ?? false) {
      _addTask(controller.text.trim(), dueDate: dueDate);
      Navigator.pop(ctx);
    }
  }

  Future<void> _confirmDelete(Task task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Task'),
        content: Text('Delete "${task.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _deleteTask(task);
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.keyResult.title),
        actions: const [],
      ),
      body: Column(
        children: [
          _KrSummaryBanner(
            keyResult: widget.keyResult,
            krCurrent: widget.krCurrent,
            krTarget: widget.krTarget,
            onCurrentChanged: widget.onCurrentChanged,
          ),
          Expanded(
            child: StreamBuilder<List<Task>>(
              stream: _db.tasksStream(
                uid: widget.uid,
                objectiveId: widget.objectiveId,
                keyResultId: widget.keyResult.id,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                final tasks = snapshot.data ?? [];
                if (tasks.isEmpty) {
                  return const _EmptyTasksPlaceholder();
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
                  itemCount: tasks.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _TaskCard(
                    task: tasks[i],
                    onSliderChanged: (pct) =>
                        _updateCompletion(tasks[i], pct),
                    onDelete: () => _confirmDelete(tasks[i]),
                    onDueDateChanged: (date) =>
                        _updateDueDate(tasks[i], date),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddTaskDialog,
        backgroundColor: const Color(0xFF9E9E9E),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Task'),
      ),
    );
  }

}

// ─────────────────────────────────────────────────────────────────────────────
// KR Summary Banner
// ─────────────────────────────────────────────────────────────────────────────

class _KrSummaryBanner extends StatefulWidget {
  const _KrSummaryBanner({
    required this.keyResult,
    this.krCurrent,
    this.krTarget,
    this.onCurrentChanged,
  });

  final KeyResult keyResult;
  final int? krCurrent;
  final int? krTarget;
  final ValueChanged<int>? onCurrentChanged;

  @override
  State<_KrSummaryBanner> createState() => _KrSummaryBannerState();
}

class _KrSummaryBannerState extends State<_KrSummaryBanner> {
  late double _localCurrent;

  @override
  void initState() {
    super.initState();
    _localCurrent = (widget.krCurrent ?? 0).toDouble();
  }

  Color _scoreColor(double current, double target) {
    final ratio = target > 0 ? current / target : 0.0;
    if (ratio >= 0.7) return Colors.green.shade600;
    if (ratio >= 0.4) return Colors.orange.shade700;
    return Colors.red.shade600;
  }

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/'
      '${date.year}';

  @override
  Widget build(BuildContext context) {
    final kr = widget.keyResult;
    final hasScoreSlider = widget.onCurrentChanged != null && widget.krTarget != null;
    final target = widget.krTarget ?? 10;
    final scoreColor = _scoreColor(_localCurrent, target.toDouble());

    // Progress bar uses task completion (kr.progress) when available,
    // otherwise falls back to the score ratio.
    final barValue = hasScoreSlider
        ? _localCurrent / target
        : kr.progress;
    final barColor = hasScoreSlider ? scoreColor : _progressBarColor(kr.progress);

    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  kr.description.isNotEmpty
                      ? kr.description
                      : 'Task completion drives this KR\'s progress',
                  style: TextStyle(
                    fontSize: 13,
                    color: kr.description.isEmpty
                        ? Colors.grey.shade400
                        : Colors.grey.shade700,
                    fontStyle: kr.description.isEmpty
                        ? FontStyle.italic
                        : FontStyle.normal,
                  ),
                ),
              ),
              if (hasScoreSlider) ...[
                const SizedBox(width: 12),
                Text(
                  '${_localCurrent.round()} / $target',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: scoreColor,
                  ),
                ),
              ],
            ],
          ),
          if (hasScoreSlider) ...[
            Row(
              children: [
                Text('Score',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                Expanded(
                  child: Slider(
                    value: _localCurrent,
                    min: 0,
                    max: target.toDouble(),
                    divisions: target,
                    activeColor: scoreColor,
                    label: '${_localCurrent.round()}',
                    onChanged: (v) => setState(() => _localCurrent = v),
                    onChangeEnd: (v) => widget.onCurrentChanged!(v.round()),
                  ),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: barValue,
                minHeight: 8,
                backgroundColor: Colors.grey.shade300,
                valueColor: AlwaysStoppedAnimation(barColor),
              ),
            ),
          ],
          if (kr.dueDate != null) ...[
            const SizedBox(height: 6),
            Text(
              'Due: ${_formatDate(kr.dueDate!)}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ],
      ),
    );
  }

  Color _progressBarColor(double progress) {
    if (progress >= 0.7) return Colors.green.shade600;
    if (progress >= 0.4) return Colors.orange.shade700;
    return Colors.red.shade600;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Task Card
// ─────────────────────────────────────────────────────────────────────────────

class _TaskCard extends StatefulWidget {
  const _TaskCard({
    required this.task,
    required this.onSliderChanged,
    required this.onDelete,
    required this.onDueDateChanged,
  });

  final Task task;
  final ValueChanged<int> onSliderChanged;
  final VoidCallback onDelete;
  final ValueChanged<DateTime?> onDueDateChanged;

  @override
  State<_TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<_TaskCard> {
  late double _localPct;

  @override
  void initState() {
    super.initState();
    _localPct = widget.task.completionPercentage.toDouble();
  }

  @override
  void didUpdateWidget(_TaskCard old) {
    super.didUpdateWidget(old);
    // Sync if Firestore pushed a change from another device
    if (old.task.completionPercentage != widget.task.completionPercentage) {
      _localPct = widget.task.completionPercentage.toDouble();
    }
  }

  Color get _statusColor {
    switch (widget.task.status) {
      case TaskStatus.done:
        return Colors.green.shade600;
      case TaskStatus.inProgress:
        return Colors.orange.shade700;
      case TaskStatus.todo:
        return Colors.grey.shade500;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pct = _localPct.round();
    final isDone = widget.task.status == TaskStatus.done;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title row + status badge + delete
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.task.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      decoration:
                          isDone ? TextDecoration.lineThrough : null,
                      color: isDone
                          ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                _StatusChip(status: widget.task.status, color: _statusColor),
                IconButton(
                  tooltip: 'Delete task',
                  icon: const Icon(Icons.delete_outline, size: 20),
                  color: Colors.red.shade400,
                  onPressed: widget.onDelete,
                ),
              ],
            ),

            // Due date row — tap to edit, × to clear, or show picker if unset
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: widget.task.dueDate ??
                            DateTime.now().add(const Duration(days: 7)),
                        firstDate: DateTime.now().subtract(const Duration(days: 365)),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) widget.onDueDateChanged(picked);
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 12,
                          color: widget.task.isOverdue
                              ? Colors.red
                              : Colors.grey.shade500,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          widget.task.dueDate != null
                              ? _formatDate(widget.task.dueDate!)
                              : 'Add due date',
                          style: TextStyle(
                            fontSize: 12,
                            color: widget.task.isOverdue
                                ? Colors.red
                                : widget.task.dueDate != null
                                    ? Colors.grey.shade600
                                    : Colors.grey.shade400,
                            fontWeight: widget.task.isOverdue
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        if (widget.task.isOverdue) ...[
                          const SizedBox(width: 4),
                          const Text(
                            'Overdue',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (widget.task.dueDate != null) ...[
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () => widget.onDueDateChanged(null),
                      child: Icon(Icons.close,
                          size: 14, color: Colors.grey.shade400),
                    ),
                  ],
                ],
              ),
            ),

            // % Complete slider
            Row(
              children: [
                Text(
                  '$pct%',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: _statusColor,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                Expanded(
                  child: Slider(
                    value: _localPct,
                    min: 0,
                    max: 100,
                    divisions: 20, // 5% increments
                    activeColor: _statusColor,
                    inactiveColor: Colors.grey.shade200,
                    onChanged: (v) => setState(() => _localPct = v),
                    onChangeEnd: (v) =>
                        widget.onSliderChanged(v.round()),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/'
      '${date.year}';
}

// ─────────────────────────────────────────────────────────────────────────────
// Status Chip
// ─────────────────────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, required this.color});
  final TaskStatus status;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty State
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyTasksPlaceholder extends StatelessWidget {
  const _EmptyTasksPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_box_outline_blank,
              size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(
            'No tasks yet',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tap + Add Task to get started',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }
}
