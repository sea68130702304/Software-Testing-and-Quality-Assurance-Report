class KRTask {
  String title;
  double percentComplete;
  DateTime dueDate;

  KRTask({required this.title, this.percentComplete = 0.0, required this.dueDate});
}

class KeyResult {
  String title;
  int confidence; // 1-10
  List<KRTask> tasks;

  KeyResult({required this.title, this.confidence = 5, required this.tasks});
}