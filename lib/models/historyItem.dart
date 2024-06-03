// ignore_for_file: file_names

import 'mathModel.dart';

class HistoryItem {
  const HistoryItem({required this.models, required this.result});
  
  final List<Model> models;
  final String result;

  Map<String, dynamic> toJson() {
    return {
      "models": models.map((m) => m.toJson()).toList(),
      "result": result.toString(),
    };
  }

  factory HistoryItem.fromJson(Map<String, dynamic> json) {
    return HistoryItem(
      models: (json["models"] as List).map<Model>((json) => Model.fromJson(json)).toList(), 
      result: json["result"],
    );
  }
}