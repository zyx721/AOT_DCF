import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

void showFundraisingDialog(BuildContext context, Map<String, dynamic> fundraiser) {
  // Convert values to proper types and handle null values
  final double funding = (fundraiser['funding'] ?? 0).toDouble();
  final double targetAmount = (fundraiser['donationAmount'] ?? 0).toDouble();
  final int donators = (fundraiser['donators'] ?? 0);
  final Timestamp expirationDate = fundraiser['expirationDate'] ?? Timestamp.now();
  final int daysLeft = expirationDate.toDate().difference(DateTime.now()).inDays;
  final double progressPercentage = targetAmount > 0 
      ? (funding / targetAmount * 100).clamp(0.0, 100.0) 
      : 0.0;
  final double fundsLeft = targetAmount - funding;

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Fundraising Results',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 16),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('fundraisers')
                      .doc(fundraiser['id'])
                      .collection('prayers')
                      .snapshots(),
                  builder: (context, snapshot) {
                    int prayersCount = 0;
                    if (snapshot.hasData) {
                      prayersCount = snapshot.data!.docs.length;
                    }

                    return GridView.count(
                      shrinkWrap: true,
                      crossAxisCount: 2,
                      childAspectRatio: 2.5,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      children: [
                        _buildStatCard(
                          '\$${NumberFormat('#,##0.00').format(funding)}',
                          'Funds gained'
                        ),
                        _buildStatCard(
                          '\$${NumberFormat('#,##0.00').format(fundsLeft)}',
                          'Funds left'
                        ),
                        _buildStatCard(
                          NumberFormat('#,##0').format(donators),
                          'Donators'
                        ),
                        _buildStatCard(
                          daysLeft.toString(),
                          'Days left'
                        ),
                        _buildStatCard(
                          '${progressPercentage.toStringAsFixed(1)}%',
                          'Funds reached'
                        ),
                        _buildStatCard(
                          NumberFormat('#,##0').format(prayersCount),
                          'Prayers'
                        ),
                      ],
                    );
                  }
                ),
                SizedBox(height: 16),
                if (funding > 0)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                    ),
                    onPressed: () {
                      // TODO: Implement withdrawal functionality
                      Navigator.of(context).pop();
                    },
                    child: Text(
                      'Withdraw Funds (\$${NumberFormat('#,##0.00').format(funding)})',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

Widget _buildStatCard(String value, String label) {
  return Container(
    decoration: BoxDecoration(
      border: Border.all(color: Colors.green),
      borderRadius: BorderRadius.circular(12),
    ),
    padding: EdgeInsets.all(8),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[700],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}
