import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/database_service.dart';
import 'kr_detail_screen.dart';
import 'profile_screen.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────
const _headerColor = Color(0xFF9E9E9E);
const _headerTextStyle = TextStyle(
  color: Colors.white,
  fontWeight: FontWeight.w600,
  fontSize: 14,
);

// ── Mutable data classes ──────────────────────────────────────────────────────
class _KRData {
  _KRData(this.label, this.current, this.target);
  String label;
  int current;
  int target;
}

enum HealthStatus { green, yellow, red }

class _HealthData {
  _HealthData(this.label, this.status, this.note);
  String label;
  HealthStatus status;
  String? note;
}

// ── DashboardScreen ───────────────────────────────────────────────────────────
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, this.db, this.auth});

  final DatabaseService? db;
  final FirebaseAuth? auth;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<String> _priorities = [];
  String _objective = '';
  List<_KRData> _keyResults = [];
  List<String> _projects = [];
  List<_HealthData> _healthItems = [];
  String _displayName = '';

  late final _db = widget.db ?? DatabaseService();
  FirebaseAuth get _auth => widget.auth ?? FirebaseAuth.instance;
  String get _uid => _auth.currentUser?.uid ?? 'guest';

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadDisplayName();
  }

  Future<void> _loadDisplayName() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('display_name') ?? '';
    if (mounted) setState(() => _displayName = name);
  }

  // ── Persistence (Firestore) ───────────────────────────────────────────

  Future<void> _loadData() async {
    final data = await _db.loadDashboard(_uid);
    if (data == null) return;
    setState(() {
      _objective = data['objective'] as String? ?? '';

      final pList = data['priorities'];
      if (pList != null) _priorities = List<String>.from(pList);

      final krList = data['keyResults'];
      if (krList != null) {
        _keyResults = (krList as List)
            .map((e) => _KRData(e['label'], e['current'], e['target']))
            .toList();
      }

      final projList = data['projects'];
      if (projList != null) _projects = List<String>.from(projList);

      final healthList = data['health'];
      if (healthList != null) {
        _healthItems = (healthList as List)
            .map((e) => _HealthData(
                  e['label'],
                  HealthStatus.values.firstWhere(
                      (s) => s.name == e['status'],
                      orElse: () => HealthStatus.green),
                  e['note'] as String?,
                ))
            .toList();
      }
    });
  }

  Future<void> _saveAll() => _db.saveDashboard(_uid, {
        'objective': _objective,
        'priorities': _priorities,
        'keyResults': _keyResults
            .map((kr) =>
                {'label': kr.label, 'current': kr.current, 'target': kr.target})
            .toList(),
        'projects': _projects,
        'health': _healthItems
            .map((h) =>
                {'label': h.label, 'status': h.status.name, 'note': h.note})
            .toList(),
      });

  // convenience aliases so existing call sites still compile
  Future<void> _savePriorities() => _saveAll();
  Future<void> _saveObjective() => _saveAll();
  Future<void> _saveKeyResults() => _saveAll();
  Future<void> _saveProjects() => _saveAll();
  Future<void> _saveHealth() => _saveAll();

  // ── Edit: Priorities ──────────────────────────────────────────────────

  Future<void> _editPriorities() async {
    final items = List<String>.from(_priorities);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _StringListEditor(
        title: 'Priorities this week',
        items: items,
        onSave: (updated) {
          setState(() => _priorities = updated);
          _savePriorities();
        },
      ),
    );
  }

  // ── Edit: Objective ───────────────────────────────────────────────────

  Future<void> _editObjective() async {
    final ctrl = TextEditingController(text: _objective);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Objective'),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          autofocus: true,
          decoration: const InputDecoration(
              labelText: 'Objective', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('Save')),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      setState(() => _objective = result);
      _saveObjective();
    }
  }

  // ── Edit: KR ─────────────────────────────────────────────────────────

  Future<void> _editKR(_KRData kr) async {
    final labelCtrl = TextEditingController(text: kr.label);
    int current = kr.current;
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Edit Key Result'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: labelCtrl,
                  decoration: const InputDecoration(
                      labelText: 'KR Label', border: OutlineInputBorder()),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                _KRInputControls(
                  current: current,
                  onCurrentChanged: (v) => setLocal(() => current = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  setState(() {
                    kr.label = labelCtrl.text.trim();
                    kr.current = current;
                    kr.target = _KRInputControls.target;
                  });
                  _saveKeyResults();
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addKR() async {
    final labelCtrl = TextEditingController();
    int current = 0;
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Add Key Result'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: labelCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(
                      labelText: 'KR Label', border: OutlineInputBorder()),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                _KRInputControls(
                  current: current,
                  onCurrentChanged: (v) => setLocal(() => current = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  setState(() {
                    _keyResults.add(_KRData(
                      labelCtrl.text.trim(),
                      current,
                      _KRInputControls.target,
                    ));
                  });
                  _saveKeyResults();
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Edit: Projects ────────────────────────────────────────────────────

  Future<void> _editProjects() async {
    final items = List<String>.from(_projects);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _StringListEditor(
        title: 'Next 4 weeks – Projects',
        items: items,
        onSave: (updated) {
          setState(() => _projects = updated);
          _saveProjects();
        },
      ),
    );
  }

  // ── Edit: Health ──────────────────────────────────────────────────────

  Future<void> _editHealthItem(_HealthData item) async {
    final labelCtrl = TextEditingController(text: item.label);
    final noteCtrl = TextEditingController(text: item.note ?? '');
    HealthStatus status = item.status;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Edit Health Item'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: labelCtrl,
                decoration: const InputDecoration(
                    labelText: 'Label', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<HealthStatus>(
                initialValue: status,
                decoration: const InputDecoration(
                    labelText: 'Status', border: OutlineInputBorder()),
                items: HealthStatus.values
                    .map((s) => DropdownMenuItem(
                          value: s,
                          child: Row(children: [
                            Icon(Icons.circle,
                                size: 12, color: _healthColor(s)),
                            const SizedBox(width: 8),
                            Text(s.name[0].toUpperCase() + s.name.substring(1)),
                          ]),
                        ))
                    .toList(),
                onChanged: (v) => setLocal(() => status = v ?? status),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                    labelText: 'Note (optional)',
                    border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                setState(() {
                  item.label = labelCtrl.text.trim();
                  item.status = status;
                  item.note = noteCtrl.text.trim().isEmpty
                      ? null
                      : noteCtrl.text.trim();
                });
                _saveHealth();
                Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addHealthItem() async {
    final labelCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    HealthStatus status = HealthStatus.green;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Add Health Item'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: labelCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                    labelText: 'Label', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<HealthStatus>(
                initialValue: status,
                decoration: const InputDecoration(
                    labelText: 'Status', border: OutlineInputBorder()),
                items: HealthStatus.values
                    .map((s) => DropdownMenuItem(
                          value: s,
                          child: Row(children: [
                            Icon(Icons.circle,
                                size: 12, color: _healthColor(s)),
                            const SizedBox(width: 8),
                            Text(s.name[0].toUpperCase() + s.name.substring(1)),
                          ]),
                        ))
                    .toList(),
                onChanged: (v) => setLocal(() => status = v ?? status),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                    labelText: 'Note (optional)',
                    border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (labelCtrl.text.trim().isNotEmpty) {
                  setState(() {
                    _healthItems.add(_HealthData(
                      labelCtrl.text.trim(),
                      status,
                      noteCtrl.text.trim().isEmpty
                          ? null
                          : noteCtrl.text.trim(),
                    ));
                  });
                  _saveHealth();
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  static Color _healthColor(HealthStatus s) {
    switch (s) {
      case HealthStatus.green:
        return Colors.green.shade600;
      case HealthStatus.yellow:
        return Colors.yellow.shade700;
      case HealthStatus.red:
        return Colors.red.shade600;
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('OKR Radical Dashboard'),
        actions: [
          GestureDetector(
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
              _loadDisplayName(); // refresh after returning from Profile
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: Colors.white.withValues(alpha: 0.3),
                child: Text(
                  _displayName.isNotEmpty
                      ? _displayName[0].toUpperCase()
                      : (_auth.currentUser?.email?[0].toUpperCase() ?? '?'),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 600;
            return Padding(
              padding: const EdgeInsets.all(12),
              child: isWide ? _buildWide() : _buildNarrow(),
            );
          },
        ),
      ),
    );
  }

  Widget _buildWide() {
    return Column(
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _buildPrioritiesCard()),
              const SizedBox(width: 12),
              Expanded(child: _buildOkrCard()),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _buildProjectsCard()),
              const SizedBox(width: 12),
              Expanded(child: _buildHealthCard()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNarrow() {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildPrioritiesCard(),
          const SizedBox(height: 12),
          _buildOkrCard(),
          const SizedBox(height: 12),
          _buildProjectsCard(),
          const SizedBox(height: 12),
          _buildHealthCard(),
        ],
      ),
    );
  }

  // ── Card builders ─────────────────────────────────────────────────────

  Widget _buildPrioritiesCard() {
    return _DashCard(
      title: 'Priorities this week',
      onEdit: _editPriorities,
      child: _priorities.isEmpty
          ? _EmptyHint(label: 'No priorities yet', onAdd: _editPriorities)
          : Column(
              children:
                  _priorities.map((t) => _PriorityRow(label: t)).toList(),
            ),
    );
  }

  Widget _buildOkrCard() {
    return _DashCard(
      title: 'OKR Confidence',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _objective.isEmpty
                    ? GestureDetector(
                        onTap: _editObjective,
                        child: Text('Tap to set objective...',
                            style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade400,
                                fontStyle: FontStyle.italic)),
                      )
                    : Text('Objective: $_objective',
                        style: const TextStyle(fontSize: 13, height: 1.4)),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 16),
                color: _headerColor,
                tooltip: 'Edit objective',
                onPressed: _editObjective,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_keyResults.isEmpty)
            _EmptyHint(label: 'No key results yet', onAdd: _addKR),
          ..._keyResults.map((kr) => _KRRow(
                data: kr,
                uid: _uid,
                onEdit: () => _editKR(kr),
                onDelete: () {
                  setState(() => _keyResults.remove(kr));
                  _saveKeyResults();
                },
                onCurrentChanged: (v) {
                  setState(() => kr.current = v);
                  _saveKeyResults();
                },
              )),
          TextButton.icon(
            onPressed: _addKR,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add KR', style: TextStyle(fontSize: 13)),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectsCard() {
    return _DashCard(
      title: 'Next 4 weeks – Projects',
      onEdit: _editProjects,
      child: _projects.isEmpty
          ? _EmptyHint(label: 'No projects yet', onAdd: _editProjects)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _projects
                  .map((p) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('• ', style: TextStyle(fontSize: 16)),
                            Expanded(
                              child: Text(p,
                                  style: const TextStyle(
                                      fontSize: 13, height: 1.4)),
                            ),
                          ],
                        ),
                      ))
                  .toList(),
            ),
    );
  }

  Widget _buildHealthCard() {
    return _DashCard(
      title: 'Health',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_healthItems.isEmpty)
            _EmptyHint(label: 'No health items yet', onAdd: _addHealthItem),
          ..._healthItems.map((item) => _HealthRow(
                data: item,
                onEdit: () => _editHealthItem(item),
                onDelete: () {
                  setState(() => _healthItems.remove(item));
                  _saveHealth();
                },
              )),
          TextButton.icon(
            onPressed: _addHealthItem,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add item', style: TextStyle(fontSize: 13)),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 4),
            ),
          ),
        ],
      ),
    );
  }
}

