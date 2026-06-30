import 'package:flutter/foundation.dart';
import '../log_level.dart';

class FilterState extends ChangeNotifier {
  static final FilterState instance = FilterState._();
  FilterState._();

  Set<LogLevel> activeLevels = {...LogLevel.values};
  Set<LogTag>   activeTags   = {...LogTag.values};
  bool latestFirst = false;
  bool autoScroll  = true;

  bool get allLevelsActive => activeLevels.length == LogLevel.values.length;
  bool get allTagsActive   => activeTags.length   == LogTag.values.length;

  int get activeFilterCount {
    int n = 0;
    if (!allLevelsActive) n += LogLevel.values.length - activeLevels.length;
    if (!allTagsActive)   n += LogTag.values.length   - activeTags.length;
    return n;
  }

  void toggleLevel(LogLevel l) {
    if (activeLevels.contains(l)) {
      if (activeLevels.length > 1) activeLevels.remove(l);
    } else {
      activeLevels.add(l);
    }
    notifyListeners();
  }

  void toggleTag(LogTag t) {
    if (activeTags.contains(t)) {
      if (activeTags.length > 1) activeTags.remove(t);
    } else {
      activeTags.add(t);
    }
    notifyListeners();
  }

  void selectAllTags()    { activeTags = {...LogTag.values}; notifyListeners(); }
  void deselectAllTags()  { activeTags.clear();              notifyListeners(); }
  void toggleLatestFirst(){ latestFirst = !latestFirst;      notifyListeners(); }
  void toggleAutoScroll() { autoScroll  = !autoScroll;       notifyListeners(); }
}
