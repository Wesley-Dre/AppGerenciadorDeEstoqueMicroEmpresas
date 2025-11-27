import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fp1/screens/Banco_de_dados_Produtos/banco_produtos_supabase.dart';

class Removerprodutos extends StatefulWidget {
  const Removerprodutos({Key? key}) : super(key: key);

  @override
  _RemoverprodutosState createState() => _RemoverprodutosState();
}

class _RemoverprodutosState extends State<Removerprodutos> {
  final MobileScannerController _cameraController = MobileScannerController();
  bool _isProcessing = false;

  List<Map<String, String>> produtosEscaneados = [];

  // 🔹 Controllers persistentes para cada produto
  Map<String, TextEditingController> controllersQtd = {};

  Color _corFundo = const Color(0xFF96CDE7);
  int _usuarioId = 0;

  @override
  void initState() {
    super.initState();
    _carregarCorDoShared();
    _checkCameraPermission();
  }

  Future<void> _carregarCorDoShared() async {
    final prefs = await SharedPreferences.getInstance();

    final nomeUsuario = prefs.getString('usuario_logado') ?? '';
    final idUsuario = prefs.getInt('usuario_id_logado') ?? 0;
    final corSalva = prefs.getInt('usuario_cor');

    if (mounted) {
      setState(() {
        _usuarioId = idUsuario;
        _corFundo = corSalva != null ? Color(corSalva) : const Color(0xFF96CDE7);
      });
    }
  }

  Future<void> _checkCameraPermission() async {
    final status = await Permission.camera.status;
    if (!status.isGranted) {
      await Permission.camera.request();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _corFundo,
      appBar: AppBar(
        title: const Text(
          'Remover Produto',
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

                    final String code =
                        capture.barcodes.first.rawValue ?? 'Desconhecido';

                    final produto = await SupabaseHelperProdutos
                        .getProdutoPorCodigo(code, _usuarioId);

                    if (produto != null) {
                      setState(() {
                        final index = produtosEscaneados.indexWhere(
                          (p) => p['codigo'] == code,
                        );

                        if (index != -1) {
                          final atual = int.tryParse(
                                  produtosEscaneados[index]['quantidade'] ??
                                      '1') ??
                              1;
                          produtosEscaneados[index]['quantidade'] =
                              (atual + 1).toString();

                          controllersQtd[code]?.text =
                              produtosEscaneados[index]['quantidade']!;
                        } else {
                          produtosEscaneados.add({
                            'codigo': code,
                            'nome': produto['nome'],
                            'id': produto['id'].toString(),
                            'quantidade': '1',
                          });

                          controllersQtd[code] =
                              TextEditingController(text: "1");
                        }
                      });
                    } else {
                      _cameraController.stop();
                      await _mostrarErroProdutoNaoEncontrado();
                      _cameraController.start();
                    }

                    await Future.delayed(const Duration(seconds: 1));
                    _isProcessing = false;
                  },
                ),
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
                          width: 400,
                          height: 200,
                          decoration: const BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.all(Radius.circular(15)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 📦 LISTA DE PRODUTOS ESCANEADOS
          Expanded(
            flex: 3,
            child: Container(
              width: double.infinity,
              color: _corFundo,
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  const Text(
                    'Produtos escaneados:',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const Divider(color: Colors.white, thickness: 1),

                  Expanded(
                    child: ListView.builder(
                      itemCount: produtosEscaneados.length,
                      itemBuilder: (context, index) {
                        final produto = produtosEscaneados[index];

                        return Card(
                          elevation: 2,
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          child: ListTile(
                            leading: const Icon(Icons.qr_code_2),
                            title: Text(produto['nome'] ?? ''),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Código: ${produto['codigo']}'),
                                const SizedBox(height: 4),

                                Row(
                                  children: [
                                    const Text("Qtd: "),
                                    SizedBox(
                                      width: 50,
                                      child: TextField(
                                        controller:
                                            controllersQtd[produto['codigo']],
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(
                                          isDense: true,
                                          contentPadding: EdgeInsets.all(6),
                                        ),
                                        onChanged: (v) {
                                          setState(() {
                                            produto['quantidade'] = v;
                                          });
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  ElevatedButton.icon(
                    icon: const Icon(Icons.delete, color: Colors.white),
                    label: const Text('Remover todos'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    onPressed: _removerTodos,
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _mostrarErroProdutoNaoEncontrado() async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Produto não encontrado'),
        content: const Text(
          'Produto não cadastrado para este usuário.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            child: const Text('OK'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Future<void> _removerTodos() async {
    if (produtosEscaneados.isEmpty) return;

    for (var produto in produtosEscaneados) {
      final codigo = produto['codigo']!;
      final quantidade = int.tryParse(produto['quantidade'] ?? '1') ?? 1;

      final prodDb =
          await SupabaseHelperProdutos.getProdutoPorCodigo(codigo, _usuarioId);

      if (prodDb == null) continue;

      int quantidadeAtual = prodDb['quantidade'] ?? 0;
      int quantidadeARemover =
          quantidade > quantidadeAtual ? quantidadeAtual : quantidade;

      await SupabaseHelperProdutos.atualizarQuantidade(
        prodDb['id'],
        quantidadeAtual - quantidadeARemover,
      );

      await SupabaseHelperProdutos.inserirMovimentacao(
        produto['nome']!,
        codigo,
        "Saída",
        quantidadeARemover,
        DateTime.now(),
        _usuarioId,
      );
    }

    setState(() {
      produtosEscaneados.clear();
      controllersQtd.clear();
    });
  }
}
