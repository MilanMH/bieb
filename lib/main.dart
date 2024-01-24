import 'package:flutter/material.dart';
import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

//post and get url (ipconfig in cmd en dan ipv4 adres gebruiken)
const String baseUrl = 'http://10.0.2.10:3000';


void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Book Scanner',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const MainPage(),
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _currentIndex = 0;
  final List<Widget> _pages = [const ScannerPage(), const BooksListPage()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.camera_alt),
            label: 'Scan',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list),
            label: 'Boekenlijst',
          ),
        ],
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }
}

class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});

  @override
  _ScannerPageState createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  String _scanBarcode = 'Unknown';
  String _bookTitle = '';
  String _bookDescription = '';
  String _bookPages = '';
  String _bookQuantity = ''; // Variable for book quantity

  Future<void> scanBarcodeNormal() async {
    String barcodeScanRes;
    try {
      barcodeScanRes = await FlutterBarcodeScanner.scanBarcode(
          '#ff6666', 'Cancel', true, ScanMode.BARCODE);
      if (!mounted) return;
      setState(() {
        _scanBarcode = barcodeScanRes;
      });

      if (barcodeScanRes != '-1') {
        fetchBookData(barcodeScanRes);
      }
    } on Exception {
      barcodeScanRes = 'Failed to get barcode.';
    }
  }

  Future<void> fetchBookData(String isbn) async {
    final url = Uri.parse('https://www.googleapis.com/books/v1/volumes?q=isbn:$isbn');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        _bookTitle = data['items'][0]['volumeInfo']['title'] ?? 'No Title';
        _bookDescription = data['items'][0]['volumeInfo']['description'] ?? 'No Description';
        _bookPages = data['items'][0]['volumeInfo']['pageCount'].toString() ?? 'No Page Count';
      });
    } else {
      setState(() {
        _bookTitle = 'Failed to load book data';
        _bookDescription = '';
        _bookPages = '';
      });
    }
  }

  Future<void> addBookToDatabase() async {
    final url = Uri.parse(baseUrl + '/add_book'); // Adjust this to your server URL
    final headers = {"Content-Type": "application/json"};
    final bookJson = json.encode({
      'isbn': _scanBarcode,
      'title': _bookTitle,
      'description': _bookDescription,
      'pages': _bookPages,
      'quantity': _bookQuantity // Add the quantity to the data
    });

    try {
      final response = await http.post(url, headers: headers, body: bookJson);
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Book added to database"),
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Failed to add book"),
        ));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Exception: $e"),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Barcode Scanner'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text('Scan result: $_scanBarcode\n',
                style: Theme.of(context).textTheme.headline6),
            Text('Title: $_bookTitle\n',
                style: Theme.of(context).textTheme.headline6),
            Text('Description: $_bookDescription\n',
                style: Theme.of(context).textTheme.bodyText2),
            Text('Pages: $_bookPages\n',
                style: Theme.of(context).textTheme.bodyText2),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Aantal',
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  _bookQuantity = value;
                },
              ),
            ),
            ElevatedButton(
              onPressed: _scanBarcode != 'Unknown' && _bookQuantity.isNotEmpty
                  ? addBookToDatabase
                  : null,
              child: const Text('Add Book to Database'),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: scanBarcodeNormal,
        tooltip: 'Scan',
        child: const Icon(Icons.camera_alt),
      ),
    );
  }
}

class BooksListPage extends StatefulWidget {
  const BooksListPage({super.key});

  @override
  _BooksListPageState createState() => _BooksListPageState();
}

class _BooksListPageState extends State<BooksListPage> {
  List<dynamic> _books = [];

  @override
  void initState() {
    super.initState();
    fetchBooks();
  }

  Future<void> fetchBooks() async {
    final url = Uri.parse(baseUrl + '/get_books'); // Adjust for your network setup
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        setState(() {
          _books = json.decode(response.body);
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Failed to fetch books"),
        ));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Exception: $e"),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Boekenlijst'),
      ),
      body: ListView.builder(
        itemCount: _books.length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(_books[index]['title']),
            subtitle: Text(_books[index]['description']),
            trailing: Text('Aantal: ${_books[index]['quantity']}'),
          );
        },
      ),
    );
  }
}
