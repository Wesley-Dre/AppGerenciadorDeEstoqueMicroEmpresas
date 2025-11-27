// main.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:supabase_flutter/supabase_flutter.dart';


import 'package:fp1/screens/Funcoes/login.dart';
import 'package:fp1/screens/Funcoes/cadastro_usuario.dart';
import 'package:fp1/tutoriais/tutorialHome.dart';

class AnimacaoInicial extends StatefulWidget {
  const AnimacaoInicial({super.key});

  @override
  State<AnimacaoInicial> createState() => _AnimacaoInicialState();
}

class _AnimacaoInicialState extends State<AnimacaoInicial> {
  @override
  void initState() {
    super.initState();

    Timer(const Duration(seconds: 3), () {
      Navigator.pushReplacementNamed(context, '/main');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 150, 205, 231),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/images/logo.png', width: 200),
            const SizedBox(height: 20),
            const Text(
              'GERENCIADOR DE ESTOQUE',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            const CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa o Supabase - substitua a anonKey se quiser trocar depois
  await Supabase.initialize(
    url: 'https://sxxbhzvseufhvmiojmmt.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN4eGJoenZzZXVmaHZtaW9qbW10Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTg0Mjk0MjYsImV4cCI6MjA3NDAwNTQyNn0.lGHTqwGVTp1zX3xxkDH55aoebCSy8wC3wSVluF0gN80',
  );

  final prefs = await SharedPreferences.getInstance();
  final viuTutorial = prefs.getBool('viuTutorial') ?? false;

  runApp(AppComSplash(viuTutorial: viuTutorial));
}

class AppComSplash extends StatelessWidget {
  final bool viuTutorial;
  const AppComSplash({super.key, required this.viuTutorial});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Controle de Estoque',
      initialRoute: '/',
      routes: {
        '/': (context) => const AnimacaoInicial(),
        '/main': (context) => MainApp(viuTutorial: viuTutorial),
      },
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('pt', 'BR')],
      locale: const Locale('pt', 'BR'),
    );
  }
}

class MainApp extends StatelessWidget {
  final bool viuTutorial;
  const MainApp({super.key, required this.viuTutorial});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: viuTutorial ? const HomePage() : const TutorialScreen(),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('pt', 'BR')],
      locale: const Locale('pt', 'BR'),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 150, 205, 231),
      body: Stack(
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(
                right: 20.0,
                top: 50.0,
                left: 20.0,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Stack(
                    children: [
                      Text(
                        'GERENCIADOR DE ESTOQUE',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                          foreground:
                              Paint()
                                ..style = PaintingStyle.stroke
                                ..strokeWidth = 3
                                ..color = Colors.black,
                        ),
                      ),
                      const Text(
                        'GERENCIADOR DE ESTOQUE',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 100),

                  //logo
                  Image.asset(
                    'assets/images/logo.png',
                    width: 300,
                    height: 300,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 20),

                  //btn login
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const Login()),
                      );
                    },
                    icon: const Icon(
                      Icons.login,
                      size: 30,
                      color: Colors.black,
                    ),
                    label: const Text(
                      'LOGAR',
                      style: TextStyle(fontSize: 30, color: Colors.black),
                    ),
                  ),

                  const SizedBox(height: 20),

                  //btn Cadastro
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const Cadastro(),
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.person,
                      size: 30,
                      color: Colors.black,
                    ),
                    label: const Text(
                      'Cadastrar',
                      style: TextStyle(fontSize: 30, color: Colors.black),
                    ),
                  ),

                  const SizedBox(height: 20),

                  //Btn Sair
                  ElevatedButton.icon(
                    onPressed: () {
                      SystemNavigator.pop();
                    },
                    icon: const Icon(
                      Icons.exit_to_app,
                      size: 30,
                      color: Colors.black,
                    ),
                    label: const Text(
                      'SAIR DO APP',
                      style: TextStyle(fontSize: 30, color: Colors.black),
                    ),
                  ),
                ],
              ),
            ),
          ),

          Positioned(
            bottom: 820,
            right: 20,
            child: IconButton(
              icon: const Icon(
                Icons.help_outline,
                size: 30,
                color: Colors.black,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TutorialScreen(),
                  ),
                );
              },
              tooltip: 'Ver tutorial',
              splashRadius: 28,
            ),
          ),
        ],
      ),
    );
  }
}
