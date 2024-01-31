import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:http_parser/http_parser.dart';

const ipurl = 'http://10.0.1.68:3000';

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
  String _bookAuthor = '';
  String _bookDescription = '';
  String _bookPages = '';
  String _bookQuantity = '1';
  File? _image;

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
        await _takePicture();
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
        _bookAuthor = data['items'][0]['volumeInfo']['authors']?.join(', ') ?? 'Unknown Author';
        _bookDescription = data['items'][0]['volumeInfo']['description'] ?? 'No Description';
        _bookPages = data['items'][0]['volumeInfo']['pageCount'].toString() ?? 'No Page Count';
      });
    } else {
      setState(() {
        _bookTitle = 'Failed to load book data';
        _bookAuthor = '';
        _bookDescription = '';
        _bookPages = '';
      });
    }
  }

  Future<void> _takePicture() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);

    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  Future<void> addBookToDatabase() async {
    var uri = Uri.parse(ipurl + '/add_book');
    var request = http.MultipartRequest('POST', uri)
      ..fields['isbn'] = _scanBarcode
      ..fields['title'] = _bookTitle
      ..fields['author'] = _bookAuthor
      ..fields['description'] = _bookDescription
      ..fields['pages'] = _bookPages
      ..fields['quantity'] = _bookQuantity;
    if (_image != null) {
      request.files.add(await http.MultipartFile.fromPath(
        'image_path',
        _image!.path,
        contentType: MediaType('image', 'jpeg'),
      ));
    }

    try {
      final response = await request.send();
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
        backgroundColor: const Color(0xFF664E9F),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text('Scan result: $_scanBarcode\n', style: Theme.of(context).textTheme.headline6),
            Text('Title: $_bookTitle\n', style: Theme.of(context).textTheme.headline6),
            Text('Author: $_bookAuthor\n', style: Theme.of(context).textTheme.bodyText2),
            Text('Description: $_bookDescription\n', style: Theme.of(context).textTheme.bodyText2),
            Text('Pages: $_bookPages\n', style: Theme.of(context).textTheme.bodyText2),
            if (_image != null)
              Container(
                width: 100.0,  // Breedte van de afbeelding
                height: 150.0, // Hoogte van de afbeelding
                child: Image.file(_image!, fit: BoxFit.cover),
              ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: TextEditingController(text: _bookQuantity),
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
    final url = Uri.parse(ipurl + '/get_books');
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
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              showSearch(
                context: context,
                delegate: BookSearchDelegate(_books),
              );
            },
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: _books.length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(_books[index]['title']),
            subtitle: Text(_books[index]['author']),
            trailing: Text(_books[index]['isbn']),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BookDetailsPage(book: _books[index]),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class BookSearchDelegate extends SearchDelegate {
  final List<dynamic> books;

  BookSearchDelegate(this.books);

  List<dynamic> _filterBooks(String searchText) {
    if (searchText.isEmpty) {
      return books;
    }

    return books.where((book) {
      return book['isbn'].toLowerCase().contains(searchText.toLowerCase()) ||
          book['title'].toLowerCase().contains(searchText.toLowerCase()) ||
          book['author'].toLowerCase().contains(searchText.toLowerCase());
    }).toList();
  }

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
          showResults(context);
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    final filteredBooks = _filterBooks(query);
    return ListView.builder(
      itemCount: filteredBooks.length,
      itemBuilder: (context, index) {
        return ListTile(
          title: Text(filteredBooks[index]['title']),
          subtitle: Text(filteredBooks[index]['author']),
          trailing: Text(filteredBooks[index]['isbn']),
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final filteredBooks = _filterBooks(query);
    return ListView.builder(
      itemCount: filteredBooks.length,
      itemBuilder: (context, index) {
        return ListTile(
          title: Text(filteredBooks[index]['title']),
          subtitle: Text(filteredBooks[index]['author']),
          trailing: Text(filteredBooks[index]['isbn']),
        );
      },
    );
  }
}

class BookDetailsPage extends StatefulWidget {
  final dynamic book;

  const BookDetailsPage({Key? key, required this.book}) : super(key: key);

  @override
  _BookDetailsPageState createState() => _BookDetailsPageState();
}

class _BookDetailsPageState extends State<BookDetailsPage> {
  late int availability;

  @override
  void initState() {
    super.initState();
    availability = widget.book['availability'] ?? 0;
  }

  Future<void> _updateAvailability(int newAvailability) async {
    final url = Uri.parse(ipurl + '/update_availability');
    final response = await http.post(url,
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          'id': widget.book['id'],
          'availability': newAvailability,
        }));

    if (response.statusCode == 200) {
      setState(() {
        availability = newAvailability;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Beschikbaarheid bijgewerkt')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fout bij het bijwerken van de beschikbaarheid')));
    }
  }

  Future<void> _deleteBook() async {
    final confirmation = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Boek verwijderen'),
          content: const Text('Weet je zeker dat je dit boek wilt verwijderen?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Annuleren'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text('Verwijderen'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmation == true) {
      final url = Uri.parse(ipurl + '/delete_book/${widget.book['id']}');
      final response = await http.delete(url);

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Boek succesvol verwijderd')));
        Navigator.of(context).pop(); // Ga terug naar de vorige pagina
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fout bij het verwijderen van het boek')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String imageUrl = ipurl + '/uploads/' + (widget.book['image_path'] ?? '');

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.book['title'] ?? 'Boek Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _deleteBook,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              imageUrl.isNotEmpty
                  ? Image.network(imageUrl, fit: BoxFit.cover)
                  : Placeholder(fallbackHeight: 200.0),
              SizedBox(height: 20),
              Text('ISBN: ${widget.book['isbn'] ?? 'N/A'}', style: TextStyle(fontSize: 16)),
              SizedBox(height: 10),
              Text('Titel: ${widget.book['title'] ?? 'N/A'}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              SizedBox(height: 10),
              Text('Auteur: ${widget.book['author'] ?? 'N/A'}', style: TextStyle(fontSize: 16)),
              SizedBox(height: 10),
              Text('Beschrijving: ${widget.book['description'] ?? 'N/A'}', style: TextStyle(fontSize: 16)),
              SizedBox(height: 10),
              Text('Pagina\'s: ${widget.book['pages']?.toString() ?? 'N/A'}', style: TextStyle(fontSize: 16)),
              SizedBox(height: 10),
              Text('Hoeveelheid: ${widget.book['quantity']?.toString() ?? 'N/A'}', style: TextStyle(fontSize: 16)),
              SizedBox(height: 10),
              Text('Beschikbaarheid: $availability', style: TextStyle(fontSize: 16)),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  IconButton(
                    icon: const Icon(Icons.remove),
                    onPressed: () => _updateAvailability(availability > 0 ? availability - 1 : 0),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () => _updateAvailability(availability < (widget.book['quantity'] ?? 0) ? availability + 1 : availability),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}