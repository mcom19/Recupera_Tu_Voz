// lib/services/face_framing_service.dart
//
// Encapsula Google ML Kit Face Detection para dar feedback de encuadre
// en tiempo real durante la captura de vídeo de lectura de labios.
//
// Por qué ML Kit y no MediaPipe puro: no existe un plugin oficial y
// mantenido de MediaPipe Face Landmarker para Flutter con el mismo
// nivel de madurez cross-platform (Android + iOS) que
// `google_mlkit_face_detection`. ML Kit expone contornos de labios
// (FaceContourType.upperLipTop/Bottom, lowerLipTop/Bottom) que cubren
// la misma necesidad — localizar la boca en tiempo real — sin
// depender de bindings nativos propios. Si en el futuro hace falta
// más resolución de landmarks (los 468 puntos de un face mesh
// completo), `google_mlkit_face_mesh_detection` es el sustituto
// directo de este servicio (misma idea, más puntos, hoy solo Android).
//
// Todo el cálculo de "¿está bien encuadrada la boca?" se hace en
// coordenadas de la imagen de la cámara (ratios 0..1), nunca en
// coordenadas de pantalla. Así el veredicto (bueno/muy cerca/muy
// lejos/descentrado) es fiable aunque el mapeo a píxeles de pantalla
// para dibujar el overlay no sea perfecto en todos los dispositivos.

import 'dart:io';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

enum FramingQuality {
  sinRostro, // no se detecta cara
  muyLejos, // boca demasiado pequeña en el encuadre
  muyCerca, // boca demasiado grande / cara pegada a la cámara
  descentrada, // boca fuera de la zona central
  buena, // encuadre correcto, se puede grabar
}

class FramingState {
  final FramingQuality quality;
  final Rect? mouthRectInImage; // coordenadas de la imagen de cámara (no de pantalla)
  final Size? imageSize;

  const FramingState({
    required this.quality,
    this.mouthRectInImage,
    this.imageSize,
  });

  static const inicial = FramingState(quality: FramingQuality.sinRostro);

  String get mensaje {
    switch (quality) {
      case FramingQuality.sinRostro:
        return 'Coloca tu cara frente a la cámara';
      case FramingQuality.muyLejos:
        return 'Acércate un poco más';
      case FramingQuality.muyCerca:
        return 'Aléjate un poco';
      case FramingQuality.descentrada:
        return 'Centra la boca en el óvalo';
      case FramingQuality.buena:
        return '¡Encuadre correcto! Mantén así';
    }
  }
}

class FaceFramingService {
  FaceFramingService()
      : _detector = FaceDetector(
          options: FaceDetectorOptions(
            enableContours: true,
            performanceMode: FaceDetectorMode.fast,
          ),
        );

  final FaceDetector _detector;
  bool _busy = false;

  // Umbrales de encuadre (ratio respecto al ancho de la imagen de cámara).
  // Ajustar tras probar en dispositivo real: son heurísticas de partida,
  // no valores medidos.
  static const double _minMouthWidthRatio = 0.09;
  static const double _maxMouthWidthRatio = 0.32;
  static const double _maxCenterOffsetRatio = 0.18;

  static const _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  /// Procesa un frame de la cámara y devuelve el estado de encuadre.
  /// Devuelve `null` si hay que descartar el frame (formato/rotación no
  /// soportados, o ya hay un frame en proceso).
  Future<FramingState?> processCameraImage({
    required CameraImage image,
    required CameraDescription camera,
    required DeviceOrientation deviceOrientation,
  }) async {
    if (_busy) return null;
    _busy = true;
    try {
      final inputImage = _inputImageFromCameraImage(
        image: image,
        camera: camera,
        deviceOrientation: deviceOrientation,
      );
      if (inputImage == null) return null;

      final faces = await _detector.processImage(inputImage);
      if (faces.isEmpty) {
        return const FramingState(quality: FramingQuality.sinRostro);
      }

      final face = faces.first;
      final mouthRect = _mouthRectFromFace(face);
      final imgSize = Size(image.width.toDouble(), image.height.toDouble());
      if (mouthRect == null) {
        return const FramingState(quality: FramingQuality.sinRostro);
      }

      final quality = _evaluateFraming(mouthRect, imgSize);
      return FramingState(
        quality: quality,
        mouthRectInImage: mouthRect,
        imageSize: imgSize,
      );
    } finally {
      _busy = false;
    }
  }

  Rect? _mouthRectFromFace(Face face) {
    final points = <Point<int>>[
      ...?face.contours[FaceContourType.upperLipTop]?.points,
      ...?face.contours[FaceContourType.upperLipBottom]?.points,
      ...?face.contours[FaceContourType.lowerLipTop]?.points,
      ...?face.contours[FaceContourType.lowerLipBottom]?.points,
    ];
    if (points.isEmpty) return null;

    var minX = points.first.x.toDouble();
    var maxX = points.first.x.toDouble();
    var minY = points.first.y.toDouble();
    var maxY = points.first.y.toDouble();
    for (final p in points) {
      minX = p.x < minX ? p.x.toDouble() : minX;
      maxX = p.x > maxX ? p.x.toDouble() : maxX;
      minY = p.y < minY ? p.y.toDouble() : minY;
      maxY = p.y > maxY ? p.y.toDouble() : maxY;
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  FramingQuality _evaluateFraming(Rect mouth, Size imageSize) {
    final widthRatio = mouth.width / imageSize.width;
    if (widthRatio < _minMouthWidthRatio) return FramingQuality.muyLejos;
    if (widthRatio > _maxMouthWidthRatio) return FramingQuality.muyCerca;

    final mouthCenter = mouth.center;
    final imageCenter = Offset(imageSize.width / 2, imageSize.height / 2);
    final dx = (mouthCenter.dx - imageCenter.dx).abs() / imageSize.width;
    final dy = (mouthCenter.dy - imageCenter.dy).abs() / imageSize.height;
    if (dx > _maxCenterOffsetRatio || dy > _maxCenterOffsetRatio) {
      return FramingQuality.descentrada;
    }
    return FramingQuality.buena;
  }

  /// Conversión CameraImage -> InputImage siguiendo el patrón oficial
  /// de google_ml_kit_flutter. Requiere que el CameraController se haya
  /// creado con `imageFormatGroup: ImageFormatGroup.nv21` en Android y
  /// `ImageFormatGroup.bgra8888` en iOS (ver lip_capture_prototype_screen.dart).
  InputImage? _inputImageFromCameraImage({
    required CameraImage image,
    required CameraDescription camera,
    required DeviceOrientation deviceOrientation,
  }) {
    final sensorOrientation = camera.sensorOrientation;
    InputImageRotation? rotation;

    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
      var rotationCompensation = _orientations[deviceOrientation];
      if (rotationCompensation == null) return null;
      if (camera.lensDirection == CameraLensDirection.front) {
        rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
      } else {
        rotationCompensation = (sensorOrientation - rotationCompensation + 360) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
    }
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;
    if (Platform.isAndroid && format != InputImageFormat.nv21) return null;
    if (Platform.isIOS && format != InputImageFormat.bgra8888) return null;
    if (image.planes.length != 1) return null;

    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  Future<void> dispose() async {
    await _detector.close();
  }
}
