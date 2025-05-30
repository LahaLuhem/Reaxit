import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart';
import 'package:http_parser/http_parser.dart';
import 'package:oauth2/oauth2.dart' as oauth2;
import 'package:reaxit/api/api_repository.dart';
import 'package:reaxit/api/exceptions.dart';
import 'package:reaxit/config.dart';
import 'package:reaxit/models.dart';
import 'package:reaxit/models/thabliod.dart';
import 'package:reaxit/models/vacancie.dart';
import 'package:reaxit/models/announcement.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

class LoggingClient extends oauth2.Client {
  LoggingClient(
    super.credentials, {
    super.identifier,
    super.secret,
    super.basicAuth,
    super.httpClient,
    super.onCredentialsRefreshed,
  });

  LoggingClient.fromClient(oauth2.Client client)
    : super(
        client.credentials,
        identifier: client.identifier,
        secret: client.secret,
      );

  static void logResponse(Uri url, int statusCode) {
    if (kDebugMode) {
      print('url: $url, response code: $statusCode');
    }
  }

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    StreamedResponse response;
    try {
      response = await super.send(request);
    } catch (e) {
      if (kDebugMode) {
        print('url: ${request.url}, failed: $e');
      }
      rethrow;
    }
    if (kDebugMode) {
      print('url: ${request.url}, response code: ${response.statusCode}');
    }
    return response;
  }
}

/// Provides an interface to the api.
///
/// Its methods may throw an [ApiException] if there are unexpected results.
/// In case credentials cannot be refreshed, this calls `logOut`, which should
/// close the client and indicates that the user is no longer logged in.
class ConcrexitApiRepository implements ApiRepository {
  @override
  final Config config;

  /// The authenticated client used to access the API.
  LoggingClient? _innerClient;

  final Function() _onLogOut;

  ConcrexitApiRepository({
    /// The authenticated client used to access the API.
    required LoggingClient client,

    /// An [Config] describing the API.
    required this.config,

    /// Called when the client can no longer authenticate.
    required Function() onLogOut,
  }) : _innerClient = client,
       _onLogOut = onLogOut,
       _baseUri = Uri(
         scheme: config.scheme,
         host: config.host,
         port: config.port,
       );

  @override
  void close() {
    if (_innerClient != null) {
      _innerClient!.close();
      _innerClient = null;
    }
  }

  /// The authenticated client used to access the API.
  ///
  /// Throws [ApiException.notLoggedIn] if the ApiRepository is not closed.
  LoggingClient get _client {
    if (_innerClient == null) {
      throw ApiException.notLoggedIn;
    } else {
      return _innerClient!;
    }
  }

  final Uri _baseUri;

  static const String _basePath = 'api/v2';

  /// Headers that should be specified on requests with a JSON body.
  static const Map<String, String> _jsonHeader = {
    'Content-type': 'application/json',
  };

  /// Convenience method for building a URL to an API endpoint.
  Uri _uri({required String path, Map<String, dynamic>? query}) {
    return _baseUri.replace(
      path: path.startsWith('/') ? '$_basePath$path' : '$_basePath/$path',
      queryParameters: query,
    );
  }

  /// Wrapper that utf-8 decodes the body of a response to json.
  static Map<String, dynamic> _jsonDecode(Response response) =>
      jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

  /// Wrapper that utf-8 decodes the body of a response to json.
  static List<dynamic> _jsonDecodeList(Response response) =>
      jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;

  /// A wrapper for requests that throws only [ApiException]s.
  ///
  /// Translates exceptions that can be thrown by [oauth2.Client.send()],
  /// and throws exceptions based on status codes. By default, all status codes
  /// other than 200, 201, 203, and 204 result in an [ApiException], but this can be
  /// overridden with `allowedStatusCodes`.
  ///
  /// Can be called for example as:
  /// ```dart
  /// final response = await _handleExceptions(() => client.get(uri));
  /// ```
  ///
  /// If you want to manually handle for example 403s, you can use:
  /// ```dart
  /// final response = await _handleExceptions(
  ///   () => client.get(uri),
  ///   allowedStatusCodes: [200, 403],
  /// );
  /// // Use `response.statusCode` here to handle 403.
  /// ```
  Future<Response> _handleExceptions(
    Future<Response> Function() request, {
    List<int> allowedStatusCodes = const [200, 201, 202, 204],
  }) async {
    try {
      final response = await request();
      if (allowedStatusCodes.contains(response.statusCode)) return response;
      switch (response.statusCode) {
        case 401:
          Sentry.addBreadcrumb(Breadcrumb(message: '401 return'));

          _onLogOut();
          throw ApiException.notLoggedIn;
        case 403:
          throw ApiException.notAllowed;
        case 404:
          throw ApiException.notFound;
        default:
          throw ApiException.unknownError;
      }
    } on oauth2.ExpirationException {
      _onLogOut();
      throw ApiException.notLoggedIn;
    } on oauth2.AuthorizationException {
      _onLogOut();
      throw ApiException.notLoggedIn;
    } on SocketException {
      throw ApiException.noInternet;
    } on FormatException {
      throw ApiException.unknownError;
    } on ClientException {
      throw ApiException.unknownError;
    } on HandshakeException {
      throw ApiException.unknownError;
    } on OSError {
      throw ApiException.unknownError;
    } on ApiException {
      rethrow;
    }
  }

