import 'dart:async';

import 'package:plugin_pitel/model/http/get_extension_info.dart';
import 'package:plugin_pitel/model/http/get_profile.dart';
import 'package:plugin_pitel/model/http/get_sip_info.dart';
import 'package:plugin_pitel/model/http/login.dart';
import 'package:plugin_pitel/pitel_sdk/pitel_log.dart';
import 'package:plugin_pitel/pitel_sdk/pitel_profile.dart';
import 'package:plugin_pitel/web_service/api_web_service.dart';
import 'package:plugin_pitel/web_service/portal_service.dart';
import 'package:plugin_pitel/web_service/sdk_service.dart';

class _PitelAPIImplement implements PitelApi {
  final ApiWebService _sdkService = SDKService.getInstance();
  final ApiWebService _portalService = PortalService.getInstance();
  final PitelLog _logger = PitelLog(tag: 'PitelApi');

  @override
  Future<String> login(
      {String api = '/api/v1/auth/login/',
      required String username,
      required String password}) async {
    final request = LoginRequest(username: username, password: password);
    try {
      final response = await _sdkService.post(api, null, request.toMap());
      final loginResponse = LoginResponse.fromMap(response);
      return loginResponse.token;
    } catch (err) {
      rethrow;
    }
  }

  @override
  Future<PitelProfileUser> getProfile(
      {String api = '/api/v1/auth/profile/', required String token}) async {
    final headers = GetProfileHeaders(token: token);
    try {
      final response = await _sdkService.get(api, headers.toMap(), null);
      final profileResponse = GetProfileResponse.fromMap(response);
      final pitelProfileUser = PitelProfileUser.convertFrom(profileResponse);
      return pitelProfileUser;
    } catch (err) {
      rethrow;
    }
  }

  @override
  Future<String> getSipInfo(
      {String api = '/api/v1/sdk/token/',
      required String token,
      required String apiKey,
      required String sipUsername}) async {
    final headers = GetSipInfoHeaders(token: token);
    final params = GetSipInfoRequest(apiKey: apiKey, number: sipUsername);
    try {
      final response =
          await _sdkService.get(api, headers.toMap(), params.toMap());
      final pitelToken = GetSipInfoResponse.fromMap(response);
      return pitelToken.token;
    } catch (err) {
      rethrow;
    }
  }

  @override
  Future<GetExtensionResponse> getExtensionInfo(
      {String api = '/sdk/info/',
      required String pitelToken,
      required String sipUsername}) async {
    final headers = GetExtensionInfoHeaders(xPitelToken: pitelToken);
    final params = GetExtensionInfoRequest(number: sipUsername);
    try {
      final response =
          await _portalService.get(api, headers.toMap(), params.toMap());
      final getExtInfo = GetExtensionResponse.fromMap(response);
      return getExtInfo;
    } catch (err) {
      rethrow;
    }
  }
}

abstract class PitelApi {
  static PitelApi? _pitelApi;
  static PitelApi getInstance() {
    if (_pitelApi == null) {
      _pitelApi = _PitelAPIImplement();
    }
    return _pitelApi!;
  }

  Future<String> login(
      {String api = '/api/v1/auth/login/',
      required String username,
      required String password});

  Future<PitelProfileUser> getProfile(
      {String api = '/api/v1/auth/profile/', required String token});

  Future<String> getSipInfo(
      {String api = '/api/v1/sdk/token/',
      required String token,
      required String apiKey,
      required String sipUsername});

  Future<GetExtensionResponse> getExtensionInfo(
      {String api = '/sdk/info/',
      required String pitelToken,
      required String sipUsername});
}
