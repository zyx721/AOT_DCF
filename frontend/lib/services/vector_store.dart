import 'dart:math';

class Document {
  final String content;
  final List<double> embedding;
  final String source;

  Document({
    required this.content,
    required this.embedding,
    required this.source,
  });
}

class VectorStore {
  static final VectorStore _instance = VectorStore._internal();
  factory VectorStore() => _instance;
  VectorStore._internal();

  final List<Document> _documents = [];
  
  // Simple TF-IDF like embedding
  List<double> _createEmbedding(String text) {
    final words = text.toLowerCase().split(RegExp(r'\W+'));
    final Map<String, int> wordCount = {};
    
    for (final word in words) {
      wordCount[word] = (wordCount[word] ?? 0) + 1;
    }
    
    // Create a simple 100-dimensional vector
    final List<double> embedding = List.filled(100, 0.0);
    for (var i = 0; i < wordCount.length && i < 100; i++) {
      embedding[i] = wordCount.values.elementAt(i).toDouble();
    }
    
    // Normalize the vector
    final magnitude = sqrt(embedding.map((e) => e * e).reduce((a, b) => a + b));
    return embedding.map((e) => e / (magnitude == 0 ? 1 : magnitude)).toList();
  }

  double _cosineSimilarity(List<double> a, List<double> b) {
    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;
    
    for (var i = 0; i < a.length; i++) {
      dotProduct += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    
    return dotProduct / (sqrt(normA) * sqrt(normB));
  }

  void addDocument(String content, String source) {
    final embedding = _createEmbedding(content);
    _documents.add(Document(
      content: content,
      embedding: embedding,
      source: source,
    ));
  }

  List<Document> search(String query, {int topK = 3}) {
    if (_documents.isEmpty) return [];
    
    final queryEmbedding = _createEmbedding(query);
    final scores = _documents.map((doc) {
      final similarity = _cosineSimilarity(queryEmbedding, doc.embedding);
      return MapEntry(doc, similarity);
    }).toList();
    
    scores.sort((a, b) => b.value.compareTo(a.value));
    return scores.take(topK).map((e) => e.key).toList();
  }

  void clear() {
    _documents.clear();
  }
}
