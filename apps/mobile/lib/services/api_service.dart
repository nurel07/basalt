import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/collection.dart';
import '../config/constants.dart';

class ApiService {
  Future<List<MobileCollection>> getCollections() async {
    final response = await http.get(Uri.parse('${AppConstants.baseUrl}/collections'));

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => MobileCollection.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load collections');
    }
  }

  Future<MobileCollection> getCollection(String id) async {
    final response = await http.get(Uri.parse('${AppConstants.baseUrl}/collections/$id'));

    if (response.statusCode == 200) {
      return MobileCollection.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to load collection');
    }
  }
}

// Provider
final apiServiceProvider = Provider<ApiService>((ref) => ApiService());

final collectionsProvider = FutureProvider<List<MobileCollection>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  return api.getCollections();
});

final collectionDetailsProvider = FutureProvider.family<MobileCollection, String>((ref, id) async {
  final api = ref.watch(apiServiceProvider);
  return api.getCollection(id);
});
