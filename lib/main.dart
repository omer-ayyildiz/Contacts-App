import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:contacts_app/constants.dart';
import 'package:csv/csv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:gsheets/gsheets.dart';
import 'package:url_launcher/url_launcher.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: MyHomePage(title: 'Demo'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final db = FirebaseFirestore.instance;
  List<String> itemList = [];
  String location = '[ALL]';
  @override
  void initState() {
    super.initState();
    fetchData();
  }

  Future<void> fetchData() async {
    final CollectionReference itemRef =
        FirebaseFirestore.instance.collection('contacts');
    QuerySnapshot querySnapshot = await itemRef.get();
    List<String> tempItemList = [];
    tempItemList.add('[ALL]');
    querySnapshot.docs.forEach((element) {
      if (!tempItemList.contains(element['location'].toString())) {
        tempItemList.add(element['location'].toString());
      }
    });
    setState(() {
      itemList = tempItemList;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: myAppBar(),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                exportData();
              },
              child: const Text('Assets Tabloyu Yükle'),
            ),
            ElevatedButton(
              onPressed: () {
                googleSheetTablo();
              },
              child: const Text('Google Sheet Tablo Yükle'),
            ),
            Expanded(flex: 1, child: chips()),
            Expanded(flex: 5, child: contactListView())
          ],
        ),
      ),
    );
  }

  Widget chips() {
    return FutureBuilder(
      future: Firebase.initializeApp(),
      builder: (context, snapshot) {
        return StreamBuilder(
          stream: location == '[ALL]'
              ? db.collection('contacts').snapshots()
              : db
                  .collection('contacts')
                  .where('location', isEqualTo: location)
                  .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            } else {
              return ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  var data = snapshot.data!.docs;
                  return Wrap(
                    children: [
                      myChip(data[index]['category'], Colors.grey),
                    ],
                  );
                },
              );
            }
          },
        );
      },
    );
  }

  Widget contactListView() {
    return FutureBuilder(
      future: firebaseStart(),
      builder: (context, snapshot) {
        return StreamBuilder<QuerySnapshot>(
          stream: location == '[ALL]'
              ? db.collection('contacts').snapshots()
              : db
                  .collection('contacts')
                  .where('location', isEqualTo: location)
                  .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            } else {
              return ListView.builder(
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  var docs = snapshot.data!.docs;
                  return contacts(docs: docs, index: index);
                },
              );
            }
          },
        );
      },
    );
  }

  Widget contacts(
      {List<QueryDocumentSnapshot<Object?>>? docs, required int index}) {
    return Card(
      child: Row(
        children: [
          Flexible(
            flex: 4,
            child: Column(
              children: [
                Text(
                  docs![index]['name'],
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                Text(
                  docs[index]['position'],
                  style: const TextStyle(
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  children: [
                    Expanded(child: Text(docs![index]['location'])),
                    Container(
                      color: Colors.black87,
                      padding: const EdgeInsets.only(
                          left: 20, right: 20, top: 5, bottom: 5),
                      child: Text(
                        docs[index]['category'],
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
          Flexible(
            flex: 1,
            child: Column(
              children: [
                IconButton(
                    onPressed: () {
                      phoneCall(phoneNo: docs[index]['cell_no']);
                    },
                    icon: const Icon(Icons.call)),
                IconButton(
                    onPressed: () {
                      sendSms();
                    },
                    icon: const Icon(Icons.textsms_outlined)),
                IconButton(
                    onPressed: () {
                      sendWhatsApp(docs[index]['cell_no']);
                    },
                    icon: const Icon(Icons.circle)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void exportData() async {
    final CollectionReference cotacts =
        FirebaseFirestore.instance.collection('contacts');
    final myData = await rootBundle.loadString('assets/res/demo.csv');
    List<List<dynamic>> csvTable = const CsvToListConverter().convert(myData);
    List<List<dynamic>> data = [];
    data = csvTable;
    for (var i = 0; i < data.length; i++) {
      var record = {
        'category': data[i][1],
        'name': data[i][2],
        'cell_no': data[i][3],
        'position': data[i][4],
        'location': data[i][5],
        'email': data[i][6],
      };
      cotacts.add(record);
    }
  }

  void googleSheetTablo() async {
    final CollectionReference contacts =
        FirebaseFirestore.instance.collection('contacts');
    final gSheets = GSheets(credentials);
    final ss = await gSheets.spreadsheet(spreadSheedId);
    var sheet = ss.worksheetByTitle('Sayfa1');
    int rows = sheet!.rowCount;
    print(rows);
    var cellRows;
    for (var i = 1; i < rows; i++) {
      cellRows = await sheet.cells.row(i);
      print(cellRows);
      //firebase ekle --
      var record = {
        'category': cellRows.elementAt(1).value,
        'name': cellRows.elementAt(2).value,
        'cell_no': cellRows.elementAt(3).value,
        'position': cellRows.elementAt(4).value,
        'location': cellRows.elementAt(5).value,
        'email': cellRows.elementAt(6).value,
      };
      contacts.add(record);
    }
  }

  void sendSms() async {
    List<String> recepients = ['+905388398686'];
    //await sendSMS(message: 'Hi', recipients: recepients);
  }

  void sendWhatsApp(String urlS) {
    String url = 'whatsapp://send?+$urlS';
    launchUrl(Uri.parse(url));
  }

  Future<void> firebaseStart() async {
    await Firebase.initializeApp();
  }

  void phoneCall({String? phoneNo}) {
    launchUrl(Uri(scheme: 'tel', path: phoneNo));
  }

  Widget contact() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        title: Row(
          children: [
            Flexible(
              flex: 4,
              child: GestureDetector(
                child: Column(
                  children: [
                    const Text(
                      'name',
                      style:
                          TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const Text(
                      'positioned',
                      style:
                          TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'location',
                            style: TextStyle(fontSize: 12),
                            textAlign: TextAlign.left,
                            softWrap: true,
                          ),
                        ),
                        Container(
                          color: Colors.black,
                          padding: const EdgeInsets.only(
                              left: 20, right: 20, top: 5, bottom: 5),
                          child: const Text(
                            'Category',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        )
                      ],
                    )
                  ],
                ),
              ),
            ),
            Flexible(
                flex: 1,
                child: Column(
                  children: [
                    IconButton(onPressed: () {}, icon: const Icon(Icons.call)),
                    IconButton(
                        onPressed: () {},
                        icon: const Icon(Icons.textsms_outlined)),
                    IconButton(onPressed: () {}, icon: const Icon(Icons.cabin))
                  ],
                ))
          ],
        ),
      ),
    );
  }

  Widget myChip(String label, Color color) {
    Color color = Colors.amber;
    var rnd = Random();
    int i = rnd.nextInt(6);
    switch (i) {
      case 1:
        color = Colors.deepOrange;

        break;
      case 2:
        color = Colors.purple;

        break;
      case 3:
        color = Colors.orangeAccent;

        break;
      case 4:
        color = Colors.greenAccent;

        break;
      case 5:
        color = Colors.blue;

        break;
      case 6:
        color = Colors.yellow;

        break;
      default:
    }

    return GestureDetector(
      onTap: () {},
      child: Chip(
        label: Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
        labelPadding: const EdgeInsets.only(left: 8, right: 8),
        backgroundColor: color,
        elevation: 6,
        shadowColor: Colors.grey[60],
        padding: const EdgeInsets.all(8),
      ),
    );
  }

  AppBar myAppBar() {
    return AppBar(
      title: Column(
        children: [
          Text(
            widget.title,
          ),
          locationDropDown(),
        ],
      ),
      actions: [
        GestureDetector(
          onTap: () {},
          child: const Icon(
            Icons.info,
            size: 40,
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: () {},
          child: const Icon(
            Icons.help,
            size: 40,
          ),
        ),
      ],
    );
  }

  Widget locationDropDown() {
    return Center(
      child: itemList.isEmpty
          ? const CircularProgressIndicator()
          : DropdownButton(
              value: location,
              items: itemList.map<DropdownMenuItem<String>>((String e) {
                return DropdownMenuItem(
                  value: e,
                  child: Text(e),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  location = value.toString();
                });
              },
            ),
    );
  }
}
