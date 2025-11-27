import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Banco_de_dados_Produtos/banco_produtos_supabase.dart';

class ListaDeProdutos extends StatefulWidget {
  const ListaDeProdutos({Key? key}) : super(key: key);

  @override
  State<ListaDeProdutos> createState() => _ListaDeProdutosState();
}

class _ListaDeProdutosState extends State<ListaDeProdutos> {
  final TextEditingController _controller = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  List<Map<String, dynamic>> _produtos = [];
  List<Map<String, dynamic>> _produtosEncontrados = [];
  List<int> _cardsExpandidos = [];

  int _totalProdutos = 0;
  int _totalProdutosEncontrados = 0;

  Color _corFundo = const Color.fromARGB(255, 150, 205, 231);
  int _usuarioId = 0;

  int _limiteVermelho = 1;
  int _limiteAmarelo = 4;

  bool _limitesAberto = false;

  @override
  void initState() {
    super.initState();
    _carregarUsuarioEProdutos();
  }

  Future<void> _carregarUsuarioEProdutos() async {
    final prefs = await SharedPreferences.getInstance();

    _usuarioId = prefs.getInt('usuario_id_logado') ?? 0;
    final corSalva = prefs.getInt('usuario_cor');

    if (corSalva != null) {
      setState(() {
        _corFundo = Color(corSalva);
      });
    }

    if (_usuarioId != 0) {
      await _carregarLimites();
      await _carregarProdutos();
    }
  }

  Future<void> _carregarLimites() async {
    try {
      final limites = await SupabaseHelperProdutos.client
          .from('usuarios')
          .select('limite_vermelho, limite_amarelo')
          .eq('id', _usuarioId)
          .maybeSingle();

      if (limites != null) {
        setState(() {
          _limiteVermelho = limites['limite_vermelho'] ?? 1;
          _limiteAmarelo = limites['limite_amarelo'] ?? 4;
        });
      }
    } catch (e) {
      print('Erro ao carregar limites: $e');
    }
  }

  Future<void> _carregarProdutos() async {
    try {
      final produtosFiltrados = await SupabaseHelperProdutos.client
          .from('produtos')
          .select()
          .eq('usuario_id', _usuarioId)
          .order('nome', ascending: true);

      setState(() {
        _produtos = List<Map<String, dynamic>>.from(produtosFiltrados);
        _totalProdutos = _produtos.length;
      });
    } catch (e) {
      print('Erro ao carregar produtos: $e');
    }
  }

  Future<void> _buscarProdutos() async {
    final searchQuery = _controller.text.toLowerCase();
    if (searchQuery.isNotEmpty) {
      final encontrados = await SupabaseHelperProdutos.client
          .from('produtos')
          .select()
          .eq('usuario_id', _usuarioId)
          .or('nome.ilike.%$searchQuery%,codigo.ilike.%$searchQuery%')
          .order('nome', ascending: true);

      setState(() {
        _produtosEncontrados = List<Map<String, dynamic>>.from(encontrados);
        _totalProdutosEncontrados = _produtosEncontrados.length;
      });
    } else {
      setState(() {
        _produtosEncontrados = [];
        _totalProdutosEncontrados = 0;
      });
    }
  }

  Future<void> _removerProduto(int id) async {
    await SupabaseHelperProdutos.removerProduto(id);
    await _carregarProdutos();
    if (_controller.text.isNotEmpty) {
      await _buscarProdutos();
    }

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remoção'),
        content: const Text('Produto removido com sucesso!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _adicionarImagem(int produtoId) async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    if (pickedFile != null) {
      final String filePath = pickedFile.path;
      await SupabaseHelperProdutos.atualizarImagem(produtoId, filePath);
      await _carregarProdutos();
      if (_controller.text.isNotEmpty) await _buscarProdutos();
    }
  }

  Future<void> _salvarPreco(int produtoId, double preco) async {
    await SupabaseHelperProdutos.client
        .from('produtos')
        .update({'preco': preco})
        .eq('id', produtoId);

    await _carregarProdutos();
    if (_controller.text.isNotEmpty) await _buscarProdutos();
  }

  void _abrirModalLimites() {
    setState(() {
      _limitesAberto = true;
    });
  }

