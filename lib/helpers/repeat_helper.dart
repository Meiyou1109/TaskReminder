import '../models/task.dart';

class RepeatHelper {
  /// Tính ngày lặp lại tiếp theo
  static DateTime? calculateNextRepeat(Task task) {
    final current = task.dueDate;
    if (current == null) return null;

    switch (task.repeat) {
      case RepeatFrequency.daily:
        return current.add(Duration(days: task.repeatEvery));

      case RepeatFrequency.weekly:
        final weekdays = task.repeatWeekdays ?? [];
        if (weekdays.isEmpty) return null;

        final nowWeekday = current.weekday % 7;
        final sorted = [...weekdays]..sort();

        for (int d in sorted) {
          if (d > nowWeekday) {
            return current.add(Duration(days: d - nowWeekday));
          }
        }

        // sang tuần kế tiếp
        return current.add(Duration(days: 7 * task.repeatEvery - nowWeekday + sorted.first));

      case RepeatFrequency.monthly:
        return DateTime(current.year, current.month + task.repeatEvery, current.day);

      case RepeatFrequency.yearly:
        return DateTime(current.year + task.repeatEvery, current.month, current.day);

      default:
        return null;
    }
  }
}
