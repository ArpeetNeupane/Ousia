import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/auth_service.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _stats;
  List<Map<String, dynamic>> _screenTimeData = [];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    final authService = AuthService();

    final statsResult = await authService.fetchAdminDashboardStats();
    final screenTimeResult = await authService.fetchScreenTimeStats();

    if (mounted) {
      setState(() {
        _stats = statsResult['success'] ? statsResult['data'] : null;
        _screenTimeData = screenTimeResult;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin Dashboard"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDashboardData,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        child:
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _stats == null
                ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: theme.dividerColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Dashboard backend is not connected yet.',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'You can still use Profile and Logout from the bottom navigation.',
                            style: theme.textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 12),
                          TextButton.icon(
                            onPressed: _loadDashboardData,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
                : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildMetricGrid(colorScheme),
                      const SizedBox(height: 24),
                      _buildSectionTitle(
                        theme,
                        "Screen Time per User (Minutes)",
                      ),
                      _buildBarChart(theme),
                      const SizedBox(height: 24),
                      _buildSectionTitle(theme, "Engagement Ratio"),
                      _buildPieChart(theme),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
      ),
    );
  }

  Widget _buildSectionTitle(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildMetricGrid(ColorScheme colorScheme) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _StatCard(
          label: "New Users",
          value: "${_stats!['new_users_past_month']}",
          subtitle: "Past 30 days",
          icon: Icons.group_add,
          color: colorScheme.primary,
        ),
        _StatCard(
          label: "New Posts",
          value: "${_stats!['new_posts_past_month']}",
          subtitle: "Past 30 days",
          icon: Icons.post_add,
          color: Colors.orange,
        ),
        _StatCard(
          label: "In Review",
          value: "${_stats!['moderation_queue_count']}",
          subtitle: "Pending AI review",
          icon: Icons.gavel,
          color: Colors.redAccent,
        ),
        _StatCard(
          label: "Retention",
          value: "${_stats!['retention_rate']}%",
          subtitle: "User loyalty",
          icon: Icons.loop,
          color: Colors.green,
        ),
      ],
    );
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  String _abbreviatedUsername(dynamic raw) {
    final username = (raw ?? '').toString().trim();
    if (username.isEmpty) return '';
    if (username.length <= 8) return username;
    return '${username.substring(0, 8)}.';
  }

  Widget _buildBarChart(ThemeData theme) {
    if (_screenTimeData.isEmpty) {
      return Container(
        height: 250,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.dividerColor),
        ),
        child: const Center(child: Text('No screen time data available.')),
      );
    }

    final maxMinutes = _screenTimeData
        .map((e) => _toDouble(e['total_minutes']))
        .fold<double>(0, (prev, curr) => curr > prev ? curr : prev);
    final maxY = maxMinutes <= 0 ? 10.0 : (maxMinutes * 1.2).ceilToDouble();
    final yInterval = ((maxY / 5).ceilToDouble().clamp(1, 100000)).toDouble();

    return Container(
      height: 250,
      padding: const EdgeInsets.all(16),
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final computedWidth = _screenTimeData.length * 56.0;
          final chartWidth =
              computedWidth < constraints.maxWidth
                  ? constraints.maxWidth
                  : computedWidth;

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: chartWidth,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceEvenly,
                  maxY: maxY,
                  barTouchData: BarTouchData(enabled: true),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 54,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index >= 0 && index < _screenTimeData.length) {
                            return Transform.rotate(
                              angle: -0.65,
                              child: Padding(
                                padding: const EdgeInsets.only(top: 10.0),
                                child: Text(
                                  _abbreviatedUsername(
                                    _screenTimeData[index]['username'],
                                  ),
                                  style: const TextStyle(fontSize: 10),
                                ),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      axisNameWidget: const Padding(
                        padding: EdgeInsets.only(bottom: 6),
                        child: Text(
                          'Minutes',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 42,
                        interval: yInterval,
                        getTitlesWidget: (value, meta) {
                          if (value < 0) return const SizedBox.shrink();
                          return Text(
                            value.toInt().toString(),
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: yInterval,
                    getDrawingHorizontalLine:
                        (value) => FlLine(
                          color: theme.dividerColor.withAlpha(120),
                          strokeWidth: 1,
                        ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: List.generate(_screenTimeData.length, (i) {
                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: _toDouble(_screenTimeData[i]['total_minutes']),
                          color: theme.colorScheme.primary,
                          width: 16,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPieChart(ThemeData theme) {
    final engagementRaw = _stats?['engagement_ratio'];
    final engagement =
        engagementRaw is Map<String, dynamic>
            ? engagementRaw
            : <String, dynamic>{};
    final active = _toDouble(engagement['active_posters']);
    final silent = _toDouble(engagement['silent_users']);
    final total = active + silent;
    final activePct = total > 0 ? ((active / total) * 100).round() : 0;
    final silentPct = total > 0 ? ((silent / total) * 100).round() : 0;

    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      child:
          total <= 0
              ? const Center(child: Text('No engagement data available.'))
              : PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                  sections: [
                    PieChartSectionData(
                      color: theme.colorScheme.primary,
                      value: active,
                      title: 'Posters\n$activePct%',
                      radius: 50,
                      titleStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    PieChartSectionData(
                      color: theme.colorScheme.tertiary,
                      value: silent,
                      title: 'Silent\n$silentPct%',
                      radius: 50,
                      titleStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 20),
              Text(
                value,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
