import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:io';
import 'package:intl/intl.dart';

class DatabaseHelper {
  static const _databaseName = "estoque.db";
  static const _databaseVersion = 3;

//table prod
  static const tableProdutos = 'produtos';
  static const columnId = 'id';
  static const columnNome = 'nome';
  static const columnCodigo = 'codigo';
  static const columnQuantidade = 'quantidade';

//table mov
  static const tableMovimentacoes = 'movimentacoes';
  static const columnIdMov = 'id';
  static const columnCodigoMov = 'codigo';
  static const columnNomeMov = 'nome';
  static const columnQuantidadeMov = 'quantidade';
  static const columnTipoMov = 'tipo';
  static const columnDataMov = 'data';

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    return await openDatabase(
      join(await getDatabasesPath(), _databaseName),
      version: _databaseVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $tableProdutos (
            $columnId INTEGER PRIMARY KEY AUTOINCREMENT,
            $columnNome TEXT NOT NULL,
            $columnCodigo TEXT NOT NULL,
            $columnQuantidade INTEGER NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE $tableMovimentacoes (
            $columnIdMov INTEGER PRIMARY KEY AUTOINCREMENT,
            $columnCodigoMov TEXT NOT NULL,
            $columnNomeMov TEXT NOT NULL,
            $columnQuantidadeMov INTEGER NOT NULL,
            $columnTipoMov TEXT NOT NULL,
            $columnDataMov TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE setores (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            nome TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE setores_produtos (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            setor_id INTEGER NOT NULL,
            produto_id INTEGER NOT NULL,
            FOREIGN KEY(setor_id) REFERENCES setores(id),
            FOREIGN KEY(produto_id) REFERENCES produtos(id)
          )
        ''');
      },
    );
  }

  // --- Métodos Produtos ---
  Future<void> inserirProduto(String nome, String codigo) async {
    final db = await database;
    await db.insert(tableProdutos, {
      columnNome: nome,
      columnCodigo: codigo,
      columnQuantidade: 1,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> diminuirQuantidade(int id, int quantidade) async {
    final db = await database;
    final produto = await getProdutoPorId(id);
    if (produto == null) return;

    final atual = int.tryParse(produto[columnQuantidade].toString()) ?? 0;
    int novaQuantidade = atual - quantidade;
    if (novaQuantidade < 0) novaQuantidade = 0;

    if (novaQuantidade == 0) {
      await db.delete(tableProdutos, where: '$columnId = ?', whereArgs: [id]);
    } else {
      await db.update(
        tableProdutos,
        {columnQuantidade: novaQuantidade},
        where: '$columnId = ?',
        whereArgs: [id],
      );
    }
  }

  Future<Map<String, dynamic>?> getProdutoPorId(int id) async {
    final db = await database;
    final resultado = await db.query(
      tableProdutos,
      where: '$columnId = ?',
      whereArgs: [id],
    );
    return resultado.isNotEmpty ? resultado.first : null;
  }

  Future<Map<String, dynamic>?> getProdutoPorCodigo(String codigo) async {
    final db = await database;
    final result = await db.query(
      tableProdutos,
      where: '$columnCodigo = ?',
      whereArgs: [codigo],
    );
    return result.isNotEmpty ? result.first : null;
  }

  Future<List<Map<String, dynamic>>> listarProdutos() async {
    final db = await database;
    return await db.query(tableProdutos);
  }

  Future<void> removerProduto(int id) async {
    final db = await database;
    await db.delete(tableProdutos, where: '$columnId = ?', whereArgs: [id]);
  }

  Future<String?> getCodigoPorNome(String nome) async {
    final db = await database;
    final resultado = await db.query(
      tableProdutos,
      columns: [columnCodigo],
      where: '$columnNome = ?',
      whereArgs: [nome],
      limit: 1,
    );
    return resultado.isNotEmpty ? resultado.first[columnCodigo]?.toString() : null;
  }

  Future<List<Map<String, dynamic>>> buscarProdutosPorNomeOuCodigo(String searchQuery) async {
    final db = await database;
    return await db.query(
      tableProdutos,
      where: '$columnNome LIKE ? OR $columnCodigo LIKE ?',
      whereArgs: ['%$searchQuery%', '%$searchQuery%'],
    );
  }

  Future<int> contarProdutosComMesmoNome(String nome) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) FROM $tableProdutos WHERE $columnNome = ?',
      [nome],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<List<Map<String, dynamic>>> contarProdutosAgrupadosPorNome() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT nome, SUM(quantidade) as quantidade
      FROM $tableProdutos
      GROUP BY nome
    ''');
  }

  Future<int> quantidadeTotalPorCodigo(String codigo) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT SUM(quantidade) as total FROM produtos WHERE codigo = ?',
      [codigo],
    );
    return result.isNotEmpty && result.first['total'] != null
        ? int.parse(result.first['total'].toString())
        : 0;
  }

