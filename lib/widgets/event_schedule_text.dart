import 'package:afterglow_app/models/event.dart';
import 'package:flutter/material.dart';

/// イベントの開催日時表示（§5.7）。
///
/// 終了日時があれば `2026/07/20 13:00 〜 17:00` のように範囲で表示し、
/// 日をまたぐ場合は終了側も日付から表示する。`intl` を導入せずに整形する
/// 方針は [CommentSection] に揃える。
class EventScheduleText extends StatelessWidget {
  const EventScheduleText({super.key, required this.event, this.style});

  final Event event;
  final TextStyle? style;

  static String _two(int n) => n.toString().padLeft(2, '0');

  /// `2026/07/20 13:00` 形式。
  static String formatDateTime(DateTime time) =>
      '${time.year}/${_two(time.month)}/${_two(time.day)} '
      '${_two(time.hour)}:${_two(time.minute)}';

  /// `13:00` 形式。
  static String formatTime(DateTime time) =>
      '${_two(time.hour)}:${_two(time.minute)}';

  /// 開始〜終了をまとめた文字列。終了日時が無ければ開始日時のみ。
  static String formatRange(Event event) {
    final start = formatDateTime(event.startAt);
    final end = event.endAt;
    if (end == null) {
      return start;
    }

    final isSameDay =
        end.year == event.startAt.year &&
        end.month == event.startAt.month &&
        end.day == event.startAt.day;
    return '$start 〜 ${isSameDay ? formatTime(end) : formatDateTime(end)}';
  }

  @override
  Widget build(BuildContext context) {
    return Text(formatRange(event), style: style);
  }
}
