import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../theme/app_theme.dart';
import '../repositories/profile_repository.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/options_sheet.dart';
import '../widgets/thumbnail.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _repo = ProfileRepository();
  final _nameController = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  String? _avatarPath;
  bool _pickingAvatar = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final name = await _repo.getDisplayName();
    final avatarPath = await _repo.getAvatarPath();
    if (!mounted) return;
    setState(() {
      _nameController.text = name;
      _avatarPath = avatarPath;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    await _repo.setDisplayName(name);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  void _pickAvatar() {
    showOptionsSheet(
      context,
      options: [
        SheetOption(
          icon: Icons.photo_camera_outlined,
          label: 'Take Photo',
          onTap: () => _setAvatarFrom(ImageSource.camera),
        ),
        SheetOption(
          icon: Icons.photo_library_outlined,
          label: 'Choose from Gallery',
          onTap: () => _setAvatarFrom(ImageSource.gallery),
        ),
      ],
    );
  }

  Future<void> _setAvatarFrom(ImageSource source) async {
    final picked = await ImagePicker().pickImage(source: source, maxWidth: 1024, imageQuality: 85);
    if (picked == null || !mounted) return;

    setState(() => _pickingAvatar = true);
    final dir = await getApplicationSupportDirectory();
    final savedPath = p.join(dir.path, 'avatar${p.extension(picked.path)}');
    await File(picked.path).copy(savedPath);
    await _repo.setAvatarPath(savedPath);

    if (!mounted) return;
    setState(() {
      _avatarPath = savedPath;
      _pickingAvatar = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.accent),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  // ── App bar ────────────────────────────────────────────────
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(
                          Icons.arrow_back_ios_new,
                          color: AppColors.textPrimary,
                          size: 20,
                        ),
                      ),
                      const Expanded(
                        child: Text(
                          'Edit Profile',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: AppFonts.sans,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),

                  const SizedBox(height: 16),

                  Center(
                    child: GestureDetector(
                      onTap: _pickingAvatar ? null : _pickAvatar,
                      child: Stack(
                        children: [
                          CircleThumbnail(size: 100, imagePath: _avatarPath),
                          if (_pickingAvatar)
                            const Positioned.fill(
                              child: CircleAvatar(
                                backgroundColor: Colors.black45,
                                child: SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                                ),
                              ),
                            ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: const BoxDecoration(
                                color: AppColors.accent,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.camera_alt, size: 16, color: AppColors.background),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  const Text(
                    'NAME',
                    style: TextStyle(
                      fontFamily: AppFonts.mono,
                      fontSize: 11,
                      letterSpacing: 1.2,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nameController,
                    autofocus: true,
                    style: const TextStyle(
                      fontFamily: AppFonts.sans,
                      color: AppColors.textPrimary,
                      fontSize: 15,
                    ),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.surfaceHigh,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (_) => _save(),
                  ),

                  const SizedBox(height: 28),

                  ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.background,
                            ),
                          )
                        : const Text('Save'),
                  ),
                ],
              ),
      ),
    );
  }
}
