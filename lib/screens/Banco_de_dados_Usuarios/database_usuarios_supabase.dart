import 'package:supabase_flutter/supabase_flutter.dart';

class DatabaseHelperSupabase {
  // Usa o client inicializado em Supabase.initialize()
  static final SupabaseClient client = Supabase.instance.client;

  // Verificar usuário (retorna mapa do usuário ou null)
  static Future<Map<String, dynamic>?> verificarUsuario(
      String nome, String senha) async {
    final response = await client
        .from('usuarios')
        .select()
        .eq('nome', nome)
        .eq('senha', senha)
        .maybeSingle();

    return response as Map<String, dynamic>?;
  }

  // Verificar funcionário
  static Future<Map<String, dynamic>?> verificarFuncionario(
      String nome, String senha) async {
    final response = await client
        .from('funcionarios')
        .select()
        .eq('nome', nome)
        .eq('senha', senha)
        .maybeSingle();

    return response as Map<String, dynamic>?;
  }

  // Inserir usuário (já aceita salvar cor também)
  static Future<void> inserirUsuario(
      String nome, String email, String senha, String nestab,
      {int? cor}) async {
    await client.from('usuarios').insert({
      'nome': nome,
      'email': email,
      'senha': senha,
      'nestab': nestab,
      if (cor != null) 'cor': cor,
    });
  }

  // Inserir funcionário
  static Future<void> inserirFuncionario(
      String nome, String senha, String nestab,
      {int? cor}) async {
    await client.from('funcionarios').insert({
      'nome': nome,
      'senha': senha,
      'nestab': nestab,
      if (cor != null) 'cor': cor,
    });
  }

  static Future<void> inserirFuncionarioSupabase(
      {required String nome,
      required String senha,
      required String nestab,
      required int usuarioId,
      int? cor}) async {
    await client.from('funcionarios').insert({
      'nome': nome,
      'senha': senha,
      'nestab': nestab,
      'usuario_id': usuarioId,
      if (cor != null) 'cor': cor,
    });
  }

  // Listar funcionários por empresa (nestab)
  static Future<List<Map<String, dynamic>>> listarFuncionariosPorEmpresa(
      String nestab) async {
    final response = await client
        .from('funcionarios')
        .select()
        .eq('nestab', nestab);
    return List<Map<String, dynamic>>.from(response as List<dynamic>);
  }

  // Remover funcionário
  static Future<void> removerFuncionario(int id) async {
    await client.from('funcionarios').delete().eq('id', id);
  }
}


