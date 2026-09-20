import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/providers/core_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../../../meal_log/presentation/providers/meal_log_providers.dart';
import '../../domain/entities/user_profile.dart';
import '../providers/profile_providers.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  final _fullNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _contactNoController = TextEditingController();

  bool _initialized = false;
  bool _editing = false;
  bool _saving = false;
  bool _uploadingAvatar = false;

  void _initFromProfile(UserProfile? profile) {
    if (_initialized || profile == null) return;
    _initialized = true;
    _fullNameController.text = profile.fullName ?? '';
    _usernameController.text = profile.username ?? '';
    _contactNoController.text = profile.phone ?? '';
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    _contactNoController.dispose();
    super.dispose();
  }

  void _startEditing() => setState(() => _editing = true);

  void _cancelEditing(UserProfile? profile) {
    setState(() {
      _fullNameController.text = profile?.fullName ?? '';
      _usernameController.text = profile?.username ?? '';
      _contactNoController.text = profile?.phone ?? '';
      _editing = false;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final userId = ref.read(authRepositoryProvider).currentUserId;
    if (userId == null) return;

    setState(() => _saving = true);
    try {
      await ref.read(updateProfileUseCaseProvider)(
        userId: userId,
        username: _usernameController.text.trim(),
        fullName: _fullNameController.text.trim(),
        phone: _contactNoController.text.trim(),
      );
      ref.invalidate(currentUserProfileProvider);
      await ref.read(mealLogProvider.notifier).refreshProfile();
      if (!mounted) return;
      setState(() => _editing = false);
      showAppSnackBar(context, 'Profile updated');
    } catch (err) {
      if (!mounted) return;
      showAppSnackBar(context, '$err');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickAvatar() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(LucideIcons.camera),
              title: const Text('Take photo'),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(LucideIcons.image),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null) return;

    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 90,
    );
    if (picked == null) return;
    if (!mounted) return;

    final userId = ref.read(authRepositoryProvider).currentUserId;
    if (userId == null) return;
    final previousAvatarPath = ref
        .read(currentUserProfileProvider)
        .valueOrNull
        ?.avatarPath;

    setState(() => _uploadingAvatar = true);
    try {
      await ref.read(uploadAvatarUseCaseProvider)(
        userId: userId,
        imagePath: picked.path,
        previousAvatarPath: previousAvatarPath,
      );
      ref.invalidate(currentUserProfileProvider);
      await ref.read(mealLogProvider.notifier).refreshProfile();
      if (!mounted) return;
      showAppSnackBar(context, 'Profile photo updated');
    } catch (err) {
      if (!mounted) return;
      showAppSnackBar(context, '$err');
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentUserProfileProvider);
    profileAsync.whenData(_initFromProfile);
    final profile = profileAsync.valueOrNull;
    final email = ref.watch(authRepositoryProvider).currentUserEmail;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Profile'),
        actions: [
          if (_editing)
            TextButton(
              onPressed: () => _cancelEditing(profile),
              child: const Text('Cancel'),
            ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: _ProfileAvatar(
                  avatarPath: profile?.avatarPath,
                  uploading: _uploadingAvatar,
                  onTap: _pickAvatar,
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  _fullNameController.text.isEmpty
                      ? 'Add your name'
                      : _fullNameController.text,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Center(
                child: Text(
                  _usernameController.text.isEmpty
                      ? 'No username set'
                      : _usernameController.text,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(height: 24),
              _ProfileSection(
                title: 'Personal info',
                children: [
                  _ProfileField(
                    icon: LucideIcons.user,
                    label: 'Full name',
                    controller: _fullNameController,
                    editing: _editing,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  _ProfileField(
                    icon: LucideIcons.at_sign,
                    label: 'Username',
                    controller: _usernameController,
                    editing: _editing,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  _ProfileField(
                    icon: LucideIcons.mail,
                    label: 'Email',
                    value: email,
                    editing: _editing,
                    readOnly: true,
                  ),
                  _ProfileField(
                    icon: LucideIcons.phone,
                    label: 'Contact no.',
                    controller: _contactNoController,
                    editing: _editing,
                    keyboardType: TextInputType.phone,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: _editing
                    ? FilledButton(
                        onPressed: _saving ? null : _save,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.onScrim,
                          disabledBackgroundColor: AppColors.textDisabled,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.onScrim,
                                ),
                              )
                            : const Text('Save changes'),
                      )
                    : OutlinedButton(
                        onPressed: _startEditing,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                        ),
                        child: const Text('Edit profile'),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileAvatar extends ConsumerWidget {
  const _ProfileAvatar({
    required this.avatarPath,
    required this.uploading,
    required this.onTap,
  });

  final String? avatarPath;
  final bool uploading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = avatarPath;
    final avatarUrl = path == null
        ? null
        : ref.watch(avatarRepositoryProvider).publicUrlFor(path);

    return GestureDetector(
      onTap: uploading ? null : onTap,
      child: Stack(
        children: [
          CircleAvatar(
            radius: 44,
            backgroundColor: AppColors.surfaceMuted,
            backgroundImage: avatarUrl == null ? null : NetworkImage(avatarUrl),
            child: avatarUrl == null
                ? const Icon(
                    LucideIcons.circle_user,
                    size: 56,
                    color: AppColors.textTertiary,
                  )
                : null,
          ),
          if (uploading)
            const CircleAvatar(
              radius: 44,
              backgroundColor: Colors.black38,
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.onScrim,
                ),
              ),
            ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary,
              ),
              child: const Icon(
                LucideIcons.camera,
                size: 14,
                color: AppColors.onScrim,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textTertiary,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                children[i],
                if (i != children.length - 1)
                  const Divider(height: 1, color: AppColors.divider),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileField extends StatelessWidget {
  const _ProfileField({
    required this.icon,
    required this.label,
    this.controller,
    this.value,
    required this.editing,
    this.keyboardType,
    this.validator,
    this.readOnly = false,
  }) : assert(
         controller != null || value != null,
         'either controller (editable fields) or value (readOnly fields) must be set',
       );

  final IconData icon;
  final String label;

  /// Editable fields pass a live [TextEditingController]. Read-only fields
  /// (Email) have no controller of their own — [value] is used instead so
  /// this widget doesn't need to create/own one just to display text.
  final TextEditingController? controller;
  final String? value;

  final bool editing;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  /// When true, this field always renders as display-only text, never a
  /// [TextFormField], regardless of [editing] — used for Email, which has
  /// no update path on this screen (see `ProfileScreen` plan notes).
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final showEditor = editing && !readOnly;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: AppColors.textPrimary),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: SizedBox(
              height: 20,
              child: Align(
                alignment: Alignment.centerRight,
                child: showEditor
                    ? TextFormField(
                        controller: controller,
                        keyboardType: keyboardType,
                        validator: validator,
                        textAlign: TextAlign.end,
                        maxLines: 1,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                        decoration: const InputDecoration(
                          isCollapsed: true,
                          contentPadding: EdgeInsets.zero,
                          border: InputBorder.none,
                          errorStyle: TextStyle(fontSize: 0, height: 0),
                        ),
                      )
                    : _buildDisplayText(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisplayText() {
    final text = controller?.text ?? value ?? '';
    return Text(
      text.isEmpty ? '—' : text,
      textAlign: TextAlign.end,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
    );
  }
}
