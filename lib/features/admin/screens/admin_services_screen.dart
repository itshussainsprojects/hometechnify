import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/constants.dart';
import '../../../core/services/admin_api_service.dart';
import '../../../core/services/socket_service.dart';
import '../../../core/theme/neu_theme.dart';

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
    // Catches a change made from a different admin session/tab — this one
    // refetches live instead of only reflecting its own edits.
    SocketService().onCatalogUpdated = () {
      if (mounted) { _loadCategories(); _loadServices(); }
    };
  }

  @override
  void dispose() {
    SocketService().onCatalogUpdated = null;
    _tab.dispose();
    super.dispose();
  }

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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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

  Widget _neuIconButton({required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: NeuTheme.sm(radius: 10),
        child: Icon(icon, size: 15, color: color),
      ),
    );
  }

  Widget _neuActionButton({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: NeuTheme.raised(radius: 12),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: NeuTheme.bg,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: NeuTheme.inset(radius: 16),
            child: TabBar(
              controller: _tab,
              labelColor: Colors.white,
              unselectedLabelColor: AppColors.textSecondary,
              indicator: BoxDecoration(borderRadius: BorderRadius.circular(12), gradient: AppColors.primaryGradient),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(icon: Icon(Icons.category_rounded, size: 18), text: 'Categories'),
                Tab(icon: Icon(Icons.build_rounded, size: 18), text: 'Services'),
              ],
            ),
          ),
        ),
        Expanded(child: TabBarView(controller: _tab, children: [
          // CATEGORIES TAB
          Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${_categories.length} Categories', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _neuActionButton(icon: Icons.add_rounded, label: 'Add Category', color: AppColors.primaryBlue, onTap: () => _showCategoryDialog()),
                      _neuIconButton(icon: Icons.refresh_rounded, color: AppColors.textSecondary, onTap: _loadCategories),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(child: _loadingCats ? const Center(child: CircularProgressIndicator()) :
              GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 200, crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: 1.1),
                itemCount: _categories.length,
                itemBuilder: (ctx, i) {
                  final c = _categories[i] as Map<String, dynamic>;
                  final serviceCount = (c['_count']?['services'] as int?) ?? 0;
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: NeuTheme.raised(radius: 18),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Container(
                        width: 56, height: 56,
                        decoration: NeuTheme.circle(),
                        alignment: Alignment.center,
                        child: c['icon_url'] != null && (c['icon_url'] as String).isNotEmpty
                            ? ClipOval(child: Image.network(c['icon_url'] as String, width: 44, height: 44, fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => const Icon(Icons.category_rounded, color: AppColors.primaryBlue, size: 24)))
                            : const Icon(Icons.category_rounded, color: AppColors.primaryBlue, size: 24),
                      ),
                      const SizedBox(height: 10),
                      Text(c['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text('$serviceCount services', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      const SizedBox(height: 10),
                      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        _neuIconButton(icon: Icons.edit_rounded, color: AppColors.primaryBlue, onTap: () => _showCategoryDialog(existing: c)),
                        const SizedBox(width: 8),
                        _neuIconButton(icon: Icons.delete_outline_rounded, color: AppColors.error, onTap: () async { final ok = await adminApiService.deleteCategory(c['id']); if (ok) _loadCategories(); }),
                      ]),
                    ]),
                  ).animate(delay: Duration(milliseconds: i * 50)).fadeIn(duration: 300.ms).scale(begin: const Offset(0.9, 0.9));
                },
              ),
            ),
          ]),

          // SERVICES TAB
          Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${_services.length} Services', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _neuActionButton(icon: Icons.add_rounded, label: 'Add Service', color: AppColors.success, onTap: () => _showServiceDialog()),
                      _neuIconButton(icon: Icons.refresh_rounded, color: AppColors.textSecondary, onTap: _loadServices),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(
                    children: [
                      _tradeFilterChip('All', null),
                      ..._categories.map((c) => _tradeFilterChip(c['name'] as String, c['id'] as String)),
                    ],
                  )),
                ],
              ),
            ),
            Expanded(child: _loadingServices ? const Center(child: CircularProgressIndicator()) :
              ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _services.length,
                itemBuilder: (ctx, i) {
                  final s = _services[i] as Map<String, dynamic>;
                  final cat = s['category'] as Map<String, dynamic>?;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: NeuTheme.raised(radius: 16),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(
                        width: 48, height: 48,
                        decoration: NeuTheme.circle(),
                        alignment: Alignment.center,
                        child: (s['icon_url'] != null && (s['icon_url'] as String).isNotEmpty)
                            ? ClipOval(child: Image.network(s['icon_url'] as String, width: 38, height: 38, fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => const Icon(Icons.build_rounded, color: AppColors.success, size: 20)))
                            : const Icon(Icons.build_rounded, color: AppColors.success, size: 20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(s['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                          const SizedBox(height: 3),
                          Text('${cat?['name'] ?? 'Uncategorized'} • Rs. ${s['price'] != null ? (s['price'] as num).toStringAsFixed(0) : '0'}', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          if (s['min_price'] != null || s['max_price'] != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 5),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: NeuTheme.inset(radius: 8),
                                child: Text(
                                  'Bid range: Rs. ${s['min_price'] != null ? (s['min_price'] as num).toStringAsFixed(0) : '0'} – ${s['max_price'] != null ? (s['max_price'] as num).toStringAsFixed(0) : '∞'}',
                                  style: const TextStyle(fontSize: 10.5, color: AppColors.primaryDark, fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                          if (s['description'] != null) ...[
                            const SizedBox(height: 4),
                            Text(s['description'] as String, style: TextStyle(fontSize: 11, color: AppColors.textHint), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ],
                        ]),
                      ),
                      const SizedBox(width: 8),
                      Column(mainAxisSize: MainAxisSize.min, children: [
                        _neuIconButton(icon: Icons.edit_rounded, color: AppColors.primaryBlue, onTap: () => _showServiceDialog(existing: s)),
                        const SizedBox(height: 8),
                        _neuIconButton(icon: Icons.delete_outline_rounded, color: AppColors.error, onTap: () async { final ok = await adminApiService.deleteService(s['id']); if (ok) _loadServices(); }),
                      ]),
                    ]),
                  ).animate(delay: Duration(milliseconds: i * 30)).fadeIn(duration: 260.ms);
                },
              ),
            ),
          ]),
        ])),
      ]),
    );
  }

  Widget _tradeFilterChip(String label, String? value) {
    final isSelected = _selectedCategoryId == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () { setState(() => _selectedCategoryId = value); _loadServices(); },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: isSelected
              ? BoxDecoration(borderRadius: BorderRadius.circular(20), gradient: AppColors.primaryGradient)
              : NeuTheme.sm(radius: 20),
          child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isSelected ? Colors.white : AppColors.textSecondary)),
        ),
      ),
    );
  }
}
