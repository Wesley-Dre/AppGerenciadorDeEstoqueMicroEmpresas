import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:fp1/screens/Funcoes/criarcodigodebaras.dart';
import 'package:fp1/screens/Funcoes/inventario.dart';
import 'package:fp1/screens/Funcoes/leitor.dart';
import 'package:fp1/screens/Listas/lista_produtos.dart';
import 'package:fp1/screens/Listas/lista_usuarios.dart';
import 'package:fp1/screens/Funcoes/removerprodutos.dart';
import 'package:fp1/screens/Funcoes/login.dart';
import 'package:fp1/screens/Funcoes/movimentacoes.dart';
import 'package:fp1/screens/Funcoes/relatorio_de_vendas.dart';
import 'package:fp1/screens/Funcoes/cadstrar_funcionario.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:fp1/screens/Banco_de_dados_Usuarios/database_usuarios_supabase.dart';



class Gerenciador extends StatefulWidget {
  const Gerenciador({Key? key}) : super(key: key);

  @override
  _GerenciadorState createState() => _GerenciadorState();
}

class _GerenciadorState extends State<Gerenciador> {
  Color _corFundo = const Color.fromARGB(255, 150, 205, 231);

  String? _tipoUsuario;
  String? _nestabUsuario;
  String? _nomeUsuarioLogado;
  int _usuarioIdLogado = 0;

