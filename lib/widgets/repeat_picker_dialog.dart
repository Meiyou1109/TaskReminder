import 'package:flutter/material.dart';
import '../models/task.dart';

class RepeatPickerDialog extends StatefulWidget {
  final RepeatFrequency initialFrequency;
  final int initialEvery;
  final List<int> initialWeekdays;

  const RepeatPickerDialog({
    super.key,
    required this.initialFrequency,
    required this.initialEvery,
    required this.initialWeekdays,
  });

  @override
  State<RepeatPickerDialog> createState() => _RepeatPickerDialogState();
}

class _RepeatPickerDialogState extends State<RepeatPickerDialog> {
  late RepeatFrequency _frequency;
  late int _every;
  late List<int> _weekdays;

  final weekdayLabels = ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7'];

  @override
  void initState() {
    super.initState();
    _frequency = widget.initialFrequency;
    _every = widget.initialEvery;
    _weekdays = List.from(widget.initialWeekdays);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Thiết lập lặp lại'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButton<RepeatFrequency>(
            value: _frequency,
            isExpanded: true,
            onChanged: (value) {
              if (value != null) setState(() => _frequency = value);
            },
            items: RepeatFrequency.values.map((f) {
              return DropdownMenuItem(
                value: f,
                child: Text(_label(f)),
              );
            }).toList(),
          ),
          if (_frequency != RepeatFrequency.none)
            TextField(
              decoration: InputDecoration(
                labelText: 'Lặp mỗi ... ${_unit(_frequency)}',
              ),
              keyboardType: TextInputType.number,
              controller: TextEditingController(text: _every.toString()),
              onChanged: (val) {
                final parsed = int.tryParse(val);
                if (parsed != null && parsed > 0) setState(() => _every = parsed);
              },
            ),
          if (_frequency == RepeatFrequency.weekly)
            Wrap(
              spacing: 6,
              children: List.generate(7, (i) {
                final selected = _weekdays.contains(i);
                return ChoiceChip(
                  label: Text(weekdayLabels[i]),
                  selected: selected,
                  onSelected: (_) {
                    setState(() {
                      if (selected) {
                        _weekdays.remove(i);
                      } else {
                        _weekdays.add(i);
                      }
                    });
                  },
                );
              }),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context, {
              'repeat': _frequency,
              'every': _every,
              'weekdays': _frequency == RepeatFrequency.weekly ? _weekdays : <int>[],
            });
          },
          child: const Text('Xong'),
        ),
      ],
    );
  }

  String _label(RepeatFrequency f) {
    switch (f) {
      case RepeatFrequency.none: return 'Không lặp';
      case RepeatFrequency.daily: return 'Hàng ngày';
      case RepeatFrequency.weekly: return 'Hàng tuần';
      case RepeatFrequency.monthly: return 'Hàng tháng';
      case RepeatFrequency.yearly: return 'Hàng năm';
      case RepeatFrequency.custom: return 'Tùy chỉnh';
    }
  }

  String _unit(RepeatFrequency f) {
    switch (f) {
      case RepeatFrequency.daily: return 'ngày';
      case RepeatFrequency.weekly: return 'tuần';
      case RepeatFrequency.monthly: return 'tháng';
      case RepeatFrequency.yearly: return 'năm';
      default: return '';
    }
  }
}
