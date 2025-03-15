import 'package:frontend/services/vector_store.dart';

class RoleMatcher {
  static final RoleMatcher _instance = RoleMatcher._internal();
  factory RoleMatcher() => _instance;
  RoleMatcher._internal();

  final VectorStore _documentStore = VectorStore();
  final VectorStore _userStore =
      VectorStore(); // Add separate store for user profile
  Map<String, dynamic>? _userProfile;
  String? _rawUserProfile;

  void initializeWithDocuments({
    required String documentContent,
    required Map<String, dynamic> userProfile,
    required String rawUserProfile,
  }) {
    _userProfile = userProfile;
    _rawUserProfile = rawUserProfile;

    // Create a formatted profile with null checks
    final formattedProfile = '''
Name: ${userProfile['name'] ?? 'Unknown'}
Occupation: ${userProfile['occupation'] ?? 'Not specified'}
Availability: ${userProfile['capacity'] ?? 'Not specified'}
Skills: ${userProfile['skills'] ?? 'Not specified'}
Experience: ${userProfile['experience'] ?? 'Not specified'}
Motivations: ${userProfile['motivations'] ?? 'Not specified'}
Interests: ${userProfile['interests'] ?? 'Not specified'}''';

    print('\n📋 PROCESSED USER PROFILE:');
    print(formattedProfile);

    // Store the formatted profile
    _userStore.addDocument(formattedProfile, 'user_profile:full');

    // Store individual sections with null checks
    _userStore.addDocument(
        userProfile['skills'] ?? 'Not specified', 'user_profile:skills');
    _userStore.addDocument(userProfile['experience'] ?? 'Not specified',
        'user_profile:experience');
    _userStore.addDocument(userProfile['motivations'] ?? 'Not specified',
        'user_profile:motivations');

    // Process campaign document - focus on role-specific sections
    final sections = documentContent.split(RegExp(r'\n#{2,3}\s+'));
    for (var section in sections) {
      if (section.trim().isEmpty) continue;

      // Only store sections that contain role information
      if (section.contains('Role') ||
          section.contains('Volunteer') ||
          section.contains('Position') ||
          section.contains('Requirements')) {
        _documentStore.addDocument(section.trim(), 'campaign:roles');
      }
    }
  }

  String _buildContextHeader() {
    if (_userProfile == null || _rawUserProfile == null) return '';

    final userProfileText =
        _userStore.search('user_profile:full', topK: 1).first;

    // Build search query using multiple aspects of the profile
    final searchQuery = '''
      ${_userProfile!['background'] ?? ''} 
      ${_userProfile!['skills'] ?? ''} 
      ${_userProfile!['experience'] ?? ''} 
      ${_userProfile!['motivations'] ?? ''}
    '''
        .trim();

    final relevantRoles = _documentStore.search(searchQuery, topK: 2);

    print('\n=== 🤖 CHATBOT CONTEXT ===');
    print('👤 USER PROFILE:');
    print(userProfileText.content);
    print('\n🎯 MATCHING ROLES:');
    print(relevantRoles.map((r) => r.content).join('\n---\n'));

    return '''System: You are an AI assistant helping with the Ramadan charity campaign. Keep responses focused and concise. Context:

USER PROFILE:
${userProfileText.content}

RELEVANT ROLES:
${relevantRoles.map((doc) => doc.content).join('\n\n')}''';
  }

  String generateRoleMatchPrompt([String? userQuery]) {
    final contextHeader = _buildContextHeader();

    if (userQuery != null) {
      // Format for better readability in logs
      final formattedProfile = '''
📋 Name: ${_userProfile!['name'] ?? 'Unknown'}
👨‍🏫 Occupation: ${_userProfile!['occupation'] ?? 'Not specified'}
💰 Donation Capacity: ${_userProfile!['donation_capacity'] ?? 'Not specified'}
🎯 Motivations: ${_userProfile!['motivations'].toString().replaceAll(RegExp(r'^Motivations:\s*'), '')}''';

      final relevantRoles = _documentStore.search(
        '${_userProfile!['occupation']} ${_userProfile!['motivations']} volunteer roles requirements',
        topK: 2,
      );

      print('\n══════════ CHATBOT CONTEXT ══════════');
      print(formattedProfile);
      print('\n📑 MATCHING ROLES:');
      print(relevantRoles.map((r) => r.content.trim()).join('\n\n'));
      print('\n❓ USER QUERY: "$userQuery"');
      print('═══════════════════════════════════\n');

      return '$contextHeader\n\nUser Query: $userQuery';
    }

    return contextHeader;
  }

  String generateSystemPrompt() {
    if (_userProfile == null || _rawUserProfile == null) return '';

    // Get full user profile
    final userDocs = _userStore.search('user_profile:full', topK: 1);
    if (userDocs.isEmpty) return '';
    final userProfile = userDocs.first;

    // Get core campaign information
    final roles = _documentStore
        .search('Specialized Roles Volunteer Requirements', topK: 2);
    final overview = _documentStore.search('Campaign Overview', topK: 1);

    return '''I am an AI assistant for the Ramadan charity campaign. Let me introduce myself and explain how I can help you.

I have reviewed your profile:
${userProfile.content}

Based on the campaign requirements and your background as ${_userProfile!['name']}, a ${_userProfile!['occupation']} with a donation capacity of ${_userProfile!['donation_capacity']}, I can help match you with the most suitable volunteer roles.

Key Information About the Campaign:
${overview.map((doc) => doc.content).join('\n')}

Available Roles That Might Interest You:
${roles.map((doc) => doc.content).join('\n\n')}

I can help you:
1. Find the perfect volunteering role based on your skills and interests
2. Explain why specific roles would be a good match for you
3. Provide details about role requirements and responsibilities
4. Guide you through the role acceptance process

Would you like me to suggest some roles that would be a great fit for your profile?''';
  }

  void clear() {
    _documentStore.clear();
    _userProfile = null;
  }
}
