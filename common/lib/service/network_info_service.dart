/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */
import 'package:network_info_plus/network_info_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'network_info_service.g.dart';

@Riverpod(keepAlive: true)
NetworkInfo networkInfoService(NetworkInfoServiceRef ref) {
  return NetworkInfo();
}
