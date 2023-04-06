import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:plugin_pitel/config/pitel_config.dart';
import 'package:plugin_pitel/model/http/get_extension_info.dart';
import 'package:plugin_pitel/model/pitel_error.dart';
import 'package:plugin_pitel/model/sip_server.dart';
import 'package:plugin_pitel/pitel_sdk/pitel_api.dart';
import 'package:plugin_pitel/pitel_sdk/pitel_call.dart';
import 'package:plugin_pitel/pitel_sdk/pitel_log.dart';
import 'package:plugin_pitel/sip/src/sanity_check.dart';
import 'package:plugin_pitel/sip/src/sip_ua_helper.dart';

import 'pitel_profile.dart';

class PitelClient {
  static PitelClient? _pitelClient;
  static PitelClient getInstance() {
    _pitelClient ??= PitelClient();
    return _pitelClient!;
  }

  PitelClient() {
    _pitelApi = PitelApi.getInstance();
  }

  late String _token;
  late String _pitelToken;
  late PitelApi _pitelApi;
  late SipServer? _sipServer;
  late PitelProfileUser profileUser;
  String _username = '';
  String _password = '';
  String _displayName = '';
  final PitelLog _logger = PitelLog(tag: 'PitelClient');
  final PitelCall pitelCall = PitelCall();

  final String wssTest = 'wss://sbc03.tel4vn.com:7444';
  final String domainTest = 'pi0003.tel4vn.com';
  final int portTest = 50061;
  final String usernameTest = '103';
  final String passwordTest = '12345678@X';

  final bool isTest = false;

  bool _registerSip({String? fcmToken}) {
    if (_sipServer != null) {
      final settings = PitelSettings();
      Map<String, String> _wsExtraHeaders = {
        'Origin': 'https://${_sipServer?.domain}:${_sipServer?.port}',
        'Host': '${_sipServer?.domain}:${_sipServer?.port}',
        'X-PushToken': "${Platform.isIOS ? 'ios;' : 'android;'}$fcmToken",
      };
      settings.webSocketUrl = _sipServer?.wss ?? "";
      //settings.webSocketSettings.extraHeaders = _wsExtraHeaders;
      settings.webSocketSettings.allowBadCertificate = true;
      //settings.webSocketSettings.userAgent = 'Dart/2.8 (dart:io) for OpenSIPS.';
      settings.uri = 'sip:$_username@${_sipServer?.domain}:${_sipServer?.port}';
      settings.webSocketSettings.extraHeaders = _wsExtraHeaders;
      settings.authorizationUser = _username;
      settings.password = _password;
      settings.displayName = _displayName;
      settings.userAgent = 'SIP Client';
      settings.registerParams.extraContactUriParams = {
        'X-PushToken': "${Platform.isIOS ? 'ios;' : 'android;'}$fcmToken",
      };
      settings.dtmfMode = DtmfMode.RFC2833;
      pitelCall.register(settings);
      return true;
    } else {
      _logger.info('You must login');
      return false;
    }
  }

  bool registerSipWithoutFCM() {
    final settings = PitelSettings();

    Map<String, String> _wsExtraHeaders = {
      'Origin': 'https://${_sipServer?.domain}:${_sipServer?.port}',
      'Host': '${_sipServer?.domain}:${_sipServer?.port}',
    };

    settings.webSocketUrl = _sipServer?.wss ?? "";
    //settings.webSocketSettings.extraHeaders = _wsExtraHeaders;
    settings.webSocketSettings.allowBadCertificate = true;
    //settings.webSocketSettings.userAgent = 'Dart/2.8 (dart:io) for OpenSIPS.';
    settings.uri = 'sip:$_username@${_sipServer?.domain}:${_sipServer?.port}';
    settings.webSocketSettings.extraHeaders = _wsExtraHeaders;
    settings.authorizationUser = _username;
    settings.password = _password;
    settings.displayName = _displayName;
    settings.userAgent = 'SIP Client';
    settings.dtmfMode = DtmfMode.RFC2833;
    pitelCall.register(settings);
    return true;
  }

