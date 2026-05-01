enum AnalyticsPeriod {
  day('day', '日'),
  week('week', '周'),
  month('month', '月');

  const AnalyticsPeriod(this.value, this.label);

  final String value;
  final String label;
}

class TrendPointModel {
  const TrendPointModel({
    required this.label,
    required this.passengers,
    required this.revenue,
  });

  final String label;
  final int passengers;
  final double revenue;
}

class RouteAnalyticsModel {
  const RouteAnalyticsModel({
    required this.routeName,
    required this.passengers,
    required this.revenue,
    required this.vehicleUtilization,
  });

  final String routeName;
  final int passengers;
  final double revenue;
  final double vehicleUtilization;
}

class AdminAnalyticsSnapshot {
  const AdminAnalyticsSnapshot({
    required this.period,
    required this.totalPassengers,
    required this.totalRevenue,
    required this.vehicleUtilization,
    required this.trend,
    required this.routeRanking,
  });

  final AnalyticsPeriod period;
  final int totalPassengers;
  final double totalRevenue;
  final double vehicleUtilization;
  final List<TrendPointModel> trend;
  final List<RouteAnalyticsModel> routeRanking;
}