  /// Handler to surround all public methods as follows:
  ///
  /// ```dart
  /// return sandbox(() async {
  ///  // Method content ...
  /// });
  /// ```
  ///
  /// This prevents the ApiRepository from throwing any exceptions other than
  /// ApiExceptions.
  static Future<T> sandbox<T>(Future<T> Function() f) async {
    try {
      return await f();
    } on ApiException {
      rethrow;
    } catch (e) {
      Sentry.captureException(e);
      throw ApiException.unknownError;
    }
  }

  @override
  Future<Event> getEventByPk({required int pk}) {
    return sandbox(() async {
      final uri = _uri(path: '/events/$pk/');
      final response = await _handleExceptions(() => _client.get(uri));

      final event = Event.fromJson(_jsonDecode(response));
      if (event.isRegistered) {
        try {
          await getEventRegistrationPayable(
            registrationPk: event.registration!.pk,
          );
          event.registration!.tpayAllowed = true;
        } on ApiException catch (exception) {
          if (exception != ApiException.notAllowed) rethrow;
        }
      }
      return event;
    });
  }

  @override
  Future<Event> getEventBySlug({required String slug}) {
    return sandbox(() async {
      final uri = _uri(path: '/events/$slug/');
      final response = await _handleExceptions(() => _client.get(uri));
      final event = Event.fromJson(_jsonDecode(response));
      if (event.isRegistered) {
        try {
          await getEventRegistrationPayable(
            registrationPk: event.registration!.pk,
          );
          event.registration!.tpayAllowed = true;
        } on ApiException catch (exception) {
          if (exception != ApiException.notAllowed) rethrow;
        }
      }
      return event;
    });
  }

  @override
  Future<ListResponse<Event>> getEvents({
    String? search,
    int? limit,
    int? offset,
    String? ordering,
    DateTime? start,
    DateTime? end,
  }) {
    assert(
      ordering == null || ['start', 'end', '-start', '-end'].contains(ordering),
      'Invalid ordering parameter: $ordering',
    );
    return sandbox(() async {
      final uri = _uri(
        path: '/events/',
        query: {
          if (search != null) 'search': search,
          if (limit != null) 'limit': limit.toString(),
          if (offset != null) 'offset': offset.toString(),
          if (ordering != null) 'ordering': ordering,
          if (start != null) 'start': start.toLocal().toIso8601String(),
          if (end != null) 'end': end.toLocal().toIso8601String(),
        },
      );

      final response = await _handleExceptions(() => _client.get(uri));
      return await compute(_parseEvents, response);
    });
  }

  static ListResponse<Event> _parseEvents(Response response) {
    return ListResponse<Event>.fromJson(
      _jsonDecode(response),
      (json) => Event.fromJson(json as Map<String, dynamic>),
    );
  }

  @override
  Future<ListResponse<PartnerEvent>> getPartnerEvents({
    String? search,
    int? limit,
    int? offset,
    String? ordering,
    DateTime? start,
    DateTime? end,
  }) {
    assert(
      ordering == null || ['start', 'end', '-start', '-end'].contains(ordering),
      'Invalid ordering parameter: $ordering',
    );
    return sandbox(() async {
      final uri = _uri(
        path: '/events/external/',
        query: {
          if (search != null) 'search': search,
          if (limit != null) 'limit': limit.toString(),
          if (offset != null) 'offset': offset.toString(),
          if (ordering != null) 'ordering': ordering,
          if (start != null) 'start': start.toLocal().toIso8601String(),
          if (end != null) 'end': end.toLocal().toIso8601String(),
        },
      );

      final response = await _handleExceptions(() => _client.get(uri));
      return await compute(_parsePartnerEvents, response);
    });
  }

  static ListResponse<PartnerEvent> _parsePartnerEvents(Response response) {
    return ListResponse<PartnerEvent>.fromJson(
      _jsonDecode(response),
      (json) => PartnerEvent.fromJson(json as Map<String, dynamic>),
    );
  }

  @override
  Future<ListResponse<EventRegistration>> getEventRegistrations({
    required int pk,
    int? limit,
    int? offset,
  }) async {
    return sandbox(() async {
      final uri = _uri(
        path: '/events/$pk/registrations/',
        query: {
          if (limit != null) 'limit': limit.toString(),
          if (offset != null) 'offset': offset.toString(),
        },
      );

      final response = await _handleExceptions(() => _client.get(uri));
      return await compute(_parseEventRegistrations, response);
    });
  }

  static ListResponse<EventRegistration> _parseEventRegistrations(
    Response response,
  ) {
    return ListResponse<EventRegistration>.fromJson(
      _jsonDecode(response),
      (json) => EventRegistration.fromJson(json as Map<String, dynamic>),
    );
  }

  @override
  Future<EventRegistration> registerForEvent(int pk) async {
    return sandbox(() async {
      final uri = _uri(path: '/events/$pk/registrations/');
      final response = await _handleExceptions(() => _client.post(uri));
      return EventRegistration.fromJson(_jsonDecode(response));
    });
  }

