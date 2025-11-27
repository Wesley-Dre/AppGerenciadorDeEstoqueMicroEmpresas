import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;

import '../Banco_de_dados_Produtos/banco_produtos_supabase.dart';

class GerarCodigoBarras extends StatefulWidget {
  const GerarCodigoBarras({super.key});

  @override
  State<GerarCodigoBarras> createState() => _GerarCodigoBarrasState();
}

class _GerarCodigoBarrasState extends State<GerarCodigoBarras> {
  final TextEditingController _nomeController = TextEditingController();
  final GlobalKey _barcodeKey = GlobalKey();

  String? _codigoGerado;
  bool _salvando = false;

  int _usuarioId = 0;
  Color _corFundo = const Color(0xFF96CDE7);

  @override
  void initState() {
    super.initState();
    _carregarPreferenciasUsuario();
  }

  Future<void> _carregarPreferenciasUsuario() async {
    final prefs = await SharedPreferences.getInstance();

    _usuarioId = prefs.getInt('usuario_id_logado') ?? 0;

    // Corrigido igual ao CadastroFunc — pegando cor salva
    final corSalva = prefs.getInt('usuario_cor');
    if (corSalva != null) {
      _corFundo = Color(corSalva);
    }

    setState(() {});
  }

  /// Gera um código EAN-13 válido
  String _gerarCodigoBarras() {
    List<int> digits = [];

    for (int i = 0; i < 12; i++) {
      digits.add((0 + i * 7 + DateTime.now().millisecondsSinceEpoch ~/ (i + 1)) % 10);
    }

    int somaImpares = digits[1] + digits[3] + digits[5] + digits[7] + digits[9] + digits[11];
    int somaPares = digits[0] + digits[2] + digits[4] + digits[6] + digits[8] + digits[10];
    int somaTotal = somaImpares * 3 + somaPares;

    int digitoVerificador = (10 - (somaTotal % 10)) % 10;
    digits.add(digitoVerificador);

    return digits.join();
  }

  Future<Uint8List?> _capturarCodigoBarras() async {
    try {
      final boundary =
          _barcodeKey.currentContext!.findRenderObject() as RenderRepaintBoundary;

      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);

      return byteData?.buffer.asUint8List();
    } catch (e) {
      print("Erro ao capturar imagem do código: $e");
      return null;
    }
  }

  Future<void> _salvarProduto() async {
    if (_nomeController.text.isEmpty || _codigoGerado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preencha o nome e gere o código.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_usuarioId == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erro: usuário não identificado.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _salvando = true);

    Uint8List? imagemBytes = await _capturarCodigoBarras();

    if (imagemBytes == null) {
      setState(() => _salvando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erro ao gerar imagem do código.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    String imagemBase64 = base64Encode(imagemBytes);

    try {
      await SupabaseHelperProdutos.inserirOuAtualizarProdutoComImagem(
        nome: _nomeController.text.trim(),
        codigo: _codigoGerado!,
        imagemBase64: imagemBase64,
        usuarioId: _usuarioId,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Produto salvo com sucesso!'),
          backgroundColor: Colors.green,
        ),
      );

      setState(() {
        _salvando = false;
        _codigoGerado = null;
        _nomeController.clear();
      });
    } catch (e) {
      setState(() => _salvando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao salvar: $e'),
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
        title: const Text("Gerar Código de Barras"),
        backgroundColor: _corFundo,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            children: [
              const Text(
                "Informe o nome do produto:",
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
              const SizedBox(height: 10),

              TextField(
                controller: _nomeController,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  hintText: "Ex: Coca-Cola 2L",
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),

              const SizedBox(height: 20),

              ElevatedButton.icon(
                icon: const Icon(Icons.qr_code),
                label: const Text("Gerar Código de Barras"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
                onPressed: () {
                  setState(() {
                    _codigoGerado = _gerarCodigoBarras();
                  });
                },
              ),

              const SizedBox(height: 25),

              if (_codigoGerado != null) ...[
                const Text(
                  "Código Gerado:",
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
                const SizedBox(height: 10),

                RepaintBoundary(
                  key: _barcodeKey,
                  child: Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(12),
                    child: BarcodeWidget(
                      barcode: Barcode.code128(),
                      data: _codigoGerado!,
                      width: 260,
                      height: 110,
                    ),
                  ),
                ),

                const SizedBox(height: 20),
                Text(
                  _codigoGerado!,
                  style: const TextStyle(
                    fontSize: 18,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 30),
              ],

              ElevatedButton.icon(
                icon: _salvando
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(_salvando ? "Salvando..." : "Salvar Produto"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  minimumSize: const Size(double.infinity, 50),
                ),
                onPressed: _salvando ? null : _salvarProduto,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
