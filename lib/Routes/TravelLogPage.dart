import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:travel_log/Routes/TripDetailsPage.dart';
import '../Models/UserModel.dart';

class TravelLogPage extends StatefulWidget{
  @override
  State<TravelLogPage> createState() => _TravelLogPageState();
}

class _TravelLogPageState extends State<TravelLogPage>{
  UserModel userData = UserModel();

  late String _timeString;
  late Timer _timer;

  // All trips from DB, tripData is the filtered list displayed.
  List<Map<String, dynamic>> allTrips = [];
  List<Map<String, dynamic>> tripData = [];

  // Search controller
  final TextEditingController _searchController = TextEditingController();

  Future<void> getTripData() async {
    Database db = await userData.initDB();
    final List<Map<String, dynamic>> fetched = await userData.getData(db);

    // Make sure lists are non-null
    allTrips = List<Map<String, dynamic>>.from(fetched);
    // Initially show all trips
    tripData = List<Map<String, dynamic>>.from(allTrips);

    setState(() {});
  }

  @override
  void initState(){
    super.initState();
    _timeString = _formatedTimeString(DateTime.now());

    _timer = Timer.periodic(const Duration(seconds: 1), (timer){
      setState(() {
        _timeString = _formatedTimeString(DateTime.now());
      });
    });

    // listen to clear events (optional) or handle via onChanged
    _searchController.addListener(() {
      _filterTrips(_searchController.text);
    });

    getTripData();
  }

  String _formatedTimeString(DateTime time){
    return "${time.hour.toString().padLeft(2,'0')}:"
        "${time.minute.toString().padLeft(2,'0')}";
  }

  // Filtering logic: case-insensitive match against title, location or date
  void _filterTrips(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      setState(() {
        tripData = List<Map<String, dynamic>>.from(allTrips);
      });
      return;
    }

    final filtered = allTrips.where((row) {
      final title = (row['title'] ?? '').toString().toLowerCase();
      final location = (row['location'] ?? '').toString().toLowerCase();
      final date = (row['date'] ?? '').toString().toLowerCase();

      // If date is stored in another format or contains time, user can type a substring.
      return title.contains(q) || location.contains(q) || date.contains(q);
    }).toList();

