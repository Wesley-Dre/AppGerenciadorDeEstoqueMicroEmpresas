import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RelatorioMovimentacao extends StatefulWidget {
  const RelatorioMovimentacao({Key? key}) : super(key: key);

  @override
  State<RelatorioMovimentacao> createState() => _RelatorioMovimentacaoState();
}

class _RelatorioMovimentacaoState extends State<RelatorioMovimentacao> {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> movimentacoes = [];
  bool _isLoading = true;

  DateTime? dataSelecionada;
  Color _corFundo = const Color.fromARGB(255, 150, 205, 231);
  int usuarioId = 0;

  String _filtroTipo = 'Todos';
  String _busca = '';

  @override
  void initState() {
    super.initState();
    dataSelecionada = DateTime.now();
    _carregarUsuarioECor();
  }

  /// 🔹 Carrega ID e cor do usuário salvos no SharedPreferences
  Future<void> _carregarUsuarioECor() async {
    final prefs = await SharedPreferences.getInstance();

    usuarioId = prefs.getInt('usuario_id_logado') ?? 0;
    final corSalva = prefs.getInt('usuario_cor');

    // 🔸 Se houver cor salva, aplica imediatamente
    if (corSalva != null) {
      setState(() {
        _corFundo = Color(corSalva);
      });
    }

    // 🔸 Caso o usuário esteja logado, busca as movimentações
    if (usuarioId != 0) {
      final dataFormatada = DateFormat('yyyy-MM-dd').format(dataSelecionada!);
      await _carregarMovimentacoes(data: dataFormatada);
    }
  }

  Future<void> _carregarMovimentacoes({String? data}) async {
    setState(() => _isLoading = true);

    try {
      PostgrestFilterBuilder query = supabase
          .from('movimentacoes')
          .select()
          .eq('usuario_id', usuarioId);

      if (data != null) {
        query = query
            .gte('data', '$data 00:00:00')
            .lte('data', '$data 23:59:59');
      }

      if (_filtroTipo != 'Todos') {
        query = query.eq('tipo', _filtroTipo);
      }

      final response = await query.order('data', ascending: false);
      final lista = List<Map<String, dynamic>>.from(response);

      final filtrada = lista.where((mov) {
        final nome = (mov['nome'] ?? '').toString().toLowerCase();
        final codigo = (mov['codigo'] ?? '').toString().toLowerCase();
        final buscaLower = _busca.toLowerCase();
        return nome.contains(buscaLower) || codigo.contains(buscaLower);
      }).toList();

      setState(() {
        movimentacoes = filtrada;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Erro ao carregar movimentações: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selecionarData(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: dataSelecionada ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        dataSelecionada = picked;
      });

      final dataFormatada = DateFormat('yyyy-MM-dd').format(picked);
      await _carregarMovimentacoes(data: dataFormatada);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dataTexto = dataSelecionada != null
        ? DateFormat('dd/MM/yyyy').format(dataSelecionada!)
        : 'Selecione a data';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: _corFundo,
        title: const Text('Relatório Diário'),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: () => _selecionarData(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              final dataFormatada =
                  DateFormat('yyyy-MM-dd').format(DateTime.now());
              _carregarMovimentacoes(data: dataFormatada);
            },
          ),
        ],
      ),
      backgroundColor: _corFundo,
      body: Column(
        children: [
          // 🔹 Botões de filtro
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
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
                  if (index == 0) _filtroTipo = 'Todos';
                  if (index == 1) _filtroTipo = 'Entrada';
                  if (index == 2) _filtroTipo = 'Saída';
                });
                final dataFormatada =
                    DateFormat('yyyy-MM-dd').format(dataSelecionada!);
                _carregarMovimentacoes(data: dataFormatada);
              },
              children: const [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('Todos'),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('Entrada'),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('Saída'),
                ),
              ],
            ),
          ),

          // 🔹 Campo de busca
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Buscar por nome ou código',
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              ),
              onChanged: (v) {
                setState(() => _busca = v);
                final dataFormatada =
                    DateFormat('yyyy-MM-dd').format(dataSelecionada!);
                _carregarMovimentacoes(data: dataFormatada);
              },
            ),
          ),

          // 🔹 Data selecionada
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              'Data: $dataTexto',
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),

          // 🔹 Lista de movimentações
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : movimentacoes.isEmpty
                    ? const Center(
                        child: Text('Nenhuma movimentação encontrada.'),
                      )
                    : ListView.builder(
                        itemCount: movimentacoes.length,
                        itemBuilder: (context, index) {
                          final mov = movimentacoes[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            child: ListTile(
                              leading: Icon(
                                mov['tipo'] == 'Entrada'
                                    ? Icons.arrow_upward
                                    : Icons.arrow_downward,
                                color: mov['tipo'] == 'Entrada'
                                    ? Colors.green
                                    : Colors.red,
                              ),
                              title: Text(mov['nome'] ?? 'Produto'),
                              subtitle: Text(
                                '${mov['tipo']} - ${mov['quantidade']} '
                                '${mov['quantidade'] == 1 ? 'unidade' : 'unidades'} '
                                '(${mov['codigo'] ?? '-'})\n'
                                'Data: ${mov['data']}',
                              ),
                              isThreeLine: true,
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
