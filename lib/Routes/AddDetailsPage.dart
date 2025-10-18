import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../Models/UserModel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';

class AddDetails extends StatefulWidget {
  const AddDetails({super.key});

  @override
  State<AddDetails> createState() => _AddDetailsState();
}

class _AddDetailsState extends State<AddDetails> {
  // controllers
  final TextEditingController _controllerTitle = TextEditingController();
  final TextEditingController _controllerLocation = TextEditingController();
  final TextEditingController _controllerDes = TextEditingController();

  DateTime? _selectedDate;

  File? _imageFile; // preview first image
  final ImagePicker _picker = ImagePicker();
  final UserModel user = UserModel();

  List<String> imageList = []; // copied image paths
  String imagePathsJson = '[]'; // JSON to save

  // compact label with optional required marker
  Widget _label(String text, {bool required = true}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(text, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black)),
        if (required) const Text(' *', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red)),
      ],
    );
  }

  // outline border helper
  OutlineInputBorder _outlineBorder(double width, Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(width: width, color: color),
  );

  // Text field builder
  Widget _buildTextField(TextEditingController controller, String hint, {int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.black38),
        enabledBorder: _outlineBorder(2, Colors.black45),
        focusedBorder: _outlineBorder(3, Colors.black54),
      ),
    );
  }

  // coping picked file to app documents and return new path
  Future<String> _copyFileToAppDir(XFile picked) async {
    final dir = await getApplicationDocumentsDirectory();
    final newPath = join(dir.path, basename(picked.path));
    final copied = await File(picked.path).copy(newPath);
    return copied.path;
  }

  // pick multiple images from gallery
  Future<void> _pickFromGallery() async {
    try {
      final List<XFile>? pickedFiles = await _picker.pickMultiImage();
      if (pickedFiles == null || pickedFiles.isEmpty) return;

      final List<String> newPaths = [];
      for (final picked in pickedFiles) {
        final path = await _copyFileToAppDir(picked);
        newPaths.add(path);
      }

      setState(() {
        imageList.addAll(newPaths);
        imagePathsJson = jsonEncode(imageList);
        if (_imageFile == null && imageList.isNotEmpty) _imageFile = File(imageList.first);
      });
    } catch (e) {
      debugPrint('Error picking images: $e');
    }
  }

  // remove image at index and update preview
  void _removeImageAt(int index) {
    setState(() {
      final removed = imageList.removeAt(index);
      imagePathsJson = jsonEncode(imageList);
      if (_imageFile != null && _imageFile!.path == removed) {
        _imageFile = imageList.isNotEmpty ? File(imageList.first) : null;
      }
    });
  }

  // full-screen preview of tapped image
  void _openPreview(int tappedIndex) {
    showDialog(
      context: this.context,
      builder: (BuildContext dialogContext) {
        final imagePath = imageList[tappedIndex];
        final file = File(imagePath);
        return Dialog(
          backgroundColor: Colors.black,
          insetPadding: const EdgeInsets.all(8),
          child: GestureDetector(
            onTap: () => Navigator.of(dialogContext).pop(),
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

  // show date picker
  Future<void> _datePicker(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDate: _selectedDate ?? DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = DateTime(picked.year, picked.month, picked.day);
      });
    }
  }

  // save data to DB
  Future<void> saveData() async {
    try {
      Database db = await user.initDB();

      String formattedDate = _selectedDate != null ? DateFormat('yyyy-MM-dd').format(_selectedDate!) : '';

      if (imageList.isEmpty) imagePathsJson = '[]';

      await user.insertData(
        db,
        _controllerTitle.text,
        _controllerLocation.text,
        formattedDate,
        _controllerDes.text,
        imagePathsJson,
      );

      final List<Map<String, dynamic>> tripDetails = await user.getData(db);
      debugPrint('Inserted data: $tripDetails');
    } catch (e) {
      debugPrint('Error saving data: $e');
      if (mounted) ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text('Error saving: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    final width = MediaQuery.of(context).size.width;

    final String formattedDate = _selectedDate != null ? DateFormat('yyyy-MM-dd').format(_selectedDate!) : "No date selected";

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Add Details', style: TextStyle(fontSize: 40, fontWeight: FontWeight.w600, color: Color(0xff3c3c3c), fontFamily: 'Intern')),
                  const SizedBox(height: 20),

                  // Title
                  _label('Add Title'),
                  const SizedBox(height: 8),
                  _buildTextField(_controllerTitle, 'ex. Summer Vacation'),
                  const SizedBox(height: 12),

                  // Location
                  _label('Add Location'),
                  const SizedBox(height: 8),
                  _buildTextField(_controllerLocation, 'ex. Paris'),
                  const SizedBox(height: 12),

                  // Description
                  _label('Description'),
                  const SizedBox(height: 8),
                  _buildTextField(_controllerDes, 'ex. Explored the city...', maxLines: 3),
                  const SizedBox(height: 12),

                  // Date
                  _label('Date'),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: width * 0.9,
                    child: ElevatedButton(
                      onPressed: () => _datePicker(context),
                      style: ElevatedButton.styleFrom(
                        alignment: Alignment.centerLeft,
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: const BorderSide(width: 2, color: Colors.black54),
                        padding: const EdgeInsets.all(12),
                      ),
                      child: Text(formattedDate, style: const TextStyle(fontSize: 18, color: Colors.black38)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Images
                  _label('Add Images'),
                  const SizedBox(height: 8),

                  if (imageList.isNotEmpty) ...[
                    SizedBox(
                      height: 120,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: imageList.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        padding: const EdgeInsets.only(top: 8, bottom: 8),
                        itemBuilder: (context, index) {
                          final path = imageList[index];
                          final file = File(path);
                          final exists = file.existsSync();
                          return Stack(
                            children: [
                              GestureDetector(
                                onTap: () => _openPreview(index),
                                child: Container(
                                  width: 140,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 6, offset: const Offset(0, 3))],
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
                              ),
                              Positioned(
                                top: 6,
                                right: 6,
                                child: GestureDetector(
                                  onTap: () => _removeImageAt(index),
                                  child: Container(
                                    decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                    padding: const EdgeInsets.all(6),
                                    child: const Icon(Icons.delete, size: 18, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  const SizedBox(height: 8),

                  // Image pick button + count
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: _pickFromGallery,
                        child: const Text('Select Images', style: TextStyle(fontSize: 18, color: Colors.black54)),
                      ),
                      const SizedBox(width: 8),
                      if (imageList.isNotEmpty) Text('${imageList.length} selected', style: const TextStyle(fontSize: 16)),
                    ],
                  ),

                  const SizedBox(height: 40),

                  // Save button
                  Center(
                    child: ElevatedButton(
                      onPressed: () async {
                        if (_controllerTitle.text.isNotEmpty && _controllerLocation.text.isNotEmpty && _controllerDes.text.isNotEmpty) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).clearSnackBars();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('Saved Successfully!', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                                duration: const Duration(seconds: 2),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                margin: const EdgeInsets.symmetric(vertical: 100, horizontal: 50),
                                behavior: SnackBarBehavior.floating,
                                backgroundColor: const Color(0xE2191818),
                              ),
                            );
                          }
                          await saveData();
                          Navigator.pop(context,true);//Indicator that a new trip was added
                        } else {
                          if (mounted) {
                            ScaffoldMessenger.of(context).clearSnackBars();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('Please enter valid input', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                                duration: const Duration(seconds: 2),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                margin: const EdgeInsets.symmetric(vertical: 100, horizontal: 80),
                                behavior: SnackBarBehavior.floating,
                                backgroundColor: const Color(0xE2191818),
                              ),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xff5d9dff),
                        padding: EdgeInsets.symmetric(horizontal: width * 0.34, vertical: height * 0.02),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      child: const Text('Save', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),

                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
