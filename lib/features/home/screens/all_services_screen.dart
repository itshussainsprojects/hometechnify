// All Services Screen - Full grid of all available services

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/constants.dart';
import '../../../core/utils/responsive.dart';
import '../providers/service_provider.dart';
import '../widgets/service_card.dart';
import '../widgets/home_shimmer.dart';

class AllServicesScreen extends StatefulWidget {
  const AllServicesScreen({super.key});

  @override
  State<AllServicesScreen> createState() => _AllServicesScreenState();
}

class _AllServicesScreenState extends State<AllServicesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ServiceProvider>().loadServices();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmall = size.height < 700;
    final horizontalPadding = Responsive.horizontalPadding(context);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
        ),
        title: const Text(
          'All Services',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(68),
          child: Padding(
            padding: EdgeInsets.fromLTRB(horizontalPadding, 8, horizontalPadding, 12),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.grey50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.grey200),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 14),
                  Icon(Icons.search_rounded, color: AppColors.grey400, size: isSmall ? 18 : 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search services...',
                        hintStyle: TextStyle(
                          color: AppColors.grey400,
                          fontSize: isSmall ? 13 : 14,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      style: TextStyle(fontSize: isSmall ? 13 : 14, color: AppColors.textPrimary),
                    ),
                  ),
                  if (_searchQuery.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Icon(Icons.close_rounded, color: AppColors.grey500, size: 18),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Consumer<ServiceProvider>(
          builder: (context, provider, _) {
            if (provider.isLoading) {
              return const HomeShimmer();
            }

            final allServices = provider.services;
            final filtered = _searchQuery.isEmpty
                ? allServices
                : allServices
                    .where((s) => s.name.toLowerCase().contains(_searchQuery))
                    .toList();

            if (filtered.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.search_off_rounded, size: 64, color: AppColors.grey300),
                    const SizedBox(height: 16),
                    Text(
                      _searchQuery.isEmpty ? 'No services available' : 'No results for "$_searchQuery"',
                      style: const TextStyle(fontSize: 16, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    if (_searchQuery.isNotEmpty)
                      TextButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                        child: const Text('Clear search'),
                      ),
                  ],
                ),
              );
            }

            final crossAxisCount = size.width >= 1024 ? 5 : size.width >= 600 ? 4 : 3;
            final spacing = isSmall ? 8.0 : 12.0;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(horizontalPadding, 16, horizontalPadding, 8),
                  child: Text(
                    _searchQuery.isEmpty
                        ? '${allServices.length} Services Available'
                        : '${filtered.length} results',
                    style: TextStyle(
                      fontSize: isSmall ? 12 : 13,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Expanded(
                  child: GridView.builder(
                    padding: EdgeInsets.fromLTRB(horizontalPadding, 0, horizontalPadding, 24),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: spacing,
                      mainAxisSpacing: spacing,
                      childAspectRatio: 0.75,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      return ServiceCard(
                        data: filtered[index],
                        index: index,
                      );
                    },
                  ),
                ),
              ],
            ).animate().fadeIn(duration: 300.ms);
          },
        ),
      ),
    );
  }
}
