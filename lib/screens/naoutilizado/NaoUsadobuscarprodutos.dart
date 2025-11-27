import 'package:flutter/material.dart';
import 'package:fp1/screens/Banco_de_dados_Produtos/banco_produtos.dart'; 

class BuscarProdutos extends StatefulWidget {
  const BuscarProdutos({Key? key}) : super(key: key);

  @override
  _BuscarProdutosState createState() => _BuscarProdutosState();
}

class _BuscarProdutosState extends State<BuscarProdutos> {
  TextEditingController _controller = TextEditingController();
  List<Map<String, dynamic>> _produtosEncontrados = [];
  int _totalProdutosEncontrados = 0;

  // Função que carrega os produtos encontrados com nome ou código similar
  Future<void> _buscarProdutos() async {
    final searchQuery = _controller.text;
    if (searchQuery.isNotEmpty) {
      final produtos = await DatabaseHelper().buscarProdutosPorNomeOuCodigo(searchQuery);
      setState(() {
        _produtosEncontrados = produtos;
        _totalProdutosEncontrados = produtos.length;  // Atualiza o contador
      });
    } else {
      setState(() {
        _produtosEncontrados = [];
        _totalProdutosEncontrados = 0;  // Caso o campo esteja vazio, o contador é 0
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buscar Produtos'),
        backgroundColor: Colors.blueAccent,
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Campo de busca
                TextField(
                  controller: _controller,
                  decoration: const InputDecoration(
                    labelText: 'Digite o nome ou código do produto',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (text) {
                    _buscarProdutos(); // Chama a função de busca a cada mudança
                  },
                ),
                const SizedBox(height: 20),
                // Lista de produtos encontrados
                Expanded(
                  child: _produtosEncontrados.isEmpty
                      ? const Center(child: Text('Nenhum produto encontrado.'))
                      : ListView.builder(
                          itemCount: _produtosEncontrados.length,
                          itemBuilder: (context, index) {
                            final produto = _produtosEncontrados[index];
                            return ListTile(
                              leading: const Icon(Icons.inventory_2),
                              title: Text(produto['nome']),
                              subtitle: Text('Código: ${produto['codigo']}'),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          // Círculo com contador no canto inferior direito
          Positioned(
            bottom: 20,
            right: 20,
            child: CircleAvatar(
              backgroundColor: Colors.blueAccent,
              radius: 24,
              child: Text(
                '$_totalProdutosEncontrados', // Exibe o número de produtos encontrados
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
