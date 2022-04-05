import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:deepgram_transcribe/utils/authentication_client.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:subtitle/subtitle.dart';
import 'package:tuple/tuple.dart';

class DatabaseClient {
  final firestore = FirebaseFirestore.instance;
  final _authClient = AuthenticationClient();

  Future<void> addUser({required User user}) async {
    final userDoc = firestore.collection('users').doc(user.uid);

    final Map<String, dynamic> data = {
      'uid': user.uid,
      'name': user.displayName,
      'email': user.email,
    };

    await userDoc
        .set(data)
        .then((value) => log('User added: ${user.uid}'))
        .catchError((error) => log("Failed to add user: $error"));
  }

  Future<String> addTranscript({
    required List<Subtitle> subtitles,
    required String audioUrl,
    required String audioName,
    required List<double> confidences,
  }) async {
    final userDoc =
        firestore.collection('users').doc(_authClient.auth.currentUser!.uid);
    final dataTime = DateTime.now().millisecondsSinceEpoch;

    final transcriptDoc = userDoc.collection('transcripts').doc('$dataTime');

    List<Map<String, dynamic>> subtitleMapList = [];

    for (var subtitle in subtitles) {
      final data = {
        'index': subtitle.index,
        'data': subtitle.data,
        'start': subtitle.start.inMilliseconds,
        'end': subtitle.end.inMilliseconds,
      };
      subtitleMapList.add(data);
    }

    final Map<String, dynamic> transcriptData = {
      'id': dataTime,
      'subtitles': subtitleMapList,
      'url': audioUrl,
      'name': audioName,
      'confidences': confidences,
      'title': '',
    };

    await transcriptDoc
        .set(transcriptData)
        .then((value) => log('Transcript added!'))
        .catchError((error) => log("Failed to add transcript: $error"));

    return dataTime.toString();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> retrieveTranscripts() {
    final userDoc =
        firestore.collection('users').doc(_authClient.auth.currentUser!.uid);
    final transcriptSnapshots = userDoc.collection('transcripts').snapshots();
    return transcriptSnapshots;
  }

  Future<bool> isAlreadyPresent({required String audioName}) async {
    final userDoc =
        firestore.collection('users').doc(_authClient.auth.currentUser!.uid);
    final transcriptDocs = await userDoc.collection('transcripts').get();

    bool isPresent = false;

    for (int i = 0; i < transcriptDocs.docs.length; i++) {
      final String name = transcriptDocs.docs[i].data()['name'];

      if (name == audioName) {
        isPresent = true;
        break;
      }
    }

    log('Is ($audioName) already present: $isPresent');

    return isPresent;
  }

  Future<Tuple4<List<Subtitle>, String, String, List<double>>>
      retrieveSubtitles({required String audioName}) async {
    final userDoc =
        firestore.collection('users').doc(_authClient.auth.currentUser!.uid);
    final transcriptDoc = await userDoc
        .collection('transcripts')
        .where('name', isEqualTo: audioName)
        .get();

    final List<Map<String, dynamic>> rawSubtitles =
        List<Map<String, dynamic>>.from(transcriptDoc.docs[0].get('subtitles'));

    final downloadUrl = transcriptDoc.docs[0].get('url');
    final confidences = transcriptDoc.docs[0].get('confidences');

    List<Subtitle> subtitles = [];

    for (var rawSubtitle in rawSubtitles) {
      final subtitle = Subtitle(
        start: Duration(milliseconds: rawSubtitle['start']),
        end: Duration(milliseconds: rawSubtitle['end']),
        data: rawSubtitle['data'],
        index: rawSubtitle['index'],
      );

      subtitles.add(subtitle);
    }

    log('Subtitles retrieved successfully!');

    return Tuple4(
      subtitles,
      transcriptDoc.docs[0].id,
      downloadUrl,
      confidences,
    );
  }

  Future<void> storeTitle({
    required String docId,
    required String title,
  }) async {
    final userDoc =
        firestore.collection('users').doc(_authClient.auth.currentUser!.uid);
    final transcriptDoc = userDoc.collection('transcripts').doc(docId);

    final data = {'title': title};

    await transcriptDoc
        .update(data)
        .then((value) => log('Title added: $docId'))
        .catchError((error) => log("Failed to add title: $error"));
  }

  Future<void> deleteTranscribe({required String docId}) async {
    final userDoc =
        firestore.collection('users').doc(_authClient.auth.currentUser!.uid);
    final transcriptDoc = userDoc.collection('transcripts').doc(docId);

    await transcriptDoc.delete();

    log('Transcript deleted: $docId');
  }
}
