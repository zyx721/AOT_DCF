import 'package:flutter/material.dart';
import 'package:frontend/screens/payment/baridi_payment_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pay/pay.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../mixins/lifecycle_mixin.dart';
import '../../widgets/modern_app_bar.dart';
import '../payment/paypal_webview_screen.dart';

class DonationScreen extends StatefulWidget {
  @override
  _DonationScreenState createState() => _DonationScreenState();
}

class _DonationScreenState extends State<DonationScreen> with LifecycleMixin {
  double _selectedAmount = 0.0;
  bool _isAnonymous = false;
  final List<double> _donationAmounts = [5, 10, 25, 50, 100, 200];
  String? _selectedPaymentMethod;
  final _paymentItems = <PaymentItem>[];

  @override
  void initState() {
    super.initState();
    _paymentItems.add(
      PaymentItem(
        amount: '0',
        label: 'Donation',
        status: PaymentItemStatus.final_price,
      ),
    );
  }

  void _selectAmount(double amount) {
    setState(() {
      _selectedAmount = amount;
    });
  }

  void _toggleAnonymous(bool? value) {
    setState(() {
      _isAnonymous = value ?? false;
    });
  }

  void _updatePaymentItems() {
    setState(() {
      _paymentItems[0] = PaymentItem(
        amount: _selectedAmount.toStringAsFixed(2),
        label: 'Donation to DCF',
        status: PaymentItemStatus.final_price,
      );
    });
  }

  void _selectPaymentMethod(String method) {
    setState(() {
      _selectedPaymentMethod = method;
    });
  }

  void _onGooglePayResult(paymentResult) {
    debugPrint('Payment Result: $paymentResult');
    if (mounted) {
      // Check if widget is still mounted
      if (paymentResult != null) {
        // Show success dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Payment Success'),
            content: Text(
                'Your donation of \$${_selectedAmount.toStringAsFixed(2)} was successful'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop(); // Go back to previous screen
                },
                child: Text('OK'),
              ),
            ],
          ),
        );
      }
      // If paymentResult is null, user likely canceled - just do nothing
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
            // Check if widget is still mounted
            debugPrint('Google Pay Error: $error');
            // Only show error dialog for non-cancellation errors
            if (error.toString().toLowerCase().contains('canceled') == false) {
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
        isDismissible: true, // Allow dismissing the bottom sheet
        builder: (context) => Container(
          padding: EdgeInsets.all(20),
          child: googlePayButton,
        ),
      );
    } catch (e) {
      if (mounted) {
        // Check if widget is still mounted
        debugPrint('Error setting up Google Pay: $e');
        // Only show error for non-cancellation errors
        if (e.toString().toLowerCase().contains('canceled') == false) {
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
        'item_name': 'Donation to DCF',
        'amount': _selectedAmount.toString(),
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
                    content: Text(
                        'Your donation of \$${_selectedAmount.toStringAsFixed(2)} was successful'),
                    actions: [
                      TextButton(
                        onPressed: () {
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

  Future<void> _handleBaridiPayment() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BaridiPaymentScreen(
          amount: _selectedAmount,
          orderNumber: 'DCF${DateTime.now().millisecondsSinceEpoch}',
        ),
      ),
    );

    if (result == true && mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Payment Success'),
          content: Text(
              'Your donation of \$${_selectedAmount.toStringAsFixed(2)} was successful'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop(); // Go back to previous screen
              },
              child: Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ModernAppBar(
        title: "Donate",
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              "Enter the Amount",
              style: GoogleFonts.poppins(
                  fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Container(
              padding: EdgeInsets.symmetric(vertical: 20),
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF57AB7D)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                "\$${_selectedAmount.toStringAsFixed(0)}",
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF57AB7D)),
              ),
            ),
            SizedBox(height: 15),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _donationAmounts.map((amount) {
                return GestureDetector(
                  onTap: () => _selectAmount(amount),
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 12, horizontal: 18),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFF57AB7D)),
                      borderRadius: BorderRadius.circular(20),
                      color: _selectedAmount == amount
                          ? const Color(0xFF57AB7D)
                          : Colors.white,
                    ),
                    child: Text(
                      "\$${amount.toStringAsFixed(0)}",
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _selectedAmount == amount
                            ? Colors.white
                            : const Color(0xFF57AB7D),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            SizedBox(height: 20),
            Row(
              children: [
                Checkbox(
                  value: _isAnonymous,
                  onChanged: _toggleAnonymous,
                  activeColor: const Color(0xFF57AB7D),
                ),
                Text("Donate as anonymous", style: GoogleFonts.poppins()),
              ],
            ),
            SizedBox(height: 20),
            Text(
              "Payment Method",
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildPaymentMethodCard('assets/images/paypal.png', 'PayPal'),
                _buildPaymentMethodCard(
                    'assets/images/google_pay.jpg', 'Google Pay'),
                _buildPaymentMethodCard(
                    'assets/images/baridi.png', 'Baridi Pay'),
              ],
            ),
            Spacer(),
            ElevatedButton(
              onPressed: (_selectedAmount > 0 && _selectedPaymentMethod != null)
                  ? () {
                      if (_selectedPaymentMethod == 'Google Pay') {
                        _handleGooglePay();
                      } else if (_selectedPaymentMethod == 'PayPal') {
                        _handlePayPalPayment();
                      } else if (_selectedPaymentMethod == 'Baridi Pay') {
                        _handleBaridiPayment();
                      }
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF57AB7D),
                minimumSize: Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25)),
              ),
              child: Text(
                "Continue",
                style: GoogleFonts.poppins(fontSize: 18, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodCard(String imagePath, String name) {
    bool isSelected = _selectedPaymentMethod == name;
    return GestureDetector(
      onTap: () => _selectPaymentMethod(name),
      child: Container(
        width: 100,
        padding: EdgeInsets.all(10),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? Colors.blue : const Color(0xFF57AB7D),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              imagePath,
              height: 40,
              width: 40,
              fit: BoxFit.contain,
            ),
            SizedBox(height: 8),
            Text(
              name,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: isSelected ? Colors.blue : const Color(0xFF57AB7D),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
