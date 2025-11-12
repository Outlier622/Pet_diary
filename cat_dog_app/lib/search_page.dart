import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class SearchPage extends StatefulWidget {
  @override
  _SearchPageState createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  String _searchKeyword = '';
  List<Map<String, dynamic>> _tableData = [];

  @override
  void initState() {
    super.initState();
    _fetchRecords();
  }

  Future<void> _fetchRecords() async {
    try {
      final uri = Uri.parse('http://192.168.1.240:5000/records');
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List<dynamic>;
        setState(() {
          _tableData = data.map((e) => e as Map<String, dynamic>).toList();
        });
      } else {
        _showErrorDialog('Failed to fetch records: ${response.statusCode}');
      }
    } catch (e) {
      _showErrorDialog('Error fetching records: $e');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    var filteredData = _tableData.where((row) {
      return row.values.any((val) =>
          val.toString().toLowerCase().contains(_searchKeyword.toLowerCase()));
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Search Records'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _fetchRecords,
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              decoration: InputDecoration(labelText: 'Search keyword'),
              onChanged: (value) {
                setState(() {
                  _searchKeyword = value;
                });
              },
            ),
            SizedBox(height: 20),
            Expanded(
              child: _tableData.isEmpty
                  ? Center(child: Text('No records found'))
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: [
                          DataColumn(label: Text('Animal')),
                          DataColumn(label: Text('Color')),
                          DataColumn(label: Text('Breed')),
                          DataColumn(label: Text('Confidence')),
                        ],
                        rows: filteredData.map((row) {
                          return DataRow(cells: [
                            DataCell(Text(row['animal'].toString())),
                            DataCell(Text(row['color'].toString())),
                            DataCell(Text(row['breed'].toString())),
                            DataCell(Text('${row['confidence']}%')),
                          ]);
                        }).toList(),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
