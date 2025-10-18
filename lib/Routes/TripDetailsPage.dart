import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:url_launcher/url_launcher.dart';
import '../Models/UserModel.dart';
import 'package:flutter/material.dart';

/// TripDetailsPage
/// Loads a single trip's details from local SQLite DB (via UserModel)
/// Shows time (updates every second)
/// Displays images (horizontal gallery) with full-screen preview on tap
/// Allows opening the trip location in maps
class TripDetailsPage extends StatefulWidget {
  final int id; // The trip ID passed from the list page (used for locating record)
  const TripDetailsPage({super.key, required this.id});
  @override
  State<TripDetailsPage> createState() => _TripDetailsPageState();
}

class _TripDetailsPageState extends State<TripDetailsPage> {
  // DB model helper
  UserModel user = UserModel();

  // String timer
  late String _timeString;
  late Timer _timer;

  // Trip fields loaded from DB
  String? _title;
  String? _location;
  String? _desc;

  // Raw JSON string from DB and parsed list of image paths
  String _imagePath = ""; // stored JSON string ('["/path/img1.jpg", ...]')
  List<String> _imagePathsList = [];

  // Local copy of all trip rows fetched (used to pick the specific trip)
  List<Map<String, dynamic>> _tripData = [];

  // Loading flag to prevent multiple simultaneous launches
  bool _isLoading = false;

  // ------------------ openLocationOnMap and _showSnackBar ------------------
  /// Attempts to open the given placeName in Google Maps (web search URL).
  /// Uses url_launcher and handles errors + loading state.
  Future<void> openLocationOnMap(String? placeName) async {
    if (_isLoading) return; // avoid concurrent attempts
    setState(() => _isLoading = true);

    if (placeName == null || placeName.trim().isEmpty) {
      _showSnackBar('No valid location provided.', isError: true);
      setState(() => _isLoading = false);
      return;
    }

    try {
      final encoded = Uri.encodeComponent(placeName);
      final Uri googleMapsWeb =
      Uri.parse('https://www.google.com/maps/search/?api=1&query=$encoded');
      debugPrint('Opening maps search URL: $googleMapsWeb');

      if (await canLaunchUrl(googleMapsWeb)) {
        await launchUrl(googleMapsWeb, mode: LaunchMode.externalApplication);
      } else {
        _showSnackBar('No app available to open Maps URL.', isError: true);
      }
    } catch (e) {
      debugPrint('openLocationOnMap error: $e');
      _showSnackBar('Failed to open location: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Utility to show an information or error SnackBar.
  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ------------------ getTripData: parse imagePaths JSON ------------------
  /// Loads all trips from DB and populates fields for the trip with id = widget.id.
  /// NOTE: current implementation uses `widget.id - 1` as an index into the fetched list.
  /// That works if your DB returns rows in insertion order and IDs are contiguous starting at 1.
  /// If your DB ordering or IDs differ, consider fetching by ID in UserModel.
  // Load trip data by ID (safe — does not assume row order)
  Future<void> getTripData() async {
    final db = await user.initDB();

    // Use new getById to fetch specific row
    final row = await user.getById(db, widget.id);

    if (row == null) {
      _showSnackBar('Trip not found', isError: true);
      return;
    }

    _title = row['title'] as String?;
    _location = row['location'] as String?;
    _desc = row['description'] as String?;
    _imagePath = row['imagePaths'] as String? ?? '';

    // Parse JSON string to List<String>
    try {
      final parsed = jsonDecode(_imagePath);
      if (parsed is List) {
        _imagePathsList = parsed.map((e) => e.toString()).toList();
      } else {
        _imagePathsList = [];
      }
    } catch (e) {
      debugPrint('Failed to parse imagePaths JSON: $e');
      _imagePathsList = [];
    }

    setState(() {});
  }


  /// Formats the time for display as "HH:mm".
  String _formattedTimeString(DateTime time) {
    return "${time.hour.toString().padLeft(2, '0')}:"
        "${time.minute.toString().padLeft(2, '0')}";
  }

  @override
  void initState() {
    super.initState();

    // Initialize and update the clock every second.
    _timeString = _formattedTimeString(DateTime.now());
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _timeString = _formattedTimeString(DateTime.now());
      });
    });

