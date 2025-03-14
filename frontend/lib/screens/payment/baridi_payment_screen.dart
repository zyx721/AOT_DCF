import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class BaridiPaymentScreen extends StatefulWidget {
  final double amount;
  final String orderNumber;

  const BaridiPaymentScreen({
    Key? key,
    required this.amount,
    required this.orderNumber,
  }) : super(key: key);

  @override
  _BaridiPaymentScreenState createState() => _BaridiPaymentScreenState();
}

class _BaridiPaymentScreenState extends State<BaridiPaymentScreen> {
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Baridi Pay', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Image.asset('assets/images/baridi.png', height: 60),
              SizedBox(height: 10),
              Text(
                'INFORMATIONS PERSONNELLES',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF336799),
                ),
              ),
              Divider(thickness: 2, color: Color(0xFFF3CB35)),
              SizedBox(height: 20),
              Card(
                elevation: 2,
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Table(
                        border: TableBorder.all(
                          color: Color(0xFF336799),
                          width: 1,
                        ),
                        children: [
                          TableRow(
                            decoration: BoxDecoration(
                              color: Color(0xFF336799),
                            ),
                            children: [
                              TableCell(
                                child: Padding(
                                  padding: EdgeInsets.all(8),
                                  child: Text(
                                    'ORDER NUMBER',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                              ),
                              TableCell(
                                child: Padding(
                                  padding: EdgeInsets.all(8),
                                  child: Text(
                                    'TOTAL',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          TableRow(
                            decoration: BoxDecoration(
                              color: Colors.white,
                            ),
                            children: [
                              TableCell(
                                child: Padding(
                                  padding: EdgeInsets.all(8),
                                  child: Text(widget.orderNumber),
                                ),
                              ),
                              TableCell(
                                child: Padding(
                                  padding: EdgeInsets.all(8),
                                  child: Text(
                                      '${widget.amount.toStringAsFixed(2)} DZD'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      SizedBox(height: 20),
                      _buildTextField('Credit card number'),
                      SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: _buildTextField('Month')),
                          SizedBox(width: 10),
                          Expanded(child: _buildTextField('Year')),
                        ],
                      ),
                      SizedBox(height: 10),
                      _buildTextField('Card holder name'),
                      SizedBox(height: 10),
                      _buildTextField('CVV'),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    Navigator.of(context).pop(true);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF336799),
                  minimumSize: Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: Text(
                  'Submit',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label) {
    return TextFormField(
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'This field is required';
        }
        return null;
      },
    );
  }
}
