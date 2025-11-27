import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart'; // 🔁 Importa para acessar a HomePage

class TutorialScreen extends StatefulWidget {
  const TutorialScreen({super.key});

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  final PageController _controller = PageController();
  int _paginaAtual = 0;

  final List<Map<String, String>> _paginas = [
    {
      'titulo': 'Bem-vindo!',
      'descricao':
          'Este é o seu gerenciador de estoque.\nVamos te explicar como ele pode te ajudar.',
    },
    {
      'titulo': 'Criar uma conta',
      'descricao':
          'Você precisara se cadastrar para permitir o uso das fuções do aplicativo, caso seja um funcionario basta realizar o login.',
    },
    {
      'titulo': 'Funções',
      'descricao':
          'Monitore entradas e saídas do seu estoque em tempo real.\n Cadastre e romova produtos.\n Emita relatorios de vendas.',
    },
    {
      'titulo': 'Pronto!',
      'descricao':
          'Agora que você ja sabe o basico, é só começar a usar o app. Boa sorte!',
    },
  ];

 
  Future<void> _concluirTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('viuTutorial', true);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const HomePage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.lightBlue[50],
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _controller,
              onPageChanged: (index) {
                setState(() => _paginaAtual = index);
              },
              itemCount: _paginas.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/images/logo.png',
                        width: 200,
                        height: 200,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 40),
                      Text(
                        _paginas[index]['titulo']!,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _paginas[index]['descricao']!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 18),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Indicadores de página
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_paginas.length, (index) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 16),
                width: _paginaAtual == index ? 16 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _paginaAtual == index ? Colors.blue : Colors.grey,
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),

          // Botões de navegação
          if (_paginaAtual == _paginas.length - 1)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Center(
                child: ElevatedButton(
                  onPressed: _concluirTutorial,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                  child: const Text('Concluir', style: TextStyle(fontSize: 18)),
                ),
              ),
            )
          else
            const SizedBox(height: 48), // Espaço reservado para manter a altura
        ],
      ),
    );
  }
}
