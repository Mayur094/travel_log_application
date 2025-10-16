import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../Models/UserModel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';

class AddDetails extends StatefulWidget{
  const AddDetails({super.key});

  @override
  State<AddDetails> createState() => _AddDetailsState();
}

class _AddDetailsState extends State<AddDetails>{
  final TextEditingController _controllerTitle = TextEditingController();
  final TextEditingController _controllerLocation = TextEditingController();
  final TextEditingController _controllerDes = TextEditingController();

  DateTime? _selectedDate;

  File? _imageFile; // will hold first image for preview
  final ImagePicker _picker = ImagePicker();
  UserModel user = UserModel();

  List<String> imageList = []; // store local copied image paths
  String imagePathsJson = '[]'; // json string to save to DB

  // copy a picked file to app documents and return the new path
  Future<String> _copyFileToAppDir(XFile picked) async {
    final dir = await getApplicationDocumentsDirectory();
    final newPath = join(dir.path, basename(picked.path));
    final copied = await File(picked.path).copy(newPath);
    return copied.path;
  }

  // Pick multiple images from gallery
  Future<void> _pickFromGallery() async{
    try {
      final List<XFile> pickedFiles = await _picker.pickMultiImage();
      if (pickedFiles == null || pickedFiles.isEmpty) return;

      List<String> newPaths = [];
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

  // Remove an image from list
  void _removeImageAt(int index) {
    setState(() {
      final removed = imageList.removeAt(index);
      imagePathsJson = jsonEncode(imageList);
      // if preview was the removed image, update preview to first or null
      if (_imageFile != null && _imageFile!.path == removed) {
        _imageFile = imageList.isNotEmpty ? File(imageList.first) : null;
      }
    });
  }

  // preview image full screen
  void _openPreview(int tappedIndex) {
    showDialog(
      context: this.context,
      builder: (BuildContext dialogContext) {
        final imagePath = imageList[tappedIndex];
        final file = File(imagePath);
        return Dialog(
          backgroundColor: Colors.black,
          insetPadding: EdgeInsets.all(8),
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



  Future<void> _datePicker(BuildContext context) async{
    final DateTime? picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if(picked != null){
      setState(() {
        _selectedDate = DateTime(picked.year, picked.month, picked.day);
      });
    }
  }

  @override
  Widget build(BuildContext context){
    final height = MediaQuery.of(context).size.height;
    final width = MediaQuery.of(context).size.width;

    String formattedDate = _selectedDate != null
        ? DateFormat('yyyy-MM-dd').format(_selectedDate!)
        : "No date selected";

    Future<void> saveData() async {
      try {
        Database db = await user.initDB();

        String formattedDate = _selectedDate != null
            ? DateFormat('yyyy-MM-dd').format(_selectedDate!)
            : '';

        // If no images selected, imagePathsJson should be '[]'
        if (imageList.isEmpty) {
          imagePathsJson = '[]';
        }

        // Insert - now passes JSON string
        await user.insertData(
          db,
          _controllerTitle.text,
          _controllerLocation.text,
          formattedDate,
          _controllerDes.text,
          imagePathsJson,
        );

        // Read (for debugging)
        List<Map<String,dynamic>> tripDetails = await user.getData(db);
        debugPrint('Inserted data: $tripDetails');
      } catch (e) {
        debugPrint('Error saving data: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving: $e')),
        );
      }
    }

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          Expanded(child:SingleChildScrollView(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Add Details',style: TextStyle(
                    fontSize: 40,fontWeight: FontWeight.w600,color: Color(
                    0xff3c3c3c),fontFamily: 'Intern'
                ),),
                const SizedBox(height: 20,),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    RichText(text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'Add Title',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        TextSpan(
                            text: ' *',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            )
                        )
                      ],
                    )),
                    const SizedBox(height: 8,),
                    TextField(
                      controller: _controllerTitle,
                      decoration: InputDecoration(
                          hintText: 'ex. Summer Vacation',
                          hintStyle: TextStyle(
                            color: Colors.black38,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(width: 2,color: Colors.black45),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(width: 3,color: Colors.black54),
                          )
                      ),
                    ),

                    const SizedBox(height: 12,),
                    // Location
                    RichText(text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'Add Location',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        TextSpan(
                            text: ' *',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            )
                        )
                      ],
                    )),
                    const SizedBox(height: 8,),
                    TextField(
                      controller: _controllerLocation,
                      decoration: InputDecoration(
                          hintText: 'ex. Paris',
                          hintStyle: TextStyle(
                            color: Colors.black38,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(width: 2,color: Colors.black45),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(width: 3,color: Colors.black54),
                          )
                      ),
                    ),

                    const SizedBox(height: 12,),
                    // Description
                    RichText(text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'Description',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        TextSpan(
                            text: ' *',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            )
                        )
                      ],
                    )),
                    const SizedBox(height: 8,),
                    TextField(
                      controller: _controllerDes,
                      decoration: InputDecoration(
                          hintText: 'ex. Explored the city of lights and visited the Eiffel Tower.',
                          hintStyle: TextStyle(
                            color: Colors.black38,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(width: 2,color: Colors.black45),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(width: 3,color: Colors.black54),
                          )
                      ),
                    ),

                    const SizedBox(height: 12,),
                    // Date
                    RichText(text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'Date',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        TextSpan(
                            text: ' *',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            )
                        )
                      ],
                    )),
                    SizedBox(
                      width: width * 0.9,
                      child: ElevatedButton(
                        onPressed: (){
                          _datePicker(context);
                        },
                        style: ElevatedButton.styleFrom(
                          alignment: Alignment.centerLeft,
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(width: 2, color: Colors.black54,),
                          padding: EdgeInsets.all(12),
                        ),
                        child: Text(formattedDate,style: TextStyle(
                          fontSize: 18,color: Colors.black38,
                        ),),
                      ),
                    ),

                    const SizedBox(height: 12,),
                    // Images
                    RichText(text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'Add Images',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        TextSpan(
                            text: ' *',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            )
                        )
                      ],
                    )),
                    const SizedBox(height: 8,),
                    // HORIZONTAL GALLERY: thumbnails of selected images
                    if (imageList.isNotEmpty) ...[
                      SizedBox(
                        height: 120,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: imageList.length,
                          separatorBuilder: (_, __) => SizedBox(width: 12),
                          padding: EdgeInsets.only(top: 8, bottom: 8),
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
                                ),
                                // small remove button at top-right
                                Positioned(
                                  top: 6,
                                  right: 6,
                                  child: GestureDetector(
                                    onTap: () => _removeImageAt(index),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.black54,
                                        shape: BoxShape.circle,
                                      ),
                                      padding: EdgeInsets.all(6),
                                      child: Icon(Icons.delete, size: 18, color: Colors.white),
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
                    SizedBox(height: 8,),
                    // Buttons to pick images
                    Row(
                      children: [
                        ElevatedButton(
                          onPressed: _pickFromGallery,
                          child: Text('Select Images',style: TextStyle(
                            fontSize: 18,color: Colors.black54,
                          ),),
                        ),
                        const SizedBox(width: 8,),
                        // optional: show count
                        if (imageList.isNotEmpty)
                          Text('${imageList.length} selected', style: TextStyle(fontSize: 16))
                      ],
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
                Center(
                  child: ElevatedButton(
                    onPressed: () async {
                      if(_controllerTitle.text.isNotEmpty && _controllerLocation.text.isNotEmpty
                          && _controllerDes.text.isNotEmpty){
                        ScaffoldMessenger.of(context).clearSnackBars();
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Saved Successfully!',textAlign: TextAlign.center,style: TextStyle(
                              fontSize: 16,fontWeight: FontWeight.bold,color: Colors.white,
                            ),),
                              duration: Duration(seconds: 2),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              margin: EdgeInsets.symmetric(vertical: 100,horizontal: 50),
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: Color(0xE2191818),
                            )
                        );
                        await saveData();
                        Navigator.pop(context);
                      }
                      else{
                        ScaffoldMessenger.of(context).clearSnackBars();
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Please enter valid input',textAlign: TextAlign.center,style: TextStyle(
                              fontSize: 16,fontWeight: FontWeight.bold,color: Colors.white,
                            ),),
                              duration: Duration(seconds: 2),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              margin: EdgeInsets.symmetric(vertical: 100,horizontal: 80),
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: Color(0xE2191818),
                            )
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xff5d9dff),
                      padding: EdgeInsets.symmetric(horizontal: width * 0.34,vertical: height * 0.02),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: Text('Save',style: TextStyle(
                        fontSize: 28,fontWeight: FontWeight.bold,color: Colors.white),),
                  ),
                ),
                const SizedBox(height: 10,),
              ],
            ),
          ),
          )
        ]
      )
    );
  }
}
