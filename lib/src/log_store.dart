import 'package:flutter/foundation.dart';

import 'models/log_entry.dart';
import 'models/log_session.dart';

class LogStore extends ChangeNotifier {
  final List<LogSession> _sessions = [];

  List<LogSession> get sessions => List.unmodifiable(_sessions);

  LogSession? get currentSession =>
      _sessions.isEmpty ? null : _sessions.last;

  void startSession(String sessionId, DateTime startTime) {
    _sessions.add(LogSession(id: sessionId, startTime: startTime));
    notifyListeners();
  }

  void append(LogEntry entry) {
    currentSession?.addEntry(entry);
    notifyListeners();
  }

  void loadSessions(List<LogSession> loaded) {
    _sessions.addAll(loaded);
    notifyListeners();
  }

  void clear() {
    _sessions.clear();
    notifyListeners();
  }

  LogEntry entryFromJson(Map<String, dynamic> json) =>
      LogEntry.fromJson(json);

  Map<String, dynamic> entryToJson(LogEntry entry) => entry.toJson();
}
