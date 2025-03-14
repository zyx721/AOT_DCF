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
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Image.asset('assets/images/baridi.png', height: 60),
              SizedBox(height: 10),
              Text(
                'INFORMATIONS PERSONNELLES',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF57AB7D),
                ),
              ),
              Divider(thickness: 2, color: Color(0xFF57AB7D)),
              SizedBox(height: 20),
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Color(0xFF57AB7D)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('ORDER NUMBER'),
                        Text('TOTAL'),
                      ],
                    ),
                    Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(widget.orderNumber),
                        Text('${widget.amount.toStringAsFixed(2)} DZD'),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),
              _buildTextField('Credit card number'),
              SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Month',
                      ),
                      value: '11',
                      items: List.generate(12, (index) {
                        final month = (index + 1).toString().padLeft(2, '0');
                        return DropdownMenuItem(value: month, child: Text(month));
                      }),
                      onChanged: (value) {},
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Year',
                      ),
                      value: '2024',
                      items: List.generate(10, (index) {
                        final year = (2024 + index).toString();
                        return DropdownMenuItem(value: year, child: Text(year));
                      }),
                      onChanged: (value) {},
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10),
              _buildTextField('Card holder name'),
              SizedBox(height: 10),
              _buildTextField('CVV'),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    // Handle payment submission
                    Navigator.of(context).pop(true);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF57AB7D),
                  minimumSize: Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: Text('Submit Payment'),
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