  @override
  Future<void> cancelRegistration({
    required int eventPk,
    required int registrationPk,
  }) async {
    return sandbox(() async {
      final uri = _uri(path: '/events/$eventPk/registrations/$registrationPk/');
      await _handleExceptions(() => _client.delete(uri));
    });
  }

  @override
  Future<Map<String, RegistrationField>> getRegistrationFields({
    required int eventPk,
    required int registrationPk,
  }) async {
    return sandbox(() async {
      final uri = _uri(
        path: '/events/$eventPk/registrations/$registrationPk/fields/',
      );
      final response = await _handleExceptions(() => _client.get(uri));
      var json = _jsonDecode(response);
      return json.map(
        (key, jsonField) => MapEntry(
          key,
          RegistrationField.fromJson(jsonField as Map<String, dynamic>),
        ),
      );
    });
  }

  @override
  Future<void> updateRegistrationFields({
    required int eventPk,
    required int registrationPk,
    required Map<String, RegistrationField> fields,
  }) async {
    return sandbox(() async {
      final uri = _uri(
        path: '/events/$eventPk/registrations/$registrationPk/fields/',
      );
      final body = jsonEncode(
        fields.map((key, field) => MapEntry(key, field.value)),
      );
      await _handleExceptions(
        () => _client.put(uri, body: body, headers: _jsonHeader),
      );
    });
  }

  @override
  Future<AdminEvent> getAdminEvent({required int pk}) {
    return sandbox(() async {
      final uri = _uri(path: '/admin/events/$pk/');
      final response = await _handleExceptions(() => _client.get(uri));
      return AdminEvent.fromJson(_jsonDecode(response));
    });
  }

  @override
  Future<ListResponse<AdminEventRegistration>> getAdminEventRegistrations({
    required int pk,
    int? limit,
    int? offset,
    String? search,
    String? ordering,
    bool? cancelled,
    bool? queued,
  }) async {
    assert(
      ordering == null ||
          [
            'date',
            'date_cancelled',
            'queue_position',
            '-date',
            '-date_cancelled',
            '-queue_position',
          ].contains(ordering),
      'Invalid ordering parameter: $ordering',
    );
    return sandbox(() async {
      final uri = _uri(
        path: '/admin/events/$pk/registrations/',
        query: {
          if (limit != null) 'limit': limit.toString(),
          if (offset != null) 'offset': offset.toString(),
          if (ordering != null) 'ordering': ordering,
          if (search != null) 'search': search,
          if (cancelled != null) 'cancelled': cancelled.toString(),
          if (queued != null) 'queued': queued.toString(),
        },
      );
      final response = await _handleExceptions(() => _client.get(uri));
      return await compute(_parseAdminEventRegistrations, response);
    });
  }

  static ListResponse<AdminEventRegistration> _parseAdminEventRegistrations(
    Response response,
  ) {
    return ListResponse<AdminEventRegistration>.fromJson(
      _jsonDecode(response),
      (json) => AdminEventRegistration.fromJson(json as Map<String, dynamic>),
    );
  }

  @override
  Future<AdminEventRegistration> markPresentAdminEventRegistration({
    required int eventPk,
    required int registrationPk,
    required bool present,
  }) async {
    return sandbox(() async {
      final uri = _uri(
        path: '/admin/events/$eventPk/registrations/$registrationPk/',
      );
      final body = jsonEncode({'present': present});
      final response = await _handleExceptions(
        () => _client.patch(uri, body: body, headers: _jsonHeader),
      );
      return AdminEventRegistration.fromJson(_jsonDecode(response));
    });
  }

  @override
  Future<String> markPresentEventRegistration({
    required int eventPk,
    required String token,
  }) async {
    return sandbox(() async {
      final uri = _uri(path: '/events/$eventPk/mark-present/$token/');
      final response = await _handleExceptions(
        () => _client.patch(uri),
        allowedStatusCodes: [200, 403],
      );
      final detail = _jsonDecode(response)['detail'] as String;
      if (response.statusCode == 403) throw ApiException.message(detail);
      return detail;
    });
  }

  @override
  Future<Payable> markPaidAdminEventRegistration({
    required int registrationPk,
    required PaymentType paymentType,
  }) async {
    assert(paymentType != PaymentType.tpayPayment);
    return sandbox(() async {
      final uri = _uri(
        path:
            '/admin/payments/payables/events/eventregistration/$registrationPk/',
      );
      late String typeString;
      switch (paymentType) {
        case PaymentType.cardPayment:
          typeString = 'card_payment';
          break;
        case PaymentType.cashPayment:
          typeString = 'cash_payment';
          break;
        case PaymentType.wirePayment:
          typeString = 'wire_payment';
          break;
        case PaymentType.tpayPayment:
          // This case should never occur.
          typeString = 'tpay_payment';
          break;
      }
      final body = jsonEncode({'payment_type': typeString});
      final response = await _handleExceptions(
        () => _client.patch(uri, body: body, headers: _jsonHeader),
      );
      return Payable.fromJson(_jsonDecode(response));
    });
  }

