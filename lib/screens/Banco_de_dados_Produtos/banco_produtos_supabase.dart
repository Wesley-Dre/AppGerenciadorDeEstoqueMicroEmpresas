import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseHelperProdutos {
  static final SupabaseClient client = Supabase.instance.client;

  static const tableProdutos = 'produtos';
  static const tableMovimentacoes = 'movimentacoes';
  static const tableSetores = 'setores';
  static const tableSetoresProdutos = 'setores_produtos';

  // ================== PRODUTOS ==================

  /// agora recebe QUANTIDADE real
  static Future<void> inserirProduto(
      String nome, String codigo, int quantidade, int usuarioId) async {
    await client.from(tableProdutos).insert({
      'nome': nome,
      'codigo': codigo,
      'quantidade': quantidade,   // ✔ QUANTIDADE REAL
      'usuario_id': usuarioId,
    });
  }

  static Future<bool> decrementarProduto(int id) async {
    final produto = await client
        .from(tableProdutos)
        .select()
        .eq('id', id)
        .maybeSingle();

    if (produto == null) return false;

    final int quantidadeAtual = produto['quantidade'] ?? 0;

    if (quantidadeAtual <= 0) {
      return false;
    } else {
      await client
          .from(tableProdutos)
          .update({'quantidade': quantidadeAtual - 1})
          .eq('id', id);
      return true;
    }
  }

  static Future<Map<String, dynamic>?> getProdutoParaRemocao(
      String codigo, int usuarioId) async {
    final response = await client
        .from(tableProdutos)
        .select()
        .eq('codigo', codigo)
        .eq('usuario_id', usuarioId)
        .maybeSingle();

    return response;
  }

  // ================== PRODUTOS ENTRADA ==================

  /// Corrigido: recebe quantidade da tela
  static Future<void> inserirOuAtualizarProduto(
      String nome, String codigo, int quantidadeEntrada, int usuarioId) async {
    final existing = await client
        .from(tableProdutos)
        .select()
        .eq('codigo', codigo)
        .eq('usuario_id', usuarioId)
        .maybeSingle();

    if (existing != null) {
      final int quantidadeAtual = existing['quantidade'] ?? 0;

      /// ✔ SOMA A QUANTIDADE REAL
      await client
          .from(tableProdutos)
          .update({'quantidade': quantidadeAtual + quantidadeEntrada})
          .eq('id', existing['id']);
    } else {
      /// ✔ INSERE COM A QUANTIDADE REAL
      await inserirProduto(nome, codigo, quantidadeEntrada, usuarioId);
    }
  }

  static Future<List<Map<String, dynamic>>> listarProdutos() async {
    final response = await client.from(tableProdutos).select();
    return List<Map<String, dynamic>>.from(response);
  }

  static Future<Map<String, dynamic>?> getProdutoPorCodigo(
      String codigo, int usuarioId) async {
    final response = await client
        .from(tableProdutos)
        .select()
        .eq('codigo', codigo)
        .eq('usuario_id', usuarioId)
        .maybeSingle();

    return response;
  }

  static Future<void> removerProduto(int id) async {
    await client.from(tableProdutos).delete().eq('id', id);
  }

  /// mantém igual, pois recebe quantidade já calculada
  static Future<void> atualizarQuantidade(int id, int quantidade) async {
    await client
        .from(tableProdutos)
        .update({'quantidade': quantidade}).eq('id', id);
  }

  // ================== IMAGEM ==================

  static Future<void> atualizarImagem(int produtoId, String caminho) async {
    await client
        .from('produtos')
        .update({'imagem': caminho})
        .eq('id', produtoId);
  }

  static String? normalizarImagem(dynamic imagemBase64) {
    if (imagemBase64 == null) return null;
    if (imagemBase64 is String) return imagemBase64;
    if (imagemBase64 is List<String>) {
      return imagemBase64.isNotEmpty ? imagemBase64.first : null;
    }
    return null;
  }

  static Future<void> inserirOuAtualizarProdutoComImagem({
    required String nome,
    required String codigo,
    required String imagemBase64,
    required int usuarioId,
  }) async {
    final client = Supabase.instance.client;

    final mapInsert = {
      'nome': nome,
      'codigo': codigo,
      'imagem': imagemBase64,
      'usuario_id': usuarioId,
      'quantidade': 0,
      'preco': 0.00,
      'sku': null,
    };

    await client.from('produtos').upsert(mapInsert, onConflict: 'codigo');
  }

  // ================== MOVIMENTAÇÕES ==================

  static Future<void> inserirMovimentacao(
    String nome,
    String codigo,
    String tipo,
    int quantidade,
    DateTime data,
    int usuarioId,
  ) async {
    await client.from(tableMovimentacoes).insert({
      'nome': nome,
      'codigo': codigo,
      'tipo': tipo,
      'quantidade': quantidade,
      'data': data.toIso8601String(),
      'usuario_id': usuarioId,
    });
  }

  static Future<List<Map<String, dynamic>>> listarMovimentacoes() async {
    final response = await client
        .from(tableMovimentacoes)
        .select()
        .order('data', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  static Future<void> removerMovimentacao(int id) async {
    await client.from(tableMovimentacoes).delete().eq('id', id);
  }

  // ================== SETORES ==================

  static Future<void> inserirSetor(String nome) async {
    await client.from(tableSetores).insert({'nome': nome});
  }

  static Future<List<Map<String, dynamic>>> listarSetores() async {
    final response = await client
        .from(tableSetores)
        .select()
        .order('nome', ascending: true);

    return List<Map<String, dynamic>>.from(response);
  }

  static Future<void> removerSetor(int id) async {
    await client.from(tableSetoresProdutos).delete().eq('setor_id', id);
    await client.from(tableSetores).delete().eq('id', id);
  }

  static Future<void> associarProdutoAoSetor(int setorId, int produtoId) async {
    final existe = await client
        .from(tableSetoresProdutos)
        .select()
        .eq('setor_id', setorId)
        .eq('produto_id', produtoId);

    if (existe.isEmpty) {
      await client.from(tableSetoresProdutos).insert({
        'setor_id': setorId,
        'produto_id': produtoId,
      });
    }
  }

  static Future<List<Map<String, dynamic>>> listarProdutosPorSetor(
      int setorId) async {
    final response = await client
        .from(tableSetoresProdutos)
        .select('produto_id, produtos(id, nome, codigo, quantidade)')
        .eq('setor_id', setorId);

    return List<Map<String, dynamic>>.from(response);
  }
}
