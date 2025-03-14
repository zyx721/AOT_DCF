import 'package:flutter/material.dart';
import 'create_fund_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditFundraisingScreen extends StatelessWidget {
  final String fundraiserId;
  final Map<String, dynamic> fundraiserData;

  EditFundraisingScreen({
    required this.fundraiserId,
    required this.fundraiserData,
  });

  @override
  Widget build(BuildContext context) {
    return CreateFundraisingScreen(
      isEditing: true,
      initialData: fundraiserData,
      fundraiserId: fundraiserId,
    );
  }
}
