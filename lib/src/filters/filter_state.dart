import 'package:flutter/foundation.dart';
import '../log_level.dart';

class FilterState extends ChangeNotifier {
  static final FilterState instance = FilterState._();
  FilterState._();

  Set<LogLevel> activeLevels = {...LogLevel.values};
  Set<LogTag> activeTags = {...LogTag.values};
  bool latestFirst = true;

  bool reduceBubbleOpacityWhenIdle = true;
  int bubbleIdleTimeoutSeconds = 3;
  double bubbleIdleOpacity = 0.3;

  bool get allLevelsActive => activeLevels.length == LogLevel.values.length;
  bool get allTagsActive => activeTags.length == LogTag.values.length;

  int get activeFilterCount {
    int n = 0;
    if (!allLevelsActive) n += LogLevel.values.length - activeLevels.length;
    if (!allTagsActive) n += LogTag.values.length - activeTags.length;
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

  void selectAllTags() {
    activeTags = {...LogTag.values};
    notifyListeners();
  }

  void deselectAllTags() {
    activeTags.clear();
    notifyListeners();
  }

  void toggleLatestFirst() {
    latestFirst = !latestFirst;
    notifyListeners();
  }

  void setReduceBubbleOpacityWhenIdle(bool value) {
    reduceBubbleOpacityWhenIdle = value;
    notifyListeners();
  }

  void setBubbleIdleTimeoutSeconds(int seconds) {
    bubbleIdleTimeoutSeconds = seconds;
    notifyListeners();
  }

  void setBubbleIdleOpacity(double opacity) {
    bubbleIdleOpacity = opacity;
    notifyListeners();
  }
}
