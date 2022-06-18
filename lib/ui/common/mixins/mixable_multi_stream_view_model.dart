import 'package:stacked/stacked.dart';

abstract class MixableMultiStreamViewModel extends MultipleStreamViewModel {
  @override
  Map<String, StreamData> get streamsMap => {};
}