// ── _DashCard ─────────────────────────────────────────────────────────────────
class _DashCard extends StatelessWidget {
  const _DashCard({
    required this.title,
    required this.child,
    this.onEdit,
  });

  final String title;
  final Widget child;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        border: Border.all(color: _headerColor.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: const BoxDecoration(
              color: _headerColor,
              borderRadius: BorderRadius.vertical(top: Radius.circular(5)),
            ),
            child: Row(
              children: [
                Expanded(child: Text(title, style: _headerTextStyle)),
                if (onEdit != null)
                  InkWell(
                    onTap: onEdit,
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.edit_outlined,
                          size: 16, color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: child,
          ),
        ],
      ),
    );
  }
}

// ── _PriorityRow ──────────────────────────────────────────────────────────────
class _PriorityRow extends StatelessWidget {
  const _PriorityRow({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _headerColor,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text('P1',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label,
                style: const TextStyle(fontSize: 13, height: 1.4)),
          ),
        ],
      ),
    );
  }
}

// ── _KRRow ────────────────────────────────────────────────────────────────────
class _KRRow extends StatelessWidget {
  const _KRRow({
    required this.data,
    required this.uid,
    required this.onEdit,
    required this.onDelete,
    required this.onCurrentChanged,
  });

  final _KRData data;
  final String uid;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<int> onCurrentChanged;