  void setExtensionInfo(GetExtensionResponse extensionResponse) {
    _logger.info('sipServer ${extensionResponse.sipServer.toString()}');
    _sipServer = extensionResponse.sipServer;
    _username = extensionResponse.username;
    _password = extensionResponse.password;
    _displayName = extensionResponse.display_name;
    if (isTest) {
      _username = usernameTest;
      _password = passwordTest;
      _sipServer = SipServer(
          id: 0,
          domain: domainTest,
          port: portTest,
          outboundProxy: '',
          wss: wssTest,
          transport: 0,
          createdAt: '',
          project: '');
    }
    _logger.info('sipAccount ${extensionResponse.username} enabled');
  }

  Future<Either<bool, Error>> call(String dest, [bool voiceonly = true]) async {
    final String destSip =
        'sip:$dest@${_sipServer?.domain}:${_sipServer?.port}';
    if (destSip != _mySipUri) {
      try {
        final isCallSuccess = await pitelCall.call(dest, voiceonly);
        return left(isCallSuccess);
      } catch (err) {
        return right(PitelError(err.toString()));
      }
    } else {
      _logger.error('Cannot call because number is mine');
      return right(PitelError('Cannot call because number is mine'));
    }
  }

  release() {
    pitelCall.unregister();
  }

  Future<bool> login(String username, String password,
      {String? fcmToken}) async {
    _logger.info('login $username $password');
    final loginSuccess = await _login(username, password);
    _logger.info('login $loginSuccess');
    if (loginSuccess) {
      final getProfileSuccess = await _getProfile();
      _logger.info('login getProfileSuccess $getProfileSuccess');
      if (getProfileSuccess) {
        final getSipInfoSucces = await _getSipInfo();
        _logger.info('login getSipInfoSucces $getSipInfoSucces');
        if (getSipInfoSucces) {
          await _getExtensionInfo();
          return _registerSip(fcmToken: fcmToken);
        }
      }
    }
    if (isTest) {
      await _getExtensionInfo();
      return _registerSip(fcmToken: fcmToken);
    }
    return false;
  }

  Future<bool> _login(String username, String password) async {
    try {
      final tk = await _pitelApi.login(username: username, password: password);
      _token = tk;
      _logger.info('token - $_token');
      return true;
    } catch (err) {
      print(err);
      return false;
    }
  }

  Future<bool> _getProfile() async {
    try {
      final profile = await _pitelApi.getProfile(token: _token);
      profileUser = profile;
      // _logger.info('profile ${profileUser.toString()}');
      return true;
    } catch (err) {
      print(err);
      return false;
    }
  }

  Future<bool> _getSipInfo() async {
    try {
      final pitelToken = await _pitelApi.getSipInfo(
          token: _token,
          apiKey: PitelConfigure.API_KEY,
          sipUsername: profileUser.sipAccount.sipUserName);
      _pitelToken = pitelToken;
      _logger.info('pitelToken $_pitelToken');
      return true;
    } catch (err) {
      _logger.error(err);
      return false;
    }
  }

  Future<bool> _getExtensionInfo() async {
    try {
      final sipResponse = await _pitelApi.getExtensionInfo(
          pitelToken: _pitelToken,
          sipUsername: profileUser.sipAccount.sipUserName);
      if (sipResponse.enabled) {
        _logger.info('sipServer ${sipResponse.sipServer.toString()}');
        _sipServer = sipResponse.sipServer;
        _username = sipResponse.username;
        _password = sipResponse.password;
        _displayName = sipResponse.display_name;
        if (isTest) {
          _username = usernameTest;
          _password = passwordTest;
          _sipServer = SipServer(
              id: 0,
              domain: domainTest,
              port: portTest,
              outboundProxy: '',
              wss: wssTest,
              transport: 0,
              createdAt: '',
              project: '');
        }
        //_sipServer?.wss = "wss://sbc03.tel4vn.com:7444";
        _logger.info('sipAccount ${sipResponse.username} enabled');
        return true;
      } else {
        _logger.error('sipAccount ${sipResponse.username} not enabled');
        return false;
      }
    } catch (err) {
      _logger.error('_getExtensionInfo $err');
      if (isTest) {
        _username = usernameTest;
        _password = passwordTest;
        _sipServer = SipServer(
            id: 0,
            domain: domainTest,
            port: portTest,
            outboundProxy: '',
            wss: wssTest,
            transport: 0,
            createdAt: '',
            project: '');
        return true;
      }
      return false;
    }
  }

  String? get _mySipUri =>
      'sip:$_username@${_sipServer?.domain}:${_sipServer?.port}';
}
