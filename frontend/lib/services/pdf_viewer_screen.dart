import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';

class PdfPageController extends ChangeNotifier {
  bool _isLoading = true;
  int _currentPage = 0;
  int _totalPages = 0;
  bool _pdfReady = false;
  
  bool get isLoading => _isLoading;
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  bool get pdfReady => _pdfReady;
  
  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
  
  void setPage(int page) {
    _currentPage = page;
    notifyListeners();
  }
  
  void setTotalPages(int pages) {
    _totalPages = pages;
    notifyListeners();
  }

  void setPdfReady(bool ready) {
    _pdfReady = ready;
    if (ready) {
      _isLoading = false;
    }
    notifyListeners();
  }
}

class PdfViewerScreen extends StatefulWidget {
  final String filePath;
  final String title;
  
  const PdfViewerScreen({
    Key? key, 
    required this.filePath, 
    required this.title
  }) : super(key: key);

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  late PdfPageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PdfPageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _pageController,
      child: Scaffold(
        appBar: AppBar(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              bottom: Radius.circular(15),
            ),
          ),
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.green.shade700,
                  Colors.green.shade500,
                ],
              ),
            ),
          ),
          title: Text(
            widget.title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.share, color: Colors.white),
              onPressed: () async {
                await Share.shareFiles([widget.filePath], text: 'Sharing ${widget.title} document');
              },
            ),
            IconButton(
              icon: Icon(Icons.download, color: Colors.white),
              onPressed: () async {
                try {
                  final downloadsDir = await getExternalStorageDirectory();
                  final newFile = await File(widget.filePath).copy('${downloadsDir?.path}/${widget.title}.pdf');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Document saved to Downloads')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to save document')),
                  );
                }
              },
            ),
          ],
        ),
        body: Stack(
          children: [
            PDFView(
              filePath: widget.filePath,
              enableSwipe: true,
              swipeHorizontal: false,
              autoSpacing: true,
              pageFling: true,
              onRender: (pages) {
                _pageController.setTotalPages(pages!);
                _pageController.setPdfReady(true);
              },
              onError: (error) {
                _pageController.setPdfReady(true);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $error')),
                );
              },
              onPageError: (page, error) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error on page $page: $error')),
                );
              },
              onViewCreated: (controller) {
                // Don't set loading to false here, wait for onRender
              },
              onPageChanged: (page, total) {
                _pageController.setPage(page!);
              },
            ),
            Consumer<PdfPageController>(
              builder: (context, controller, _) {
                if (!controller.pdfReady) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: Colors.green,
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
      ),
    );
  }
}
