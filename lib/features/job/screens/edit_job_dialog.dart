import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../data/models/job_post_model.dart';
import '../providers/job_post_provider.dart';
import '../../../core/utils/snackbar_helper.dart';

class EditJobDialog extends StatefulWidget {
  final JobPostModel job;

  const EditJobDialog({super.key, required this.job});

  @override
  State<EditJobDialog> createState() => _EditJobDialogState();
}

class _EditJobDialogState extends State<EditJobDialog> {
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late List<String> _currentMedia;
  final List<String> _mediaToDelete = [];
  final List<XFile> _newMediaFiles = [];
  final ImagePicker _picker = ImagePicker();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.job.title);
    _descController = TextEditingController(text: widget.job.description);
    _currentMedia = List.from(widget.job.mediaUrls);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(source: source);
      if (image != null) {
        setState(() {
          _newMediaFiles.add(image);
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  void _pickVideo() async {
    try {
      final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
      if (video != null) {
        setState(() {
          _newMediaFiles.add(video);
        });
      }
    } catch (e) {
      debugPrint('Error picking video: $e');
    }
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo),
              title: const Text('Gallery Image'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam),
              title: const Text('Gallery Video'),
              onTap: () {
                Navigator.pop(context);
                _pickVideo();
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);

    final success = await context.read<JobPostProvider>().updateJob(
      widget.job.id,
      _titleController.text,
      _descController.text,
      null,
      _newMediaFiles.map((e) => e.path).toList(),
      mediaToDelete: _mediaToDelete,
    );

    if (mounted) {
      if (success) {
        SnackBarHelper.showSuccess(context, "Job updated successfully");
        Navigator.pop(context); // Close dialog
      } else {
        SnackBarHelper.showError(context, "Failed to update job");
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Edit Job"),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: "Title", border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descController,
                decoration: const InputDecoration(labelText: "Description", border: OutlineInputBorder()),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              const Text("Attachments", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),

              // Existing Media
              if (_currentMedia.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _currentMedia.map((url) {
                    return Stack(
                      children: [
                        Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                            image: url.endsWith('.jpg') || url.endsWith('.png')
                                ? DecorationImage(image: NetworkImage(url), fit: BoxFit.cover)
                                : null,
                          ),
                          child: url.contains('video') || url.endsWith('.mp4')
                              ? const Icon(Icons.videocam, color: Colors.purple)
                              : (url.endsWith('.jpg') || url.endsWith('.png')
                                  ? null
                                  : const Icon(Icons.insert_drive_file, color: Colors.grey)),
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _currentMedia.remove(url);
                                _mediaToDelete.add(url);
                              });
                            },
                            child: const CircleAvatar(
                              radius: 10,
                              backgroundColor: Colors.red,
                              child: Icon(Icons.close, size: 12, color: Colors.white),
                            ),
                          ),
                        )
                      ],
                    );
                  }).toList(),
                ),

              const SizedBox(height: 12),
              if (_newMediaFiles.isNotEmpty)
                const Text("New Attachments", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 8),

              // New Media
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ..._newMediaFiles.map((file) {
                    return Stack(
                      children: [
                        Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                            image: file.path.endsWith('.jpg') || file.path.endsWith('.png')
                                ? DecorationImage(image: FileImage(File(file.path)), fit: BoxFit.cover)
                                : null,
                          ),
                          child: file.path.endsWith('.mp4')
                              ? const Icon(Icons.videocam, color: Colors.purple)
                              : (file.path.endsWith('.jpg') || file.path.endsWith('.png')
                                  ? null
                                  : const Icon(Icons.file_present)),
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _newMediaFiles.remove(file);
                              });
                            },
                            child: const CircleAvatar(
                              radius: 10,
                              backgroundColor: Colors.red,
                              child: Icon(Icons.close, size: 12, color: Colors.white),
                            ),
                          ),
                        )
                      ],
                    );
                  }),
                  // Add Button
                  InkWell(
                    onTap: _showAttachmentOptions,
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade400, style: BorderStyle.solid),
                      ),
                      child: const Icon(Icons.add, color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
        ElevatedButton(
          onPressed: _isSaving ? null : _saveChanges,
          child: _isSaving 
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
            : const Text("Save Changes"),
        ),
      ],
    );
  }
}