  int limiteEstoqueBaixo = 5;
  List<Map<String, dynamic>> _produtosEstoqueBaixo = [];

  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _carregarDadosUsuario();
    _verificarEstoqueBaixo();
  }

  Future<void> _carregarDadosUsuario() async {
    final prefs = await SharedPreferences.getInstance();
    _nomeUsuarioLogado = prefs.getString('usuario_logado') ?? '';

    if (_nomeUsuarioLogado!.isNotEmpty) {
      try {
        final response =
            await supabase
                .from('usuarios')
                .select()
                .eq('nome', _nomeUsuarioLogado!)
                .maybeSingle();

        if (response != null) {
          final int corSupabase = response['cor'] ?? 0xFF96CDE7;

          setState(() {
            _tipoUsuario =
                response['nome'].toString().toLowerCase() == 'admin'
                    ? 'Admin'
                    : 'Usuario';
            _nestabUsuario = response['nestab'];
            _corFundo = Color(corSupabase);
            _usuarioIdLogado = response['id'];
          });

          await prefs.setInt('usuario_id_logado', _usuarioIdLogado);
          await prefs.setString('usuario_logado', response['nome']);
          await prefs.setInt('usuario_cor', corSupabase);

          print('Usuário carregado do Supabase: ${response['nome']}');
        } else {
          print("Usuário não encontrado no Supabase.");
        }
      } catch (e) {
        print("Erro ao buscar usuário no Supabase: $e");
      }
    }
  }

  Future<void> _salvarCorBanco(Color cor) async {
    if (_nomeUsuarioLogado!.isNotEmpty) {
      try {
        await supabase
            .from('usuarios')
            .update({'cor': cor.value})
            .eq('nome', _nomeUsuarioLogado!);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('usuario_cor', cor.value);

        print("Cor atualizada com sucesso no Supabase e no cache local!");
      } catch (e) {
        print("Erro ao salvar cor no Supabase: $e");
      }
    }
  }

  Future<void> _resetarCorBanco() async {
    if (_nomeUsuarioLogado!.isNotEmpty) {
      try {
        await supabase
            .from('usuarios')
            .update({'cor': null})
            .eq('nome', _nomeUsuarioLogado!);
      } catch (e) {
        print("Erro ao resetar cor no Supabase: $e");
      }
    }
  }

  Future<void> _verificarEstoqueBaixo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final usuarioId = prefs.getInt('usuario_id');

      if (usuarioId == null) {
        print("Usuário não encontrado no SharedPreferences");
        return;
      }

      // 🔹 Buscar limite_vermelho do usuário no banco
      final usuario =
          await supabase
              .from('usuarios')
              .select('limite_vermelho')
              .eq('id', usuarioId)
              .maybeSingle();

      if (usuario == null || usuario['limite_vermelho'] == null) {
        print("Limite vermelho não encontrado para o usuário");
        return;
      }

      final limiteEstoqueBaixo = usuario['limite_vermelho'] as int;

      // 🔹 Buscar produtos com quantidade abaixo do limite
      final produtosBaixo = await supabase
          .from('produtos')
          .select()
          .lt('quantidade', limiteEstoqueBaixo)
          .eq('usuario_id', usuarioId);

      if (produtosBaixo.isNotEmpty && mounted) {
        setState(() {
          _produtosEstoqueBaixo = List<Map<String, dynamic>>.from(
            produtosBaixo,
          );
        });
        _mostrarAlertaEstoqueBaixo(limiteEstoqueBaixo);
      }
    } catch (e) {
      print("Erro ao verificar estoque baixo: $e");
    }
  }

  void _mostrarAlertaEstoqueBaixo(int limite) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Atenção! Estoque baixo'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('O limite mínimo definido é: $limite unidades.'),
                const SizedBox(height: 10),
                ListView.builder(
                  shrinkWrap: true,
                  itemCount: _produtosEstoqueBaixo.length,
                  itemBuilder: (context, index) {
                    final produto = _produtosEstoqueBaixo[index];
                    return ListTile(
                      title: Text(produto['nome'] ?? 'Produto sem nome'),
                      subtitle: Text('Quantidade: ${produto['quantidade']}'),
                    );
                  },
                ),
              ],
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
  }

  void _mostrarColorPicker() {
    Color corTemporaria = _corFundo;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Escolha a cor de fundo'),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: corTemporaria,
              onColorChanged: (color) {
                corTemporaria = color;
              },
              enableAlpha: false,
              labelTypes: const [],
              pickerAreaHeightPercent: 0.7,
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Refresh'),
              onPressed: () async {
                corTemporaria = const Color.fromARGB(255, 150, 205, 231);
                if (!mounted) return;
                setState(() {
                  _corFundo = corTemporaria;
                });
                await _resetarCorBanco();
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Salvar'),
              onPressed: () async {
                if (!mounted) return;
                setState(() {
                  _corFundo = corTemporaria;
                });
                await _salvarCorBanco(corTemporaria);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<bool> _confirmarLogout() async {
    bool? confirmarLogout = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Tem certeza?'),
          content: const Text('Você deseja deslogar?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Confirmar'),
            ),
          ],
        );
      },
    );
    return confirmarLogout ?? false;
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('usuario_logado');
    await prefs.remove('usuario_id_logado');

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const Login()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _confirmarLogout,
      child: Scaffold(
        backgroundColor: _corFundo,
        appBar: AppBar(
          title: Text(
            _nestabUsuario != null ? ' $_nestabUsuario' : 'Carregando...',
            style: const TextStyle(fontSize: 30),
          ),
          backgroundColor: _corFundo,
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.color_lens),
              onPressed: _mostrarColorPicker,
              tooltip: 'Alterar Cor de Fundo',
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(20.0),
          child: GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 20,
            mainAxisSpacing: 20,
            children: [
              _buildMenuButton(
                label: 'Cadastrar Produto',
                icon: Icons.edit_note,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const Leitor()),
                  );
                },
              ),
              _buildMenuButton(
                label: 'Ver Estoque',
                icon: Icons.inventory,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ListaDeProdutos(),
                    ),
                  );
                },
              ),
              _buildMenuButton(
                label: 'Saída de Produtos',
                icon: Icons.remove_shopping_cart,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const Removerprodutos(),
                    ),
                  );
                },
              ),
              _buildMenuButton(
                label: 'Funcionarios',
                icon: Icons.person_add,
                onPressed: () {
                  if (_nestabUsuario != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => CadastroFunc(
                              nestab: _nestabUsuario!,
                              usuarioId: _usuarioIdLogado,
                              cor: _corFundo.value,
                            ),
                      ),
                    );
                  }
                },
              ),
              if (_tipoUsuario == 'Admin')
                _buildMenuButton(
                  label: 'Usuários',
                  icon: Icons.people,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ListaDeUsuarios(),
                      ),
                    );
                  },
                ),
              _buildMenuButton(
                label: 'Movimentações',
                icon: Icons.multiple_stop,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const RelatorioMovimentacao(),
                    ),
                  );
                },
              ),
              _buildMenuButton(
                label: 'Relatório de Vendas',
                icon: Icons.attach_money,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const RelatorioDeVendasMensal(),
                    ),
                  );
                },
              ),
              _buildMenuButton(
                label: 'Inventario',
                icon: Icons.assignment_turned_in,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => SetoresScreen()),
                  );
                },
              ),
              _buildMenuButton(
                label: 'Logout',
                icon: Icons.logout,
                onPressed: () async {
                  final confirmar = await _confirmarLogout();
                  if (confirmar) {
                    await _logout();
                  }
                },
              ),
              _buildMenuButton(
                label: 'Gerar código de barras',
                icon: Icons.barcode_reader,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const GerarCodigoBarras()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.all(16),
        backgroundColor: const Color.fromARGB(255, 228, 228, 228),
        foregroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48),
          const SizedBox(height: 16),
          Text(
            label,
            style: const TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