  @override
  Future<void> markNotPaidAdminEventRegistration({
    required int registrationPk,
  }) async {
    return sandbox(() async {
      final uri = _uri(
        path:
            '/admin/payments/payables/events/eventregistration/$registrationPk/',
      );
      await _handleExceptions(() => _client.delete(uri));
    });
  }

  @override
  Future<ListResponse<AdminFoodOrder>> getAdminFoodOrders({
    required int pk,
    int? limit,
    int? offset,
    String? search,
  }) async {
    return sandbox(() async {
      final uri = _uri(
        path: '/admin/food/events/$pk/orders/',
        query: {
          if (limit != null) 'limit': limit.toString(),
          if (offset != null) 'offset': offset.toString(),
          if (search != null) 'search': search,
        },
      );
      final response = await _handleExceptions(() => _client.get(uri));
      return await compute(_parseAdminFoodOrders, response);
    });
  }

  static ListResponse<AdminFoodOrder> _parseAdminFoodOrders(Response response) {
    return ListResponse<AdminFoodOrder>.fromJson(
      _jsonDecode(response),
      (json) => AdminFoodOrder.fromJson(json as Map<String, dynamic>),
    );
  }

  @override
  Future<Payable> markPaidAdminFoodOrder({
    required int orderPk,
    required PaymentType paymentType,
  }) async {
    assert(paymentType != PaymentType.tpayPayment);
    return sandbox(() async {
      final uri = _uri(
        path: '/admin/payments/payables/pizzas/foodorder/$orderPk/',
      );
      late String typeString;
      switch (paymentType) {
        case PaymentType.cardPayment:
          typeString = 'card_payment';
          break;
        case PaymentType.cashPayment:
          typeString = 'cash_payment';
          break;
        case PaymentType.wirePayment:
          typeString = 'wire_payment';
          break;
        case PaymentType.tpayPayment:
          // This case should never occur.
          typeString = 'tpay_payment';
          break;
      }
      final body = jsonEncode({'payment_type': typeString});
      final response = await _handleExceptions(
        () => _client.patch(uri, body: body, headers: _jsonHeader),
      );
      return Payable.fromJson(_jsonDecode(response));
    });
  }

  @override
  Future<void> markNotPaidAdminFoodOrder({required int orderPk}) async {
    return sandbox(() async {
      final uri = _uri(
        path: '/admin/payments/payables/pizzas/foodorder/$orderPk/',
      );
      await _handleExceptions(() => _client.delete(uri));
    });
  }

  @override
  Future<FoodEvent> getFoodEvent(int pk) async {
    return sandbox(() async {
      final uri = _uri(path: '/food/events/$pk/');
      final response = await _handleExceptions(() => _client.get(uri));
      final foodEvent = FoodEvent.fromJson(_jsonDecode(response));
      if (foodEvent.hasOrder) {
        try {
          await getFoodOrderPayable(foodOrderPk: foodEvent.order!.pk);
          foodEvent.order!.tpayAllowed = true;
        } on ApiException catch (exception) {
          if (exception != ApiException.notAllowed) rethrow;
        }
      }
      return foodEvent;
    });
  }

  @override
  Future<ListResponse<FoodEvent>> getFoodEvents({
    int? limit,
    int? offset,
    String? ordering,
    DateTime? start,
    DateTime? end,
  }) async {
    assert(
      ordering == null || ['start', 'end', '-start', '-end'].contains(ordering),
      'Invalid ordering parameter: $ordering',
    );
    return sandbox(() async {
      final uri = _uri(
        path: '/food/events/',
        query: {
          if (limit != null) 'limit': limit.toString(),
          if (offset != null) 'offset': offset.toString(),
          if (ordering != null) 'ordering': ordering,
          if (start != null) 'start': start.toLocal().toIso8601String(),
          if (end != null) 'end': end.toLocal().toIso8601String(),
        },
      );

      final response = await _handleExceptions(() => _client.get(uri));
      return await compute(_parseFoodEvents, response);
    });
  }

  static ListResponse<FoodEvent> _parseFoodEvents(Response response) {
    return ListResponse<FoodEvent>.fromJson(
      _jsonDecode(response),
      (json) => FoodEvent.fromJson(json as Map<String, dynamic>),
    );
  }

  @override
  Future<FoodEvent> getCurrentFoodEvent() async {
    return sandbox(() async {
      final now = DateTime.now().toLocal();
      final uri = _uri(
        path: '/food/events/',
        query: {
          'ordering': 'start',
          'start': now.subtract(const Duration(hours: 8)).toIso8601String(),
          'end': now.add(const Duration(hours: 8)).toIso8601String(),
        },
      );
      final response = await _handleExceptions(() => _client.get(uri));
      final events =
          ListResponse<FoodEvent>.fromJson(
            _jsonDecode(response),
            (json) => FoodEvent.fromJson(json as Map<String, dynamic>),
          ).results;

      if (events.isEmpty) {
        throw ApiException.notFound;
      } else if (events.length == 1) {
        final foodEvent = events.first;
        if (foodEvent.hasOrder) {
          try {
            await getFoodOrderPayable(foodOrderPk: foodEvent.order!.pk);
            foodEvent.order!.tpayAllowed = true;
          } on ApiException catch (exception) {
            if (exception != ApiException.notAllowed) rethrow;
          }
        }
        return foodEvent;
      } else {
        final foodEvent = events.firstWhere(
          (event) => event.end.isAfter(now),
          orElse: () => events.first,
        );
        if (foodEvent.hasOrder) {
          try {
            await getFoodOrderPayable(foodOrderPk: foodEvent.order!.pk);
            foodEvent.order!.tpayAllowed = true;
          } on ApiException catch (exception) {
            if (exception != ApiException.notAllowed) rethrow;
          }
        }
        return foodEvent;
      }
    });
  }

