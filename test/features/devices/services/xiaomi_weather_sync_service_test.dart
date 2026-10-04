import 'dart:convert';
import 'dart:ui' show Locale;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/device/xiaomi/systems/info_system.dart';
import 'package:oronbox/src/features/devices/models/xiaomi_device_features.dart';
import 'package:oronbox/src/features/devices/services/xiaomi_air_quality.dart';
import 'package:oronbox/src/features/devices/services/xiaomi_weather_sync_service.dart';
import 'package:oronbox/src/device/xiaomi/protocol/generated/wear_common.pb.dart'
    as pb_common;

void main() {
  test('normalizes AQI labels for every supported app language', () {
    expect(
      XiaomiAirQualityNormalizer.normalize(
        aqi: 39,
        raw: 'Good',
        locale: const Locale('zh'),
      ),
      '优',
    );
    expect(
      XiaomiAirQualityNormalizer.normalize(
        aqi: 84,
        raw: 'Good',
        locale: const Locale('en'),
      ),
      'Moderate',
    );
    expect(
      XiaomiAirQualityNormalizer.normalize(
        aqi: null,
        raw: 'Unhealthy for sensitive groups',
        locale: const Locale('ja'),
      ),
      '敏感な人に影響',
    );
    expect(
      XiaomiAirQualityNormalizer.normalize(
        aqi: null,
        raw: 'unknown',
        locale: const Locale('ru'),
      ),
      isEmpty,
    );
  });

  test(
    'uses official Xiaomi weather request with raw device identity',
    () async {
      final dio = Dio();
      String? officialLocale;
      String? officialData;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path.contains('location/city/search')) {
              return handler.resolve(
                Response<dynamic>(
                  requestOptions: options,
                  data: [
                    {
                      'name': '万州区',
                      'affiliation': '重庆市, 中国',
                      'locationKey': 'weathercn:101041300',
                      'latitude': '30.46',
                      'longitude': '108.24',
                      'status': 0,
                    },
                  ],
                ),
              );
            }
            if (options.path.contains('get_weather_info_v3')) {
              final data = options.data;
              if (data is Map) {
                officialLocale = data['locale']?.toString();
                officialData = data['data']?.toString();
              }
              return handler.resolve(
                Response<dynamic>(
                  requestOptions: options,
                  data: {
                    'code': 0,
                    'message': 'ok',
                    'result': {
                      'locationKey': 'weathercn:101041300',
                      'location_name': '万州',
                      'affiliation': '重庆, 中国',
                      'pubTime': '2026-08-26T14:03:35+08:00',
                      'weather': '0',
                      'temperature': {'unit': '℃', 'value': '34'},
                      'humidity': {'unit': '%', 'value': '47'},
                      'pressure': {'unit': 'hPa', 'value': '945'},
                      'uvIndex': '7',
                      'wind': {
                        'direction': {'unit': '°', 'value': '44.0'},
                        'speed': {'unit': 'km/h', 'value': '5.0'},
                      },
                      'aqi': {'aqi': '39'},
                      'aqi_level': 'Good',
                      'daily_forecast': {},
                      'hourly_forecast': {},
                      'alerts': [],
                    },
                  },
                ),
              );
            }
            throw StateError('legacy Xiaomi endpoint must not be requested');
          },
        ),
      );

      final weather = await XiaomiWeatherSyncService(dio: dio)
          .fetch('万州', model: ' M2517W1 ', firmwareVersion: ' 3.112.035 ');
      final request = (jsonDecode(officialData!) as Map)
          .cast<String, Object?>();

      expect(officialLocale, 'zh_CN');
      expect(request['locationKey'], 'weathercn:101041300');
      expect(request['model'], 'M2517W1');
      expect(request['fw_ver'], '3.112.035');
      expect(weather.source, XiaomiWeatherSource.xiaomi);
      expect(weather.cityName, '万州区');
      expect(weather.locationName, '万州区');
      expect(weather.aqi, 39);
      expect(weather.aqiLevel, '优');
    },
  );

  test(
    'falls back to Open-Meteo when Xiaomi cannot resolve the city',
    () async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path.contains('weatherapi.market.xiaomi.com')) {
              return handler.resolve(
                Response<dynamic>(
                  requestOptions: options,
                  data: const <dynamic>[],
                ),
              );
            }
            if (options.path.contains('geocoding-api')) {
              return handler.resolve(
                Response<Map<String, dynamic>>(
                  requestOptions: options,
                  data: {
                    'results': [
                      {'name': 'Test City', 'latitude': 1.0, 'longitude': 2.0},
                    ],
                  },
                ),
              );
            }
            if (options.path.contains('air-quality-api')) {
              return handler.resolve(
                Response<Map<String, dynamic>>(
                  requestOptions: options,
                  data: {
                    'current': {'time': '2026-08-21T10:00', 'us_aqi': 84},
                  },
                ),
              );
            }
            return handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                data: {
                  'utc_offset_seconds': 8 * 60 * 60,
                  'current': {
                    'time': '2026-08-21T10:00',
                    'temperature_2m': 20,
                    'relative_humidity_2m': 50,
                    'weather_code': 0,
                    'wind_speed_10m': 5,
                    'wind_direction_10m': 90,
                    'uv_index': 1,
                    'surface_pressure': 1000,
                  },
                  'daily': {
                    'time': ['2026-08-21', '2026-08-22'],
                    'weather_code': [0, 3],
                    'temperature_2m_min': [10, null],
                    'temperature_2m_max': [20, 30],
                    'sunrise': ['2026-08-21T06:00', '2026-08-22T06:01'],
                    'sunset': ['2026-08-21T18:00', '2026-08-22T18:01'],
                  },
                  'hourly': {
                    'time': [
                      '2026-08-21T10:00',
                      '2026-08-21T11:00',
                      '2026-08-21T12:00',
                    ],
                    'weather_code': [0, null, 3],
                    'temperature_2m': [20, 99, 22],
                    'wind_speed_10m': [5, 6, 7],
                    'wind_direction_10m': [90, 100, 110],
                  },
                },
              ),
            );
          },
        ),
      );

      final weather = await XiaomiWeatherSyncService(dio: dio).fetch('Test');

      expect(weather.daily, hasLength(1));
      expect(weather.daily.single.date, '2026-08-21');
      expect(weather.daily.single.sunrise, '2026-08-21T06:00:00+08:00');
      expect(weather.publishedAt, '2026-08-21T10:00:00+08:00');
      expect(weather.aqi, 84);
      expect(weather.source, XiaomiWeatherSource.openMeteo);
      expect(weather.locationKey, startsWith('open-meteo:'));
      expect(weather.hourly.map((item) => item.time), [
        '2026-08-21T10:00',
        '2026-08-21T12:00',
      ]);
      expect(weather.hourly.last.temperature, 22);
      expect(weather.hourly.last.windDirection, 110);
    },
  );

  test('uses Xiaomi weather data before trying Open-Meteo', () async {
    final dio = Dio();
    Map<String, dynamic>? weatherQuery;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path.contains('location/city/search')) {
            return handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                data: [
                  {
                    'name': '万州区',
                    'affiliation': '重庆市, 中国',
                    'locationKey': 'weathercn:101271400',
                    'latitude': '30.8160',
                    'longitude': '108.3741',
                    'status': 0,
                  },
                ],
              ),
            );
          }
          if (options.path.contains('weather/all')) {
            weatherQuery = Map<String, dynamic>.from(options.queryParameters);
            return handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                data: {
                  'current': {
                    'pubTime': '2026-08-23T10:00:00',
                    'weather': '0',
                    'temperature': {'value': '28'},
                    'humidity': {'value': '80'},
                    'pressure': {'value': '995'},
                    'uvIndex': '3',
                    'wind': {
                      'direction': {'value': '90'},
                      'speed': {'value': '5'},
                    },
                  },
                  'aqi': {'aqi': '84'},
                  'aqi_level': '良',
                  'city_name': '重庆市',
                  'location_name': '重庆市，中国',
                  'alerts': [
                    {
                      'alertId': 'alert-1',
                      'type': 'rain',
                      'level': 'yellow',
                      'title': '暴雨预警',
                      'detail': '请注意防范',
                    },
                  ],
                  'indices': {
                    'uvIndex': {'level': '中等'},
                    'indices': [
                      {'type': 'uvIndex', 'value': '3'},
                    ],
                  },
                  'forecastDaily': {
                    'aqi': {
                      'value': [42],
                    },
                    'aqi_level': ['优'],
                    'sunRiseSet': {
                      'value': [
                        {
                          'from': '2026-08-23T06:17:00+08:00',
                          'to': '2026-08-23T19:21:00+08:00',
                        },
                      ],
                    },
                    'weather': {
                      'value': [
                        {'from': '0', 'to': '1'},
                      ],
                    },
                    'temperature': {
                      'value': [
                        {'from': '30', 'to': '24'},
                      ],
                    },
                  },
                  'forecastHourly': {
                    'aqi': {
                      'value': [84, 85],
                    },
                    'aqi_level': ['良', '良'],
                    'weather': {
                      'value': [0, 1],
                    },
                    'temperature': {
                      'pubTime': '2026-08-23T14:00:00',
                      'value': [28, 29],
                    },
                    'wind': {
                      'value': [
                        {'direction': '90', 'speed': '5'},
                        {'direction': '100', 'speed': '6'},
                      ],
                    },
                  },
                },
              ),
            );
          }
          throw StateError('Open-Meteo must not be requested');
        },
      ),
    );

    final weather = await XiaomiWeatherSyncService(dio: dio)
        .fetch('万州', model: ' M2517W1 ', firmwareVersion: ' 3.112.035 ');

    expect(weather.source, XiaomiWeatherSource.xiaomi);
    expect(weatherQuery?['model'], 'M2517W1');
    expect(weatherQuery?['fw_ver'], '3.112.035');
    expect(weather.locationKey, 'weathercn:101271400');
    expect(weather.cityName, '万州区');
    expect(weather.locationName, '万州区');
    expect(weather.publishedAt, '2026-08-23T10:00:00+08:00');
    expect(weather.temperature, 28);
    expect(weather.aqi, 84);
    expect(weather.aqiLevel, '良');
    expect(weather.uvIndexLevel, '中等');
    expect(weather.alerts.single.title, '暴雨预警');
    expect(weather.alerts.single.id, 'alert-1');
    expect(weather.daily.single.minimumTemperature, 24);
    expect(weather.daily.single.maximumTemperature, 30);
    expect(weather.daily.single.aqi, 42);
    expect(weather.daily.single.aqiLevel, '优');
    expect(weather.daily.single.weatherFrom, 0);
    expect(weather.daily.single.weatherTo, 1);
    expect(weather.daily.single.sunrise, '2026-08-23T06:17:00+08:00');
    expect(weather.daily.single.sunset, '2026-08-23T19:21:00+08:00');
    expect(weather.hourly, hasLength(2));
    expect(weather.hourly.first.aqi, 84);
    expect(weather.hourly.first.aqiLevel, '良');
    expect(weather.hourly.last.time, '2026-08-23T15:00:00+08:00');
  });

  test('encodes Xiaomi daily temperature range as maximum then minimum', () {
    final range = xiaomiDailyTemperatureRange(
      const XiaomiWeatherDay(
        conditionCode: 0,
        minimumTemperature: 12,
        maximumTemperature: 25,
      ),
    );

    expect(range.from, 25);
    expect(range.to, 12);
  });

  test(
    'encodes current and hourly values with Gadgetbridge field semantics',
    () {
      const weather = XiaomiWeatherData(
        locationKey: 'open-meteo:30.8160:108.3741',
        cityName: '万州',
        locationName: '万州',
        publishedAt: '2026-08-22T08:30:00+08:00',
        conditionCode: 0,
        temperature: 28,
        humidity: 80,
        windSpeedBeaufort: 2,
        windDirection: 52,
        uvIndex: 2,
        aqi: 84,
        aqiLevel: '良',
        uvIndexLevel: '中等',
        alerts: [
          XiaomiWeatherAlert(
            id: 'alert-1',
            type: 'rain',
            level: 'yellow',
            title: '暴雨预警',
            detail: '请注意防范',
          ),
        ],
        pressureHpa: 970,
        daily: [],
        hourly: [],
      );
      final id = buildXiaomiWeatherId(weather);
      final latest = buildXiaomiWeatherLatest(weather, id);
      final hourly = buildXiaomiHourlyWeatherEntry(
        const XiaomiWeatherHour(
          conditionCode: 1,
          temperature: 29,
          windSpeedBeaufort: 2,
          windDirection: 55,
        ),
      );

      expect(id.pubTime, '2026-08-22T08:30:00+08:00');
      expect(latest.temperature.key, '℃');
      expect(latest.temperature.value, 28);
      expect(latest.aqi.key, '良');
      expect(latest.aqi.value, 84);
      expect(latest.uvindex.key, '中等');
      expect(latest.alertsList.list.single.id, 'alert-1');
      expect(latest.windInfo.key, '52');
      expect(latest.windInfo.value, 2);
      expect(hourly.temperature.from, 0);
      expect(hourly.temperature.to, 29);
      expect(hourly.windInfo.key, '55');
      expect(hourly.windInfo.value, 2);
    },
  );

  test('encodes weather values as protobuf sint32 ZigZag integers', () {
    final one = pb_common.KeyValue(key: 'x', value: 1).writeToBuffer();
    final temperature = pb_common.KeyValue(key: 'x', value: 28).writeToBuffer();

    expect(one, [0x0a, 0x01, 0x78, 0x10, 0x02]);
    expect(temperature, [0x0a, 0x01, 0x78, 0x10, 0x38]);
  });
}
