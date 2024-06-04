// ignore_for_file: file_names

class Model {
  Model({this.value, this.operation, this.isDecimal = false});

  String? value;
  String? operation;
  bool isDecimal;

  Map<String, String> toJson() {
    return {
      "value": value.toString(),
      "operation": operation.toString(),
      "decimal": isDecimal ? "1": "0",
    };
  }

  factory Model.fromJson(Map<String, dynamic> json) {
    return Model(
      value: json["value"],
      operation: json["operation"],
      isDecimal: json["decimal"] == "1",
    );
  }

}