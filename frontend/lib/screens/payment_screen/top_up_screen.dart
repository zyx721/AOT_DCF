import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:pay/pay.dart'; // Add this import
import 'package:webview_flutter/webview_flutter.dart';
import '../payment/paypal_webview_screen.dart';

class TopUpScreen extends StatefulWidget {
  @override
  _TopUpScreenState createState() => _TopUpScreenState();
}

class _TopUpScreenState extends State<TopUpScreen> {
  final _formKey = GlobalKey<FormState>();
  String selectedAmount = '10';
  final List<String> amounts = ['10', '20', '50', '100', '200', '500'];
  String selectedPaymentMethod = ''; // Changed to empty string initially

  // Card form controllers
  final cardNumberController = TextEditingController();
  final expiryController = TextEditingController();
  final cvvController = TextEditingController();
  final nameController = TextEditingController();

  final _paymentItems = <PaymentItem>[]; // Add this field

  @override
  void initState() {
    super.initState();
    _paymentItems.add(
      PaymentItem(
        amount: '0',
        label: 'Top Up',
        status: PaymentItemStatus.final_price,
      ),
    );
  }

  void _updatePaymentItems() {
    setState(() {
      _paymentItems[0] = PaymentItem(
        amount: selectedAmount,
        label: 'Top Up Amount',
        status: PaymentItemStatus.final_price,
      );
    });
  }

