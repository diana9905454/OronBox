import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/io.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/services.dart';

import 'package:dio/dio.dart';
import 'package:oronbox/src/device/xiaomi/esim/esim_activation_code.dart';
import 'package:fixnum/fixnum.dart';
import 'package:oronbox/src/core/logging/logging_service.dart';
import 'package:oronbox/src/device/xiaomi/protocol/generated/wear.pb.dart'
    as pb;
import 'package:oronbox/src/device/xiaomi/protocol/generated/wear_lpa.pb.dart'
    as pb_lpa;
import 'package:oronbox/src/device/xiaomi/systems/xiaomi_system.dart';

typedef XiaomiEsimProgressListener = void Function(int progress);

/// Handles the Xiaomi LPA control plane used by eSIM profile provisioning.
///
/// The phone does not implement carrier provisioning APIs here. It forwards a
/// user-supplied standard Activation Code to the watch, then serves as the
/// watch LPA's HTTPS bridge when the watch requests one.
class XiaomiLpaSystem extends XiaomiPbSystem {
  XiaomiLpaSystem({Dio? dio, this.onProgress})
    : _dio = dio ?? Dio(),
      _log = getLogger('XiaomiLpaSystem') {
    _tlsReady = _installGsmaTrust(_dio);
  }

  static const _requestTimeout = Duration(seconds: 30);

  /// GSMA Certificate Issuer roots used by SM-DP+/SM-DS (SGP.22).
  static const _gsmaTrustAssets = <String>[
    'assets/certs/gsma_live.pem',
    'assets/certs/gsma_china.pem',
  ];

  /// Debug escape hatch: accept any TLS certificate.
  ///
  /// Only active in debug builds, or when the app is built with
  /// `--dart-define=ORONBOX_LPA_TRUST_ALL=true`. Release builds verify the
  /// GSMA CI roots below.
  static const bool _forceTrustAllTls = bool.fromEnvironment(
    'ORONBOX_LPA_TRUST_ALL',
  );

  late final Future<void> _tlsReady;
  static const _maxResponseBytes = 4 * 1024 * 1024;

  final Dio _dio;
  final Logger _log;
  final XiaomiEsimProgressListener? onProgress;

  Future<void> downloadProfile(
    String activationCode, {
    String confirmationCode = '',
  }) async {
    final parsed = XiaomiEsimActivationCode.parse(activationCode);
    if (parsed == null) {
      throw const FormatException('Invalid eSIM Activation Code');
    }
    final code = parsed.value;
    await component.sendPbPacket(
      pb.WearPacket(
        type: pb.WearPacket_Type.LPA,
        id: pb_lpa.Lpa_LpaID.DOWNLOAD_PROFILE.value,
        lpa: pb_lpa.Lpa(
          profileDownload: pb_lpa.ProfileDownload(
            activationCode: code,
            confirmationCode: confirmationCode.trim(),
          ),
        ),
      ),
      waitForAck: true,
    );
    _log.info(
      '[${entity.id}] eSIM profile download requested '
      'activation_length=${code.length} confirmation_present=${confirmationCode.trim().isNotEmpty}',
    );
  }

  Future<List<pb_lpa.Profile>> fetchProfiles() async {
    final response = await component.requestPool.request<pb_lpa.Profile_List>(
      packet: pb.WearPacket(
        type: pb.WearPacket_Type.LPA,
        id: pb_lpa.Lpa_LpaID.GET_PROFILE_LIST.value,
        lpa: pb_lpa.Lpa(),
      ),
      typeMatcher: (packet) =>
          packet.whichPayload() == pb.WearPacket_Payload.lpa &&
          packet.id == pb_lpa.Lpa_LpaID.GET_PROFILE_LIST.value &&
          packet.lpa.hasProfileList(),
      responseMapper: (packet) => packet.lpa.profileList,
      timeout: const Duration(seconds: 10),
    );
    return List.unmodifiable(response.list);
  }

  @override
  void onWearPacket(pb.WearPacket packet) {
    if (packet.type != pb.WearPacket_Type.LPA || !packet.hasLpa()) return;
    _log.info(
      '[${entity.id}] LPA packet id=${packet.id} '
      'payload=${packet.lpa.whichPayload().name}',
    );

    if (packet.id == pb_lpa.Lpa_LpaID.REQUEST_HTTP.value &&
        packet.lpa.hasHttpRequest()) {
      unawaited(_handleHttpRequest(packet.lpa.httpRequest));
      return;
    }
    if (packet.id == pb_lpa.Lpa_LpaID.REPORT_DOWNLOAD_PROGRESS.value &&
        packet.lpa.hasDownloadResult()) {
      final progress = packet.lpa.downloadResult.progress;
      onProgress?.call(progress);
      _log.info('[${entity.id}] eSIM profile download progress=$progress');
    }
  }

  Future<void> _handleHttpRequest(pb_lpa.HttpRequest request) async {
    final uri = Uri.tryParse(request.url.trim());
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        (uri.hasPort && uri.port != 443)) {
      await _sendHttpResponse(xid: request.xid, statusCode: -1, result: '');
      _log.warning('[${entity.id}] rejected non-HTTPS LPA URL');
      return;
    }

