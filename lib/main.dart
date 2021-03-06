import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:math';
import 'dart:io';
import 'dart:core';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_database/ui/firebase_animated_list.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

// const String _name = "Vu Dinh";
final googleSignIn = new GoogleSignIn();
final analytics = new FirebaseAnalytics();
final auth = FirebaseAuth.instance;

final ThemeData kIOSTheme = new ThemeData(
  primarySwatch: Colors.orange,
  primaryColor: Colors.grey[100],
  primaryColorBrightness: Brightness.light,
);

final ThemeData kDefaultTheme = new ThemeData(
  primarySwatch: Colors.red,
  accentColor: Colors.orangeAccent[400],
);

void main() => runApp(
  new MaterialApp(
    title: "Firechat",
    home: new FireChatApp(),
  )
);

class FireChatApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return new MaterialApp (
      title: "Firechat",
      theme: defaultTargetPlatform == TargetPlatform.iOS
        ? kIOSTheme
        : kDefaultTheme,
      home: new ChatScreen(),
    );
  }

}

class ChatScreen extends StatefulWidget {

  @override
  State<StatefulWidget> createState() {
    return new ChatScreenState();
  }
    
}
    
class ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = new TextEditingController();
  bool _isComposing = false;
  final reference = FirebaseDatabase.instance.reference().child('messages');

  // ---- input field
  Widget _buildTextComposer() {
    return new IconTheme(
      data: new IconThemeData(color: Theme.of(context).accentColor),
      child: new Container(
        margin: const EdgeInsets.symmetric(horizontal: 8.0),
        child: new Row(
          children: <Widget>[
            new Container(
              margin: const EdgeInsets.symmetric(horizontal: 4.0),
              child: new IconButton(
                icon: new Icon(Icons.photo_camera),
                onPressed: () async {
                  await _ensureLoggedIn();
                  File imageFile = await ImagePicker.pickImage();
                  int rand = new Random().nextInt(100000);
                  StorageReference ref = 
                    FirebaseStorage.instance.ref().child("image_$rand.jpg");
                    StorageUploadTask uploadTask = ref.put(imageFile);
                    Uri downloadUrl = (await uploadTask.future).downloadUrl;
                    _sendMessage(imageUrl: downloadUrl.toString());
                },
              ),
            ),
            new Flexible(
              child: new TextField(
                controller: _textController,
                onChanged: (String text) {
                  setState(() {
                    _isComposing = text.length > 0;
                  });
                },
                onSubmitted: _handleSubmitted,
                decoration: new InputDecoration.collapsed(
                  hintText: "Send a message"
                ),
              ),
            ),
            new Container(
              margin: new EdgeInsets.symmetric(horizontal: 4.0),
              child: Theme.of(context).platform == TargetPlatform.iOS
                ? new CupertinoButton(
                child: new Text("Send"),
                onPressed: _isComposing 
                    ? () => _handleSubmitted(_textController.text)
                    : null,
                )

                : new IconButton(
                icon: new Icon(Icons.send),
                onPressed: _isComposing 
                    ? () => _handleSubmitted(_textController.text)
                    : null,
                )
            )
          ],
        ),
      ),
    );
  }

  // ---- chat screen state
  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      appBar: new AppBar(
        title: new Text("Firechat"),
        elevation:
          Theme.of(context).platform == TargetPlatform.iOS ? 0.0 : 4.0,
      ),
      body: new Container(
        child: new Column(
          children: <Widget>[
            // chat history
            new Flexible(
              child: new FirebaseAnimatedList(
                query: reference,
                sort: (a, b) => b.key.compareTo(a.key),
                padding: new EdgeInsets.all(8.0),
                reverse: true,
                itemBuilder: (_, DataSnapshot snapshot, Animation<double> animation) {
                  return new ChatMessage(
                    snapshot: snapshot,
                    animation: animation
                  );
                },
              )
            ),
            // divider
            new Divider(height: 10.0),
            new Container(
              decoration: new BoxDecoration(
                color: Theme.of(context).cardColor,
              ),
              child: _buildTextComposer()
            ),
          ],
        ),
        decoration: Theme.of(context).platform == TargetPlatform.iOS
          ? new BoxDecoration(
            border: new Border(
              top: new BorderSide(color: Colors.grey[200]),
            )
          ) : null,
      ),
    );
  }

  Future<Null> _ensureLoggedIn() async {
    GoogleSignInAccount user = googleSignIn.currentUser;
    if (user == null)
      user = await googleSignIn.signInSilently();
    if (user == null) {
      await googleSignIn.signIn();
      analytics.logLogin();
    }
    // firebase auth
    if (await auth.currentUser() == null) {
      GoogleSignInAuthentication credentials = await googleSignIn.currentUser.authentication;
      await auth.signInWithGoogle(
        idToken: credentials.idToken,
        accessToken: credentials.accessToken,
      );
    }
  }

  Future<Null> _handleSubmitted(String inputText) async {
    _textController.clear();
    setState(() {
      _isComposing = false;
    });
    // check log-in
    await _ensureLoggedIn();
    _sendMessage(text: inputText);
  }

  void _sendMessage({ String text, String imageUrl }) {
    DateTime timestamp = new DateTime.now();
    reference.push().set({
      'text': text,
      'imageUrl': imageUrl,
      'senderName': googleSignIn.currentUser.displayName,
      'senderPhotoUrl': googleSignIn.currentUser.photoUrl,
      'time': timestamp.millisecondsSinceEpoch,
    });
    analytics.logEvent(name: 'send_message');
  }

}

