import 'dart:async';
import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:geocoding/geocoding.dart';
import '../Models/UserModel.dart';
import 'package:flutter/material.dart';

class StatisticsPage extends StatefulWidget {
  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  final UserModel userData = UserModel();

  late String _timeString;
  late Timer _timer;

  double _totalDistance = 0.0;
  int _totalTrips = 0;
  bool isDistanceLoading = true;

  List<FlSpot> chartSpots = [];
  List<String> chartLabels = [];
  bool isChartLoading = true;
  final int monthsToShow = 6;

  // format "HH:mm"
  String _formattedTime(DateTime t) =>
      "${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}";

  // geocode a list of place names -> list of [lat, lon]
  Future<List<List<double>>> geocodePlaceNames(List<String> places) async {
    final coords = <List<double>>[];
    for (final place in places) {
      //skips empty names
      if(place.trim().isEmpty) continue;

      try {
        final results = await locationFromAddress(place).timeout(const Duration(seconds: 8));
        if (results.isNotEmpty) {
          final loc = results.first;
          coords.add([loc.latitude, loc.longitude]);
        }
      } catch (e) {
        // skip places that fail to geocode
        debugPrint('Geocode failed for "$place": $e');
      }
    }
    return coords;
  }

  // haversine distance in km between two lat/lon points
  double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0;
    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degToRad(lat1)) * cos(_degToRad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  double _degToRad(double deg) => deg * pi / 180;

  // calculating total distance across consecutive trip locations (in insertion order)
  void calculateTotalDistance() async {
    setState(() {
      isDistanceLoading = true;
    });

    try {
      final db = await userData.initDB();
      // use consistent column name 'ID' for ordering
      final rows = await db.query('tripDetails', columns: ['location'], orderBy: 'ID ASC');
      final idRows = await db.query('tripDetails', columns: ['ID'], orderBy: 'ID ASC');
      await db.close();

      // update trips count
      setState(() => _totalTrips = idRows.length);

      if (rows.isEmpty) {
        setState(() {
          _totalDistance = 0.0;
          isDistanceLoading = false;
        });
        debugPrint('No rows found for distance calculation.');
        return;
      }

      final places = rows
          .map((r) => (r['location'] ?? '').toString())
          .where((s) => s.isNotEmpty)
          .toList();

      debugPrint('Places for distance calculation: $places');

      if (places.length < 2) {
        // Not enough points to compute distance
        setState(() {
          _totalDistance = 0.0;
          isDistanceLoading = false;
        });
        debugPrint('Not enough places to calculate distance (need at least 2).');
        return;
      }

      final coords = await geocodePlaceNames(places);
      debugPrint('Geocoded coords: $coords (length ${coords.length})');

      if (coords.length < 2) {
        // geocoding produced too few valid coordinates
        setState(() {
          _totalDistance = 0.0;
          isDistanceLoading = false;
        });
        debugPrint('Geocoding returned <2 coordinates — cannot compute distance.');
        return;
      }

      // sum pairwise distances
      double total = 0.0;
      for (int i = 0; i < coords.length - 1; i++) {
        final a = coords[i];
        final b = coords[i + 1];
        total += _haversineKm(a[0], a[1], b[0], b[1]);
      }

      setState(() {
        _totalDistance = total;
        isDistanceLoading = false;
      });
      debugPrint('Total distance calculated: ${_totalDistance.toStringAsFixed(3)} km');

    } catch (e) {
      debugPrint('Error calculating distance: $e');
      setState(() {
        _totalDistance = 0.0;
        isDistanceLoading = false;
      });
    }
  }


  // prepares data for trips-per-month chart
  void tripsPerMonth() async {
    setState(() => isChartLoading = true);
    try {
      final db = await userData.initDB();
      final rows = await db.query('tripDetails', columns: ['location', 'date'], orderBy: 'date ASC');
      await db.close();

      final now = DateTime.now();
      final monthsList = List.generate(monthsToShow, (i) {
        return DateTime(now.year, now.month - (monthsToShow - 1 - i), 1);
      });

      // initializes counts for each month
      final counts = {
        for (final m in monthsList) "${m.year}-${m.month.toString().padLeft(2, '0')}": 0
      };

      // count trips per month
      for (final r in rows) {
        final rawDate = r['date'];
        if (rawDate == null) continue;

        DateTime? tripDate;
        if (rawDate is int) {
          tripDate = DateTime.fromMillisecondsSinceEpoch(rawDate);
        } else if (rawDate is String) {
          try {
            tripDate = DateTime.parse(rawDate);
          } catch (_) {
            // ignore parse errors
          }
        }
        if (tripDate == null) continue;

        final key = "${tripDate.year}-${tripDate.month.toString().padLeft(2, '0')}";
        if (counts.containsKey(key)) counts[key] = (counts[key] ?? 0) + 1;
      }

      // converting counts to chart data
      final spots = <FlSpot>[];
      final labels = <String>[];
      for (int i = 0; i < monthsList.length; i++) {
        final m = monthsList[i];
        final key = "${m.year}-${m.month.toString().padLeft(2, '0')}";
        spots.add(FlSpot(i.toDouble(), (counts[key] ?? 0).toDouble()));
        labels.add(_shortMonth(m.month));
      }

      setState(() {
        chartSpots = spots;
        chartLabels = labels;
        isChartLoading = false;
      });
    } catch (e) {
      debugPrint('Error preparing chart: $e');
      setState(() {
        isChartLoading = false;
        chartSpots = [];
        chartLabels = [];
      });
    }
  }

  // short month name
  String _shortMonth(int m) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[(m - 1) % 12];
  }

  @override
  void initState() {
    super.initState();
    _timeString = _formattedTime(DateTime.now());
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _timeString = _formattedTime(DateTime.now()));
    });

    calculateTotalDistance();
    tripsPerMonth();
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final maxYValue = chartSpots.isEmpty ? 1.0 : chartSpots.map((s) => s.y).reduce(max);
    final chartMaxY = (maxYValue * 1.2).ceilToDouble();

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_timeString, style: const TextStyle(fontFamily: 'Intern', fontWeight: FontWeight.w600, fontSize: 24, color: Color(0xff4c4c4c))),
              const SizedBox(height: 20),
              const Text('Statistics', style: TextStyle(fontSize: 45, fontWeight: FontWeight.bold, fontFamily: 'Intern', color: Color(0xff3c3c3c))),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildCard(context, 'Total Trips', _totalTrips.toString()),
                  _buildCard(
                    context,
                    'Total Distance',
                    (_totalTrips == 0)
                        ? '0.0'
                        : (isDistanceLoading)
                        ? 'Calculating...'
                        : '${_totalDistance.toStringAsFixed(2)}km',
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: Card(
                  elevation: 0,
                  color: const Color(0xFFF5F5F5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(30),
                    child: isChartLoading
                        ? const Center(child: CircularProgressIndicator())
                        : (chartSpots.isEmpty
                        ? const Center(child: Text('No trip data'))
                        : LineChart(
                      LineChartData(
                        gridData: FlGridData(show: false),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              interval: 1,
                              getTitlesWidget: (value, _) {
                                if (value % 1 == 0) return Text(value.toInt().toString());
                                return const SizedBox.shrink();
                              },
                              reservedSize: 40,
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              interval: 1,
                              getTitlesWidget: (value, _) {
                                final ix = value.toInt();
                                if (ix >= 0 && ix < chartLabels.length) return Text(chartLabels[ix]);
                                return const SizedBox.shrink();
                              },
                            ),
                          ),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        borderData: FlBorderData(show: false),
                        minX: 0,
                        maxX: (chartSpots.length - 1).toDouble(),
                        minY: 0,
                        maxY: chartMaxY,
                        lineBarsData: [
                          LineChartBarData(
                            spots: chartSpots,
                            isCurved: true,
                            dotData: FlDotData(show: true),
                            belowBarData: BarAreaData(show: true, color: Colors.blue.withOpacity(0.2)),
                            barWidth: 3,
                            color: Colors.blue,
                          ),
                        ],
                      ),
                    )),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              const Text(' Wormb Lips', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  // small card widget for stats
  Widget _buildCard(BuildContext context, String title, String subtitle) {
    return Expanded(
      child: Card(
        elevation: 0,
        color: const Color(0xFFF5F5F5),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 18)),
              Text(subtitle, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}
