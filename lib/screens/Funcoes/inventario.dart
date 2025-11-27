import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SetoresScreen extends StatefulWidget {
  const SetoresScreen({Key? key}) : super(key: key);

  @override
  _SetoresScreenState createState() => _SetoresScreenState();
}

class _SetoresScreenState extends State<SetoresScreen> {
  final supabase = Supabase.instance.client;

  final TextEditingController _nomeSetorController = TextEditingController();
  final TextEditingController _buscaController = TextEditingController();

  List<Map<String, dynamic>> setores = [];
  List<Map<String, dynamic>> setoresFiltrados = [];
  Map<int, List<Map<String, dynamic>>> produtosPorSetor = {};

  Color _corFundo = const Color.fromARGB(255, 150, 205, 231);
  int usuarioId = 0;

  @override
  void initState() {
    super.initState();
    _carregarUsuarioECor();
    _buscaController.addListener(() {
      _filtrarSetores(_buscaController.text);
    });
  }

  /// 🔹 Carrega o usuário logado e a cor personalizada
  Future<void> _carregarUsuarioECor() async {
    final prefs = await SharedPreferences.getInstance();

    usuarioId = prefs.getInt('usuario_id_logado') ?? 0;
    final corInt = prefs.getInt('cor_usuario');

    if (corInt != null) {
      setState(() {
        _corFundo = Color(corInt);
      });
    }

    if (usuarioId != 0) {
      await _carregarSetoresComProdutos();
    }
  }

  /// 🔹 Busca setores e seus produtos no Supabase
  Future<void> _carregarSetoresComProdutos() async {
    try {
      final responseSetores = await supabase
          .from('setores')
          .select()
          .eq('usuario_id', usuarioId)
          .order('id');

      final listaSetores =
          List<Map<String, dynamic>>.from(responseSetores as List);

      final mapaProdutos = <int, List<Map<String, dynamic>>>{};
      for (var setor in listaSetores) {
        final responseProdutos = await supabase
            .from('produtos_setores')
            .select('produtos(id, nome, codigo)')
            .eq('setor_id', setor['id']);

        final produtos = (responseProdutos as List)
            .map((e) => {
                  'id': e['produtos']['id'],
                  'nome': e['produtos']['nome'],
                  'codigo': e['produtos']['codigo'],
                })
            .toList();

        mapaProdutos[setor['id']] = produtos;
      }

      setState(() {
        setores = listaSetores;
        produtosPorSetor = mapaProdutos;
        _filtrarSetores(_buscaController.text);
      });
    } catch (e) {
      debugPrint('Erro ao carregar setores: $e');
    }
  }

  /// 🔹 Filtro por nome de setor
  void _filtrarSetores(String texto) {
    texto = texto.toLowerCase();
    setState(() {
      setoresFiltrados = setores.where((setor) {
        final nome = (setor['nome'] ?? '').toString().toLowerCase();
        return nome.contains(texto);
      }).toList();
    });
  }