    setState(() {
      tripData = filtered;
    });
  }

  // Helper to clear search
  void _clearSearch() {
    _searchController.clear();
    _filterTrips('');
    FocusScope.of(context).unfocus();
  }

  void removeAt(id) async{
    final db = await userData.initDB();
    await userData.deleteData(db, id);
    debugPrint(tripData.toString());
    setState(() {
      tripData.removeWhere((trip) => trip['ID'] == id); // delete from list by id
    });
    ScaffoldMessenger.of(this.context).clearSnackBars();
    ScaffoldMessenger.of(this.context).showSnackBar(
        SnackBar(content: Text('Deleted Successfully!',textAlign: TextAlign.center,style: TextStyle(
          fontSize: 16,fontWeight: FontWeight.bold,color: Colors.white,
        ),),
          duration: Duration(seconds: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          margin: EdgeInsets.symmetric(vertical: 100,horizontal: 50),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Color(0xE2191818),
        )
    );

    debugPrint("Deleted item with ID: $id");
  }

  @override
  Widget build(BuildContext context){
    final height = MediaQuery.of(context).size.height;
    final width = MediaQuery.of(context).size.width;

    return Scaffold(
      body: Padding(
        padding: EdgeInsets.all(30),
        child: Center(
          child: Column(
            children: [
              Row(
                children: [
                  Text(
                    _timeString,
                    style: TextStyle(
                        fontFamily: 'Intern',fontWeight: FontWeight.w600,fontSize: 24,color: Color(
                        0xff4c4c4c)
                    ),
                  ),
                  const Spacer(),
                  PopupMenuButton(
                    color: Color(0xFFF5F5F5),
                    elevation: 0.5,
                    offset: Offset(0,40),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    icon: const Icon(Icons.more_horiz,size: 40,),
                    itemBuilder: (context) => [
                      PopupMenuItem(value: 1,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Icon(Icons.stacked_line_chart,size: 30,color: Color(
                                0xff636368),),
                            const Text('Statistics',
                              style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 22,
                            ),),
                          ],
                        ),
                      ),
                    ],
                    onSelected: (value){
                      if(value == 1){
                        Navigator.pushNamed(context, '/statistic');
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20,),
              Row(
                children: [
                  const Text(
                    'Travel Log',
                    style: TextStyle(
                      fontSize: 45,fontWeight: FontWeight.bold,fontFamily: 'Intern',color: Color(0xff3c3c3c),
                    ),
                  ),
                  const Spacer(),
                ],
              ),
              const SizedBox(height: 20,),
              //Search Box
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search trips (title, location or date)',
                  hintStyle: TextStyle(fontSize: 20,color: Colors.black54),
                  prefixIcon: const Icon(Icons.search, color: Colors.black54, size: 28,),
                  prefixIconConstraints: const BoxConstraints(
                    minWidth: 60,
                    minHeight: 40,
                  ),
                  // Clear button when there's text
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                    icon: Icon(Icons.clear),
                    onPressed: _clearSearch,
                  )
                      : null,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.black12,width: 2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.black54,width: 3),
                  ),
                ),
                style: TextStyle(fontSize: 18),
                onChanged: (value){
                  _filterTrips(value);
                },
              ),
              const SizedBox(height: 30,),
              Expanded(
                child: (tripData.isEmpty)
                    ? Center(child: Text('No Data'))
                    : ListView.separated(
                  physics: BouncingScrollPhysics(),
                  itemCount: tripData.length,
                  itemBuilder: (context,index){
                    var row = tripData[index];
                    var id = row['ID'];
                    // parse imagePaths JSON to List<String>
                    List<dynamic> imagesDynamic = [];
                    try {
                      if (row['imagePaths'] != null && row['imagePaths'] is String
                          && (row['imagePaths'] as String).isNotEmpty) {
                        imagesDynamic = jsonDecode(row['imagePaths']);
                      }
                    } catch (e) {
                      imagesDynamic = [];
                    }
                    String? firstImagePath;
                    if (imagesDynamic.isNotEmpty) {
                      firstImagePath = imagesDynamic.first as String?;
                    }

                    return Stack(
                      children : [
                        ElevatedButton(
                          onPressed: () {
                            debugPrint("Id : $id");
                            Navigator.push(context,MaterialPageRoute(builder: (context) => TripDetailsPage(id: id)))
                                .then((_) => getTripData()); // refreshes when coming back
                          },
                          style: ElevatedButton.styleFrom(
                            elevation: 0,
                            padding: EdgeInsets.zero,
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: Container(
                            width: width * 0.90,
                            height: height * 0.16,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F5F5),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                double parentWidth = constraints.maxWidth;
                                double parentHeight = constraints.maxHeight;

                                double innerHeight = parentHeight - 40;

                                return Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Container(
                                        height: innerHeight * 0.9,
                                        width: parentWidth * 0.25,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(12),
                                          image: DecorationImage(
                                            image: (firstImagePath == null || firstImagePath.isEmpty)
                                                ? const AssetImage('assets/Images/Paris.jpg') as ImageProvider
                                                : FileImage(File(firstImagePath)),
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 20),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Flexible(
                                              child: Text(
                                                row['title'] ?? '',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 20,
                                                  color: Color(0xff3c3c3c),
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 1,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Flexible(
                                              child: Text(
                                                row['location'] ?? '',
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w400,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 2,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              row['date'] ?? '',
                                              style: const TextStyle(
                                                fontSize: 14,
                                                color: Colors.blueGrey,
                                                fontWeight: FontWeight.w400,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 20,
                          child: GestureDetector(
                            onTap: () => removeAt(id),
                            child: Container(
                              height: 40,
                              width: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                              ),
                              padding: EdgeInsets.all(6),
                              child: Icon(Icons.delete, size: 24, color: Color(0xff5d9dff)),
                            ),
                          ),
                        ),
                      ]
                    );
                  },
                  separatorBuilder: (context,index){
                    return SizedBox(height: 20,);
                  },
                ),
              ),
              const SizedBox(height: 20,),
              ElevatedButton(
                onPressed: (){
                  Navigator.pushNamed(context, '/addDetails').then((_) => getTripData());
                },
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: width * 0.34,vertical: height * 0.02),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  backgroundColor: Color(0xff5d9dff),
                ),
                child: Text('Add',style: TextStyle(
                  fontWeight: FontWeight.bold,color: Colors.white,fontSize: 28,
                ),),
              ),
              const SizedBox(height: 20,),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose(){
    _timer.cancel();
    _searchController.dispose();
    super.dispose();
  }
}