  @override
  Future<FoodOrder> getFoodOrder(int pk) async {
    return sandbox(() async {
      final uri = _uri(path: '/food/events/$pk/order/');
      final response = await _handleExceptions(() => _client.get(uri));
      final foodOrder = FoodOrder.fromJson(_jsonDecode(response));
      try {
        await getFoodOrderPayable(foodOrderPk: foodOrder.pk);
        foodOrder.tpayAllowed = true;
      } on ApiException catch (exception) {
        if (exception != ApiException.notAllowed) rethrow;
      }
      return foodOrder;
    });
  }

  @override
  Future<void> cancelFoodOrder(int pk) async {
    return sandbox(() async {
      final uri = _uri(path: '/food/events/$pk/order/');
      await _handleExceptions(() => _client.delete(uri));
    });
  }

  @override
  Future<FoodOrder> placeFoodOrder({
    required int eventPk,
    required int productPk,
  }) async {
    return sandbox(() async {
      final uri = _uri(path: '/food/events/$eventPk/order/');
      final body = jsonEncode({'product': productPk});
      final response = await _handleExceptions(
        () => _client.post(uri, body: body, headers: _jsonHeader),
      );
      final foodOrder = FoodOrder.fromJson(_jsonDecode(response));
      try {
        await getFoodOrderPayable(foodOrderPk: foodOrder.pk);
        foodOrder.tpayAllowed = true;
      } on ApiException catch (exception) {
        if (exception != ApiException.notAllowed) rethrow;
      }
      return foodOrder;
    });
  }

  @override
  Future<FoodOrder> changeFoodOrder({
    required int eventPk,
    required int productPk,
  }) async {
    return sandbox(() async {
      final uri = _uri(path: '/food/events/$eventPk/order/');
      final body = jsonEncode({'product': productPk});
      final response = await _handleExceptions(
        () => _client.put(uri, body: body, headers: _jsonHeader),
      );
      final foodOrder = FoodOrder.fromJson(_jsonDecode(response));
      try {
        await getFoodOrderPayable(foodOrderPk: foodOrder.pk);
        foodOrder.tpayAllowed = true;
      } on ApiException catch (exception) {
        if (exception != ApiException.notAllowed) rethrow;
      }
      return foodOrder;
    });
  }

  @override
  Future<ListResponse<Product>> getFoodEventProducts(
    int pk, {
    int? limit,
    int? offset,
    String? search,
  }) async {
    return sandbox(() async {
      final uri = _uri(
        path: '/food/events/$pk/products/',
        query: {
          if (limit != null) 'limit': limit.toString(),
          if (offset != null) 'offset': offset.toString(),
        },
      );

      final response = await _handleExceptions(() => _client.get(uri));
      return await compute(_parseFoodEventProducts, response);
    });
  }

  static ListResponse<Product> _parseFoodEventProducts(Response response) {
    return ListResponse<Product>.fromJson(
      _jsonDecode(response),
      (json) => Product.fromJson(json as Map<String, dynamic>),
    );
  }

  Future<Payable> _getPayable({
    required String appLabel,
    required String modelName,
    required String payablePk,
  }) async {
    return sandbox(() async {
      final uri = _uri(
        path: '/payments/payables/$appLabel/$modelName/$payablePk/',
      );

      final response = await _handleExceptions(() => _client.get(uri));
      return Payable.fromJson(_jsonDecode(response));
    });
  }

  Future<Payable> _makeThaliaPayPayment({
    required String appLabel,
    required String modelName,
    required String payablePk,
  }) async {
    return sandbox(() async {
      final uri = _uri(
        path:
            '/payments/payables/$appLabel/'
            '$modelName/${Uri.encodeComponent(payablePk)}/',
      );

      final response = await _handleExceptions(() => _client.patch(uri));
      return Payable.fromJson(_jsonDecode(response));
    });
  }

  @override
  Future<PaymentUser> getPaymentUser() async {
    return sandbox(() async {
      final uri = _uri(path: '/payments/users/me/');
      final response = await _handleExceptions(() => _client.get(uri));
      return PaymentUser.fromJson(_jsonDecode(response));
    });
  }

  @override
  Future<Payable> getFoodOrderPayable({required int foodOrderPk}) =>
      _getPayable(
        appLabel: 'pizzas',
        modelName: 'foodorder',
        payablePk: foodOrderPk.toString(),
      );

  @override
  Future<Payable> thaliaPayFoodOrder({required int foodOrderPk}) =>
      _makeThaliaPayPayment(
        appLabel: 'pizzas',
        modelName: 'foodorder',
        payablePk: foodOrderPk.toString(),
      );

