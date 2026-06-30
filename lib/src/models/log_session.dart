import 'log_entry.dart';

class LogSession {
  LogSession({required this.id, required this.startTime});

  final String id;
  final DateTime startTime;
  final List<LogEntry> _entries = [];

  List<LogEntry> get entries => List.unmodifiable(_entries);

  void addEntry(LogEntry entry) => _entries.add(entry);

  String formatAsText(int sessionNumber) {
    final header = 'SESSION #$sessionNumber  •  ${_formatHeader(startTime)}'
        '  •  ${_entries.length} entries';
    final divider = '=' * 72;
    final entryBlocks = _entries
        .map((e) => e.formatAsText(sessionNumber: sessionNumber))
        .join('\n\n');
    return '$header\n$divider\n$entryBlocks';
  }

  static String _formatHeader(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final month = months[dt.month - 1];
    final day = dt.day.toString().padLeft(2, '0');
    final hourNum = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final second = dt.second.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$month $day, ${dt.year}  •  $hourNum:$minute:$second $ampm';
  }
}
