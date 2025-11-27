import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Banco_de_dados_Usuarios/database_usuarios.dart';

class ListaDeUsuarios extends StatefulWidget {
  const ListaDeUsuarios({Key? key}) : super(key: key);

  @override
  State<ListaDeUsuarios> createState() => _ListaDeUsuariosState();
}

class _ListaDeUsuariosState extends State<ListaDeUsuarios> {
  final TextEditingController _controller = TextEditingController();
  List<Map<String, dynamic>> _usuarios = [];
  List<Map<String, dynamic>> _usuariosEncontrados = [];
  int _totalUsuarios = 0;
  int _totalUsuariosEncontrados = 0;

  Color _corFundo = const Color.fromARGB(255, 150, 205, 231);

  @override
  void initState() {
    super.initState();
    _carregarUsuarios();
    _carregarCorUsuario();
  }

  Future<void> _carregarCorUsuario() async {
    final prefs = await SharedPreferences.getInstance();
    final nomeUsuario = prefs.getString('usuario_logado') ?? '';

    if (nomeUsuario.isNotEmpty) {
      final usuario = await DatabaseHelper().getUsuarioPorNome(nomeUsuario);

      if (usuario != null && usuario['cor'] != null) {
        setState(() {
          _corFundo = Color(usuario['cor']);
        });
      }
    }
  }

  Future<void> _carregarUsuarios() async {
    final usuarios = await DatabaseHelper().listarUsuarios();
    setState(() {
      _usuarios = usuarios;
      _totalUsuarios = usuarios.length;
    });
  }

  Future<void> _buscarUsuarios() async {
    final searchQuery = _controller.text.trim();
    if (searchQuery.isNotEmpty) {
      final encontrados =
          await DatabaseHelper().buscarUsuarioPorNomeOuEmail(searchQuery);
      setState(() {
        _usuariosEncontrados = encontrados;
        _totalUsuariosEncontrados = encontrados.length;
      });
    } else {
      setState(() {
        _usuariosEncontrados = [];
        _totalUsuariosEncontrados = 0;
      });
    }
  }

  Future<void> _removerUsuario(int id) async {
    await DatabaseHelper().removerConta(id);
    await _carregarUsuarios();
    await _buscarUsuarios();
  }

  String nomeDaCor(int? cor) {
    switch (cor) {
      case 0xFF96CDE7:
        return 'Azul Claro';
      case 0xFFFFD54F:
        return 'Amarelo';
      case 0xFFA5D6A7:
        return 'Verde Claro';
      case 0xFFFF8A65:
        return 'Laranja';
      case 0xFFE57373:
        return 'Vermelho';
      default:
        return 'Cor Personalizada';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool buscando = _controller.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: _corFundo,
      appBar: AppBar(
        title: const Text('Lista de Usuários'),
        backgroundColor: _corFundo,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white, // fundo branco para o campo de busca
                labelText: 'Buscar por nome ou email',
                border: const OutlineInputBorder(),
              ),
              onChanged: (text) => _buscarUsuarios(),
            ),
          ),
          Expanded(
            child: buscando
                ? _usuariosEncontrados.isNotEmpty
                    ? _buildLista(_usuariosEncontrados, true)
                    : const Center(child: Text('Nenhum usuário encontrado.'))
                : _usuarios.isNotEmpty
                    ? _buildLista(_usuarios, true)
                    : const Center(child: Text('Nenhum usuário cadastrado.')),
          ),
        ],
      ),
      floatingActionButton: CircleAvatar(
        backgroundColor: Colors.blueAccent,
        radius: 28,
        child: Text(
          buscando ? '$_totalUsuariosEncontrados' : '$_totalUsuarios',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildLista(List<Map<String, dynamic>> usuarios, bool podeExcluir) {
    return ListView.separated(
      itemCount: usuarios.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      itemBuilder: (context, index) {
        final usuario = usuarios[index];
        final corRaw = usuario['cor'];
        int? corValor;

        if (corRaw == null) {
          corValor = null;
        } else if (corRaw is int) {
          corValor = corRaw;
        } else if (corRaw is String) {
          corValor = int.tryParse(corRaw.replaceAll('#', ''), radix: 16);
        }

        return Card(
          color: Colors.white,
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: ListTile(
            leading: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: corValor != null ? Color(corValor) : const Color(0xFF96CDE7),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black54),
              ),
            ),
            title: Text(
              usuario['nome'],
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              'ID: ${usuario['id']} | Email: ${usuario['email']} | Cor: ${nomeDaCor(corValor)}',
            ),
            trailing: podeExcluir
                ? IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Confirmar Exclusão'),
                          content:
                              Text('Deseja remover o usuário "${usuario['nome']}"?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancelar'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Remover'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await _removerUsuario(usuario['id']);
                      }
                    },
                  )
                : null,
          ),
        );
      },
    );
  }
}
