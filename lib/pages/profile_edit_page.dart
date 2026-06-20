import 'dart:typed_data';

import 'package:afterglow_app/models/app_user.dart';
import 'package:afterglow_app/services/user_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// プロフィール編集画面。ユーザー名・自己紹介・プロフィール画像を変更する。
class ProfileEditPage extends StatefulWidget {
  const ProfileEditPage({super.key, required this.user});

  final AppUser user;

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  final _formKey = GlobalKey<FormState>();
  final UserService _userService = UserService();
  final ImagePicker _imagePicker = ImagePicker();

  late final TextEditingController _usernameController = TextEditingController(
    text: widget.user.username,
  );
  late final TextEditingController _bioController = TextEditingController(
    text: widget.user.bio,
  );

  XFile? _selectedImage;
  Uint8List? _previewImageBytes;
  bool _isSaving = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    if (picked == null) {
      return;
    }

    final bytes = await picked.readAsBytes();
    if (!mounted) {
      return;
    }

    setState(() {
      _selectedImage = picked;
      _previewImageBytes = bytes;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _isSaving = true);

    try {
      String? imageUrl;
      if (_selectedImage != null) {
        imageUrl = await _userService.uploadProfileImage(
          widget.user.id,
          _selectedImage!,
        );
      }

      await _userService.updateProfile(
        widget.user.id,
        username: _usernameController.text.trim(),
        bio: _bioController.text.trim(),
        profileImageUrl: imageUrl,
      );

      messenger.showSnackBar(
        const SnackBar(content: Text('プロフィールを更新しました')),
      );
      navigator.pop();
    } catch (_) {
      if (mounted) {
        setState(() => _isSaving = false);
      }
      messenger.showSnackBar(
        const SnackBar(
          content: Text('更新に失敗しました'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasExistingImage = (widget.user.profileImageUrl ?? '').isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('プロフィール編集')),
      body: AbsorbPointer(
        absorbing: _isSaving,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 48,
                            backgroundColor: Colors.grey.shade200,
                            backgroundImage: _previewImageBytes != null
                                ? MemoryImage(_previewImageBytes!)
                                : hasExistingImage
                                ? CachedNetworkImageProvider(
                                    widget.user.profileImageUrl!,
                                  )
                                : null,
                            child:
                                _previewImageBytes == null && !hasExistingImage
                                ? const Icon(
                                    Icons.person,
                                    size: 48,
                                    color: Colors.grey,
                                  )
                                : null,
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Material(
                              color: Theme.of(context).colorScheme.primary,
                              shape: const CircleBorder(),
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: _pickImage,
                                child: const Padding(
                                  padding: EdgeInsets.all(6),
                                  child: Icon(
                                    Icons.camera_alt,
                                    size: 18,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _usernameController,
                      decoration: const InputDecoration(
                        labelText: 'ユーザー名',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if ((value?.trim() ?? '').isEmpty) {
                          return 'ユーザー名を入力してください';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _bioController,
                      decoration: const InputDecoration(
                        labelText: '自己紹介',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                      maxLines: null,
                      minLines: 3,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isSaving ? null : _save,
                      child: _isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('保存する'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