  void _openDetail(BuildContext context) {
    final kr = KeyResult(
      id: data.label.replaceAll(' ', '_').toLowerCase(),
      title: data.label,
      description: '',
      progress: data.target > 0 ? data.current / data.target : 0.0,
    );
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => KrDetailScreen(
          uid: uid,
          objectiveId: 'demo_objective',
          keyResult: kr,
          krCurrent: data.current,
          krTarget: data.target,
          onCurrentChanged: onCurrentChanged,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => _openDetail(context),
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('KR: ${data.label}',
                          style: const TextStyle(fontSize: 13)),
                    ),
                    _ConfidenceBadge(
                        current: data.current, target: data.target),
                    const SizedBox(width: 2),
                    const Icon(Icons.chevron_right,
                        size: 16, color: Colors.grey),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 16),
            color: _headerColor,
            tooltip: 'Edit KR',
            onPressed: onEdit,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 16),
            color: Colors.red.shade300,
            tooltip: 'Delete KR',
            onPressed: onDelete,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
        ],
      ),
    );
  }
}

// ── _ConfidenceBadge ──────────────────────────────────────────────────────────
class _ConfidenceBadge extends StatelessWidget {
  const _ConfidenceBadge({required this.current, required this.target});
  final int current;
  final int target;

  Color get _color {
    final ratio = target > 0 ? current / target : 0.0;
    if (ratio >= 0.7) return Colors.green.shade600;
    if (ratio >= 0.4) return Colors.orange.shade700;
    return Colors.red.shade600;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.15),
        border: Border.all(color: _color),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '$current/$target',
        style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.bold, color: _color),
      ),
    );
  }
}

