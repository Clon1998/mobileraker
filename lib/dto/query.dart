import 'dart:convert';

class Query {
  Map<String,dynamic> objects;

  Map<String, dynamic> toJson() =>
      {
        'objects': objects,
      };
}