import 'package:flutter/material.dart';
import 'package:fp1/screens/Pagina_pos_login/home.dart';
import 'package:fp1/screens/Funcoes/Esqueceu_a_senha.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Banco_de_dados_Usuarios/database_usuarios_supabase.dart';

class Login extends StatefulWidget {
  const Login({Key? key}) : super(key: key);

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final TextEditingController _nomeController = TextEditingController();
  final TextEditingController _senhaController = TextEditingController();

  Future<void> _realizarLogin() async {
    final nome = _nomeController.text.trim();
    final senha = _senhaController.text.trim();

    if (nome.isEmpty || senha.isEmpty) {
      _mostrarDialogo('Campos obrigatórios', 'Preencha todos os campos.');
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();

      // 🔹 1. Verifica se é USUÁRIO (dono)
      final usuario =
          await DatabaseHelperSupabase.verificarUsuario(nome, senha);

      if (usuario != null) {
        print('✅ Login como USUÁRIO: $nome');
        usuario.forEach((k, v) => print('  $k: $v'));

        await prefs.setString('usuario_logado', nome);
        await prefs.setInt('usuario_id_logado', usuario['id']);
        await prefs.setString('tipo_usuario', 'usuario');
        await prefs.setInt('usuario_cor', usuario['cor'] ?? 0xFF96CDE7);

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const Gerenciador()),
        );
        return;
      }

      // 🔹 2. Verifica se é FUNCIONÁRIO
      final funcionario =
          await DatabaseHelperSupabase.verificarFuncionario(nome, senha);

      if (funcionario != null) {
        print('✅ Login como FUNCIONÁRIO: $nome');
        funcionario.forEach((k, v) => print('  $k: $v'));

        await prefs.setString('usuario_logado', nome);
        await prefs.setString('tipo_usuario', 'funcionario');
        await prefs.setInt('usuario_id_funcionario', funcionario['id']);
        await prefs.setInt('usuario_cor', funcionario['cor'] ?? 0xFF96CDE7);

        // ⚠️ Novo: se a tabela funcionarios tiver o campo usuario_id
        if (funcionario['usuario_id'] != null) {
          await prefs.setInt(
              'usuario_id_logado', funcionario['usuario_id']); // Dono
        }

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const Gerenciador()),
        );
        return;
      }

      // 🔹 3. Nenhum encontrado
      _mostrarDialogo('Login incorreto', 'Usuário ou senha inválidos.');
    } catch (e) {
      print('❌ Erro ao realizar login: $e');
      _mostrarDialogo(
          'Erro de conexão', 'Não foi possível conectar ao servidor.');
    }
  }

  void _mostrarDialogo(String titulo, String mensagem) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(titulo),
        content: Text(mensagem),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 150, 205, 231),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 150, 205, 231),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Center(
              child: Image.asset('assets/images/logo.png', width: 200),
            ),
            const SizedBox(height: 30),
            const Text("Usuário", style: TextStyle(fontSize: 18)),
            const SizedBox(height: 8),
            TextField(
              controller: _nomeController,
              decoration: const InputDecoration(
                labelText: 'Digite seu nome de usuário',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            const Text("Senha", style: TextStyle(fontSize: 18)),
            const SizedBox(height: 8),
            TextField(
              controller: _senhaController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Digite sua senha',
                border: OutlineInputBorder(),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const EsqueceuSenha(),
                  ),
                );
              },
              child: const Text(
                'Esqueceu a Senha?',
                style: TextStyle(fontSize: 10, color: Colors.black),
              ),
            ),
            const SizedBox(height: 5),
            ElevatedButton(
              onPressed: _realizarLogin,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
              child: const Text(
                'Login',
                style: TextStyle(fontSize: 18, color: Colors.black),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
