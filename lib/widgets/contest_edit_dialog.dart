import 'package:afterglow_app/models/contest.dart';
import 'package:afterglow_app/services/auth_service.dart';
import 'package:afterglow_app/services/contest_service.dart';
import 'package:afterglow_app/widgets/event_schedule_text.dart';
import 'package:flutter/material.dart';

class ContestEditDialog extends StatefulWidget {
  const ContestEditDialog({
    super.key,
    this.contest,
    this.contestService,
    this.authService,
  });

  final Contest? contest;
  final ContestService? contestService;
  final AuthService? authService;

  @override
  State<ContestEditDialog> createState() => _ContestEditDialogState();
}

class _ContestEditDialogState extends State<ContestEditDialog> {
  late final ContestService _contestService =
      widget.contestService ?? ContestService();
  late final AuthService _authService = widget.authService ?? AuthService();

  late final TextEditingController _titleController = TextEditingController(
    text: widget.contest?.title ?? '',
  );
  late final TextEditingController _descriptionController =
      TextEditingController(text: widget.contest?.description ?? '');

  late DateTime _entryDeadline =
      widget.contest?.entryDeadline ?? _defaultEntryDeadline();
  late DateTime _votingDeadline =
      widget.contest?.votingDeadline ??
      _entryDeadline.add(const Duration(days: 7));

  bool _isSaving = false;

  bool get _isEditing => widget.contest != null;

  static DateTime _defaultEntryDeadline() {
    final nextWeek = DateTime.now().add(const Duration(days: 7));
    return DateTime(nextWeek.year, nextWeek.month, nextWeek.day, 23, 59);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<DateTime?> _pickDateTime(DateTime initial) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime(initial.year + 5),
    );
    if (date == null || !mounted) {
      return null;
    }

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) {
      return null;
    }

    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _editEntryDeadline() async {
    final picked = await _pickDateTime(_entryDeadline);
    if (picked == null) {
      return;
    }
    setState(() {
      _entryDeadline = picked;
      if (!_votingDeadline.isAfter(_entryDeadline)) {
        _votingDeadline = _entryDeadline.add(const Duration(days: 7));
      }
    });
  }

  Future<void> _editVotingDeadline() async {
    final picked = await _pickDateTime(_votingDeadline);
    if (picked == null) {
      return;
    }
    if (!picked.isAfter(_entryDeadline)) {
      _showError('投票締切はエントリー締切より後にしてください');
      return;
    }
    setState(() => _votingDeadline = picked);
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      _showError('コンテスト名を入力してください');
      return;
    }
    if (!_votingDeadline.isAfter(_entryDeadline)) {
      _showError('投票締切はエントリー締切より後にしてください');
      return;
    }

    final uid = _authService.currentUserId;
    if (uid == null) {
      _showError('ログイン情報を取得できませんでした');
      return;
    }

    setState(() => _isSaving = true);

    final now = DateTime.now();
    final contest = Contest(
      id: widget.contest?.id ?? '',
      creatorId: widget.contest?.creatorId ?? uid,
      title: title,
      description: _descriptionController.text.trim(),
      entryDeadline: _entryDeadline,
      votingDeadline: _votingDeadline,
      createdAt: widget.contest?.createdAt ?? now,
      updatedAt: now,
    );

    final succeeded = _isEditing
        ? await _contestService.updateContest(contest)
        : await _contestService.createContest(contest);

    if (!mounted) {
      return;
    }

    if (!succeeded) {
      setState(() => _isSaving = false);
      _showError(_isEditing ? 'コンテストの更新に失敗しました' : 'コンテストの作成に失敗しました');
      return;
    }

    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'コンテストを編集' : 'コンテストを作成'),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _titleController,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'コンテスト名'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: '説明'),
              ),
              const SizedBox(height: 12),
              _buildDateTimeRow(
                label: 'エントリー締切',
                value: EventScheduleText.formatDateTime(_entryDeadline),
                onPressed: _isSaving ? null : _editEntryDeadline,
              ),
              _buildDateTimeRow(
                label: '投票締切',
                value: EventScheduleText.formatDateTime(_votingDeadline),
                onPressed: _isSaving ? null : _editVotingDeadline,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
          child: const Text('キャンセル'),
        ),
        TextButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_isEditing ? '保存' : '作成'),
        ),
      ],
    );
  }

  Widget _buildDateTimeRow({
    required String label,
    required String value,
    required VoidCallback? onPressed,
  }) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        TextButton(onPressed: onPressed, child: Text(value)),
      ],
    );
  }
}
