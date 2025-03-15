import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';

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
  final double progressDecimal = progressPercentage / 100;
  final double fundsLeft = targetAmount - funding;
  
  final String fundraiserTitle = fundraiser['title'] ?? 'Fundraiser';

  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (BuildContext context) {
      return Dialog(
        insetPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24.0),
        ),
        elevation: 8,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.95,
          constraints: BoxConstraints(maxWidth: 500),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24.0),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, Color(0xFFF5F9F5)],
            ),
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with more space
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          fundraiserTitle,
                          style: TextStyle(
                            fontSize: 24, 
                            fontWeight: FontWeight.bold,
                            color: Colors.green[800],
                            height: 1.3,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: Colors.grey[600], size: 28),
                        padding: EdgeInsets.all(8),
                        onPressed: () => Navigator.of(context).pop(),
                      )
                    ],
                  ),
                  SizedBox(height: 32),
                  
                  // Progress indicator with more breathing room
                  Align(
                    alignment: Alignment.center,
                    child: CircularPercentIndicator(
                      radius: 80,
                      lineWidth: 15,
                      percent: progressDecimal,
                      center: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "${progressPercentage.toStringAsFixed(1)}%",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 22,
                              color: Colors.green[800],
                            ),
                          ),
                          Text(
                            "Complete",
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      progressColor: Colors.green,
                      backgroundColor: Colors.green.withOpacity(0.2),
                      animation: true,
                      animationDuration: 1000,
                    ),
                  ),
                  SizedBox(height: 32),
                  
                  // Main stats with better spacing
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildMainStat(
                          context,
                          "\$${NumberFormat('#,##0.00').format(funding)}",
                          "raised of \$${NumberFormat('#,##0.00').format(targetAmount)} goal",
                          Icons.attach_money,
                        ),
                        SizedBox(height: 18),
                        _buildMainStat(
                          context,
                          NumberFormat('#,##0').format(donators),
                          "supporters",
                          Icons.people,
                        ),
                        SizedBox(height: 18),
                        _buildMainStat(
                          context,
                          "$daysLeft",
                          "days remaining",
                          Icons.calendar_today,
                        ),
                      ],
                    ),
                  ),
                  
                  SizedBox(height: 32),
                  Divider(thickness: 1.5),
                  SizedBox(height: 28),
                  
                  // Additional stats section with more space
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

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Detailed Statistics",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.green[800],
                              height: 1.3,
                            ),
                          ),
                          SizedBox(height: 24),
                          // Stack the cards vertically for more space
                          _buildStatCard(
                            "\$${NumberFormat('#,##0.00').format(fundsLeft)}",
                            "Funds needed",
                            Icons.account_balance_wallet,
                            Colors.orange[700]!,
                          ),
                          SizedBox(height: 18),
                          _buildStatCard(
                            NumberFormat('#,##0').format(prayersCount),
                            "Prayers",
                            Icons.favorite,
                            Colors.red[400]!,
                          ),
                          SizedBox(height: 24),
                        ],
                      );
                    }
                  ),
                  
                  SizedBox(height: 16),
                  if (funding > 0)
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[600],
                        foregroundColor: Colors.white,
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                        minimumSize: Size(double.infinity, 60),
                      ),
                      onPressed: () {
                        // TODO: Implement withdrawal functionality
                        Navigator.of(context).pop();
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.account_balance, size: 24,color: Colors.white,),
                          SizedBox(width: 12),
                          Text(
                            'Withdraw Funds',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  SizedBox(height: 8),
                  if (funding > 0)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          '(\$${NumberFormat('#,##0.00').format(funding)})',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

Widget _buildMainStat(BuildContext context, String value, String label, IconData icon) {
  return Row(
    children: [
      Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: Colors.green[700], size: 22),
      ),
      SizedBox(width: 16),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                height: 1.3,
              ),
            ),
            SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

Widget _buildStatCard(String value, String label, IconData icon, Color color) {
  return Container(
    width: double.infinity,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 10,
          offset: Offset(0, 4),
        ),
      ],
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Colors.white, color.withOpacity(0.1)],
      ),
    ),
    padding: EdgeInsets.all(20),
    child: Row(
      children: [
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        SizedBox(width: 20),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                height: 1.3,
              ),
            ),
            SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[700],
                height: 1.3,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}