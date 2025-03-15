
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  await Firebase.initializeApp();
  await uploadVideos();
}

Future<void> uploadVideos() async {
  final videosCollection = FirebaseFirestore.instance.collection('videos');
  
  final List<Map<String, dynamic>> videosData = [
    {
      'title': 'Ramadan Month',
      'videoUrl': 'https://drive.google.com/file/d/1Vdg54Nscas6XXvn7KAspRE_7S8N7iQim/view?usp=sharing',
      'createdAt': Timestamp.now(),
      'likeCount': 0,
      'prayCount': 0,
      'searchKeywords': ['ramadan', 'month', 'رمضان'],
      'creatorId': 'admin',
      'creatorName': 'Admin'
    },
    {
      'title': 'Iftar in Oman',
      'videoUrl': 'https://drive.google.com/file/d/13v0mmQq7F57cKDPP-XvpHWBiwXTvDrGS/view?usp=sharing',
      'createdAt': Timestamp.now(),
      'likeCount': 0,
      'prayCount': 0,
      'searchKeywords': ['iftar', 'oman', 'إفطار', 'عمان'],
      'creatorId': 'admin',
      'creatorName': 'Admin'
    },
    {
      'title': 'Blood Donation in Makkah',
      'videoUrl': 'https://drive.google.com/file/d/1SM080AtS077e2_jjFL6O98yls1GPfdYG/view?usp=sharing',
      'createdAt': Timestamp.now(),
      'likeCount': 0,
      'prayCount': 0,
      'searchKeywords': ['blood', 'donation', 'makkah', 'مكة', 'تبرع', 'دم'],
      'creatorId': 'admin',
      'creatorName': 'Admin'
    },
    {
      'title': 'Ramadan and Dollar',
      'videoUrl': 'https://drive.google.com/file/d/1poxg9BsDzyVXCRHl4ITN47bPmtm8Nq0i/view?usp=sharing',
      'createdAt': Timestamp.now(),
      'likeCount': 0,
      'prayCount': 0,
      'searchKeywords': ['ramadan', 'dollar', 'رمضان', 'دولار'],
      'creatorId': 'admin',
      'creatorName': 'Admin'
    },
    {
      'title': 'إفطار الصائمين في الحرم المكي ٩ رمضان ١٤٤٤ هجري',
      'videoUrl': 'https://drive.google.com/file/d/19pCv8mRrinuzx3_nASZIHRQEUqgDFNyA/view?usp=sharing',
      'createdAt': Timestamp.now(),
      'likeCount': 0,
      'prayCount': 0,
      'searchKeywords': ['iftar', 'makkah', 'haram', 'إفطار', 'مكة', 'الحرم'],
      'creatorId': 'admin',
      'creatorName': 'Admin'
    },
    {
      'title': 'هل للتبرع بالدم فوائد صحية؟',
      'videoUrl': 'https://drive.google.com/file/d/1wUPZVisMOy-gzcEnoQlhFFteMUifIQ9V/view?usp=sharing',
      'createdAt': Timestamp.now(),
      'likeCount': 0,
      'prayCount': 0,
      'searchKeywords': ['blood', 'donation', 'health', 'تبرع', 'دم', 'صحة'],
      'creatorId': 'admin',
      'creatorName': 'Admin'
    },
  ];

  for (final videoData in videosData) {
    try {
      await videosCollection.add(videoData);
      print('Successfully uploaded: ${videoData['title']}');
    } catch (e) {
      print('Error uploading ${videoData['title']}: $e');
    }
  }

  print('Video upload complete!');
}