  @override
  Future<Payable> getEventRegistrationPayable({required int registrationPk}) =>
      _getPayable(
        appLabel: 'events',
        modelName: 'eventregistration',
        payablePk: registrationPk.toString(),
      );

  @override
  Future<Payable> thaliaPayRegistration({required int registrationPk}) =>
      _makeThaliaPayPayment(
        appLabel: 'events',
        modelName: 'eventregistration',
        payablePk: registrationPk.toString(),
      );

  @override
  Future<Payable> getSalesOrderPayable({required String salesOrderPk}) =>
      _getPayable(
        appLabel: 'sales',
        modelName: 'order',
        payablePk: salesOrderPk,
      );

  @override
  Future<Payable> thaliaPaySalesOrder({required String salesOrderPk}) =>
      _makeThaliaPayPayment(
        appLabel: 'sales',
        modelName: 'order',
        payablePk: salesOrderPk,
      );

  @override
  Future<Member> getMember({required int pk}) async {
    return sandbox(() async {
      final uri = _uri(path: '/members/$pk/');
      final response = await _handleExceptions(() => _client.get(uri));
      return Member.fromJson(_jsonDecode(response));
    });
  }

  @override
  Future<ListResponse<ListMember>> getMembers({
    String? search,
    int? limit,
    int? offset,
    String? ordering,
    int? year,
  }) async {
    assert(
      ordering == null ||
          [
            'last_name',
            'first_name',
            'username',
            '-last_name',
            '-first_name',
            '-username',
          ].contains(ordering),
      'Invalid ordering parameter: $ordering',
    );
    return sandbox(() async {
      final uri = _uri(
        path: '/members/',
        query: {
          if (search != null) 'search': search,
          if (limit != null) 'limit': limit.toString(),
          if (offset != null) 'offset': offset.toString(),
          if (ordering != null) 'ordering': ordering,
          if (year != null) 'starting_year': year.toString(),
        },
      );

      final response = await _handleExceptions(() => _client.get(uri));
      return await compute(_parseMembers, response);
    });
  }

  static ListResponse<ListMember> _parseMembers(Response response) {
    return ListResponse<ListMember>.fromJson(
      _jsonDecode(response),
      (json) => ListMember.fromJson(json as Map<String, dynamic>),
    );
  }

  @override
  Future<FullMember> getMe() async {
    return sandbox(() async {
      final uri = _uri(path: '/members/me/');
      final response = await _handleExceptions(() => _client.get(uri));
      return FullMember.fromJson(_jsonDecode(response));
    });
  }

  @override
  Future<void> updateAvatar(String filePath) async {
    return sandbox(() async {
      final uri = _uri(path: '/members/me/');
      final request = MultipartRequest('PATCH', uri);
      request.files.add(
        await MultipartFile.fromPath(
          'profile.photo',
          filePath,
          contentType: MediaType('image', 'jpeg'),
        ),
      );

      await _handleExceptions(() async {
        final streamedResponse = await _client.send(request);
        return Response.fromStream(streamedResponse);
      });
    });
  }

  @override
  Future<void> updateDescription(String description) async {
    return sandbox(() async {
      final uri = _uri(path: '/members/me/');
      final body = jsonEncode({
        'profile': {'profile_description': description},
      });
      await _handleExceptions(
        () => _client.patch(uri, body: body, headers: _jsonHeader),
      );
    });
  }

  @override
  Future<Album> getAlbum({required String slug}) async {
    return sandbox(() async {
      final uri = _uri(path: '/photos/albums/$slug/');
      final response = await _handleExceptions(() => _client.get(uri));
      return Album.fromJson(_jsonDecode(response));
    });
  }

  @override
  Future<void> updateLiked(int pk, bool liked) async {
    return sandbox(() async {
      final uri = _uri(path: '/photos/photos/$pk/like/');
      await _handleExceptions(
        () =>
            liked
                ? _client.post(uri, headers: _jsonHeader)
                : _client.delete(uri, headers: _jsonHeader),
      );
    });
  }

  @override
  Future<ListResponse<ListAlbum>> getAlbums({
    String? search,
    int? limit,
    int? offset,
  }) async {
    return sandbox(() async {
      final uri = _uri(
        path: '/photos/albums/',
        query: {
          if (search != null) 'search': search,
          if (limit != null) 'limit': limit.toString(),
          if (offset != null) 'offset': offset.toString(),
        },
      );

      final response = await _handleExceptions(() => _client.get(uri));
      return await compute(_parseAlbums, response);
    });
  }

  static ListResponse<ListAlbum> _parseAlbums(Response response) {
    return ListResponse<ListAlbum>.fromJson(
      _jsonDecode(response),
      (json) => ListAlbum.fromJson(json as Map<String, dynamic>),
    );
  }

  @override
  Future<ListResponse<Thabloid>> getThabloids({
    String? search,
    int? limit,
    int? offset,
  }) async {
    return sandbox(() async {
      final uri = _uri(
        path: '/thabloid/thabloids/',
        query: {
          if (search != null) 'search': search,
          if (limit != null) 'limit': limit.toString(),
          if (offset != null) 'offset': offset.toString(),
        },
      );

      final response = await _handleExceptions(() => _client.get(uri));
      return await compute(_parseThabloids, response);
    });
  }