  /// 🔹 Adiciona novo setor
  Future<void> _adicionarSetor() async {
    _nomeSetorController.clear();

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        String? erroValidacao;
        return StatefulBuilder(builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('Adicionar Setor'),
            content: TextField(
              controller: _nomeSetorController,
              decoration: InputDecoration(
                labelText: 'Nome do setor',
                errorText: erroValidacao,
              ),
              autofocus: true,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () async {
                  final nome = _nomeSetorController.text.trim();
                  if (nome.isEmpty) {
                    setStateDialog(() {
                      erroValidacao = 'Informe um nome válido.';
                    });
                    return;
                  }

                  final existeDuplicado = setores.any(
                      (s) => s['nome'].toLowerCase() == nome.toLowerCase());
                  if (existeDuplicado) {
                    setStateDialog(() {
                      erroValidacao = 'Já existe um setor com esse nome.';
                    });
                    return;
                  }

                  await supabase.from('setores').insert({
                    'nome': nome,
                    'usuario_id': usuarioId,
                  });

                  Navigator.of(dialogContext).pop();
                  await _carregarSetoresComProdutos();
                },
                child: const Text('Adicionar'),
              ),
            ],
          );
        });
      },
    );
  }

  /// 🔹 Confirmação de exclusão
  Future<void> _confirmarRemoverSetor(int setorId) async {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Remover Setor'),
          content: const Text('Deseja remover este setor?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () async {
                await supabase
                    .from('setores')
                    .delete()
                    .eq('id', setorId)
                    .eq('usuario_id', usuarioId);

                await supabase
                    .from('produtos_setores')
                    .delete()
                    .eq('setor_id', setorId);

                Navigator.of(dialogContext).pop();
                await _carregarSetoresComProdutos();
              },
              child: const Text('Remover'),
            ),
          ],
        );
      },
    );
  }

  /// 🔹 Mostra produtos para associar a um setor
  Future<void> _mostrarDialogoAssociarProduto(int setorId) async {
    try {
      final responseProdutos = await supabase
          .from('produtos')
          .select()
          .eq('usuario_id', usuarioId);

      final todosProdutos =
          List<Map<String, dynamic>>.from(responseProdutos as List);

      final responseAssociados = await supabase
          .from('produtos_setores')
          .select('produto_id')
          .eq('setor_id', setorId);

      final idsAssociados =
          (responseAssociados as List).map((e) => e['produto_id'] as int).toSet();

      final produtosDisponiveis =
          todosProdutos.where((p) => !idsAssociados.contains(p['id'])).toList();

      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Adicionar Produto ao Setor'),
            content: produtosDisponiveis.isEmpty
                ? const Text('Todos os produtos já estão atribuídos a setores.')
                : SizedBox(
                    width: double.maxFinite,
                    height: 300,
                    child: ListView.builder(
                      itemCount: produtosDisponiveis.length,
                      itemBuilder: (context, index) {
                        final produto = produtosDisponiveis[index];
                        return ListTile(
                          title:
                              Text('${produto['nome']} - ${produto['codigo']}'),
                          onTap: () async {
                            await supabase.from('produtos_setores').insert({
                              'setor_id': setorId,
                              'produto_id': produto['id'],
                              'usuario_id': usuarioId,
                            });

                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Produto adicionado ao setor')),
                            );
                            await _carregarSetoresComProdutos();
                          },
                        );
                      },
                    ),
                  ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Fechar'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      debugPrint('Erro ao carregar produtos: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _corFundo,
      appBar: AppBar(
        backgroundColor: _corFundo,
        title: const Text('Setores'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.add, color: Colors.black),
                  label: const Text(
                    'Adicionar Setor',
                    style: TextStyle(color: Colors.black),
                  ),
                  onPressed: _adicionarSetor,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _buscaController,
                    decoration: InputDecoration(
                      fillColor: Colors.white,
                      filled: true,
                      labelText: 'Buscar setor por nome',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: setoresFiltrados.isEmpty
                ? const Center(child: Text('Nenhum setor encontrado'))
                : ListView.builder(
                    itemCount: setoresFiltrados.length,
                    itemBuilder: (context, index) {
                      final setor = setoresFiltrados[index];
                      final produtos = produtosPorSetor[setor['id']] ?? [];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        child: ExpansionTile(
                          title: Text(setor['nome']),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () =>
                                _confirmarRemoverSetor(setor['id']),
                          ),
                          children: [
                            if (produtos.isEmpty)
                              const ListTile(
                                  title: Text('Nenhum produto neste setor'))
                            else
                              ...produtos.map(
                                (produto) => ListTile(
                                  title: Text(
                                      '${produto['nome']} - ${produto['codigo']}'),
                                ),
                              ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16.0),
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  icon: const Icon(Icons.add),
                                  label:
                                      const Text('Adicionar itens ao setor'),
                                  onPressed: () => _mostrarDialogoAssociarProduto(
                                      setor['id']),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
