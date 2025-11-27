import 'package:flutter/material.dart';
import 'package:fp1/main.dart';
import '../Banco_de_dados_Usuarios/database_usuarios_supabase.dart';

class Cadastro extends StatefulWidget {
  const Cadastro({Key? key}) : super(key: key);

  @override
  _CadastroState createState() => _CadastroState();
}

class _CadastroState extends State<Cadastro> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _nomeController = TextEditingController();
  final TextEditingController _senhaController = TextEditingController();
  final TextEditingController _confirmarSenhaController =
      TextEditingController();
  final TextEditingController _nestabController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cadastro de Usuário'),
        backgroundColor: const Color.fromARGB(255, 150, 205, 231),
      ),
      body: Container(
        color: const Color.fromARGB(255, 150, 205, 231),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  // Centraliza a imagem
                  child: Image.asset(
                    'assets/images/logo.png',
                    width: 200,
                    height: 200,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 20),

                const Text('E-mail'),
                const SizedBox(height: 5),
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'E-mail',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),

                const Text('Nome de Usuário'),
                const SizedBox(height: 5),
                TextField(
                  controller: _nomeController,
                  decoration: const InputDecoration(
                    labelText: 'Nome de Usuário',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),

                const Text('Senha'),
                const SizedBox(height: 5),
                TextField(
                  controller: _senhaController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Senha',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),

                const Text('Confirmar Senha'),
                const SizedBox(height: 5),
                TextField(
                  controller: _confirmarSenhaController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirmar Senha',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),

                const Text('Nome do Estabelecimento'),
                const SizedBox(height: 5),
                TextField(
                  controller: _nestabController,
                  decoration: const InputDecoration(
                    labelText: 'Nome do Estabelecimento',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 30),

                Center(
                  child: ElevatedButton(
                    onPressed: _cadastrarUsuario,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                    ),
                    child: const Text(
                      'Cadastrar',
                      style: TextStyle(fontSize: 18, color: Colors.black),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _cadastrarUsuario() async {
    final email = _emailController.text.trim();
    final nome = _nomeController.text.trim();
    final senha = _senhaController.text.trim();
    final confirmarSenha = _confirmarSenhaController.text.trim();
    final nestab = _nestabController.text.trim();

    if (email.isEmpty ||
        nome.isEmpty ||
        senha.isEmpty ||
        confirmarSenha.isEmpty ||
        nestab.isEmpty) {
      _mostrarMensagem('Preencha todos os campos');
      return;
    }

    if (senha != confirmarSenha) {
      _mostrarMensagem('As senhas não coincidem');
      return;
    }

    try {
      // Verifica se já existe usuário ou estabelecimento
      final usuarioExistente = await DatabaseHelperSupabase.verificarUsuario(
        nome,
        senha,
      );
      if (usuarioExistente != null) {
        _mostrarMensagem('Nome de usuário já está em uso');
        return;
      }

      // Insere o usuário usando o helper
      await DatabaseHelperSupabase.inserirUsuario(nome, email, senha, nestab);

      _mostrarMensagem('Cadastro realizado com sucesso!');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
      );
    } catch (e) {
      print('Erro ao cadastrar usuário: $e');
      _mostrarMensagem('Erro ao cadastrar usuário');
    }
  }

  void _mostrarMensagem(String mensagem) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(mensagem)));
  }
}