  static ListResponse<Thabloid> _parseThabloids(Response response) {
    return ListResponse<Thabloid>.fromJson(
      _jsonDecode(response),
      (json) => Thabloid.fromJson(json as Map<String, dynamic>),
    );
  }

  @override
  Future<Thabloid> getThabloid({required int pk}) async {
    return sandbox(() async {
      final uri = _uri(path: '/thabloid/thabloids/$pk');

      final response = await _handleExceptions(() => _client.get(uri));
      return Thabloid.fromJson(_jsonDecode(response));
    });
  }

  @override
  Future<ListResponse<Slide>> getSlides({int? limit, int? offset}) async {
    return sandbox(() async {
      final uri = _uri(
        path: '/announcements/slides/',
        query: {
          if (limit != null) 'limit': limit.toString(),
          if (offset != null) 'offset': offset.toString(),
        },
      );

      final response = await _handleExceptions(() => _client.get(uri));
      return await compute(_parseSlides, response);
    });
  }

  static ListResponse<Slide> _parseSlides(Response response) {
    return ListResponse<Slide>.fromJson(
      _jsonDecode(response),
      (json) => Slide.fromJson(json as Map<String, dynamic>),
    );
  }

  @override
  Future<ListResponse<FrontpageArticle>> getFrontpageArticles({
    int? limit,
    int? offset,
  }) async {
    return sandbox(() async {
      final uri = _uri(
        path: '/announcements/frontpage-articles/',
        query: {
          if (limit != null) 'limit': limit.toString(),
          if (offset != null) 'offset': offset.toString(),
        },
      );

      final response = await _handleExceptions(() => _client.get(uri));
      return await compute(_parseFrontpageArticles, response);
    });
  }

  static ListResponse<FrontpageArticle> _parseFrontpageArticles(
    Response response,
  ) {
    return ListResponse<FrontpageArticle>.fromJson(
      _jsonDecode(response),
      (json) => FrontpageArticle.fromJson(json as Map<String, dynamic>),
    );
  }

  @override
  Future<List<Announcement>> getAnnouncements() async {
    return sandbox(() async {
      final uri = _uri(path: '/announcements/announcements/');

      final response = await _handleExceptions(() => _client.get(uri));
      return await compute(_parseAnnouncements, response);
    });
  }

