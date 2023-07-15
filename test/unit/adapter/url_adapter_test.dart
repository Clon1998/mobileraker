/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mobileraker/data/adapters/uri_adapter.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'url_adapter_test.mocks.dart';

@GenerateMocks([BinaryWriter, BinaryReader])
void main() {
  group('UriAdapter - Deserialization', () {
    final adapter = UriAdapter();

    test('should correctly deserialize a Uri object', () {
      final mockReader = MockBinaryReader();

      // Set up the mock BinaryReader to return the expected values for the fields
      var mockReadByteAnswer = [7, 0, 1, 2, 3, 4, 5, 6];
      when(mockReader.readByte())
          .thenAnswer((_) => mockReadByteAnswer.removeAt(0));
      var mockReadAnswer = [
        'https',
        'example.com',
        8080,
        '/path',
        'query=value',
        'fragment',
        'user:pass'
      ];
      when(mockReader.read())
          .thenAnswer((realInvocation) => mockReadAnswer.removeAt(0));

      final uri = adapter.read(mockReader);

      expect(uri.scheme, equals('https'));
      expect(uri.host, equals('example.com'));
      expect(uri.port, equals(8080));
      expect(uri.path, equals('/path'));
      expect(uri.query, equals('query=value'));
      expect(uri.fragment, equals('fragment'));
      expect(uri.userInfo, equals('user:pass'));
    });

    test('should correctly deserialize a Uri object with empty fields', () {
      final mockReader = MockBinaryReader();

      // Set up the mock BinaryReader to return the expected values for the fields
      var mockReadByteAnswer = [7, 0, 1, 2, 3, 4, 5, 6];
      when(mockReader.readByte())
          .thenAnswer((_) => mockReadByteAnswer.removeAt(0));
      var mockReadAnswer = ['', '', 0, '', '', '', ''];
      when(mockReader.read())
          .thenAnswer((realInvocation) => mockReadAnswer.removeAt(0));

      final uri = adapter.read(mockReader);

      expect(uri.scheme, equals(''));
      expect(uri.host, equals(''));
      expect(uri.port, equals(0));
      expect(uri.path, equals(''));
      expect(uri.query, equals(''));
      expect(uri.fragment, equals(''));
      expect(uri.userInfo, equals(''));
    });
  });

  group('UriAdapter - Serialization', () {
    final adapter = UriAdapter();

    test('should correctly serialize a Uri object', () {
      final mockWriter = MockBinaryWriter();
      final uri = Uri(
        scheme: 'https',
        host: 'example.com',
        port: 8080,
        path: '/path',
        query: 'query=value',
        fragment: 'fragment',
        userInfo: 'user:pass',
      );

      adapter.write(mockWriter, uri);

      verifyInOrder([
        mockWriter.writeByte(7), // Total number of fields
        mockWriter.writeByte(0), // Field index
        mockWriter.write('https'), // Field value
        mockWriter.writeByte(1), // Field index
        mockWriter.write('example.com'), // Field value
        mockWriter.writeByte(2), // Field index
        mockWriter.write(8080), // Field value
        mockWriter.writeByte(3), // Field index
        mockWriter.write('/path'), // Field value
        mockWriter.writeByte(4), // Field index
        mockWriter.write('query=value'), // Field value
        mockWriter.writeByte(5), // Field index
        mockWriter.write('fragment'), // Field value
        mockWriter.writeByte(6), // Field index
        mockWriter.write('user:pass'), // Field value
      ]);
      verifyNoMoreInteractions(mockWriter);
    });

    test('should correctly serialize a Uri object with null fields', () {
      final mockWriter = MockBinaryWriter();
      final uri = Uri(
        scheme: null,
        host: null,
        port: null,
        path: null,
        query: null,
        fragment: null,
        userInfo: null,
      );

      adapter.write(mockWriter, uri);

      verifyInOrder([
        mockWriter.writeByte(7), // Total number of fields
        mockWriter.writeByte(0), // Field index
        mockWriter.write(null), // Field value
        mockWriter.writeByte(1), // Field index
        mockWriter.write(null), // Field value
        mockWriter.writeByte(2), // Field index
        mockWriter.write(null), // Field value
        mockWriter.writeByte(3), // Field index
        mockWriter.write(null), // Field value
        mockWriter.writeByte(4), // Field index
        mockWriter.write(null), // Field value
        mockWriter.writeByte(5), // Field index
        mockWriter.write(null), // Field value
        mockWriter.writeByte(6), // Field index
        mockWriter.write(null), // Field value
      ]);
      verifyNoMoreInteractions(mockWriter);
    });

    test('should correctly serialize a Uri object with empty fields', () {
      final mockWriter = MockBinaryWriter();
      final uri = Uri(
        scheme: '',
        host: '',
        path: '',
        query: '',
        fragment: '',
        userInfo: '',
      );

      adapter.write(mockWriter, uri);

      verifyInOrder([
        mockWriter.writeByte(7), // Total number of fields
        mockWriter.writeByte(0), // Field index
        mockWriter.write(null), // Field value
        mockWriter.writeByte(1), // Field index
        mockWriter.write(null), // Field value
        mockWriter.writeByte(2), // Field index
        mockWriter.write(null), // Field value
        mockWriter.writeByte(3), // Field index
        mockWriter.write(null), // Field value
        mockWriter.writeByte(4), // Field index
        mockWriter.write(null), // Field value
        mockWriter.writeByte(5), // Field index
        mockWriter.write(null), // Field value
        mockWriter.writeByte(6), // Field index
        mockWriter.write(null), // Field value
      ]);
      verifyNoMoreInteractions(mockWriter);
    });

    test('should correctly serialize a Uri object with missing scheme field',
        () {
      final mockWriter = MockBinaryWriter();
      final uri = Uri(
        host: 'example.com',
        port: 8080,
        path: '/path',
        query: 'query=value',
        fragment: 'fragment',
        userInfo: 'user:pass',
      );

      adapter.write(mockWriter, uri);

      verifyInOrder([
        mockWriter.writeByte(7), // Total number of fields
        mockWriter.writeByte(0), // Field index
        mockWriter.write(null), // Field value
        mockWriter.writeByte(1), // Field index
        mockWriter.write('example.com'), // Field value
        mockWriter.writeByte(2), // Field index
        mockWriter.write(8080), // Field value
        mockWriter.writeByte(3), // Field index
        mockWriter.write('/path'), // Field value
        mockWriter.writeByte(4), // Field index
        mockWriter.write('query=value'), // Field value
        mockWriter.writeByte(5), // Field index
        mockWriter.write('fragment'), // Field value
        mockWriter.writeByte(6), // Field index
        mockWriter.write('user:pass'), // Field value
      ]);
      verifyNoMoreInteractions(mockWriter);
    });

    test('should correctly serialize a Uri object with missing host field', () {
      final mockWriter = MockBinaryWriter();
      final uri = Uri(
        scheme: 'https',
        port: 8080,
        path: '/path',
        query: 'query=value',
        fragment: 'fragment',
        userInfo: 'user:pass',
      );

      adapter.write(mockWriter, uri);

      verifyInOrder([
        mockWriter.writeByte(7), // Total number of fields
        mockWriter.writeByte(0), // Field index
        mockWriter.write('https'), // Field value
        mockWriter.writeByte(1), // Field index
        mockWriter.write(null), // Field value
        mockWriter.writeByte(2), // Field index
        mockWriter.write(8080), // Field value
        mockWriter.writeByte(3), // Field index
        mockWriter.write('/path'), // Field value
        mockWriter.writeByte(4), // Field index
        mockWriter.write('query=value'), // Field value
        mockWriter.writeByte(5), // Field index
        mockWriter.write('fragment'), // Field value
        mockWriter.writeByte(6), // Field index
        mockWriter.write('user:pass'), // Field value
      ]);
      verifyNoMoreInteractions(mockWriter);
    });

    test('should correctly serialize a Uri object with missing port field', () {
      final mockWriter = MockBinaryWriter();
      final uri = Uri(
        scheme: 'https',
        host: 'example.com',
        path: '/path',
        query: 'query=value',
        fragment: 'fragment',
        userInfo: 'user:pass',
      );

      adapter.write(mockWriter, uri);

      verifyInOrder([
        mockWriter.writeByte(7), // Total number of fields
        mockWriter.writeByte(0), // Field index
        mockWriter.write('https'), // Field value
        mockWriter.writeByte(1), // Field index
        mockWriter.write('example.com'), // Field value
        mockWriter.writeByte(2), // Field index
        mockWriter.write(null), // Uri will use default port
        mockWriter.writeByte(3), // Field index
        mockWriter.write('/path'), // Field value
        mockWriter.writeByte(4), // Field index
        mockWriter.write('query=value'), // Field value
        mockWriter.writeByte(5), // Field index
        mockWriter.write('fragment'), // Field value
        mockWriter.writeByte(6), // Field index
        mockWriter.write('user:pass'), // Field value
      ]);
      verifyNoMoreInteractions(mockWriter);
    });

    test('should correctly serialize a Uri object with missing path field', () {
      final mockWriter = MockBinaryWriter();
      final uri = Uri(
        scheme: 'https',
        host: 'example.com',
        port: 8080,
        query: 'query=value',
        fragment: 'fragment',
        userInfo: 'user:pass',
      );

      adapter.write(mockWriter, uri);

      verifyInOrder([
        mockWriter.writeByte(7), // Total number of fields
        mockWriter.writeByte(0), // Field index
        mockWriter.write('https'), // Field value
        mockWriter.writeByte(1), // Field index
        mockWriter.write('example.com'), // Field value
        mockWriter.writeByte(2), // Field index
        mockWriter.write(8080), // Field value
        mockWriter.writeByte(3), // Field index
        mockWriter.write(null), // Field value
        mockWriter.writeByte(4), // Field index
        mockWriter.write('query=value'), // Field value
        mockWriter.writeByte(5), // Field index
        mockWriter.write('fragment'), // Field value
        mockWriter.writeByte(6), // Field index
        mockWriter.write('user:pass'), // Field value
      ]);
      verifyNoMoreInteractions(mockWriter);
    });

    test('should correctly serialize a Uri object with missing query field',
        () {
      final mockWriter = MockBinaryWriter();
      final uri = Uri(
        scheme: 'https',
        host: 'example.com',
        port: 8080,
        path: '/path',
        fragment: 'fragment',
        userInfo: 'user:pass',
      );

      adapter.write(mockWriter, uri);

      verifyInOrder([
        mockWriter.writeByte(7), // Total number of fields
        mockWriter.writeByte(0), // Field index
        mockWriter.write('https'), // Field value
        mockWriter.writeByte(1), // Field index
        mockWriter.write('example.com'), // Field value
        mockWriter.writeByte(2), // Field index
        mockWriter.write(8080), // Field value
        mockWriter.writeByte(3), // Field index
        mockWriter.write('/path'), // Field value
        mockWriter.writeByte(4), // Field index
        mockWriter.write(null), // Field value
        mockWriter.writeByte(5), // Field index
        mockWriter.write('fragment'), // Field value
        mockWriter.writeByte(6), // Field index
        mockWriter.write('user:pass'), // Field value
      ]);
      verifyNoMoreInteractions(mockWriter);
    });

    test('should correctly serialize a Uri object with missing fragment field',
        () {
      final mockWriter = MockBinaryWriter();
      final uri = Uri(
        scheme: 'https',
        host: 'example.com',
        port: 8080,
        path: '/path',
        query: 'query=value',
        userInfo: 'user:pass',
      );

      adapter.write(mockWriter, uri);

      verifyInOrder([
        mockWriter.writeByte(7), // Total number of fields
        mockWriter.writeByte(0), // Field index
        mockWriter.write('https'), // Field value
        mockWriter.writeByte(1), // Field index
        mockWriter.write('example.com'), // Field value
        mockWriter.writeByte(2), // Field index
        mockWriter.write(8080), // Field value
        mockWriter.writeByte(3), // Field index
        mockWriter.write('/path'), // Field value
        mockWriter.writeByte(4), // Field index
        mockWriter.write('query=value'), // Field value
        mockWriter.writeByte(5), // Field index
        mockWriter.write(null), // Field value
        mockWriter.writeByte(6), // Field index
        mockWriter.write('user:pass'), // Field value
      ]);
      verifyNoMoreInteractions(mockWriter);
    });

    test('should correctly serialize a Uri object with missing userInfo field',
        () {
      final mockWriter = MockBinaryWriter();
      final uri = Uri(
        scheme: 'https',
        host: 'example.com',
        port: 8080,
        path: '/path',
        query: 'query=value',
        fragment: 'fragment',
      );

      adapter.write(mockWriter, uri);

      verifyInOrder([
        mockWriter.writeByte(7), // Total number of fields
        mockWriter.writeByte(0), // Field index
        mockWriter.write('https'), // Field value
        mockWriter.writeByte(1), // Field index
        mockWriter.write('example.com'), // Field value
        mockWriter.writeByte(2), // Field index
        mockWriter.write(8080), // Field value
        mockWriter.writeByte(3), // Field index
        mockWriter.write('/path'), // Field value
        mockWriter.writeByte(4), // Field index
        mockWriter.write('query=value'), // Field value
        mockWriter.writeByte(5), // Field index
        mockWriter.write('fragment'), // Field value
        mockWriter.writeByte(6), // Field index
        mockWriter.write(null), // Field value
      ]);
      verifyNoMoreInteractions(mockWriter);
    });
  });
}
