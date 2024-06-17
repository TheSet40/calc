// ignore_for_file: file_names

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/historyItem.dart';

class HistoryCache {

  static void addToHistory({required HistoryItem historyItem}) async {
    try {
      final path = (await getApplicationDocumentsDirectory()).path;
      final file = File("$path/History.txt");

      final Map<String, dynamic> historyMap = historyItem.toJson();

      final String jsonHistoryItem = jsonEncode(historyMap);

      file.writeAsStringSync("$jsonHistoryItem\n", mode: FileMode.append);
    } catch (error) {
      debugPrint(error.toString());
    }
  }

  static Future<List<HistoryItem>> loadHistory() async {
    try {
      final String path = (await getApplicationDocumentsDirectory()).path;
      final File file = File("$path/History.txt");
      final List<String> cache = await file.readAsLines();

      List<HistoryItem> history = [];

      for (String jsonItem in cache) {
        final Map<String, dynamic> itemMap = jsonDecode(jsonItem);

        history.add(HistoryItem.fromJson(itemMap));
      }

      return history;
    } catch (error) {
      debugPrint(error.toString());
      return [];
    }
  }

}