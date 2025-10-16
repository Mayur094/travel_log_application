import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class UserModel {
  Database? _db;

  /// Initialize and cache the database instance.
  Future<Database> initDB() async {
    if (_db != null) return _db!;
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'Details.db');

    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // Create table with imagePaths stored as a JSON string.
        await db.execute('''
          CREATE TABLE tripDetails(
            ID INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT,
            location TEXT,
            date TEXT,
            description TEXT,
            imagePaths TEXT
          )
        ''');
      },
    );
    return _db!;
  }

  /// Optional helper to close DB when you no longer need it.
  Future<void> closeDB() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
  }

  /// Insert a trip record. imagePathsJson must be a JSON string (e.g. '[]' or '["/path/a"]').
  Future<void> insertData(
      Database db,
      String title,
      String location,
      String date,
      String description,
      String imagePathsJson,
      ) async {
    await db.insert(
      'tripDetails',
      {
        'title': title,
        'location': location,
        'date': date,
        'description': description,
        'imagePaths': imagePathsJson,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Fetch all trip rows ordered by newest first.
  Future<List<Map<String, dynamic>>> getData(Database db) async {
    return await db.query('tripDetails', orderBy: 'ID DESC');
  }

  /// Delete a trip by its ID.
  Future<void> deleteData(Database db, int id) async {
    await db.delete(
      'tripDetails',
      where: 'ID = ?',
      whereArgs: [id],
    );
  }
}
