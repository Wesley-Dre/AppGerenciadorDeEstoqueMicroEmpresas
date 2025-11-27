import 'dart:typed_data';
import 'package:flutter/rendering.dart';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import '../Banco_de_dados_Produtos/banco_produtos_supabase.dart';

class RelatorioDeVendasMensal extends StatefulWidget {
  const RelatorioDeVendasMensal({Key? key}) : super(key: key);

  @override
  State<RelatorioDeVendasMensal> createState() =>
      _RelatorioDeVendasMensalState();
}

class _RelatorioDeVendasMensalState extends State<RelatorioDeVendasMensal> {
  List<Map<String, dynamic>> movimentacoes = [];
  bool _isLoading = true;
  String _filtroTipo = 'Todos';

  late int mesAtual;
  late int anoAtual;
  late int usuarioId;
  Color _corFundo = const Color.fromARGB(255, 150, 205, 231);

  final List<int> anos =
      List.generate(5, (index) => DateTime.now().year - index);
  final List<int> meses = List.generate(12, (index) => index + 1);

  final GlobalKey _graficoKey = GlobalKey(); // Para captura do PDF

  @override
  void initState() {
    super.initState();
    final agora = DateTime.now();
    mesAtual = agora.month;
    anoAtual = agora.year;
    _carregarUsuarioECor();
  }

  Future<void> _carregarUsuarioECor() async {
    final prefs = await SharedPreferences.getInstance();

    usuarioId = prefs.getInt('usuario_id_logado') ?? 0;
    final corSalva = prefs.getInt('usuario_cor');

    if (corSalva != null) setState(() => _corFundo = Color(corSalva));

    try {
      final usuario = await SupabaseHelperProdutos.client
          .from('usuarios')
          .select('id, cor')
          .eq('id', usuarioId)
          .maybeSingle();

      if (usuario != null && usuario['cor'] != null) {
        final corBanco = usuario['cor'] as int;
        prefs.setInt('usuario_cor', corBanco);
        setState(() => _corFundo = Color(corBanco));
      }
    } catch (e) {
      print('Erro ao carregar dados do usuário: $e');
    }

    Future.microtask(() => _carregarMovimentacoes());
  }

  Future<void> _carregarMovimentacoes() async {
    if (usuarioId == 0) return;
    setState(() => _isLoading = true);

    try {
      final primeiroDia = DateTime(anoAtual, mesAtual, 1);
      final proximoMes = mesAtual == 12
          ? DateTime(anoAtual + 1, 1, 1)
          : DateTime(anoAtual, mesAtual + 1, 1);

      final dados = await SupabaseHelperProdutos.client
          .from('movimentacoes')
          .select('nome, codigo, tipo, quantidade')
          .eq('usuario_id', usuarioId)
          .gte('data', primeiroDia.toIso8601String())
          .lt('data', proximoMes.toIso8601String());

      final List<Map<String, dynamic>> filtrados = _filtroTipo == 'Todos'
          ? List<Map<String, dynamic>>.from(dados)
          : dados.where((m) => m['tipo'] == _filtroTipo).toList();

      final Map<String, Map<String, dynamic>> resumo = {};
      for (var mov in filtrados) {
        final chave = '${mov['nome']}|${mov['codigo']}';
        final tipo = mov['tipo'] ?? '';
        final qtd = (mov['quantidade'] ?? 0) as int;

        resumo[chave] ??= {
          'nome': mov['nome'],
          'codigo': mov['codigo'],
          'entradas': 0,
          'saidas': 0,
        };

        if (tipo == 'Entrada') resumo[chave]!['entradas'] += qtd;
        if (tipo == 'Saída') resumo[chave]!['saidas'] += qtd;
      }

      setState(() {
        movimentacoes = resumo.values.toList()
          ..sort((a, b) => a['nome'].compareTo(b['nome']));
        _isLoading = false;
      });
    } catch (e) {
      print("Erro ao carregar movimentações: $e");
      setState(() => _isLoading = false);
    }
  }

  String _nomeMes(int mes) =>
      DateFormat.MMMM('pt_BR').format(DateTime(0, mes)).toUpperCase();

  void _mostrarSelecaoMesAno() {
    int mesSelecionado = mesAtual;
    int anoSelecionado = anoAtual;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('Selecionar Mês e Ano'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButton<int>(
                  value: mesSelecionado,
                  isExpanded: true,
                  items: meses
                      .map((m) => DropdownMenuItem(
                            value: m,
                            child: Text(_nomeMes(m)),
                          ))
                      .toList(),
                  onChanged: (v) => setStateDialog(() => mesSelecionado = v!),
                ),
                DropdownButton<int>(
                  value: anoSelecionado,
                  isExpanded: true,
                  items: anos
                      .map((a) => DropdownMenuItem(
                            value: a,
                            child: Text('$a'),
                          ))
                      .toList(),
                  onChanged: (v) => setStateDialog(() => anoSelecionado = v!),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    mesAtual = mesSelecionado;
                    anoAtual = anoSelecionado;
                  });
                  Navigator.pop(context);
                  _carregarMovimentacoes();
                },
                child: const Text('Filtrar'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _exportarGraficoParaPDF() async {
    try {
      final boundary = _graficoKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      final Uint8List pngBytes = byteData!.buffer.asUint8List();

      final pdf = pw.Document();
      final imagePdf = pw.MemoryImage(pngBytes);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) => pw.Center(child: pw.Image(imagePdf)),
        ),
      );

