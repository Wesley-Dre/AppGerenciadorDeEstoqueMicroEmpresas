import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Banco_de_dados_Produtos/banco_produtos_supabase.dart';

class Leitor extends StatefulWidget {
  const Leitor({super.key});

  @override
  _LeitorState createState() => _LeitorState();
}

class _LeitorState extends State<Leitor> {
  final MobileScannerController _cameraController = MobileScannerController();
  bool _isProcessing = false;
  bool _isSaving = false;

  // Lista de produtos escaneados
  List<Map<String, dynamic>> produtosEscaneados = [];

  // Controllers individuais para os campos X
  final Map<String, TextEditingController> _controllersX = {};

  Color _corFundo = const Color(0xFF96CDE7);
  int _usuarioId = 0;
  String _nomeUsuario = '';

  @override
  void initState() {
    super.initState();
    _carregarUsuarioDoSharedPreferences();
    _checkCameraPermission();
  }

  Future<void> _carregarUsuarioDoSharedPreferences() async {
    final prefs = await SharedPreferences.getInstance();

    _nomeUsuario = prefs.getString('usuario_logado') ?? '';
    _usuarioId = prefs.getInt('usuario_id_logado') ?? 0;
    final corSalva = prefs.getInt('usuario_cor');

    if (corSalva != null) {
      setState(() {
        _corFundo = Color(corSalva);
      });
    }

    print('Usuário logado: $_nomeUsuario (ID: $_usuarioId)');
  }

  Future<void> _checkCameraPermission() async {
    final status = await Permission.camera.status;
    if (!status.isGranted) {
      await Permission.camera.request();
    }
  }

  Future<String?> _buscarProdutoBanco(String codigo) async {
    if (_usuarioId == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Usuário não identificado. Faça login novamente.'),
          backgroundColor: Colors.orange,
        ),
      );
      return null;
    }

    final produto =
        await SupabaseHelperProdutos.getProdutoPorCodigo(codigo, _usuarioId);

    if (produto != null) {
      return produto['nome'] as String?;
    } else {
      return await _mostrarDialogoInserirNomeManual(codigo);
    }
  }

  Future<String?> _mostrarDialogoInserirNomeManual(String codigo) async {
    String nomeManual = '';

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Produto não encontrado'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Digite o nome do produto manualmente:'),
              const SizedBox(height: 10),
              TextField(
                decoration: const InputDecoration(
                  hintText: 'Nome do produto',
                ),
                onChanged: (value) => nomeManual = value.trim(),
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              child: const Text('Salvar'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );

    return nomeManual.isNotEmpty ? nomeManual : null;
  }

  Future<void> _salvarTodosProdutos() async {
    setState(() => _isSaving = true);

    if (_usuarioId == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erro: usuário não encontrado. Faça login novamente.'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _isSaving = false);
      return;
    }

    try {
      final agora = DateTime.now();

      for (var produto in produtosEscaneados) {
        final nome = produto['nome'];
        final codigo = produto['codigo'];

        // Agora pega o valor correto do controller
        final quantidadeX =
            int.tryParse(_controllersX[codigo]?.text ?? '1') ?? 1;

        await SupabaseHelperProdutos.inserirOuAtualizarProduto(
  nome,
  codigo,
  quantidadeX, // ✅ passar a quantidade aqui
  _usuarioId
);

        await SupabaseHelperProdutos.inserirMovimentacao(
          nome,
          codigo,
          'Entrada',
          quantidadeX, // VALOR CORRETO!
          agora,
          _usuarioId,
        );
      }

      setState(() {
        produtosEscaneados.clear();
        _controllersX.clear();
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Produtos salvos com sucesso!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao salvar produtos: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _corFundo,
      appBar: AppBar(
        title: const Text(
          'Leitor de Código de Barras',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: _corFundo,
      ),
      body: Column(
        children: [
          Expanded(
            flex: 4,
            child: Stack(
              children: [
                MobileScanner(
                  controller: _cameraController,
                  onDetect: (capture) async {
                    if (_isProcessing) return;
                    _isProcessing = true;

                    final String code = capture.barcodes.first.rawValue ?? '';
                    final nomeProduto = await _buscarProdutoBanco(code);

                    if (nomeProduto != null && nomeProduto.isNotEmpty) {
                      setState(() {
                        produtosEscaneados.add({
                          'codigo': code,
                          'nome': nomeProduto,
                        });

                        // Cria controller x para cada item
                        _controllersX[code] = TextEditingController(text: "1");
                      });
                    }

                    await Future.delayed(const Duration(seconds: 2));
                    _isProcessing = false;
                  },
                ),

                // Máscara
                ColorFiltered(
                  colorFilter: ColorFilter.mode(
                    _corFundo.withOpacity(1),
                    BlendMode.srcOut,
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(color: Colors.transparent),
                      Positioned(
                        top: 150,
                        left: 50,
                        right: 50,
                        child: Container(
                          height: 200,
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Borda
                Positioned(
                  top: 150,
                  left: 50,
                  right: 50,
                  child: Container(
                    height: 200,
                    decoration: BoxDecoration(
                      border: Border.all(color: _corFundo, width: 4),
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              width: double.infinity,
              color: _corFundo,
              child: Column(
                children: [
                  const Text(
                    'Produtos escaneados:',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const Divider(color: Colors.white),

                  Expanded(
                    child: produtosEscaneados.isEmpty
                        ? const Center(
                            child: Text(
                              'Nenhum produto escaneado.',
                              style: TextStyle(color: Colors.white70),
                            ),
                          )
                        : ListView.builder(
                            itemCount: produtosEscaneados.length,
                            itemBuilder: (context, index) {
                              final produto = produtosEscaneados[index];
                              final codigo = produto['codigo'];

                              return Card(
                                elevation: 3,
                                margin:
                                    const EdgeInsets.symmetric(vertical: 6),
                                child: ListTile(
                                  leading: const Icon(
                                    Icons.qr_code_2,
                                    color: Colors.blueAccent,
                                  ),
                                  title: Text(produto['nome']),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text("Código: $codigo"),
                                      const SizedBox(height: 6),

                                      Row(
                                        children: [
                                          const Text("Quantidade (X): "),
                                          SizedBox(
                                            width: 60,
                                            child: TextField(
                                              controller:
                                                  _controllersX[codigo],
                                              keyboardType:
                                                  TextInputType.number,
                                              decoration:
                                                  const InputDecoration(
                                                isDense: true,
                                                contentPadding:
                                                    EdgeInsets.all(6),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete,
                                        color: Colors.red),
                                    onPressed: () {
                                      setState(() {
                                        produtosEscaneados.removeAt(index);
                                        _controllersX.remove(codigo);
                                      });
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                  ),

                  const SizedBox(height: 10),

                  ElevatedButton.icon(
                    icon: _isSaving
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.black),
                            ),
                          )
                        : const Icon(Icons.save, color: Colors.black),
                    label: Text(
                      _isSaving
                          ? 'Salvando...'
                          : 'Salvar ${produtosEscaneados.length} produto(s)',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                    ),
                    onPressed: produtosEscaneados.isEmpty || _isSaving
                        ? null
                        : _salvarTodosProdutos,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