  Future<void> removerProdutosPorCodigo(String codigo, int quantidadeARemover) async {
    final db = await database;
    final produtos = await db.query(
      'produtos',
      where: 'codigo = ?',
      whereArgs: [codigo],
      limit: quantidadeARemover,
    );

    for (var produto in produtos) {
      int id = produto['id'] as int;
      await db.delete('produtos', where: 'id = ?', whereArgs: [id]);
    }
  }

  Future<List<Map<String, dynamic>>> getProdutosComEstoqueBaixo(int quantidadeLimite) async {
    final db = await database;
    return await db.query(
      'produtos',
      where: 'quantidade < ?',
      whereArgs: [quantidadeLimite],
    );
  }

  Future<List<Map<String, dynamic>>> buscarProdutosAgrupadosPorNomeOuCodigo(String termo) async {
    final db = await database;
    return await db.rawQuery(
      '''
      SELECT p.nome, 
             COALESCE(SUM(CASE m.tipo 
                            WHEN 'Entrada' THEN m.quantidade 
                            WHEN 'Saída' THEN -m.quantidade 
                            ELSE 0 
                          END), 0) AS quantidade
      FROM produtos p
      LEFT JOIN movimentacoes m ON p.codigo = m.codigo
      WHERE p.nome LIKE ? OR p.codigo LIKE ?
      GROUP BY p.nome
      ''',
      ['%$termo%', '%$termo%'],
    );
  }

  // --- Métodos Movimentações ---
  Future<void> inserirMovimentacao(
    String nome,
    String codigo,
    String tipo, {
    required String data,
    int? quantidade,
  }) async {
    final db = await database;
    quantidade ??= 1;

    final dataConvertida = DateFormat('dd/MM/yyyy HH:mm').parse(data);
    final dataFormatada = DateFormat('yyyy-MM-dd HH:mm').format(dataConvertida);

    await db.insert(tableMovimentacoes, {
      columnNomeMov: nome,
      columnCodigoMov: codigo,
      columnTipoMov: tipo,
      columnDataMov: dataFormatada,
      columnQuantidadeMov: quantidade,
    });
  }

  Future<List<Map<String, dynamic>>> listarMovimentacoes() async {
    final db = await database;
    return await db.query(tableMovimentacoes, orderBy: '$columnDataMov DESC');
  }

  Future<void> removerMovimentacao(int id) async {
    final db = await database;
    await db.delete(
      tableMovimentacoes,
      where: '$columnIdMov = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> buscarMovimentacoesPorCodigoOuNome(String termo) async {
    final db = await database;
    return await db.query(
      tableMovimentacoes,
      where: '$columnNomeMov LIKE ? OR $columnCodigoMov LIKE ?',
      whereArgs: ['%$termo%', '%$termo%'],
      orderBy: '$columnDataMov DESC',
    );
  }

  Future<List<Map<String, dynamic>>> listarMovimentacoesPorData(String data) async {
    final db = await database;
    return await db.query(
      tableMovimentacoes,
      where: '$columnDataMov LIKE ?',
      whereArgs: ['${data}%'],
      orderBy: '$columnDataMov DESC',
    );
  }

  Future<List<Map<String, dynamic>>> listarMovimentacoesPorMes(int mes, int ano) async {
    final db = await database;
    return await db.rawQuery(
      '''
      SELECT nome, codigo, tipo, quantidade
      FROM movimentacoes
      WHERE strftime('%m', data) = ? AND strftime('%Y', data) = ?
      ''',
      [mes.toString().padLeft(2, '0'), ano.toString()],
    );
  }

  Future<void> deletarBanco() async {
    final path = join(await getDatabasesPath(), _databaseName);
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  // --- Métodos Setores ---
  Future<void> inserirSetor(String nome) async {
    final db = await database;
    await db.insert('setores', {'nome': nome});
  }

  Future<List<Map<String, dynamic>>> listarSetores() async {
    final db = await database;
    return await db.query('setores', orderBy: 'nome ASC');
  }

  Future<void> removerSetor(int id) async {
    final db = await database;
    await db.delete('setores_produtos', where: 'setor_id = ?', whereArgs: [id]);
    await db.delete('setores', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> associarProdutoAoSetor(int setorId, int produtoId) async {
    final db = await database;
    final existe = await db.query(
      'setores_produtos',
      where: 'setor_id = ? AND produto_id = ?',
      whereArgs: [setorId, produtoId],
    );

    if (existe.isEmpty) {
      await db.insert('setores_produtos', {
        'setor_id': setorId,
        'produto_id': produtoId,
      });
    }
  }

  Future<List<Map<String, dynamic>>> listarProdutosPorSetor(int setorId) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT p.id, p.nome, p.codigo, p.quantidade
      FROM produtos p
      INNER JOIN setores_produtos sp ON p.id = sp.produto_id
      WHERE sp.setor_id = ?
      ORDER BY p.nome ASC
    ''', [setorId]);
  }

  

  
}