// ── _HealthRow ────────────────────────────────────────────────────────────────
class _HealthRow extends StatelessWidget {
  const _HealthRow({
    required this.data,
    required this.onEdit,
    required this.onDelete,
  });

  final _HealthData data;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  Color get _statusColor {
    switch (data.status) {
      case HealthStatus.green:
        return Colors.green.shade600;
      case HealthStatus.yellow:
        return Colors.yellow.shade700;
      case HealthStatus.red:
        return Colors.red.shade600;
    }
  }

  String get _statusLabel {
    switch (data.status) {
      case HealthStatus.green:
        return 'Green';
      case HealthStatus.yellow:
        return 'Yellow';
      case HealthStatus.red:
        return 'Red';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${data.label}:',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: _statusColor,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(_statusLabel,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12)),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 16),
                color: _headerColor,
                tooltip: 'Edit',
                onPressed: onEdit,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 16),
                color: Colors.red.shade300,
                tooltip: 'Delete',
                onPressed: onDelete,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
            ],
          ),
          if (data.note != null)
            Padding(
              padding: const EdgeInsets.only(left: 4, top: 2),
              child: Text(
                data.note!,
                style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic),
              ),
            ),
        ],
      ),
    );
  }
}

// ── _EmptyHint ────────────────────────────────────────────────────────────────
class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.label, required this.onAdd});
  final String label;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onAdd,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(Icons.add_circle_outline, size: 16, color: Colors.grey.shade400),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade400,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── _StringListEditor (bottom sheet) ─────────────────────────────────────────
class _StringListEditor extends StatefulWidget {
  const _StringListEditor({
    required this.title,
    required this.items,
    required this.onSave,
  });

  final String title;
  final List<String> items;
  final void Function(List<String>) onSave;

  @override
  State<_StringListEditor> createState() => _StringListEditorState();
}

class _StringListEditorState extends State<_StringListEditor> {
  late List<String> _items;

  @override
  void initState() {
    super.initState();
    _items = List<String>.from(widget.items);
  }

  void _addItem() async {
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add to ${widget.title}'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('Add')),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      setState(() => _items.add(result));
    }
  }

  void _editItem(int index) async {
    final ctrl = TextEditingController(text: _items[index]);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit item'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('Save')),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      setState(() => _items[index] = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (ctx, scrollCtrl) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(widget.title,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                FilledButton(
                  onPressed: () {
                    widget.onSave(_items);
                    Navigator.pop(context);
                  },
                  child: const Text('Done'),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: ListView.builder(
              controller: scrollCtrl,
              itemCount: _items.length + 1,
              itemBuilder: (_, i) {
                if (i == _items.length) {
                  return ListTile(
                    leading: const Icon(Icons.add),
                    title: const Text('Add item'),
                    onTap: _addItem,
                  );
                }
                return ListTile(
                  title: Text(_items[i]),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        onPressed: () => _editItem(i),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline,
                            size: 18, color: Colors.red.shade300),
                        onPressed: () =>
                            setState(() => _items.removeAt(i)),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── _KRInputControls ──────────────────────────────────────────────────────────
class _KRInputControls extends StatelessWidget {
  const _KRInputControls({
    required this.current,
    required this.onCurrentChanged,
  });

  static const int target = 10;
  final int current;
  final ValueChanged<int> onCurrentChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Current Score',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13)),
            const Spacer(),
            Text(
              '$current / $target',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _sliderColor(current),
              ),
            ),
          ],
        ),
        Slider(
          value: current.toDouble(),
          min: 0,
          max: target.toDouble(),
          divisions: target,
          activeColor: _sliderColor(current),
          label: '$current',
          onChanged: (v) => onCurrentChanged(v.round()),
        ),
      ],
    );
  }

  Color _sliderColor(int c) {
    final ratio = c / target;
    if (ratio >= 0.7) return Colors.green.shade600;
    if (ratio >= 0.4) return Colors.orange.shade700;
    return Colors.red.shade600;
  }
}
