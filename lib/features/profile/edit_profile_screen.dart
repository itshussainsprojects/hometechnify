import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/constants/constants.dart';
import 'package:home_technify/features/auth/providers/auth_provider.dart';
import 'package:home_technify/features/profile/providers/profile_provider.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  
  final ImagePicker _imagePicker = ImagePicker();
  File? _selectedImage;
  String? _existingImageUrl; // To display saved profile image

  @override
  void initState() {
    super.initState();
    
    // Priority: ProfileProvider (has DB data) > AuthProvider (has Firebase data)
    final profileUser = context.read<ProfileProvider>().user;
    final authUser = context.read<AuthProvider>().user;
    
    // Use profile data if available, otherwise fallback to auth data
    final user = profileUser ?? authUser;
    
    _nameController = TextEditingController(text: user?.name ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _phoneController = TextEditingController(text: user?.phone ?? '');
    _existingImageUrl = user?.profileImage;
    
    debugPrint("EditProfile initState - Using ${profileUser != null ? 'ProfileProvider' : 'AuthProvider'}");
    debugPrint("EditProfile initState - Phone: ${user?.phone}, Image: ${user?.profileImage}");
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.grey300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Change Profile Photo',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildPhotoOption(
                  icon: Icons.camera_alt_rounded,
                  label: 'Camera',
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.camera);
                  },
                ),
                _buildPhotoOption(
                  icon: Icons.photo_library_rounded,
                  label: 'Gallery',
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.gallery);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: AppColors.primaryBlue.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, size: 36, color: AppColors.primaryBlue),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      
      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Photo updated!'),
              backgroundColor: AppColors.primaryBlue,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not pick image: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmall = size.height < 700;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.grey200),
            ),
            child: Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          ),
        ),
        title: const Text(
          'Edit Profile',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Profile Photo Section
          GestureDetector(
            onTap: _showPhotoOptions,
            child: Center(
              child: Column(
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          gradient: (_selectedImage == null && _existingImageUrl == null) 
                              ? AppColors.primaryGradient 
                              : null,
                          color: (_selectedImage != null || _existingImageUrl != null) 
                              ? AppColors.grey100 
                              : null,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryBlue.withValues(alpha: 0.3),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                          image: _selectedImage != null
                              ? DecorationImage(
                                  image: FileImage(_selectedImage!),
                                  fit: BoxFit.cover,
                                )
                              : (_existingImageUrl != null && _existingImageUrl!.isNotEmpty)
                                  ? DecorationImage(
                                      image: NetworkImage(_existingImageUrl!),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                        ),
                        child: (_selectedImage == null && (_existingImageUrl == null || _existingImageUrl!.isEmpty))
                            ? Center(
                                child: Text(
                                  _nameController.text.isNotEmpty 
                                      ? _nameController.text.substring(0, _nameController.text.length < 2 ? _nameController.text.length : 2).toUpperCase()
                                      : 'U',
                                  style: const TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                              )
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryBlue.withValues(alpha: 0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 18),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Change Photo',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                ],
              ),
            ),
          ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.9, 0.9)),
          const SizedBox(height: 32),
          
          // Form Fields
          _buildTextField(
            label: 'Full Name',
            controller: _nameController,
            icon: Icons.person_outline_rounded,
            isSmall: isSmall,
            onChanged: (val) => setState(() {}),
          ),
          const SizedBox(height: 18),
          _buildTextField(
            label: 'Email',
            controller: _emailController,
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            isSmall: isSmall,
          ),
          const SizedBox(height: 18),
          _buildPhoneField(isSmall),
          const SizedBox(height: 18),
          const SizedBox(height: 32),
          
          // Save Button
          _buildSaveButton(isSmall),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    required bool isSmall,
    Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isSmall ? 13 : 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.grey200),
            boxShadow: [
              BoxShadow(
                color: AppColors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            onChanged: onChanged,
            style: TextStyle(
              fontSize: isSmall ? 14 : 15,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: AppColors.grey400, size: 22),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: isSmall ? 14 : 16,
              ),
              hintStyle: TextStyle(color: AppColors.textHint),
            ),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 300.ms).slideX(begin: 0.1, end: 0);
  }

  Widget _buildPhoneField(bool isSmall) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Phone Number',
          style: TextStyle(
            fontSize: isSmall ? 13 : 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.grey200),
            boxShadow: [
              BoxShadow(
                color: AppColors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  '+92',
                  style: TextStyle(
                    fontSize: isSmall ? 14 : 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              Container(
                width: 1,
                height: 24,
                color: AppColors.grey200,
              ),
              Expanded(
                child: TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  style: TextStyle(
                    fontSize: isSmall ? 14 : 15,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: isSmall ? 14 : 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ).animate().fadeIn(duration: 300.ms).slideX(begin: 0.1, end: 0);
  }

  Widget _buildSaveButton(bool isSmall) {
    return Consumer<ProfileProvider>(
      builder: (context, provider, _) {
       return GestureDetector(
        onTap: provider.isLoading ? null : () async {
          debugPrint("Update Profile Tapped");
          final authProvider = context.read<AuthProvider>();
          final profileProvider = context.read<ProfileProvider>();
          final messenger = ScaffoldMessenger.of(context);
          final navigator = Navigator.of(context);
          final currentUser = authProvider.user;

          if (currentUser == null) {
            debugPrint("Current user is null");
            return;
          }

          // AuthProvider's cached user is only populated at login and never
          // refreshed by a profile edit, so its profileImage goes stale the
          // moment the first save succeeds. ProfileProvider.user IS refreshed
          // on every successful save (see updateProfile below), so it's the
          // only reliable source for "the image the user didn't just change".
          String? imageUrl = profileProvider.user?.profileImage ?? currentUser.profileImage;

          // Upload Image if selected
          if (_selectedImage != null) {
             debugPrint("Uploading image...");
             final uploadedUrl = await provider.uploadImage(_selectedImage!);
             if (uploadedUrl != null) {
               imageUrl = uploadedUrl;
             } else {
               debugPrint("Image upload failed");
               if (!mounted) return;
               messenger.showSnackBar(const SnackBar(content: Text('Failed to upload image'), backgroundColor: Colors.red));
              return;
             }
          }

          final updatedUser = currentUser.copyWith(
            name: _nameController.text.trim(),
            email: _emailController.text.trim(),
            phone: _phoneController.text.trim(),
            profileImage: imageUrl,
          );

          debugPrint("Sending update for: ${updatedUser.name}");
          final success = await provider.updateProfile(updatedUser);
          debugPrint("Update Success: $success");

          if (!mounted) return;

          if (success) {
            // ProfileProvider now has the fresh row from the backend response;
            // push it into AuthProvider too so the home banner, chat, and
            // every other AuthProvider-bound screen update without a re-login.
            final freshUser = profileProvider.user;
            if (freshUser != null) {
              authProvider.syncUser(freshUser);
            }
            messenger.showSnackBar(SnackBar(
              content: const Text('Profile updated successfully!'),
              backgroundColor: AppColors.primaryBlue,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ));
            navigator.pop();
          } else {
            debugPrint("Error: ${provider.errorMessage}");
            messenger.showSnackBar(SnackBar(
              content: Text(provider.errorMessage ?? 'Update failed - check connection'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ));
          }
        },
        child: Container(
          width: double.infinity,
          height: isSmall ? 50 : 54,
          decoration: BoxDecoration(
            gradient: provider.isLoading ? null : AppColors.primaryGradient,
            color: provider.isLoading ? AppColors.grey300 : null,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryBlue.withValues(alpha: 0.4),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (provider.isLoading)
                 SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              else ...[
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 22),
                const SizedBox(width: 10),
                Text(
                  'Save Changes',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isSmall ? 15 : 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
     }
    );
  }
}
