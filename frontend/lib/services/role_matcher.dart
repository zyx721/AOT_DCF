import 'package:frontend/services/vector_store.dart';

class RoleMatcher {
  static final RoleMatcher _instance = RoleMatcher._internal();
  factory RoleMatcher() => _instance;
  RoleMatcher._internal();

  final VectorStore _documentStore = VectorStore();
  Map<String, dynamic>? _userProfile;

  void initializeWithDocuments({
    required String documentContent,
    required Map<String, dynamic> userProfile,
  }) {
    _userProfile = userProfile;
    
    // Split and store document into chunks
    final chunks = documentContent.split(RegExp(r'\n#{2,3}\s+\*{0,2}[^*\n]+\*{0,2}')); // Split by markdown headers
    for (var i = 0; i < chunks.length; i++) {
      if (chunks[i].trim().isNotEmpty) {
        _documentStore.addDocument(
          chunks[i].trim(),
          'document:section_$i',
        );
      }
    }
  }

  String generateRoleMatchPrompt() {
    if (_userProfile == null) return '';
    
    final name = _userProfile!['name'] ?? '';
    final occupation = _userProfile!['occupation'] ?? '';
    final donation = _userProfile!['donation_capacity'] ?? '';
    final motivations = _userProfile!['motivations'] ?? [];
    
    return '''You are an AI assistant helping match volunteers with roles for a charity campaign. 
Your task is to analyze the volunteer's profile and match them with the most suitable roles from the campaign requirements.

Volunteer Profile:
- Name: $name
- Occupation: $occupation
- Donation Capacity: $donation
- Motivations: ${motivations.join(', ')}

Please analyze this profile against the campaign's available roles and requirements. Consider:
1. The volunteer's professional background and how it could benefit specific roles
2. Their donation capacity and what sponsorship tier they might fit
3. Their stated motivations and how they align with different roles
4. Any specific skills or experiences that match particular needs

Provide a detailed recommendation of the top 2-3 most suitable roles, explaining:
- Why each role would be a good fit
- How their skills/background would contribute
- What specific responsibilities they would have
- How it aligns with their motivations

Format your response in a clear, structured way with clear role titles and explanations.''';
  }

  void clear() {
    _documentStore.clear();
    _userProfile = null;
  }
}
