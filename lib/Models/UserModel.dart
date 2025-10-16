import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class UserModel{
  Database? _db;
  Future<Database> initDB() async{
    if(_db != null) return _db!;
    String dbPath = await getDatabasesPath();
    String path = join(dbPath,'Details.db');

    _db = await openDatabase(
        path,
        version: 1,
        onCreate: (db,version) async{
          // Create table when DB is created first time (with imagePaths JSON)
          await db.execute('''
        CREATE TABLE tripDetails(
          ID INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT,
          location TEXT,
          date TEXT,
          description TEXT,
          imagePaths TEXT
        )''');
        },

    );
    return _db!;
  }

  // imagePathsJson is a JSON string
  Future<void> insertData(Database db, String title, String location, String date ,
      String description, String imagePathsJson) async{
    await db.insert(
      'tripDetails',
      {
        'title' : title,
        'location' : location,
        'date' : date,
        'description' : description,
        'imagePaths' : imagePathsJson
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String,dynamic>>> getData(Database db) async{
    return await db.query('tripDetails',orderBy: 'id DESC');
  }

  Future<void> deleteData(Database db, int id) async{
    await db.delete(
      'tripDetails',
      where: 'ID = ?',
      whereArgs: [id],
    );
  }
}