class ChatMessage extends StatelessWidget {

  ChatMessage({this.snapshot, this.animation});
  final DataSnapshot snapshot;
  final Animation animation;

  @override
  Widget build(BuildContext context) {
    return new SizeTransition(
      sizeFactor: new CurvedAnimation(
        parent: animation, curve: Curves.easeOut,
      ),
      axisAlignment: 0.0,
      child: new Container(
        margin: const EdgeInsets.symmetric(vertical: 10.0),
        child: new Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            new Container(
              margin: const EdgeInsets.only(right: 16.0),
              child: new CircleAvatar(backgroundImage: new NetworkImage(snapshot.value['senderPhotoUrl']), backgroundColor: Colors.transparent,)
            ),
            new Expanded(
              child: new Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  new Row(
                    children: <Widget>[
                      new Text( snapshot.value['senderName'],
                                style: Theme.of(context).textTheme.subhead),
                      new Container(
                        child:  new Text( _getTimeDifference(),
                                          style: Theme.of(context).textTheme.caption),
                        margin: const EdgeInsets.symmetric(horizontal: 8.0),
                      )
                    ],
                  ),
                  new Container(
                    margin: const EdgeInsets.only(top: 5.0),
                    child: snapshot.value['imageUrl'] != null ? 
                      new Image.network(
                        snapshot.value['imageUrl'],
                        width: 250.0,
                      ) :
                      new Text(snapshot.value['text']),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  // don't ask questions
  String _getTimeDifference() {
    var snaptime = new DateTime.fromMillisecondsSinceEpoch(snapshot.value['time']);
    var ima = new DateTime.now();
    Duration dur = ima.difference(snaptime);
    int seconds = dur.inSeconds; 
    int minutes = dur.inMinutes;
    int hours   = dur.inHours;
    var retval = "";
    
    if (seconds <= 15)
      retval = "just now";
    else if (minutes < 2)
      retval = "a minute ago";
    else if (minutes < 60)
      retval = "$minutes minutes ago";
    else if (hours < 2)
      retval = "an hour ago";
    else if (hours < 24)
      retval = "$hours hours ago";
    else switch(snaptime.weekday) {   // why, dart, why...
      case 1:
        retval = "Monday ${snaptime.month}, ${snaptime.day} - ${snaptime.hour}:${snaptime.minute}";
        break;
      case 2:
        retval = "Tuesday ${snaptime.month}, ${snaptime.day} - ${snaptime.hour}:${snaptime.minute}";
        break;
      case 3:
        retval = "Wednesday ${snaptime.month}, ${snaptime.day} - ${snaptime.hour}:${snaptime.minute}";
        break;
      case 4:
        retval = "Thursday ${snaptime.month}, ${snaptime.day} - ${snaptime.hour}:${snaptime.minute}";
        break;
      case 5:
        retval = "Friday ${snaptime.month}, ${snaptime.day} - ${snaptime.hour}:${snaptime.minute}";
        break;
      case 6:
        retval = "Saturday ${snaptime.month}, ${snaptime.day} - ${snaptime.hour}:${snaptime.minute}";
        break;
      case 7:
        retval = "Sunday ${snaptime.month}, ${snaptime.day} - ${snaptime.hour}:${snaptime.minute}";
        break;
      default:
        retval = "invalid time, you dun goofed bruh";
    }
    return retval;
  }

}