  Future<void> _salvarLimites(int vermelho, int amarelo) async {
    await SupabaseHelperProdutos.client
        .from('usuarios')
        .update({'limite_vermelho': vermelho, 'limite_amarelo': amarelo})
        .eq('id', _usuarioId);

    setState(() {
      _limiteVermelho = vermelho;
      _limiteAmarelo = amarelo;
      _limitesAberto = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool buscando = _controller.text.isNotEmpty;
    final listaAtual = buscando ? _produtosEncontrados : _produtos;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Estoque'),
        backgroundColor: _corFundo,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _abrirModalLimites,
          ),
        ],
      ),
      backgroundColor: _corFundo,
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextField(
                  controller: _controller,
                  decoration: const InputDecoration(
                    labelText: 'Digite o nome ou código do produto',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (text) => _buscarProdutos(),
                ),
              ),
              Expanded(
                child: listaAtual.isNotEmpty
                    ? ListView.builder(
                        itemCount: listaAtual.length,
                        itemBuilder: (context, index) {
                          final produto = listaAtual[index];
                          final isExpandido = _cardsExpandidos.contains(index);

                          final quantidade = produto['quantidade'] ?? 0;
                          final preco = produto['preco'] ?? 0.0;

                          Color corCard = Colors.white;
                          IconData iconeAlerta = Icons.check_circle;
                          Color corIcone = Colors.green;

                          if (quantidade <= _limiteVermelho) {
                            corCard = Colors.red[200]!;
                            iconeAlerta = Icons.warning;
                            corIcone = Colors.red;
                          } else if (quantidade <= _limiteAmarelo) {
                            corCard = Colors.yellow[200]!;
                            iconeAlerta = Icons.warning;
                            corIcone = Colors.orange;
                          }

                          return Card(
                            color: corCard,
                            margin: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  if (isExpandido) {
                                    _cardsExpandidos.remove(index);
                                  } else {
                                    _cardsExpandidos.add(index);
                                  }
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        if (produto['imagem'] != null &&
                                            produto['imagem'] != '')
                                          CircleAvatar(
                                            backgroundImage: FileImage(
                                              File(produto['imagem']),
                                            ),
                                            radius: 20,
                                          )
                                        else
                                          const CircleAvatar(
                                            child: Icon(Icons.image),
                                            radius: 20,
                                          ),
                                        const SizedBox(width: 8),

                                        Expanded(
                                          child: Text(
                                            produto['nome'],
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),

                                        /// -------------------------------
                                        ///  PREÇO AO LADO DIREITO (NOVO)
                                        /// -------------------------------
                                        Text(
                                          "R\$ ${preco.toStringAsFixed(2)}",
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(width: 12),

                                        Icon(iconeAlerta, color: corIcone),
                                        const SizedBox(width: 4),
                                        Text(
                                          '$quantidade',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),

                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete,
                                            color: Colors.red,
                                          ),
                                          onPressed: () async {
                                            final confirmar =
                                                await showDialog<bool>(
                                              context: context,
                                              builder: (context) =>
                                                  AlertDialog(
                                                title: const Text(
                                                    'Remover Produto'),
                                                content: const Text(
                                                    'Tem certeza que deseja remover este produto?'),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                            context, false),
                                                    child:
                                                        const Text('Cancelar'),
                                                  ),
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                            context, true),
                                                    child:
                                                        const Text('Remover'),
                                                  ),
                                                ],
                                              ),
                                            );

                                            if (confirmar == true) {
                                              await _removerProduto(
                                                  produto['id']);
                                            }
                                          },
                                        ),
                                      ],
                                    ),

                                    if (isExpandido) ...[
                                      const SizedBox(height: 8),
                                      ElevatedButton.icon(
                                        icon:
                                            const Icon(Icons.add_a_photo),
                                        label:
                                            const Text('Adicionar Imagem'),
                                        onPressed: () =>
                                            _adicionarImagem(produto['id']),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Código: ${produto['codigo']}',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey,
                                        ),
                                      ),

                                      const SizedBox(height: 10),

                                      /// -------------------------------
                                      ///  EDIÇÃO DO PREÇO (NOVO)
                                      /// -------------------------------
                                      TextField(
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(
                                          labelText: "Editar preço",
                                          border: OutlineInputBorder(),
                                        ),
                                        controller: TextEditingController(
                                          text: preco.toString(),
                                        ),
                                        onSubmitted: (valor) {
                                          final novoPreco =
                                              double.tryParse(valor);
                                          if (novoPreco != null) {
                                            _salvarPreco(
                                                produto['id'], novoPreco);
                                          }
                                        },
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      )
                    : const Center(
                        child: Text('Nenhum produto encontrado.'),
                      ),
              ),
            ],
          ),

          if (_limitesAberto)
            Container(
              color: Colors.black54,
              alignment: Alignment.center,
              child: LimitesModal(
                limiteVermelho: _limiteVermelho,
                limiteAmarelo: _limiteAmarelo,
                onCancelar: () => setState(() => _limitesAberto = false),
                onSalvar: _salvarLimites,
              ),
            ),
        ],
      ),
      floatingActionButton: CircleAvatar(
        backgroundColor: Colors.blueAccent,
        radius: 28,
        child: Text(
          buscando ? '$_totalProdutosEncontrados' : '$_totalProdutos',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class LimitesModal extends StatefulWidget {
  final int limiteVermelho;
  final int limiteAmarelo;
  final VoidCallback onCancelar;
  final Function(int, int) onSalvar;

  const LimitesModal({
    super.key,
    required this.limiteVermelho,
    required this.limiteAmarelo,
    required this.onCancelar,
    required this.onSalvar,
  });

  @override
  State<LimitesModal> createState() => _LimitesModalState();
}

class _LimitesModalState extends State<LimitesModal> {
  late TextEditingController vermelhoController;
  late TextEditingController amareloController;

  @override
  void initState() {
    super.initState();
    vermelhoController =
        TextEditingController(text: widget.limiteVermelho.toString());
    amareloController =
        TextEditingController(text: widget.limiteAmarelo.toString());
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: vermelhoController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Produto sem estoque (Alerta crítico)',
            ),
          ),
          TextField(
            controller: amareloController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Produto com baixo estoque (Alerta de atenção)',
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: widget.onCancelar,
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () {
                  final novoVermelho =
                      int.tryParse(vermelhoController.text) ?? 1;
                  final novoAmarelo =
                      int.tryParse(amareloController.text) ?? 4;
                  widget.onSalvar(novoVermelho, novoAmarelo);
                },
                child: const Text('Salvar'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
