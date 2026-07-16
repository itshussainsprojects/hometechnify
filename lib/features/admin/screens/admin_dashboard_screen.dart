import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/constants/constants.dart';
import '../../../core/services/admin_api_service.dart';
import 'admin_users_screen.dart';
import 'admin_providers_screen.dart';
import 'provider_verification_admin_screen.dart';
import 'admin_bookings_screen.dart';
import 'admin_services_screen.dart';
import 'admin_ratings_screen.dart';
import 'admin_radius_screen.dart';
import 'admin_commission_screen.dart';
import 'admin_provider_details_screen.dart';
import 'admin_finance_screen.dart';
import 'admin_withdrawals_screen.dart';
import 'admin_notification_screen.dart';
import 'admin_promos_screen.dart';
import 'admin_user_auth_screen.dart';
import 'admin_provider_auth_screen.dart';
import 'admin_recycle_bin_screen.dart';
import 'admin_provider_recycle_bin_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedNavIndex = 0;
  Map<String, dynamic>? _stats;
  bool _isLoading = true;
  String? _error;

  final List<Map<String, dynamic>> _navItems = [
    {'icon': Icons.dashboard_rounded, 'label': 'Dashboard'},
    {'icon': Icons.people_outline_rounded, 'label': 'Users'},
    {'icon': Icons.engineering_rounded, 'label': 'Providers'},
    {'icon': Icons.verified_user_rounded, 'label': 'Verify Documents'},
    {'icon': Icons.event_note_rounded, 'label': 'Bookings'},
    {'icon': Icons.category_rounded, 'label': 'Services'},
    {'icon': Icons.local_offer_rounded, 'label': 'Promos'},
    {'icon': Icons.campaign_rounded, 'label': 'Notifications'},
    {'icon': Icons.account_balance_wallet_rounded, 'label': 'Finance'},
    {'icon': Icons.payments_rounded, 'label': 'Withdrawals'},
    {'icon': Icons.admin_panel_settings_rounded, 'label': 'Auth'},
    {'icon': Icons.delete_sweep_rounded, 'label': 'Recycle Bin'},
    {'icon': Icons.star_rounded, 'label': 'Ratings'},
    {'icon': Icons.my_location_rounded, 'label': 'Provider Radius (km)'},
    {'icon': Icons.percent_rounded, 'label': 'Commission (%)'},
    {'icon': Icons.badge_rounded, 'label': 'Provider Details'},
  ];

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final stats = await adminApiService.fetchDashboardStats();
      setState(() { _stats = stats; _isLoading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width >= 1024;
    final isTablet = size.width >= 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Row(
          children: [
            if (isTablet) _buildSidebar(isDesktop),
            Expanded(
              child: Column(
                children: [
                  _buildTopBar(isDesktop),
                  Expanded(child: _buildContent()),
                ],
              ),
            ),
          ],
        ),
      ),
      drawer: isTablet ? null : _buildDrawer(),
    );
  }

  Widget _buildSidebar(bool isDesktop, {BuildContext? drawerContext}) {
    return Container(
      width: isDesktop ? 260 : 80,
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [BoxShadow(color: AppColors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(2, 0))],
      ),
      child: SafeArea(
        child: Column(
          children: [
          Container(
            padding: EdgeInsets.all(isDesktop ? 24 : 16),
            child: Row(
              mainAxisAlignment: isDesktop ? MainAxisAlignment.start : MainAxisAlignment.center,
              children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.home_repair_service_rounded, color: Colors.white, size: 26),
                ),
                if (isDesktop) ...[
                  const SizedBox(width: 12),
                  const Text('HomeTechnify', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.symmetric(horizontal: isDesktop ? 16 : 8),
              itemCount: _navItems.length,
              itemBuilder: (context, index) {
                final item = _navItems[index];
                final isSelected = _selectedNavIndex == index;
                return Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        setState(() => _selectedNavIndex = index);
                        if (!isDesktop) {
                          if (drawerContext != null) {
                            Navigator.pop(drawerContext);
                          } else {
                            Navigator.pop(context);
                          }
                        }
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: isDesktop ? 16 : 12, vertical: 14),
                        decoration: BoxDecoration(
                          gradient: isSelected ? AppColors.primaryGradient : null,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: isDesktop ? MainAxisAlignment.start : MainAxisAlignment.center,
                          children: [
                            Icon(item['icon'] as IconData, size: 22,
                                color: isSelected ? Colors.white : AppColors.grey500),
                            if (isDesktop) ...[
                              const SizedBox(width: 12),
                              Text(item['label'] as String,
                                  style: TextStyle(fontSize: 14,
                                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                      color: isSelected ? Colors.white : AppColors.textSecondary)),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: isDesktop ? 16 : 12, vertical: isDesktop ? 12 : 8),
            child: Row(
              mainAxisAlignment: isDesktop ? MainAxisAlignment.start : MainAxisAlignment.center,
              children: [
                Container(
                  width: isDesktop ? 36 : 32, height: isDesktop ? 36 : 32,
                  decoration: BoxDecoration(gradient: AppColors.primaryGradient, shape: BoxShape.circle),
                  child: Center(child: Text('A', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: isDesktop ? 13 : 11))),
                ),
                if (isDesktop) ...[
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      Text('Admin', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                      Text('Super Admin', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    ]),
                  ),
                ],
              ],
            ),
          ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(bool isDesktop) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 24 : 16, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [BoxShadow(color: AppColors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          if (!isDesktop && MediaQuery.of(context).size.width < 600)
            Builder(
              builder: (ctx) => IconButton(
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.menu_rounded), 
                onPressed: () => Scaffold.of(ctx).openDrawer()
              )
            ),
          Expanded(
            child: Text(
              _navItems[_selectedNavIndex]['label'] as String,
              style: TextStyle(
                fontSize: isDesktop ? 22 : 18, 
                fontWeight: FontWeight.w800, 
                color: AppColors.textPrimary
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          
          if (_selectedNavIndex == 0)
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: Icon(Icons.refresh_rounded, color: AppColors.primaryBlue, size: isDesktop ? 24 : 20),
              onPressed: _loadStats,
              tooltip: 'Refresh Stats',
            ),
          
          SizedBox(width: isDesktop ? 16 : 8),
          
          GestureDetector(
            onTap: () {
              context.read<AuthProvider>().logout();
              Navigator.pushNamedAndRemoveUntil(context, '/admin/login', (route) => false);
            },
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: isDesktop ? 16 : 10, vertical: isDesktop ? 10 : 8),
              decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.logout_rounded, color: AppColors.error, size: isDesktop ? 18 : 16),
                  if (MediaQuery.of(context).size.width > 350) ...[
                    const SizedBox(width: 8), 
                    Text('Logout', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600, fontSize: isDesktop ? 14 : 12))
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Keep these in the same order as _navItems — a mismatch silently sends the
  // admin to the wrong screen.
  Widget _buildContent() {
    switch (_selectedNavIndex) {
      case 0: return _buildDashboardContent();
      case 1: return const AdminUsersScreen();
      case 2: return const AdminProvidersScreen();
      case 3: return const ProviderVerificationAdminScreen(isEmbedded: true);
      case 4: return const AdminBookingsScreen();
      case 5: return const AdminServicesScreen();
      case 6: return const AdminPromosScreen();
      case 7: return const AdminNotificationScreen();
      case 8: return const AdminFinanceScreen();
      case 9: return const AdminWithdrawalsScreen();
      case 10: return _buildAuthTabsScreen();
      case 11: return _buildRecycleBinTabsScreen();
      case 12: return const AdminRatingsScreen();
      case 13: return const AdminRadiusScreen();
      case 14: return const AdminCommissionScreen();
      case 15: return const AdminProviderDetailsScreen();
      default: return _buildDashboardContent();
    }
  }

  Widget _buildDashboardContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.error_outline, size: 60, color: AppColors.error),
          const SizedBox(height: 16),
          Text('Failed to load stats', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(_error!, style: TextStyle(color: AppColors.textSecondary), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          ElevatedButton.icon(onPressed: _loadStats, icon: const Icon(Icons.refresh), label: const Text('Retry')),
        ]),
      );
    }

    final stats = _stats!;
    final size = MediaQuery.of(context).size;

    return SingleChildScrollView(
      padding: EdgeInsets.all(size.width < 600 ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatsGrid(stats),
          const SizedBox(height: 32),
          _buildAnalyticsSection(stats),
          const SizedBox(height: 32),
          size.width < 1200
              ? Column(children: [
                  _buildRecentBookingsWidget(),
                  const SizedBox(height: 24),
                  _buildPendingVerificationsWidget(),
                ])
              : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(flex: 3, child: _buildRecentBookingsWidget()),
                  const SizedBox(width: 24),
                  Expanded(flex: 2, child: _buildPendingVerificationsWidget()),
                ]),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(Map<String, dynamic> stats) {
    final statList = [
      {'label': 'Total Users', 'value': stats['totalUsers'].toString(), 'icon': Icons.people_outline_rounded, 'color': AppColors.primaryBlue},
      {'label': 'Verified Providers', 'value': stats['verifiedProviders'].toString(), 'icon': Icons.engineering_rounded, 'color': AppColors.success},
      {'label': 'Active Bookings', 'value': stats['activeBookings'].toString(), 'icon': Icons.event_note_rounded, 'color': AppColors.warning},
      {'label': 'Total Revenue', 'value': 'Rs. ${(stats['totalRevenue'] as num).toStringAsFixed(0)}', 'icon': Icons.trending_up_rounded, 'color': AppColors.primaryDark},
      {'label': 'Pending Verifications', 'value': stats['pendingProviders'].toString(), 'icon': Icons.pending_actions_rounded, 'color': AppColors.primaryAccent},
      {'label': 'Pending Withdrawals', 'value': 'Rs. ${(stats['pendingWithdrawalsAmount'] as num).toStringAsFixed(0)}', 'icon': Icons.payments_outlined, 'color': AppColors.error},
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate cross axis count based on available width
        int crossAxisCount = 1; // Default for mobile
        if (constraints.maxWidth > 1200) {
          crossAxisCount = 6;
        } else if (constraints.maxWidth > 900) {
          crossAxisCount = 3;
        } else if (constraints.maxWidth > 600) {
          crossAxisCount = 2;
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            mainAxisExtent: 175,
          ),
          itemCount: statList.length,
          itemBuilder: (context, index) {
            final stat = statList[index];
            return _buildStatCard(
              label: stat['label'] as String,
              value: stat['value'] as String,
              icon: stat['icon'] as IconData,
              color: stat['color'] as Color,
              delay: index * 50,
            );
          },
        );
      },
    );
  }

  Widget _buildStatCard({required String label, required String value, required IconData icon, required Color color, int delay = 0}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 24),
          ),
        ]),
        const SizedBox(height: 16),
        Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
      ]),
    ).animate(delay: Duration(milliseconds: delay)).fadeIn(duration: 400.ms).slideY(begin: 0.2);
  }

  Widget _buildAnalyticsSection(Map<String, dynamic> stats) {
    return LayoutBuilder(builder: (context, constraints) {
      final bool isMobile = constraints.maxWidth < 900;
      return isMobile
          ? Column(children: [_buildRevenueChart(stats), const SizedBox(height: 24), _buildBookingsChart(stats)])
          : Row(children: [
              Expanded(flex: 3, child: _buildRevenueChart(stats)),
              const SizedBox(width: 24),
              Expanded(flex: 2, child: _buildBookingsChart(stats)),
            ]);
    });
  }

  Widget _buildRevenueChart(Map<String, dynamic> stats) {
    final weeklyRevenue = (stats['weeklyRevenue'] as List).map((e) => (e as num).toDouble()).toList();
    final maxY = weeklyRevenue.isEmpty ? 5000.0 : (weeklyRevenue.reduce((a, b) => a > b ? a : b) * 1.2).clamp(1000.0, 200000.0);

    return Container(
      height: 400,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Revenue Overview', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800), overflow: TextOverflow.ellipsis),
              Text('Last 7 days (live)', style: TextStyle(fontSize: 12, color: AppColors.textSecondary), overflow: TextOverflow.ellipsis),
            ]),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: AppColors.primaryBlue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: const Text('Live Data', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primaryBlue)),
          ),
        ]),
        const SizedBox(height: 32),
        Expanded(
          child: LineChart(LineChartData(
            gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: maxY / 5),
            titlesData: FlTitlesData(
              show: true,
              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(sideTitles: SideTitles(
                showTitles: true, reservedSize: 30, interval: 1,
                getTitlesWidget: (v, meta) {
                  const style = TextStyle(color: AppColors.textHint, fontSize: 10, fontWeight: FontWeight.bold);
                  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                  final idx = v.toInt();
                  if (idx >= 0 && idx < days.length) return Text(days[idx], style: style);
                  return Container();
                },
              )),
            ),
            borderData: FlBorderData(show: false),
            minY: 0, maxY: maxY,
            lineBarsData: [LineChartBarData(
              spots: weeklyRevenue.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(),
              isCurved: true,
              gradient: const LinearGradient(colors: [AppColors.primaryBlue, AppColors.success]),
              barWidth: 4, isStrokeCapRound: true,
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(show: true, gradient: LinearGradient(
                colors: [AppColors.primaryBlue.withValues(alpha: 0.1), Colors.transparent],
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
              )),
            )],
          )),
        ),
      ]),
    ).animate().fadeIn(duration: 600.ms).slide(begin: const Offset(0, 0.1));
  }

  Widget _buildBookingsChart(Map<String, dynamic> stats) {
    final weeklyBookings = (stats['weeklyBookings'] as List).map((e) => (e as num).toInt()).toList();

    return Container(
      height: 400,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Booking Volume', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800), overflow: TextOverflow.ellipsis),
            Text('Daily bookings (live)', style: TextStyle(fontSize: 12, color: AppColors.textSecondary), overflow: TextOverflow.ellipsis),
          ])),
        ]),
        const SizedBox(height: 32),
        Expanded(
          child: BarChart(BarChartData(
            gridData: FlGridData(show: false),
            titlesData: FlTitlesData(
              show: true,
              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, _) {
                  const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                  final idx = v.toInt();
                  if (idx >= 0 && idx < days.length) return Text(days[idx], style: const TextStyle(color: AppColors.textHint, fontSize: 10));
                  return Container();
                },
              )),
            ),
            borderData: FlBorderData(show: false),
            barGroups: weeklyBookings.asMap().entries.map((e) => BarChartGroupData(
              x: e.key,
              barRods: [BarChartRodData(
                toY: e.value.toDouble(),
                gradient: LinearGradient(colors: [AppColors.primaryDark, AppColors.primaryBlue], begin: Alignment.bottomCenter, end: Alignment.topCenter),
                width: 16, borderRadius: BorderRadius.circular(6),
              )],
            )).toList(),
          )),
        ),
      ]),
    ).animate().fadeIn(duration: 600.ms, delay: 200.ms).slide(begin: const Offset(0, 0.1));
  }

  Widget _buildRecentBookingsWidget() {
    return FutureBuilder<List<dynamic>>(
      future: adminApiService.fetchBookings(status: 'all'),
      builder: (context, snapshot) {
        final bookings = (snapshot.data ?? []).take(5).toList();
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.grey200),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Expanded(child: Text('Live Operations', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800), overflow: TextOverflow.ellipsis)),
              TextButton.icon(
                onPressed: () => setState(() => _selectedNavIndex = 3),
                icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                label: const Text('All Activity', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ]),
            const SizedBox(height: 20),
            if (snapshot.connectionState == ConnectionState.waiting)
              const Center(child: CircularProgressIndicator())
            else if (bookings.isEmpty)
              const Center(child: Text('No bookings yet', style: TextStyle(color: AppColors.textSecondary)))
            else
              ...bookings.map((booking) {
                final status = (booking['status'] as String).toLowerCase();
                final serviceName = booking['service']?['name'] ?? 'Service';
                final customerName = booking['customer']?['name'] ?? 'Unknown';
                final providerName = booking['provider']?['name'] ?? 'Unknown';
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: AppColors.grey50, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.grey100)),
                  child: Row(children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [AppColors.primaryBlue.withValues(alpha: 0.2), AppColors.primaryBlue.withValues(alpha: 0.1)]),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.flash_on_rounded, color: AppColors.primaryBlue, size: 22),
                    ),
                    const SizedBox(width: 16),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(serviceName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                      const SizedBox(height: 2),
                      Row(children: [
                        Flexible(child: Text(customerName, style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(Icons.chevron_right_rounded, size: 12, color: AppColors.textHint),
                        ),
                        Flexible(child: Text(providerName, style: TextStyle(fontSize: 11, color: AppColors.primaryBlue, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis)),
                      ]),
                    ])),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: _getStatusColor(status).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                      child: Text(status.toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: _getStatusColor(status), letterSpacing: 0.5)),
                    ),
                  ]),
                );
              }),
          ]),
        ).animate().fadeIn(delay: 700.ms).slideX(begin: -0.1);
      },
    );
  }

  Widget _buildPendingVerificationsWidget() {
    return FutureBuilder<List<dynamic>>(
      future: adminApiService.fetchProviders(status: 'unverified'),
      builder: (context, snapshot) {
        final pending = (snapshot.data ?? []).take(4).toList();
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.grey200),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Expanded(child: Text('Approvals', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800), overflow: TextOverflow.ellipsis)),
              if (pending.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: Text('${pending.length} New', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.error)),
                ),
            ]),
            const SizedBox(height: 20),
            if (snapshot.connectionState == ConnectionState.waiting)
              const Center(child: CircularProgressIndicator())
            else if (pending.isEmpty)
              const Center(child: Icon(Icons.verified_user_rounded, size: 40, color: AppColors.success))
            else
              ...pending.map((provider) => GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/admin/providers/verification'),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.grey50, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.grey100)),
                  child: Row(children: [
                    CircleAvatar(radius: 16, backgroundColor: AppColors.warning.withValues(alpha: 0.2), child: const Icon(Icons.security, size: 16, color: AppColors.warning)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(provider['name'] ?? 'Provider', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                      Text(provider['phone'] ?? '', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                    ])),
                    IconButton(
                      icon: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 24),
                      onPressed: () async {
                        await adminApiService.verifyProvider(provider['id'], verify: true);
                        setState(() {});
                      },
                    ),
                  ]),
                ),
              )),
          ]),
        ).animate().fadeIn(delay: 900.ms).slideX(begin: 0.1);
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending': return AppColors.warning;
      case 'negotiating': return AppColors.primaryAccent;
      case 'accepted': return AppColors.primaryBlue;
      case 'ongoing': return AppColors.primaryDark;
      case 'completed': return AppColors.success;
      case 'cancelled': return AppColors.error;
      default: return AppColors.grey500;
    }
  }

  Widget _buildRecycleBinTabsScreen() {
    return DefaultTabController(
      length: 2,
      child: Column(children: [
        Container(
          color: AppColors.white,
          child: const TabBar(
            labelColor: AppColors.primaryBlue,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primaryBlue,
            tabs: [
              Tab(icon: Icon(Icons.people_outlined), text: 'Users'),
              Tab(icon: Icon(Icons.engineering_outlined), text: 'Providers'),
            ],
          ),
        ),
        const Expanded(child: TabBarView(children: [AdminRecycleBinScreen(isEmbedded: true), AdminProviderRecycleBinScreen(isEmbedded: true)])),
      ]),
    );
  }

  Widget _buildAuthTabsScreen() {
    return DefaultTabController(
      length: 2,
      child: Column(children: [
        Container(
          color: AppColors.white,
          child: const TabBar(
            labelColor: AppColors.primaryBlue,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primaryBlue,
            tabs: [
              Tab(icon: Icon(Icons.people_outlined), text: 'Users'),
              Tab(icon: Icon(Icons.engineering_outlined), text: 'Providers'),
            ],
          ),
        ),
        const Expanded(child: TabBarView(children: [AdminUserAuthScreen(), AdminProviderAuthScreen()])),
      ]),
    );
  }

  Widget? _buildDrawer() => Drawer(
    child: Builder(
      builder: (ctx) => _buildSidebar(true, drawerContext: ctx),
    ),
  );
}
