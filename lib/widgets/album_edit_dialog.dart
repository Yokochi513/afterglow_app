import 'package:afterglow_app/models/album.dart';
import 'package:afterglow_app/services/album_service.dart';
import 'package:afterglow_app/services/auth_service.dart';
import 'package:flutter/material.dart';

/// アルバムの作成・編集ダイアログ（PS_02）。
///
/// [album] を渡すと編集、省略すると新規作成として振る舞う。編集できるのは
/// 所有者のみで、呼び出し側がこのダイアログを開く導線を出し分ける。
/// 保存に成功すると `true` を返して閉じる。
class AlbumEditDialog extends StatefulWidget {
  const AlbumEditDialog({super.key, this.album});

  /// 編集対象のアルバム。null なら新規作成。
  final Album? album;

  @override
  State<AlbumEditDialog> createState() => _AlbumEditDialogState();
}

class _AlbumEditDialogState extends State<AlbumEditDialog> {
  final AlbumService _albumService = AlbumService();
  final AuthService _authService = AuthService();

  late final TextEditingController _titleController = TextEditingController(
    text: widget.album?.title ?? '',
  );
  late final TextEditingController _descriptionController =
      TextEditingController(text: widget.album?.description ?? '');

  bool _isSaving = false;

  bool get _isEditing => widget.album != null;

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

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      _showError('タイトルを入力してください');
      return;
    }

    final uid = _authService.currentUserId;
    if (uid == null) {
      _showError('ログイン情報が取得できませんでした');
      return;
    }

    setState(() => _isSaving = true);

    final description = _descriptionController.text.trim();
    final bool succeeded;
    if (_isEditing) {
      succeeded = await _albumService.updateAlbum(
        widget.album!.id,
        title: title,
        description: description,
      );
    } else {
      final albumId = await _albumService.createAlbum(
        Album(
          id: '',
          ownerId: uid,
          title: title,
          description: description,
          createdAt: DateTime.now(),
        ),
      );
      succeeded = albumId != null;
    }

    if (!mounted) {
      return;
    }

    if (!succeeded) {
      setState(() => _isSaving = false);
      _showError(_isEditing ? 'アルバムの更新に失敗しました' : 'アルバムの作成に失敗しました');
      return;
    }

    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'アルバムを編集' : 'アルバムを作成'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _titleController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'タイトル',
              hintText: '例: 春の撮影会',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descriptionController,
            maxLines: 3,
            decoration: const InputDecoration(labelText: '説明（任意）'),
          ),
        ],
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
}