    try {
      await _tlsReady;
      _log.info(
        '[${entity.id}] LPA euiccInfo1=${_euiccInfo1Of(request.payload)}',
      );
      _log.info(
        '[${entity.id}] LPA HTTP request started '
        'host=${uri.host} payload_length=${request.payload.length}',
      );
      final response = await _dio
          .post<ResponseBody>(
            uri.toString(),
            data: request.payload,
            options: Options(
              responseType: ResponseType.stream,
              contentType: Headers.jsonContentType,
              headers: const <String, Object>{
                'Accept': Headers.jsonContentType,
                'Content-Type': Headers.jsonContentType,
              },
              validateStatus: (_) => true,
              sendTimeout: _requestTimeout,
              receiveTimeout: _requestTimeout,
            ),
          )
          .timeout(_requestTimeout);
      final body = response.data == null
          ? ''
          : await _readResponseBody(response.data!.stream);
      _log.info(
        '[${entity.id}] LPA HTTP body: ${_summarizeLpaBody(body)}',
      );
      await _sendHttpResponse(
        xid: request.xid,
        statusCode: response.statusCode ?? -1,
        result: body,
      );
      _log.info(
        '[${entity.id}] LPA HTTP response received '
        'host=${uri.host} status=${response.statusCode ?? -1} '
        'body_length=${body.length}',
      );
    } catch (error) {
      final details = switch (error) {
        DioException(:final type, :final message, :final response) =>
          'dio_type=${type.name} message=${message ?? ""} '
              'response_status=${response?.statusCode ?? -1}',
        TimeoutException(:final message) => 'timeout message=${message ?? ""}',
        _ => 'error=$error',
      };
      _log.warning(
        '[${entity.id}] LPA HTTP request failed '
        'host=${uri.host} status=-1 $details',
      );
      await _sendHttpResponse(xid: request.xid, statusCode: -1, result: '');
    }
  }

  /// Extracts `euiccInfo1` (base64 DER) from an ES9+ request body.
  static String _euiccInfo1Of(String payload) {
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map) {
        final info = decoded['euiccInfo1'];
        if (info is String) return info;
      }
    } catch (_) {
      // Not JSON.
    }
    return '<unavailable>';
  }

  /// Condenses an SM-DP+/SM-DS JSON reply into the GSMA status fields.
  static String _summarizeLpaBody(String body) {
    if (body.isEmpty) return '<empty>';
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        final header = decoded['header'];
        if (header is Map) {
          final status = header['functionExecutionStatus'];
          if (status is Map) {
            final data = status['statusCodeData'];
            if (data is Map) {
              return 'status=${status['status']} '
                  'subject=${data['subjectCode']} '
                  'reason=${data['reasonCode']} '
                  'message=${data['message']}';
            }
            return 'status=${status['status']}';
          }
        }
        return 'keys=${decoded.keys.join(',')}';
      }
    } catch (_) {
      // Not JSON: fall through to the truncated raw body.
    }
    final flat = body.replaceAll('\n', ' ');
    return flat.length <= 240 ? flat : '${flat.substring(0, 240)}…';
  }

  Future<String> _readResponseBody(Stream<Uint8List> stream) async {
    final bytes = BytesBuilder(copy: false);
    var length = 0;
    await for (final chunk in stream) {
      length += chunk.length;
      if (length > _maxResponseBytes) {
        throw StateError('LPA HTTP response exceeds $_maxResponseBytes bytes');
      }
      bytes.add(chunk);
    }
    return utf8.decode(bytes.takeBytes(), allowMalformed: true);
  }

  /// Pins the GSMA CI roots instead of trusting every certificate.
  ///
  /// SM-DP+ endpoints are signed by GSMA Certificate Issuers which are
  /// not in the platform trust store (Redtea and 1GLOBAL both chain to
  /// "GSM Association - RSP2 Root CI1"). The watch delegates HTTPS to
  /// the phone, so this bridge validates the GSMA roots itself.
  static Future<void> _installGsmaTrust(Dio dio) async {
    if (kDebugMode || _forceTrustAllTls) {
      final insecure = HttpClient();
      insecure.badCertificateCallback = (_, _, _) => true;
      dio.httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () => insecure,
      );
      return;
    }
    final context = SecurityContext(withTrustedRoots: true);
    for (final asset in _gsmaTrustAssets) {
      final data = await rootBundle.load(asset);
      context.setTrustedCertificatesBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
    }
    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () => HttpClient(context: context),
    );
  }

  Future<void> _sendHttpResponse({
    required Int64 xid,
    required int statusCode,
    required String result,
  }) {
    _log.info(
      '[${entity.id}] LPA HTTP response xid=$xid '
      'status=$statusCode body_length=${result.length}',
    );
    return component.sendPbPacket(
      pb.WearPacket(
        type: pb.WearPacket_Type.LPA,
        id: pb_lpa.Lpa_LpaID.RESPONSE_HTTP.value,
        lpa: pb_lpa.Lpa(
          httpResponse: pb_lpa.HttpResponse(
            xid: xid,
            statusCode: statusCode,
            result: result,
          ),
        ),
      ),
    );
  }
}
