import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../../services/drive.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CreateFundraisingScreen extends StatefulWidget {
  @override
  _CreateFundraisingScreenState createState() => _CreateFundraisingScreenState();
}

class _CreateFundraisingScreenState extends State<CreateFundraisingScreen> {
  final _formKey = GlobalKey<FormState>();
  TextEditingController _titleController = TextEditingController();
  TextEditingController _donationAmountController = TextEditingController();
  TextEditingController _fundUsageController = TextEditingController();
  TextEditingController _recipientNameController = TextEditingController();
  TextEditingController _storyController = TextEditingController();
  String? _selectedCategory;
  DateTime? _selectedDate;
  bool _agreedToTerms = false;

  final GoogleDriveService _driveService = GoogleDriveService();
  final ImagePicker _picker = ImagePicker();
  File? _mainImage;
  File? _proposalDoc;
  File? _additionalDoc;
  String? _mainImageUrl;
  String? _proposalDocUrl;
  String? _additionalDocUrl;
  bool _isUploading = false;

  List<File?> _secondaryImages = List.filled(4, null);
  List<String?> _secondaryImageUrls = List.filled(4, null);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Create New Fundraising'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildImageUploader(),
                _buildTextField(_titleController, 'Title', 'Enter title', true),
                _buildDropdownField(),
                _buildTextField(_donationAmountController, 'Total Donation Required', 'Enter amount', true, isNumber: true),
                _buildDatePicker(),
                _buildTextField(_fundUsageController, 'Fund Usage Plan', 'Describe usage plan', true, maxLines: 3),
                _buildTextField(_recipientNameController, 'Name of Recipients', 'Enter name', true),
                _buildFileUploadField('Upload Donation Proposal Documents', true),
                _buildFileUploadField('Upload Aditional Documents (Optional)', false),
                _buildTextField(_storyController, 'Story', 'Describe donation story', true, maxLines: 3),
                _buildTermsCheckbox(),
                _buildActionButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _mainImage = File(image.path);
      });
    }
  }

  Future<void> _pickSecondaryImage(int index) async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _secondaryImages[index] = File(image.path);
      });
    }
  }

  Future<void> _pickDocument(bool isProposal) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    if (result != null) {
      setState(() {
        if (isProposal) {
          _proposalDoc = File(result.files.single.path!);
        } else {
          _additionalDoc = File(result.files.single.path!);
        }
      });
    }
  }

  Future<void> _uploadFiles() async {
    setState(() => _isUploading = true);
    try {
      if (_mainImage != null) {
        _mainImageUrl = await _driveService.uploadFile(_mainImage!);
      }
      // Upload secondary images
      for (int i = 0; i < _secondaryImages.length; i++) {
        if (_secondaryImages[i] != null) {
          _secondaryImageUrls[i] = await _driveService.uploadFile(_secondaryImages[i]!);
        }
      }
      if (_proposalDoc != null) {
        _proposalDocUrl = await _driveService.uploadFile(_proposalDoc!);
      }
      if (_additionalDoc != null) {
        _additionalDocUrl = await _driveService.uploadFile(_additionalDoc!);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading files: $e')),
      );
    }
    setState(() => _isUploading = false);
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          child: Container(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.green,
                  child: Icon(
                    Icons.check,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  'Successfully Created!',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 20),
                TweenAnimationBuilder(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: Duration(seconds: 1),
                  builder: (context, value, child) {
                    return LinearProgressIndicator(value: value as double);
                  },
                  onEnd: () {
                    Navigator.of(context).pop(); // Close dialog
                    Navigator.of(context).pop(); // Return to previous screen
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _submitFundraiser() async {
    if (_formKey.currentState!.validate() && _agreedToTerms) {
      await _uploadFiles();
      
      try {
        final User? currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Please login first')),
          );
          return;
        }

        // Create fundraiser document
        DocumentReference fundraiserRef = await FirebaseFirestore.instance.collection('fundraisers').add({
          'title': _titleController.text,
          'category': _selectedCategory,
          'donationAmount': double.parse(_donationAmountController.text),
          'expirationDate': _selectedDate,
          'fundUsage': _fundUsageController.text,
          'recipientName': _recipientNameController.text,
          'story': _storyController.text,
          'mainImageUrl': _mainImageUrl,
          'proposalDocUrl': _proposalDocUrl,
          'additionalDocUrl': _additionalDocUrl,
          'secondaryImageUrls': _secondaryImageUrls,
          'createdAt': FieldValue.serverTimestamp(),
          'funding': 0,
          'status': 'pending',
          'creatorId': currentUser.uid,
          'donators': 0,  // Add this line
        });

        // Update user's fundraisers list
        await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).update({
          'fundraisers': FieldValue.arrayUnion([fundraiserRef.id])
        });
        
        _showSuccessDialog();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating fundraiser: $e')),
        );
      }
    }
  }

  Widget _buildImageUploader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: _pickImage,
          child: Container(
            height: 300, // Increased from 200
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.green, width: 2),
              borderRadius: BorderRadius.circular(20),
              image: _mainImage != null
                  ? DecorationImage(
                      image: FileImage(_mainImage!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: _mainImage == null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_a_photo, size: 80, color: Colors.green), // Increased from 50
                      const SizedBox(height: 16),
                      Text(
                        'Add Cover Image',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 20,
                          fontWeight: FontWeight.bold
                        ),
                      ),
                    ],
                  )
                : null,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(4, (index) => _buildSecondaryImageSelector(index)),
        ),
      ],
    );
  }

  Widget _buildSecondaryImageSelector(int index) {
    return GestureDetector(
      onTap: () => _pickSecondaryImage(index),
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.green, width: 2),
          borderRadius: BorderRadius.circular(20),
          image: _secondaryImages[index] != null
              ? DecorationImage(
                  image: FileImage(_secondaryImages[index]!),
                  fit: BoxFit.cover,
                )
              : null,
        ),
        child: _secondaryImages[index] == null
            ? Icon(Icons.add_photo_alternate, color: Colors.green, size: 30)
            : null,
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, String hint, bool required, {bool isNumber = false, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(color: Colors.green, width: 2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(color: Colors.green, width: 2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(color: Colors.green, width: 2),
          ),
        ),
        validator: required ? (value) => value!.isEmpty ? 'This field is required' : null : null,
      ),
    );
  }

  Widget _buildDropdownField() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: DropdownButtonFormField<String>(
        value: _selectedCategory,
        decoration: InputDecoration(
          labelText: 'Category',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(color: Colors.green, width: 2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(color: Colors.green, width: 2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(color: Colors.green, width: 2),
          ),
        ),
        items: ['Medical', 'Education', 'Disaster','Poverty'].map((category) {
          return DropdownMenuItem(
            value: category,
            child: Text(category),
          );
        }).toList(),
        onChanged: (value) {
          setState(() {
            _selectedCategory = value;
          });
        },
        validator: (value) => value == null ? 'Please select a category' : null,
      ),
    );
  }

  Widget _buildDatePicker() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        readOnly: true,
        decoration: InputDecoration(
          labelText: 'Choose Donation Expiration Date',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(color: Colors.green, width: 2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(color: Colors.green, width: 2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(color: Colors.green, width: 2),
          ),
          suffixIcon: Icon(Icons.calendar_today, color: Colors.green),
        ),
        onTap: () async {
          DateTime? pickedDate = await showDatePicker(
            context: context,
            initialDate: DateTime.now(),
            firstDate: DateTime.now(),
            lastDate: DateTime(2100),
          );
          if (pickedDate != null) {
            setState(() {
              _selectedDate = pickedDate;
            });
          }
        },
        controller: TextEditingController(text: _selectedDate != null ? DateFormat.yMMMd().format(_selectedDate!) : ''),
        validator: (value) => value!.isEmpty ? 'Please select a date' : null,
      ),
    );
  }

  Widget _buildFileUploadField(String label, bool isProposal) {
    File? selectedFile = isProposal ? _proposalDoc : _additionalDoc;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        readOnly: true,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(color: Colors.green, width: 2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(color: Colors.green, width: 2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(color: Colors.green, width: 2),
          ),
          suffixIcon: Icon(Icons.upload_file, color: Colors.green),
          hintText: selectedFile != null ? selectedFile.path.split('/').last : 'No file selected',
        ),
        onTap: () => _pickDocument(isProposal),
      ),
    );
  }

  Widget _buildTermsCheckbox() {
    return Row(
      children: [
        Checkbox(
          fillColor: MaterialStateProperty.all(Colors.green),
          value: _agreedToTerms,
          onChanged: (value) {
            setState(() {
              _agreedToTerms = value!;
            });
          },
        ),
        Expanded(
          child: Text('By checking this, you agree to the terms & conditions that apply to us.'),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,  // Changed from spaceBetween to center
      children: [
        ElevatedButton(
          onPressed: _isUploading ? null : _submitFundraiser,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            padding: EdgeInsets.symmetric(horizontal: 50, vertical: 15),  // Increased horizontal padding
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          child: _isUploading
              ? CircularProgressIndicator(color: Colors.white)
              : Text(
                  'Create & Submit',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
        ),
      ],
    );
  }
}