      await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => pdf.save());
    } catch (e) {
      print('Erro ao exportar PDF: $e');
    }
  }

  void mostrarGraficoComLista(BuildContext context) {
    // Preparar top/bottom 5
    final produtosOrdenados = movimentacoes;
    final top5Final = produtosOrdenados
        .where((p) => (p['saidas'] ?? 0) > 0)
        .toList()
      ..sort((a, b) => (b['saidas'] ?? 0).compareTo(a['saidas'] ?? 0));
    final bottom5Final = produtosOrdenados
        .toList()
      ..sort((a, b) => (a['saidas'] ?? 0).compareTo(b['saidas'] ?? 0));
    final top5 = top5Final.take(5).toList();
    final bottom5 = bottom5Final.take(5).toList();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(12),
        child: SafeArea(
          child: SingleChildScrollView(
            child: RepaintBoundary(
              key: _graficoKey,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    const Text(
                      'Entradas e Saídas de Produtos',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    SizedBox(
                      height: 300,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: produtosOrdenados.length * 90.0,
                          child: BarChart(
                            BarChartData(
                              alignment: BarChartAlignment.spaceAround,
                              titlesData: FlTitlesData(
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (value, meta) {
                                      final index = value.toInt();
                                      if (index >= 0 &&
                                          index < produtosOrdenados.length) {
                                        return Transform.rotate(
                                          angle: -0.5,
                                          child: Text(
                                            produtosOrdenados[index]['nome'],
                                            style: const TextStyle(fontSize: 10),
                                          ),
                                        );
                                      }
                                      return const SizedBox.shrink();
                                    },
                                  ),
                                ),
                                leftTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: true),
                                ),
                              ),
                              barGroups:
                                  produtosOrdenados.asMap().entries.map((e) {
                                final i = e.key;
                                final produto = e.value;
                                return BarChartGroupData(
                                  x: i,
                                  barRods: [
                                    BarChartRodData(
                                      toY: (produto['entradas'] ?? 0).toDouble(),
                                      color: Colors.green,
                                    ),
                                    BarChartRodData(
                                      toY: (produto['saidas'] ?? 0).toDouble(),
                                      color: Colors.red,
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (top5.isNotEmpty)
                      const Text('Top 5 produtos com mais saídas',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ...top5.map(
                      (p) => ListTile(
                        dense: true,
                        title: Text(p['nome']),
                        subtitle: Text(
                            'Entradas: ${p['entradas']} | Saídas: ${p['saidas']}'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (bottom5.isNotEmpty)
                      const Text('Top 5 produtos com menos saídas',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ...bottom5.map(
                      (p) => ListTile(
                        dense: true,
                        title: Text(p['nome']),
                        subtitle: Text(
                            'Entradas: ${p['entradas']} | Saídas: ${p['saidas']}'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _exportarGraficoParaPDF,
                      child: const Text('Exportar PDF'),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Fechar'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tituloPeriodo = '${_nomeMes(mesAtual)} / $anoAtual';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: _corFundo,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Relatório Mensal'),
            Text(tituloPeriodo, style: const TextStyle(fontSize: 14)),
          ],
        ),
        actions: [
          IconButton(
              icon: const Icon(Icons.date_range),
              onPressed: _mostrarSelecaoMesAno),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _carregarMovimentacoes),
        ],
      ),
      backgroundColor: _corFundo,
      body: Column(
        children: [
          // Filtro tipo
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ToggleButtons(
              borderRadius: BorderRadius.circular(10),
              fillColor: Colors.white,
              selectedColor: Colors.black,
              color: Colors.white,
              isSelected: [
                _filtroTipo == 'Todos',
                _filtroTipo == 'Entrada',
                _filtroTipo == 'Saída',
              ],
              onPressed: (index) {
                setState(() {
                  _filtroTipo = ['Todos', 'Entrada', 'Saída'][index];
                });
                _carregarMovimentacoes();
              },
              children: const [
                Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('Todos')),
                Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('Entradas')),
                Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('Saídas')),
              ],
            ),
          ),
          // Botão gráfico
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: ElevatedButton.icon(
              onPressed: () => mostrarGraficoComLista(context),
              icon: const Icon(Icons.bar_chart),
              label: const Text('Visualizar Gráfico'),
            ),
          ),
          // Lista movimentações
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : movimentacoes.isEmpty
                    ? const Center(child: Text('Nenhuma movimentação encontrada.'))
                    : ListView.builder(
                        itemCount: movimentacoes.length,
                        itemBuilder: (context, index) {
                          final mov = movimentacoes[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            elevation: 3,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: ListTile(
                              leading: (mov['entradas'] ?? 0) >= (mov['saidas'] ?? 0)
                                  ? const Icon(Icons.arrow_upward, color: Colors.green)
                                  : const Icon(Icons.arrow_downward, color: Colors.red),
                              title: Text(
                                '${mov['nome']} (${mov['codigo']})',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                'Entradas: ${mov['entradas']} | Saídas: ${mov['saidas']}',
                              ),
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
