import 'dart:io' show stdout;
import 'package:app_doancunhan/models/catalog.dart';

void check(bool condition, String description) {
  if (!condition) throw StateError(description);
}

void main() {
  const uploaded = 'https://res.cloudinary.com/demo/image/upload/v1/service.jpg';
  final serviceJson = <String, dynamic>{
    'id': 1, 'categoryId': 2, 'name': 'Service fixture',
    'price': 100000, 'durationMinutes': 30, 'imageUrl': uploaded,
  };
  final comboJson = <String, dynamic>{
    'id': 3, 'name': 'Combo fixture', 'price': 200000,
    'active': true, 'items': <Map<String, dynamic>>[], 'imageUrl': uploaded,
  };
  check(Service.fromJson(serviceJson).imageUrl == uploaded, 'Service must retain API imageUrl');
  check(Combo.fromJson(comboJson).imageUrl == uploaded, 'Combo must retain API imageUrl');
  serviceJson['imageUrl'] = '  $uploaded  ';
  check(Service.fromJson(serviceJson).imageUrl == uploaded, 'Whitespace is trimmed');
  serviceJson['imageUrl'] = '$uploaded?version=2';
  check(Service.fromJson(serviceJson).imageUrl == '$uploaded?version=2', 'A refreshed image URL must replace the old one');
  serviceJson.remove('imageUrl');
  comboJson.remove('imageUrl');
  check(Service.fromJson(serviceJson).imageUrl == null, 'Old service DTO without image remains compatible');
  check(Combo.fromJson(comboJson).imageUrl == null, 'Old combo DTO without image remains compatible');
  stdout.writeln('CATALOG_IMAGE_CONTRACT: 6/6 PASS');
}