  void _onGooglePayResult(paymentResult) {
    debugPrint('Payment Result: $paymentResult');
    if (mounted) {
      if (paymentResult != null) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Payment Success'),
            content: Text('Your top up of \$$selectedAmount was successful'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();
                },
                child: Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _handleGooglePay() async {
    try {
      _updatePaymentItems();
      final googlePayButton = GooglePayButton(
        paymentConfiguration: PaymentConfiguration.fromJsonString(
          await DefaultAssetBundle.of(context)
              .loadString('assets/google_pay_config.json'),
        ),
        paymentItems: _paymentItems,
        type: GooglePayButtonType.pay,
        margin: const EdgeInsets.only(top: 15.0),
        onPaymentResult: _onGooglePayResult,
        loadingIndicator: const Center(
          child: CircularProgressIndicator(),
        ),
        onError: (error) {
          if (mounted) {
            debugPrint('Google Pay Error: $error');
            if (!error.toString().toLowerCase().contains('canceled')) {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('Payment Error'),
                  content: Text('Error processing payment. Please try again.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text('OK'),
                    ),
                  ],
                ),
              );
            }
          }
        },
      );

      await showModalBottomSheet(
        context: context,
        isDismissible: true,
        builder: (context) => Container(
          padding: EdgeInsets.all(20),
          child: googlePayButton,
        ),
      );
    } catch (e) {
      if (mounted) {
        debugPrint('Error setting up Google Pay: $e');
        if (!e.toString().toLowerCase().contains('canceled')) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('Setup Error'),
              content: Text('Failed to initialize payment. Please try again.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('OK'),
                ),
              ],
            ),
          );
        }
      }
    }
  }

  Future<void> _handlePayPalPayment() async {
    try {
      // PayPal Sandbox URL
      final baseUrl = 'https://www.sandbox.paypal.com/cgi-bin/webscr';
      final params = {
        'cmd': '_donations',
        'business':
            'aotdevimpact@gmail.com', // Your PayPal sandbox business account
        'item_name': 'Top Up',
        'amount': selectedAmount,
        'currency_code': 'USD',
        'return': 'https://success.example.com', // Your success URL
        'cancel_return': 'https://cancel.example.com', // Your cancel URL
      };

      final uri = Uri.parse(baseUrl).replace(queryParameters: params);

      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PayPalWebViewScreen(
            initialUrl: uri.toString(),
            onPaymentComplete: (success) {
              if (success && mounted) {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text('Payment Success'),
                    content:
                        Text('Your top up of \$$selectedAmount was successful'),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).pop();
                        },
                        child: Text('OK'),
                      ),
                    ],
                  ),
                );
              }
            },
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        debugPrint('PayPal Error: $e');
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Setup Error'),
            content: Text('Failed to initialize PayPal. Please try again.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Add Payment Method",
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Select Payment Method",
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 16),

                // Payment Methods Row - Changed from Grid to Row for 3 options
                Row(
                  children: [
                    Expanded(
                      child: _buildPaymentOption(
                        imageAsset: 'assets/images/baridi.png',
                        title: "Baridi Pay",
                        method: 'baridi',
                        selected: selectedPaymentMethod == 'baridi',
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _buildPaymentOption(
                        icon: FontAwesomeIcons.googlePay,
                        title: "Google Pay",
                        method: 'google_pay',
                        selected: selectedPaymentMethod == 'google_pay',
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _buildPaymentOption(
                        icon: FontAwesomeIcons.paypal,
                        title: "PayPal",
                        method: 'paypal',
                        selected: selectedPaymentMethod == 'paypal',
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 24),

                // Show Baridi card preview and form when Baridi Pay is selected
                if (selectedPaymentMethod == 'baridi') ...[
                  Container(
                    height: 280, // Increased height
                    width: double.infinity,
                    margin: EdgeInsets.only(bottom: 24),
                    child: Image.asset(
                      'assets/images/baridi_card.png',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.credit_card,
                                  size: 48,
                                  color: Colors.grey[400],
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Card Preview',
                                  style: GoogleFonts.poppins(
                                    color: Colors.grey[600],
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Card Information",
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 16),

                        // Card Number
                        TextFormField(
                          controller: cardNumberController,
                          decoration: InputDecoration(
                            labelText: 'Card Number',
                            prefixIcon: Icon(Icons.credit_card),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(16),
                          ],
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter card number';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 16),

                        // Card Holder Name
                        TextFormField(
                          controller: nameController,
                          decoration: InputDecoration(
                            labelText: 'Card Holder Name',
                            prefixIcon: Icon(Icons.person),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter card holder name';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 16),

                        // Expiry Date and CVV
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: expiryController,
                                decoration: InputDecoration(
                                  labelText: 'MM/YY',
                                  prefixIcon: Icon(Icons.calendar_today),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(4),
                                  _CardExpiryFormatter(),
                                ],
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Required';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: cvvController,
                                decoration: InputDecoration(
                                  labelText: 'CVV',
                                  prefixIcon: Icon(Icons.security),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                obscureText: true,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(3),
                                ],
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Required';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: selectedPaymentMethod.isNotEmpty
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      if (selectedPaymentMethod == 'google_pay') {
                        _handleGooglePay();
                      } else if (selectedPaymentMethod == 'paypal') {
                        _handlePayPalPayment();
                      }
                      // Handle other payment methods...
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0, // Remove default elevation
                    shadowColor: Colors.transparent,
                  ).copyWith(
                    elevation:
                        MaterialStateProperty.resolveWith<double>((states) {
                      if (states.contains(MaterialState.pressed)) return 0;
                      return 4;
                    }),
                    backgroundColor:
                        MaterialStateProperty.resolveWith<Color>((states) {
                      if (states.contains(MaterialState.pressed)) {
                        return Colors.green.shade600;
                      }
                      return Colors.green;
                    }),
                  ),
                  child: Text(
                    "Continue",
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildPaymentOption({
    IconData? icon,
    String? imageAsset,
    required String title,
    required String method,
    required bool selected,
  }) {
    return InkWell(
      onTap: () => setState(() => selectedPaymentMethod = method),
      child: Container(
        padding:
            EdgeInsets.symmetric(vertical: 16, horizontal: 12), // Added padding
        decoration: BoxDecoration(
          color: selected ? Colors.green.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? Colors.green : Colors.grey[300]!,
            width: selected ? 2 : 1,
          ),
          // Added shadow for better depth
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null)
              Icon(
                icon,
                size: 32,
                color: selected ? Colors.green : Colors.grey[700],
              )
            else if (imageAsset != null)
              Image.asset(
                imageAsset,
                height: 32,
                width: 32,
                fit: BoxFit.contain,
              ),
            SizedBox(height: 8),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected ? Colors.green : Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _CardExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final newText = newValue.text;
    if (newText.length == 2 && oldValue.text.length == 1) {
      return TextEditingValue(
        text: '$newText/',
        selection: TextSelection.collapsed(offset: 3),
      );
    }
    return newValue;
  }
}
