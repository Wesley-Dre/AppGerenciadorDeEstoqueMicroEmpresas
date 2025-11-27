import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:io';

class DatabaseHelper {
  static const _databaseName = "usuarios.db";
  static const _databaseVersion = 3;

  // Tabela de Usuários
  static const table = 'Usuarios';
  static const columnId = 'id';
  static const columnEmail = 'email';
  static const columnNome = 'nome';
  static const columnSenha = 'senha';
  static const columnNestab = 'nestab';
  static const columnCor = 'cor';

  // Tabela de Funcionários
  static const tableFuncionarios = 'Funcionarios';
  static const columnIdFunc = 'id';
  static const columnNomeFunc = 'nome';
  static const columnSenhaFunc = 'senha';
  static const columnNestabFunc = 'nestab';

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), _databaseName);
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $table (
        $columnId INTEGER PRIMARY KEY AUTOINCREMENT,
        $columnEmail TEXT NOT NULL UNIQUE,
        $columnNome TEXT NOT NULL UNIQUE,
        $columnSenha TEXT NOT NULL,
        $columnNestab TEXT NOT NULL,
        $columnCor INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableFuncionarios (
        $columnIdFunc INTEGER PRIMARY KEY AUTOINCREMENT,
        $columnNomeFunc TEXT NOT NULL,
        $columnSenhaFunc TEXT NOT NULL,
        $columnNestabFunc TEXT NOT NULL
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE $table ADD COLUMN $columnCor INTEGER');
    }
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE $tableFuncionarios (
          $columnIdFunc INTEGER PRIMARY KEY AUTOINCREMENT,
          $columnNomeFunc TEXT NOT NULL,
          $columnSenhaFunc TEXT NOT NULL,
          $columnNestabFunc TEXT NOT NULL
        )
      ''');
    }
  }

  // ---------------- FUNÇÕES USUÁRIOS ------------------

  Future<void> inserirUsuario(
    String email,
    String nome,
    String senha,
    String nestab, {
    int? cor,
  }) async {
    final db = await database;
    await db.insert(
      table,
      {
        columnEmail: email,
        columnNome: nome,
        columnSenha: senha,
        columnNestab: nestab,
        columnCor: cor,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> listarUsuarios() async {
    final db = await database;
    return await db.query(table);
  }

  Future<void> removerConta(int id) async {
    final db = await database;
    await db.delete(table, where: '$columnId = ?', whereArgs: [id]);
  }

  Future<Map<String, dynamic>?> getUsuarioPorNome(String nome) async {
    final db = await database;
    final result = await db.query(
      table,
      where: '$columnNome = ?',
      whereArgs: [nome],
    );
    return result.isNotEmpty ? result.first : null;
  }

  Future<Map<String, dynamic>?> getEmpresa(String nestab) async {
    final db = await database;
    final result = await db.query(
      table,
      where: '$columnNestab = ?',
      whereArgs: [nestab],
    );
    return result.isNotEmpty ? result.first : null;
  }

  Future<List<Map<String, dynamic>>> buscarUsuarioPorNomeOuEmail(
    String searchQuery,
  ) async {
    final db = await database;
    return await db.query(
      table,
      where: '$columnNome LIKE ? OR $columnEmail LIKE ?',
      whereArgs: ['%$searchQuery%', '%$searchQuery%'],
    );
  }

  Future<List<Map<String, dynamic>>> buscarEmpresaPorNome(
    String searchQuery,
  ) async {
    final db = await database;
    return await db.query(
      table,
      where: '$columnNestab LIKE ?',
      whereArgs: ['%$searchQuery%'],
    );
  }

  Future<Map<String, dynamic>?> verificarUsuario(
    String nome,
    String senha,
  ) async {
    final db = await database;
    final result = await db.query(
      table,
      where: '$columnNome = ? AND $columnSenha = ?',
      whereArgs: [nome, senha],
    );
    return result.isNotEmpty ? result.first : null;
  }

  Future<void> atualizarCorUsuario(String nome, int cor) async {
    final db = await database;
    await db.update(
      table,
      {columnCor: cor},
      where: '$columnNome = ?',
      whereArgs: [nome],
    );
  }

  Future<void> resetarCorUsuario(String nome) async {
    final db = await database;
    await db.update(
      table,
      {columnCor: null},
      where: '$columnNome = ?',
      whereArgs: [nome],
    );
  }

  Future<int?> obterCorUsuario(String nome) async {
    final db = await database;
    final result = await db.query(
      table,
      columns: [columnCor],
      where: '$columnNome = ?',
      whereArgs: [nome],
    );
    return result.isNotEmpty ? result.first[columnCor] as int? : null;
  }

  Future<void> atualizarUsuario({
    required int id,
    String? email,
    String? nome,
    String? senha,
    String? nestab,
    int? cor,
  }) async {
    final db = await database;
    final Map<String, dynamic> dados = {};

    if (email != null) dados[columnEmail] = email;
    if (nome != null) dados[columnNome] = nome;
    if (senha != null) dados[columnSenha] = senha;
    if (nestab != null) dados[columnNestab] = nestab;
    if (cor != null) dados[columnCor] = cor;

    if (dados.isNotEmpty) {
      await db.update(
        table,
        dados,
        where: '$columnId = ?',
        whereArgs: [id],
      );
    }
  }

  // ---------------- FUNÇÕES FUNCIONÁRIOS ------------------

  Future<void> inserirFuncionario(
    String nome,
    String senha,
    String nestab,
  ) async {
    final db = await database;
    await db.insert(
      tableFuncionarios,
      {
        columnNomeFunc: nome,
        columnSenhaFunc: senha,
        columnNestabFunc: nestab,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getUsuarioPorNestab(String nestab) async {
  final db = await database;
  final res = await db.query(
    'usuarios',
    where: 'nestab = ?',
    whereArgs: [nestab],
  );
  if (res.isNotEmpty) {
    return res.first;
  }
  return null;
}


  Future<Map<String, dynamic>?> verificarFuncionario(
    String nome,
    String senha,
  ) async {
    final db = await database;
    final result = await db.query(
      tableFuncionarios,
      where: '$columnNomeFunc = ? AND $columnSenhaFunc = ?',
      whereArgs: [nome, senha],
    );
    return result.isNotEmpty ? result.first : null;
  }

  Future<List<Map<String, dynamic>>> listarFuncionariosPorEmpresa(
    String nestab,
  ) async {
    final db = await database;
    return await db.query(
      tableFuncionarios,
      where: '$columnNestabFunc = ?',
      whereArgs: [nestab],
    );
  }

  Future<void> removerFuncionario(int id) async {
    final db = await database;
    await db.delete(
      tableFuncionarios,
      where: '$columnIdFunc = ?',
      whereArgs: [id],
    );
  }

  // Busca funcionário pelo nome
Future<Map<String, dynamic>?> getFuncionarioPorNome(String nome) async {
  final db = await database;
  final result = await db.query(
    'Funcionarios',
    where: 'nome = ?',
    whereArgs: [nome],
    limit: 1,
  );
  if (result.isNotEmpty) {
    return result.first;
  }
  return null;
}

// Busca estabelecimento pelo id
Future<Map<String, dynamic>?> getEstabelecimentoPorId(int id) async {
  final db = await database;
  final result = await db.query(
    'Estabelecimentos', // nome da tabela dos estabelecimentos
    where: 'id = ?',
    whereArgs: [id],
    limit: 1,
  );
  if (result.isNotEmpty) {
    return result.first;
  }
  return null;
}

//verficar funcionario email e estabelecimento

Future<bool> existeUsuarioComEmail(String email) async {
  final db = await database;
  final result = await db.query(
    table,
    where: '$columnEmail = ?',
    whereArgs: [email],
  );
  return result.isNotEmpty;
}

Future<bool> existeUsuarioComNome(String nome) async {
  final db = await database;
  final result = await db.query(
    table,
    where: '$columnNome = ?',
    whereArgs: [nome],
  );
  return result.isNotEmpty;
}

Future<bool> existeEstabelecimento(String nestab) async {
  final db = await database;
  final result = await db.query(
    table,
    where: '$columnNestab = ?',
    whereArgs: [nestab],
  );
  return result.isNotEmpty;
}


  // ---------------- OUTRAS FUNÇÕES ------------------

  Future<void> apagarBancoDeUsuarios() async {
    final path = join(await getDatabasesPath(), _databaseName);
    final file = File(path);

    if (await file.exists()) {
      await file.delete();
    }
  }
}
