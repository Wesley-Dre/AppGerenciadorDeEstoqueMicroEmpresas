import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

class EsqueceuSenha extends StatefulWidget {
  const EsqueceuSenha({super.key});

  @override
  EsqueceuSenhaState createState() => EsqueceuSenhaState();
}

class EsqueceuSenhaState extends State<EsqueceuSenha> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _codigoController = TextEditingController();
  final TextEditingController _novaSenhaController = TextEditingController();
  final TextEditingController _confirmarSenhaController =
      TextEditingController();

  final supabase = Supabase.instance.client;

  int? _usuarioId;
  String? _codigoGerado;

  bool _codigoEnviado = false;
  bool _codigoValidado = false; // controla se o código foi validado

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 150, 205, 231),
      appBar: AppBar(
        title: const Text('Recuperar Senha'),
        backgroundColor: const Color.fromARGB(255, 150, 205, 231),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: Column(
              children: [
                Image.asset('assets/images/triste.png', width: 200),
                const SizedBox(height: 20),
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 8,
                  color: const Color.fromARGB(255, 217, 240, 237),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Recuperação de Senha',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // ----------------------
                        // Passo 1: e-mail
                        // ----------------------
                        if (!_codigoEnviado) ...[
                          TextField(
                            controller: _emailController,
                            decoration: const InputDecoration(
                              labelText: 'E-mail',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size.fromHeight(50),
                              backgroundColor: Colors.blueAccent,
                            ),
                            onPressed: _enviarCodigo,
                            child: const Text('Enviar Código'),
                          ),
                        ],

                        // ----------------------
                        // Passo 2: validar código
                        // ----------------------
                        if (_codigoEnviado && !_codigoValidado) ...[
                          PinCodeTextField(
                            appContext: context,
                            length: 6,
                            controller: _codigoController,
                            keyboardType: TextInputType.number,
                            animationType: AnimationType.fade,
                            pinTheme: PinTheme(
                              shape: PinCodeFieldShape.box,
                              borderRadius: BorderRadius.circular(5),
                              fieldHeight: 50,
                              fieldWidth: 40,
                              inactiveColor: Colors.grey,
                              activeColor: Colors.blueAccent,
                              selectedColor: Colors.green,
                            ),
                            onChanged: (value) {},
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size.fromHeight(50),
                              backgroundColor: Colors.green,
                            ),
                            onPressed: _validarCodigo,
                            child: const Text('Validar Código'),
                          ),
                        ],

                        // ----------------------
                        // Passo 3: nova senha
                        // ----------------------
                        if (_codigoValidado) ...[
                          TextField(
                            controller: _novaSenhaController,
                            decoration: const InputDecoration(
                              labelText: 'Nova Senha',
                              border: OutlineInputBorder(),
                            ),
                            obscureText: true,
                          ),
                          const SizedBox(height: 20),
                          TextField(
                            controller: _confirmarSenhaController,
                            decoration: const InputDecoration(
                              labelText: 'Confirmar Senha',
                              border: OutlineInputBorder(),
                            ),
                            obscureText: true,
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size.fromHeight(50),
                              backgroundColor: Colors.green,
                            ),
                            onPressed: _alterarSenha,
                            child: const Text('Alterar Senha'),
                          ),
                        ],
                      ],
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

  void _mostrarSnackBar(String mensagem, {bool erro = false}) {
    if (!mounted) return;
    final snackBar = SnackBar(
      content: Text(mensagem),
      backgroundColor: erro ? Colors.red : Colors.green,
      duration: const Duration(seconds: 3),
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  // ----------------------
  // Enviar código
  // ----------------------
  Future<void> _enviarCodigo() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _mostrarSnackBar('O campo e-mail está vazio.', erro: true);
      return;
    }

    try {
      final usuario = await supabase
          .from('usuarios')
          .select()
          .eq('email', email)
          .maybeSingle();

      if (usuario == null) {
        _mostrarSnackBar('E-mail não encontrado.', erro: true);
        return;
      }

      _usuarioId = usuario['id'] as int?;

      _codigoGerado = (Random().nextInt(900000) + 100000).toString();

      await supabase.from('recuperacao_senha').insert({
        'usuario_id': _usuarioId!,
        'codigo': _codigoGerado!,
        'usado': false,
      });

      await _enviarEmail(email, _codigoGerado!);

      _codigoEnviado = true;
      setState(() {});

      _mostrarSnackBar('Código enviado para seu e-mail!');
    } catch (e) {
      _mostrarSnackBar('Falha ao enviar código: $e', erro: true);
    }
  }

  // ----------------------
  // Validar código
  // ----------------------
  Future<void> _validarCodigo() async {
    final codigoDigitado = _codigoController.text.trim();

    if (codigoDigitado.isEmpty) {
      _mostrarSnackBar('Digite o código enviado.', erro: true);
      return;
    }

    try {
      final registro = await supabase
          .from('recuperacao_senha')
          .select()
          .eq('usuario_id', _usuarioId!)
          .eq('codigo', codigoDigitado)
          .eq('usado', false)
          .maybeSingle();

      if (registro == null) {
        _mostrarSnackBar('Código inválido ou já usado.', erro: true);
        return;
      }

      // Código válido
      _codigoValidado = true;
      setState(() {});
      _mostrarSnackBar('Código validado com sucesso!');
    } catch (e) {
      _mostrarSnackBar('Erro ao validar código: $e', erro: true);
    }
  }

  // ----------------------
  // Alterar senha
  // ----------------------
  Future<void> _alterarSenha() async {
    final novaSenha = _novaSenhaController.text.trim();
    final confirmarSenha = _confirmarSenhaController.text.trim();

    if (novaSenha.isEmpty || confirmarSenha.isEmpty) {
      _mostrarSnackBar('Preencha todos os campos.', erro: true);
      return;
    }

    if (novaSenha != confirmarSenha) {
      _mostrarSnackBar('As senhas não coincidem.', erro: true);
      return;
    }

    try {
      await supabase
          .from('usuarios')
          .update({'senha': novaSenha})
          .eq('id', _usuarioId!);

      await supabase
          .from('recuperacao_senha')
          .update({'usado': true})
          .eq('usuario_id', _usuarioId!);

      _mostrarSnackBar('Senha alterada com sucesso!');

      // Resetar tela
      _emailController.clear();
      _codigoController.clear();
      _novaSenhaController.clear();
      _confirmarSenhaController.clear();
      _codigoEnviado = false;
      _codigoValidado = false;
      setState(() {});
    } catch (e) {
      _mostrarSnackBar('Falha ao alterar senha: $e', erro: true);
    }
  }

  // ----------------------
  // Enviar email
  // ----------------------
  Future<void> _enviarEmail(String destinatario, String codigo) async {
    String username = 'appgerenciadordeestoque@gmail.com';
    String password = 'gqzd xvfs fxek msds';

    final smtpServer = gmail(username, password);

    final message = Message()
      ..from = Address(username, 'Support Gerenciador de Estoque')
      ..recipients.add(destinatario)
      ..subject = 'Recuperação de Senha'
      ..text = 'Aqui está seu código de recuperação de senha: $codigo';

    try {
      await send(message, smtpServer);
      _mostrarSnackBar('Email enviado com sucesso!');
    } on MailerException catch (e) {
      _mostrarSnackBar('Erro ao enviar email: ${e.toString()}', erro: true);
    }
  }
}