    // Load trip data for display
    getTripData();
  }

  // ------------------ Image preview dialog ------------------
  /// Shows a full-screen preview of the tapped image (InteractiveViewer).
  /// If the file doesn't exist, shows a small "not found" placeholder.
  void _openPreview(int tappedIndex) {
    showDialog(
      context: context,
      builder: (_) {
        final imagePath = _imagePathsList[tappedIndex];
        final file = File(imagePath);
        return Dialog(
          backgroundColor: Colors.black,
          insetPadding: EdgeInsets.all(8),
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: InteractiveViewer(
              child: file.existsSync()
                  ? Image.file(file, fit: BoxFit.contain)
                  : Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  SizedBox(height: 30),
                  Icon(Icons.broken_image, size: 80, color: Colors.white70),
                  SizedBox(height: 16),
                  Text('Image not found', style: TextStyle(color: Colors.white70)),
                  SizedBox(height: 30),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height.roundToDouble();
    final width = MediaQuery.of(context).size.width.roundToDouble();

    return Scaffold(
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Center(
          child: Column(
            children: [
              // Top row: time + menu
              Row(
                children: [
                  Text(
                    _timeString,
                    style: TextStyle(
                      fontFamily: 'Intern',
                      fontWeight: FontWeight.w600,
                      fontSize: 24,
                      color: Color(0xff4c4c4c),
                    ),
                  ),
                  const Spacer(),
                  PopupMenuButton(
                    color: Color(0xFFF5F5F5),
                    elevation: 0.5,
                    offset: Offset(0, 40),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    icon: const Icon(
                      Icons.more_horiz,
                      size: 40,
                    ),
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 1,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Icon(
                              Icons.stacked_line_chart,
                              size: 30,
                              color: Color(0xff636368),
                            ),
                            const Text(
                              'Statistics',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 22,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    onSelected: (value) {
                      if (value == 1) {
                        Navigator.pushNamed(context, '/statistic');
                      }
                    },
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Page title
              Row(
                children: [
                  Text(
                    'Trip Details',
                    style: TextStyle(
                      fontSize: 45,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Intern',
                      color: Color(0xff3c3c3c),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Title
              Row(
                children: [
                  Flexible(
                    child: Text(
                      _title ?? 'No Title',
                      style: TextStyle(
                        fontFamily: 'Intern',
                        fontWeight: FontWeight.bold,
                        fontSize: 30,
                        color: Color(0xff303030),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Location
              Row(
                children: [
                  Flexible(
                    child: Text(
                      _location ?? 'No Location Available',
                      style: TextStyle(
                        fontFamily: 'Intern',
                        fontWeight: FontWeight.w400,
                        fontSize: 20,
                        color: Color(0xff303030),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // ------------------ IMAGE GALLERY (horizontal) ------------------
              // If images are present, show a horizontal ListView of thumbnails.
              if (_imagePathsList.isNotEmpty) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Photos',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xff303030),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 130,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _imagePathsList.length,
                    separatorBuilder: (_, __) => SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final path = _imagePathsList[index];
                      final file = File(path);
                      final exists = file.existsSync();

                      return GestureDetector(
                        onTap: () => _openPreview(index),
                        child: Container(
                          width: 200,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.12),
                                blurRadius: 6,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: exists
                                ? Image.file(file, fit: BoxFit.cover)
                                : Container(
                              color: Colors.grey[200],
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.broken_image, size: 36),
                                  SizedBox(height: 6),
                                  Text('Not found', style: TextStyle(fontSize: 12)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
              ] else ...[
                // If no images present, show a small hint
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'No photos added',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Notes / description
              Row(
                children: [
                  Text(
                    'Notes',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xff303030),
                    ),
                  )
                ],
              ),

              const SizedBox(height: 10),

              Row(
                children: [
                  Flexible(
                    child: Text(
                      _desc ?? '',
                      style: TextStyle(
                        fontFamily: 'Intern',
                        fontWeight: FontWeight.w600,
                        fontSize: 22,
                        color: Color(0xff303030),
                      ),
                    ),
                  ),
                ],
              ),

              Spacer(),

              // Button to open the trip location in maps
              ElevatedButton(
                onPressed: () {
                  if (_location != null) {
                    openLocationOnMap(_location!);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('No Location Provided')),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: width * 0.18, vertical: height * 0.02),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  backgroundColor: Color(0xFFECECEC),
                  shadowColor: Colors.transparent,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.location_on_rounded, color: Color(0xff5d9dff), size: 40),
                    SizedBox(width: 10),
                    Text(
                      'View on Map',
                      style: TextStyle(fontWeight: FontWeight.w500, fontSize: 24, color: Colors.black),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }
}
