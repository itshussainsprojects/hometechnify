import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/constants.dart';
import '../../../core/services/admin_api_service.dart';

class AdminServicesScreen extends StatefulWidget {
  const AdminServicesScreen({super.key});

  @override
  State<AdminServicesScreen> createState() => _AdminServicesScreenState();
}

class _AdminServicesScreenState extends State<AdminServicesScreen> with SingleTickerProviderStateMixin {
  late final TabController _tab;
  List<dynamic> _categories = [];
  List<dynamic> _services = [];
  bool _loadingCats = true, _loadingServices = true;
  String? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _loadCategories();
    _loadServices();
  }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  Future<void> _loadCategories() async {
    setState(() => _loadingCats = true);
    try {
      final data = await adminApiService.fetchCategories();
      setState(() { _categories = data; _loadingCats = false; });
    } catch (e) {
      debugPrint('Error loading categories: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load categories: $e')));
      setState(() => _loadingCats = false);
    }
  }

  Future<void> _loadServices() async {
    setState(() => _loadingServices = true);
    try {
      final data = await adminApiService.fetchServices(categoryId: _selectedCategoryId);
      setState(() { _services = data; _loadingServices = false; });
    } catch (e) {
      debugPrint('Error loading services: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load services: $e')));
      setState(() => _loadingServices = false);
    }
  }

  /// Square icon picker used by both the category and service dialogs.
  /// [existingUrl] is the icon already saved on the server, [picked] the file
  /// the admin just chose (which wins until saved).
  Widget _iconPicker({
    required String? existingUrl,
    required String? picked,
    required VoidCallback onPick,
    required VoidCallback onClear,
  }) {
    final hasPicked = picked != null;
    final hasExisting = existingUrl != null && existingUrl.isNotEmpty;

    return Row(
      children: [
        GestureDetector(
          onTap: onPick,
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.grey100,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.grey200),
              image: hasPicked
                  ? DecorationImage(image: FileImage(File(picked)), fit: BoxFit.cover)
                  : hasExisting
                      ? DecorationImage(image: NetworkImage(existingUrl), fit: BoxFit.cover)
                      : null,
            ),
            child: (hasPicked || hasExisting)
                ? null
                : const Icon(Icons.add_photo_alternate_outlined,
                    color: AppColors.textSecondary),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton.icon(
                onPressed: onPick,
                icon: const Icon(Icons.upload_rounded, size: 16),
                label: Text(hasPicked || hasExisting ? 'Change icon' : 'Upload icon'),
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
              ),
              if (hasPicked || hasExisting)
                TextButton.icon(
                  onPressed: onClear,
                  icon: const Icon(Icons.close_rounded, size: 16, color: AppColors.error),
                  label: const Text('Remove', style: TextStyle(color: AppColors.error)),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<String?> _pickIcon() async {
    final file = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 512);
    return file?.path;
  }

  void _showCategoryDialog({Map<String, dynamic>? existing}) {
    final nameCtrl = TextEditingController(text: existing?['name'] ?? '');
    String? existingIcon = existing?['icon_url'];
    String? pickedIcon;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(existing == null ? 'New Category' : 'Edit Category'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Category Name *', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            _iconPicker(
              existingUrl: existingIcon,
              picked: pickedIcon,
              onPick: () async {
                final p = await _pickIcon();
                if (p != null) setD(() => pickedIcon = p);
              },
              onClear: () => setD(() {
                pickedIcon = null;
                existingIcon = null;
              }),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.isEmpty) return;
                Navigator.pop(context);
                if (existing == null) {
                  await adminApiService.createCategory(nameCtrl.text, iconPath: pickedIcon);
                } else {
                  await adminApiService.updateCategory(
                    existing['id'],
                    name: nameCtrl.text,
                    iconPath: pickedIcon,
                    // Sending '' clears a removed icon; null leaves it untouched.
                    iconUrl: pickedIcon == null && existingIcon == null ? '' : null,
                  );
                }
                _loadCategories();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showServiceDialog({Map<String, dynamic>? existing}) {
    final nameCtrl = TextEditingController(text: existing?['name'] ?? '');
    final priceCtrl = TextEditingController(text: (existing?['price'] ?? '').toString());
    final descCtrl = TextEditingController(text: existing?['description'] ?? '');
    final minCtrl = TextEditingController(text: existing?['min_price'] != null ? (existing!['min_price'] as num).toStringAsFixed(0) : '');
    final maxCtrl = TextEditingController(text: existing?['max_price'] != null ? (existing!['max_price'] as num).toStringAsFixed(0) : '');
    String? selectedCatId = existing?['category_id'] ?? _selectedCategoryId ?? (_categories.isNotEmpty ? _categories.first['id'] : null);
    String? existingIcon = existing?['icon_url'];
    String? pickedIcon;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(builder: (ctx, setD) => AlertDialog(
        title: Text(existing == null ? 'New Service' : 'Edit Service'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          _iconPicker(
            existingUrl: existingIcon,
            picked: pickedIcon,
            onPick: () async {
              final p = await _pickIcon();
              if (p != null) setD(() => pickedIcon = p);
            },
            onClear: () => setD(() {
              pickedIcon = null;
              existingIcon = null;
            }),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: selectedCatId,
            decoration: const InputDecoration(labelText: 'Category *', border: OutlineInputBorder()),
            items: _categories.map((c) => DropdownMenuItem<String>(value: c['id'] as String, child: Text(c['name'] as String))).toList(),
            onChanged: (v) => setD(() => selectedCatId = v),
          ),
          const SizedBox(height: 12),
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Service Name *', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: priceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Recommended Price (Rs.)', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          // Smart Bidding — optional price fence (leave blank for open bidding)
          Row(children: [
            Expanded(child: TextField(controller: minCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Min Bid (Rs.)', hintText: 'optional', border: OutlineInputBorder()))),
            const SizedBox(width: 10),
            Expanded(child: TextField(controller: maxCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Max Bid (Rs.)', hintText: 'optional', border: OutlineInputBorder()))),
          ]),
          const SizedBox(height: 6),
          const Align(alignment: Alignment.centerLeft, child: Text('Bids outside this range are blocked. Leave blank for open bidding.', style: TextStyle(fontSize: 11, color: AppColors.textHint))),
          const SizedBox(height: 12),
          TextField(controller: descCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder())),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.isEmpty || selectedCatId == null) return;
              final minV = double.tryParse(minCtrl.text.trim());
              final maxV = double.tryParse(maxCtrl.text.trim());
              if (minV != null && maxV != null && minV > maxV) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Min bid cannot be greater than Max bid')));
                return;
              }
              Navigator.pop(context);
              if (existing == null) {
                await adminApiService.createService(
                  categoryId: selectedCatId!,
                  name: nameCtrl.text,
                  price: double.tryParse(priceCtrl.text) ?? 0,
                  description: descCtrl.text.isEmpty ? null : descCtrl.text,
                  minPrice: minV,
                  maxPrice: maxV,
                  iconPath: pickedIcon,
                );
              } else {
                await adminApiService.updateService(
                  existing['id'],
                  name: nameCtrl.text,
                  price: double.tryParse(priceCtrl.text),
                  description: descCtrl.text.isEmpty ? null : descCtrl.text,
                  minPrice: minV,
                  maxPrice: maxV,
                  iconPath: pickedIcon,
                );
              }
              _loadServices();
            },
            child: const Text('Save'),
          ),
        ],
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        color: AppColors.white,
        child: TabBar(
          controller: _tab,
          labelColor: AppColors.primaryBlue,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primaryBlue,
          tabs: const [
            Tab(icon: Icon(Icons.category_rounded), text: 'Categories'),
            Tab(icon: Icon(Icons.build_rounded), text: 'Services'),
          ],
        ),
      ),
      Expanded(child: TabBarView(controller: _tab, children: [
        // CATEGORIES TAB
        Column(children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            color: AppColors.grey50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${_categories.length} Categories', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _showCategoryDialog(),
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: const Text('Add Category'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    ),
                    const SizedBox(width: 8),
                    IconButton(icon: const Icon(Icons.refresh_rounded, size: 20), onPressed: _loadCategories),
                  ],
                ),
              ],
            ),
          ),
          Expanded(child: _loadingCats ? const Center(child: CircularProgressIndicator()) :
            GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 200, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.2),
              itemCount: _categories.length,
              itemBuilder: (ctx, i) {
                final c = _categories[i] as Map<String, dynamic>;
                final serviceCount = (c['_count']?['services'] as int?) ?? 0;
                return Container(
                  decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.grey100),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)]),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    c['icon_url'] != null && (c['icon_url'] as String).isNotEmpty
                        ? CircleAvatar(radius: 24, backgroundImage: NetworkImage(c['icon_url'] as String))
                        : Container(width: 48, height: 48, decoration: BoxDecoration(color: AppColors.primaryBlue.withValues(alpha: 0.1), shape: BoxShape.circle), child: const Icon(Icons.category_rounded, color: AppColors.primaryBlue, size: 24)),
                    const SizedBox(height: 8),
                    Text(c['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14), textAlign: TextAlign.center),
                    Text('$serviceCount services', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      InkWell(onTap: () => _showCategoryDialog(existing: c), child: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: AppColors.primaryBlue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.edit_rounded, size: 14, color: AppColors.primaryBlue))),
                      const SizedBox(width: 8),
                      InkWell(onTap: () async { final ok = await adminApiService.deleteCategory(c['id']); if (ok) _loadCategories(); }, child: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.delete_outline_rounded, size: 14, color: AppColors.error))),
                    ]),
                  ]),
                ).animate(delay: Duration(milliseconds: i * 50)).fadeIn(duration: 300.ms).scale(begin: const Offset(0.9, 0.9));
              },
            ),
          ),
        ]),

        // SERVICES TAB
        Column(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: AppColors.grey50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${_services.length} Services', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => _showServiceDialog(),
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: const Text('Add Service'),
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                        ),
                        const SizedBox(width: 8),
                        IconButton(icon: const Icon(Icons.refresh_rounded, size: 20), onPressed: _loadServices),
                      ],
                    ),
                  ],
                ),
              const SizedBox(height: 8),
              SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(
                children: [
                  GestureDetector(
                    onTap: () { setState(() => _selectedCategoryId = null); _loadServices(); },
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: _selectedCategoryId == null ? AppColors.primaryGradient : null,
                        color: _selectedCategoryId == null ? null : AppColors.grey100,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text('All', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _selectedCategoryId == null ? Colors.white : AppColors.textSecondary)),
                    ),
                  ),
                  ..._categories.map((c) => GestureDetector(
                    onTap: () { setState(() => _selectedCategoryId = c['id'] as String); _loadServices(); },
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: _selectedCategoryId == c['id'] ? AppColors.primaryGradient : null,
                        color: _selectedCategoryId == c['id'] ? null : AppColors.grey100,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(c['name'] as String, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _selectedCategoryId == c['id'] ? Colors.white : AppColors.textSecondary)),
                    ),
                  )),
                ],
              )),
            ]),
          ),
          Expanded(child: _loadingServices ? const Center(child: CircularProgressIndicator()) :
            ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _services.length,
              itemBuilder: (ctx, i) {
                final s = _services[i] as Map<String, dynamic>;
                final cat = s['category'] as Map<String, dynamic>?;
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  tileColor: AppColors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      image: (s['icon_url'] != null && (s['icon_url'] as String).isNotEmpty)
                          ? DecorationImage(image: NetworkImage(s['icon_url'] as String), fit: BoxFit.cover)
                          : null,
                    ),
                    child: (s['icon_url'] != null && (s['icon_url'] as String).isNotEmpty)
                        ? null
                        : const Icon(Icons.build_rounded, color: AppColors.success, size: 20),
                  ),
                  title: Text(s['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const SizedBox(height: 2),
                    Text('${cat?['name'] ?? 'Uncategorized'} • Rs. ${s['price'] != null ? (s['price'] as num).toStringAsFixed(0) : '0'}', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    if (s['min_price'] != null || s['max_price'] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: AppColors.primaryBlue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                          child: Text(
                            'Bid range: Rs. ${s['min_price'] != null ? (s['min_price'] as num).toStringAsFixed(0) : '0'} – ${s['max_price'] != null ? (s['max_price'] as num).toStringAsFixed(0) : '∞'}',
                            style: const TextStyle(fontSize: 10.5, color: AppColors.primaryDark, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    if (s['description'] != null) Text(s['description'] as String, style: TextStyle(fontSize: 11, color: AppColors.textHint), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ]),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(icon: const Icon(Icons.edit_rounded, size: 18, color: AppColors.primaryBlue), onPressed: () => _showServiceDialog(existing: s)),
                    IconButton(icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error), onPressed: () async { final ok = await adminApiService.deleteService(s['id']); if (ok) _loadServices(); }),
                  ]),
                );
              },
            ),
          ),
        ]),
      ])),
    ]);
  }
}
