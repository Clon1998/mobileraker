import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/data/model/hive/machine.dart';


final selectedCamIndexProvider = StateProvider.autoDispose((ref) => 0);

final machineProvider = Provider.autoDispose<Machine>((ref) => throw UnimplementedError());

