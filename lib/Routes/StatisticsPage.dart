import 'dart:async';
import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:geocoding/geocoding.dart';
import '../Models/UserModel.dart';
import 'package:flutter/material.dart';

class StatisticsPage extends StatefulWidget{
  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage>{
  UserModel userData = UserModel();

  late String _timeString;
  late Timer _timer;

  double _totalDistance = 0.0;
  int _totalTrips = 0;

  List<FlSpot> chartSpots = [];
  List<String> chartLabels = [];
  bool isChartLoading = true;
  int monthsToShow = 6;


  String _formatedTimeString(DateTime time){
    return "${time.hour.toString().padLeft(2,'0')}:"
        "${time.minute.toString().padLeft(2,'0')}";
  }

  /// Converting place name strings to lat/lng using geocoding package.
  /// Returns list of pairs [latitude, longitude].
  /// If geocoding fails for an item, that item is skipped.
  Future<List<List<double>>> geocodePlaceNames(List<String> places) async {
    List<List<double>> coords = [];
    for (final place in places) {
      try {
        final results = await locationFromAddress(place); // from geocoding package
        if (results.isNotEmpty) {
          final loc = results.first;
          coords.add([loc.latitude, loc.longitude]);
        }
      } catch (e) {
        // geocoding failed for this place — skip or handle logging
        debugPrint('Geocode failed for $place: $e');
      }
    }
    return coords;
  }

  /// Haversine formula: distance in kilometers between two lat/lon pairs
  double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0; // Earth's radius in km
    double dLat = _degToRad(lat2 - lat1);
    double dLon = _degToRad(lon2 - lon1);
    double a = sin(dLat/2) * sin(dLat/2) +
        cos(_degToRad(lat1)) * cos(_degToRad(lat2)) *
            sin(dLon/2) * sin(dLon/2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }
  double _degToRad(double deg) => deg * pi / 180;

  /// Calculating the Total Distance of all the places
  void calculateTotalDistance() async{
    try{
      final db = await userData.initDB();
      final rows = await db.query('tripDetails', columns: ['location'], orderBy: 'id ASC');
      final idRows = await db.query('tripDetails',columns: ['id'],orderBy: 'id ASC');
      await db.close();

      if(idRows.isNotEmpty) {
        setState(() {
          _totalTrips = idRows.length;
        });
      }


        if(rows.isEmpty) return;
        List<String> places = rows.map((r) {
          final value = r['location'];
          return value == null ? '' : value.toString();
        }).where((s) => s.isNotEmpty).toList();

        if(places.isEmpty){
          setState(() {
            _totalDistance = 0.0;
            return;
          });
        }

        final coords = await geocodePlaceNames(places);
        double total = 0.0;
        for (int i = 0; i < coords.length - 1; i++) {
          final a = coords[i];
          final b = coords[i + 1];
          total += _haversineKm(a[0], a[1], b[0], b[1]);
        }

        setState(() {
          _totalDistance = total;
        });
    }
    catch(e){
      debugPrint("Error calculating Distance : $e");
      setState(() {
        _totalDistance = 0.0;
      });
    }
  }

  void tripsPerMonth() async{
    setState(() => isChartLoading = true);
    try {
      final db = await userData.initDB();
      final rows = await db.query(
        'tripDetails',
        columns: ['location', 'date'],
        orderBy: 'date ASC',
      );
      await db.close();

      debugPrint("value added");

      // Prepare last 6 months
      final now = DateTime.now();
      final monthsList = List.generate(monthsToShow, (i) {
        return DateTime(now.year, now.month - (monthsToShow - 1 - i), 1);
      });

      // Initialize counts map
      Map<String, int> counts = {
        for (final m in monthsList)
          "${m.year}-${m.month.toString().padLeft(2, '0')}": 0
      };

      // Count how many trips per month
      for (final r in rows) {
        final rawDate = r['date'];
        if (rawDate == null) continue;

        DateTime? tripDate;
        if (rawDate is int) {
          tripDate = DateTime.fromMillisecondsSinceEpoch(rawDate);
        } else if (rawDate is String) {
          try {
            tripDate = DateTime.parse(rawDate);
          } catch (_) {}
        }

        if (tripDate == null) continue;
        final key =
            "${tripDate.year}-${tripDate.month.toString().padLeft(2, '0')}";
        if (counts.containsKey(key)) {
          counts[key] = (counts[key] ?? 0) + 1;
        }
      }

      // Convert counts to chart spots
      List<FlSpot> spots = [];
      List<String> labels = [];
      int index = 0;

      for (final m in monthsList) {
        final key = "${m.year}-${m.month.toString().padLeft(2, '0')}";
        spots.add(FlSpot(index.toDouble(), (counts[key] ?? 0).toDouble()));
        labels.add(_shortMonth(m.month));
        index++;
      }

      setState(() {
        chartSpots = spots;
        chartLabels = labels;
        isChartLoading = false;
      });
      debugPrint('chartSpots: ${chartSpots.map((s) => s.y).toList()}');

    }
    catch (e) {
      setState(() {
        isChartLoading = false;
        chartSpots = [];
        chartLabels = [];
      });
      debugPrint("No value added");
    }
  }

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
    _timeString = _formatedTimeString(DateTime.now());

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _timeString = _formatedTimeString(DateTime.now());
      });
    });
    calculateTotalDistance();
    tripsPerMonth();
  }

  @override
  Widget build(BuildContext context){
    final maxYValue = chartSpots.isEmpty ? 1.0 : chartSpots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final chartMaxY = (maxYValue * 1.2).ceilToDouble();
    return Scaffold(
      body: Padding(padding: EdgeInsets.all(20),
        child: Center(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _timeString,
                style: TextStyle(
                    fontFamily: 'Intern',fontWeight: FontWeight.w600,fontSize: 24,color: Color(
                    0xff4c4c4c)
                ),
              ),
              const SizedBox(height: 20,),
              const Text('Statistics', style: TextStyle(
                fontSize: 45,fontWeight: FontWeight.bold,fontFamily: 'Intern',color: Color(0xff3c3c3c),
              ),),
              const SizedBox(height: 20,),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  buildCard(context, 'Total Trips', _totalTrips.toString()),
                  buildCard(context, 'Total Distance', (_totalTrips == 0)? '0.0' :
                  (_totalDistance == 0.0)? 'Loading...' :'${_totalDistance.toStringAsFixed(2)}km'),
                ],
              ),
              const SizedBox(height: 20,),
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
                                getTitlesWidget: (value, meta) {
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
                                getTitlesWidget: (value, meta) {
                                  final ix = value.toInt();
                                  if (ix >= 0 && ix < chartLabels.length) {
                                    return Text(chartLabels[ix]);
                                  }
                                  return const SizedBox();
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
                              color: Colors.blue
                            ),
                          ],
                        )
                    )),
                  ),
                ),
              ),

              const SizedBox(height: 30),
              const Text(
                ' Wormb Lips',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                ),
              ),
              const SizedBox(height: 30),

            ],
          ),
        ),
      ),
    );
  }

  Widget buildCard(BuildContext context,String title,String subtitle){
    return Expanded(
        child: Card(
          elevation: 0,
          color: Color(0xFFF5F5F5),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 18,horizontal: 14),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title,style: TextStyle(fontSize: 18),),
                Text(subtitle,style: TextStyle(
                    fontSize: 24,fontWeight: FontWeight.bold
                ),),
              ],
            ),
          ),
        )
    );
  }

  @override
  void dispose(){
    _timer.cancel();
    super.dispose();
  }
}