  static List<Announcement> _parseAnnouncements(Response response) {
    return (_jsonDecodeList(response))
        .map((json) => Announcement.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<Device> registerDevice({
    required String token,
    required String type,
    bool active = true,
  }) async {
    return sandbox(() async {
      final uri = _uri(path: '/pushnotifications/devices/');
      final body = jsonEncode({
        'registration_id': token,
        'active': active,
        'type': type,
      });
      final response = await _handleExceptions(
        () => _client.post(uri, body: body, headers: _jsonHeader),
      );
      return Device.fromJson(_jsonDecode(response));
    });
  }

  @override
  Future<Device> getDevice({required int pk}) async {
    return sandbox(() async {
      final uri = _uri(path: '/pushnotifications/devices/$pk/');
      final response = await _handleExceptions(() => _client.get(uri));
      return Device.fromJson(_jsonDecode(response));
    });
  }

  @override
  Future<Device> disableDevice({required int pk}) async {
    return sandbox(() async {
      final uri = _uri(path: '/pushnotifications/devices/$pk/');
      final body = jsonEncode({'active': false});
      final response = await _handleExceptions(
        () => _client.patch(uri, body: body, headers: _jsonHeader),
      );
      return Device.fromJson(_jsonDecode(response));
    });
  }

  @override
  Future<Device> updateDeviceToken({
    required int pk,
    required String token,
  }) async {
    return sandbox(() async {
      final uri = _uri(path: '/pushnotifications/devices/$pk/');
      final body = jsonEncode({'registration_id': token});
      final response = await _handleExceptions(
        () => _client.patch(uri, body: body, headers: _jsonHeader),
      );
      return Device.fromJson(_jsonDecode(response));
    });
  }

  @override
  Future<Device> updateDeviceReceiveCategory({
    required int pk,
    required List<String> receiveCategory,
  }) async {
    return sandbox(() async {
      final uri = _uri(path: '/pushnotifications/devices/$pk/');
      final body = jsonEncode({'receive_category': receiveCategory});
      final response = await _handleExceptions(
        () => _client.patch(uri, body: body, headers: _jsonHeader),
      );
      return Device.fromJson(_jsonDecode(response));
    });
  }

  @override
  Future<ListResponse<PushNotificationCategory>> getCategories() async {
    return sandbox(() async {
      final uri = _uri(path: '/pushnotifications/categories/');
      final response = await _handleExceptions(() => _client.get(uri));
      return await compute(_parseCategories, response);
    });
  }

  static ListResponse<PushNotificationCategory> _parseCategories(
    Response response,
  ) {
    return ListResponse<PushNotificationCategory>.fromJson(
      _jsonDecode(response),
      (json) => PushNotificationCategory.fromJson(json as Map<String, dynamic>),
    );
  }

  @override
  Future<SalesOrder> claimSalesOrder({required String pk}) async {
    return sandbox(() async {
      final uri = _uri(path: '/sales/order/$pk/claim/');
      final response = await _handleExceptions(
        () => _client.patch(uri),
        allowedStatusCodes: [200, 201, 204, 403],
      );
      if (response.statusCode == 403) {
        final String reason = _jsonDecode(response)['detail'] as String;
        throw ApiException.message(reason);
      } else {
        final order = SalesOrder.fromJson(_jsonDecode(response));
        try {
          await getSalesOrderPayable(salesOrderPk: pk);
          order.tpayAllowed = true;
        } on ApiException catch (exception) {
          if (exception != ApiException.notAllowed) rethrow;
        }
        return order;
      }
    });
  }

  @override
  Future<ListResponse<ListGroup>> getGroups({
    int? limit,
    int? offset,
    MemberGroupType? type,
    DateTime? start,
    DateTime? end,
    String? search,
  }) async {
    const memberGroupTypeMap = {
      MemberGroupType.committee: 'committee',
      MemberGroupType.society: 'society',
      MemberGroupType.board: 'board',
    };

    final uri = _baseUri.replace(
      path: '$_basePath/activemembers/groups/',
      queryParameters: {
        if (limit != null) 'limit': limit.toString(),
        if (offset != null) 'offset': offset.toString(),
        if (type != null) 'type': memberGroupTypeMap[type],
        if (start != null) 'start': start.toIso8601String(),
        if (end != null) 'end': end.toIso8601String(),
        if (search != null) 'search': search,
      },
    );

    final response = await _handleExceptions(() => _client.get(uri));
    return ListResponse<ListGroup>.fromJson(
      _jsonDecode(response),
      (json) => ListGroup.fromJson(json as Map<String, dynamic>),
    );
  }

  @override
  Future<Group> getGroup({required int pk}) async {
    final uri = _baseUri.replace(path: '$_basePath/activemembers/groups/$pk/');
    final response = await _handleExceptions(() => _client.get(uri));
    return Group.fromJson(_jsonDecode(response));
  }

  @override
  Future<Group> getGroupBySlug({
    required MemberGroupType type,
    required String slug,
  }) async {
    // Only boards have slug support right now
    assert(type == MemberGroupType.board);

    if (type == MemberGroupType.board) {
      final uri = _baseUri.replace(
        path: '$_basePath/activemembers/boards/$slug/',
      );
      final response = await _handleExceptions(() => _client.get(uri));
      return Group.fromJson(_jsonDecode(response));
    } else {
      throw ApiException.message(
        'Slugs are unsupported for groups of this type.',
      );
    }
  }

  @override
  Future<ListResponse<AlbumPhoto>> getLikedPhotos({
    int? limit,
    int? offset,
  }) async {
    final uri = _baseUri.replace(
      path: '$_basePath/photos/photos/liked/',
      queryParameters: {
        if (limit != null) 'limit': limit.toString(),
        if (offset != null) 'offset': offset.toString(),
      },
    );

    final response = await _handleExceptions(() => _client.get(uri));
    return ListResponse<AlbumPhoto>.fromJson(
      _jsonDecode(response),
      (json) => AlbumPhoto.fromJson(json as Map<String, dynamic>),
    );
  }

  @override
  Future<ListResponse<Payment>> getPayments({
    int? limit,
    int? offset,
    String? ordering,
    DateTime? start,
    DateTime? end,
    List<PaymentType>? type,
    bool? settled,
  }) {
    return sandbox(() async {
      const paymentTypeMap = {PaymentType.tpayPayment: 'tpay_payment'};

      final uri = _baseUri.replace(
        path: '$_basePath/payments/',
        queryParameters: {
          if (limit != null) 'limit': limit.toString(),
          if (offset != null) 'offset': offset.toString(),
          if (type != null)
            'type': type.map((t) => paymentTypeMap[t]).join(','),
          if (start != null) 'start': start.toIso8601String(),
          if (end != null) 'end': end.toIso8601String(),
          if (ordering != null) 'ordering': ordering,
          if (settled != null) 'settled': settled.toString(),
        },
      );

      final response = await _handleExceptions(() => _client.get(uri));
      return ListResponse<Payment>.fromJson(
        _jsonDecode(response),
        (json) => Payment.fromJson(json as Map<String, dynamic>),
      );
    });
  }

  @override
  Future<ListResponse<Vacancy>> getVacancies({
    int? limit,
    int? offset,
    DateTime? start,
    DateTime? end,
  }) async {
    final uri = _baseUri.replace(
      path: '$_basePath/partners/vacancies/',
      queryParameters: {
        if (limit != null) 'limit': limit.toString(),
        if (offset != null) 'offset': offset.toString(),
        if (start != null) 'start': start.toIso8601String(),
        if (end != null) 'end': end.toIso8601String(),
      },
    );

    final response = await _handleExceptions(() => _client.get(uri));
    return ListResponse<Vacancy>.fromJson(
      _jsonDecode(response),
      (json) => Vacancy.fromJson(json as Map<String, dynamic>),
    );
  }
}
