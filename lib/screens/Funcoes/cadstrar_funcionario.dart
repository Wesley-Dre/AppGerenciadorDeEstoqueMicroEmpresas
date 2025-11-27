import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CadastroFunc extends StatefulWidget {
  final String nestab;        // empresa do usuário logado
  final int usuarioId;        // id do usuário logado
  final int cor;              // cor do usuário logado

  const CadastroFunc({
    super.key,
    required this.nestab,
    required this.usuarioId,
    required this.cor,
  });

  @override
  State<CadastroFunc> createState() => _CadastroFuncState();
}

class _CadastroFuncState extends State<CadastroFunc> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> funcionarios = [];

  @override
  void initState() {
    super.initState();
    _carregarFuncionarios();
  }

  Future<void> _carregarFuncionarios() async {
    final response = await supabase
        .from('funcionarios')
        .select()
        .eq('nestab', widget.nestab);
    setState(() {
      funcionarios = List<Map<String, dynamic>>.from(response as List);
    });
  }

  Future<void> _removerFuncionario(int id) async {
    await supabase.from('funcionarios').delete().eq('id', id);
    _carregarFuncionarios();
  }

  void _mostrarDialogoCadastro() {
    final nomeController = TextEditingController();
    final senhaController = TextEditingController();
    final confirmarSenhaController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Color(widget.cor),
          title: const Text('Cadastrar Novo Funcionário'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: nomeController,
                  decoration: const InputDecoration(
                    labelText: 'Nome',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: senhaController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Senha',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: confirmarSenhaController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirmar Senha',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar', style: TextStyle(color: Colors.black)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
              onPressed: () async {
                final nome = nomeController.text.trim();
                final senha = senhaController.text.trim();
                final confirmar = confirmarSenhaController.text.trim();

                if (nome.isEmpty || senha.isEmpty || confirmar.isEmpty) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Preencha todos os campos')),
                  );
                  return;
                }

                if (senha != confirmar) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Senhas não coincidem')),
                  );
                  return;
                }

                await supabase.from('funcionarios').insert({
                  'nome': nome,
                  'senha': senha,
                  'nestab': widget.nestab,
                  'usuario_id': widget.usuarioId,
                  'cor': widget.cor,
                });

                await _carregarFuncionarios();
                if (!mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Funcionário cadastrado!')),
                );
              },
              child: const Text('Cadastrar', style: TextStyle(color: Colors.black)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cadastro de Funcionários'),
        backgroundColor: Color(widget.cor),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _mostrarDialogoCadastro,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: funcionarios.isEmpty
            ? const Center(child: Text('Nenhum funcionário cadastrado'))
            : ListView.builder(
                itemCount: funcionarios.length,
                itemBuilder: (context, index) {
                  final func = funcionarios[index];
                  return Card(
                    color: Colors.grey[200],
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    child: ListTile(
                      title: Text(func['nome'], style: const TextStyle(color: Colors.black)),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _removerFuncionario(func['id']),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
