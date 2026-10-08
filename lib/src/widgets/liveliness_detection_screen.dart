import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:provider/provider.dart';
import 'package:smart_liveliness_detection/smart_liveliness_detection.dart';
import 'package:smart_liveliness_detection/src/widgets/instruction_overlay.dart';
import 'package:smart_liveliness_detection/src/widgets/liveness_progress_bar.dart';
import 'package:smart_liveliness_detection/src/widgets/status_indicator.dart';
import 'package:smart_liveliness_detection/src/widgets/success_overlay.dart';
import 'package:smart_liveliness_detection/src/widgets/challenge_hint_widget.dart';

/// Callback type for when a challenge is completed
typedef ChallengeCompletedCallback = void Function(ChallengeType challengeType);

/// Callback type for when liveness verification is completed
typedef LivenessCompletedCallback = void Function(
    String sessionId, bool isSuccessful, Map<String, dynamic> data);

/// Callback type for when final image is captured with metadata
typedef FinalImageCapturedCallback = void Function(
    String sessionId, XFile imageFile, Map<String, dynamic> metadata);

/// Callback type for when face is detected
typedef FaceDetectedCallback = void Function(
    ChallengeType challengeType,
    bool firstChallengePassed,
    CameraImage image,
    List<Face> faces,
    CameraDescription camera);

/// Callback type for when face is NOT detected
typedef FaceNotDetectedCallback = void Function(
    ChallengeType challengeType, LivenessController controller);

/// Callback type for face quality scoring results
typedef FaceQualityCallback = void Function(FaceQualityResult result);

// ---------------------------------------------------------------------------
// Main screen widget
// ---------------------------------------------------------------------------

/// Main widget for liveness detection
class LivenessDetectionScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  final LivenessConfig? config;
  final LivenessTheme? theme;
  final ChallengeCompletedCallback? onChallengeCompleted;
  final LivenessCompletedCallback? onLivenessCompleted;
  final FaceDetectedCallback? onFaceDetected;
  final FaceNotDetectedCallback? onFaceNotDetected;
  final FaceQualityCallback? onFaceQualityCheck;
  final BiometricTemplateCallback? onBiometricTemplateGenerated;
  final bool showAppBar;
  final PreferredSizeWidget? customAppBar;
  final Widget? customSuccessOverlay;
  final bool showStatusIndicators;
  final bool showCaptureImageButton;
  final Function(String sessionId, XFile imageFile)? onManualImageCaptured;
  final String? captureButtonText;
  final bool useColorProgress;
  final bool captureFinalImage;
  final FinalImageCapturedCallback? onFinalImageCaptured;

  const LivenessDetectionScreen({
    super.key,
    required this.cameras,
    this.config,
    this.theme,
    this.onChallengeCompleted,
    this.onLivenessCompleted,
    this.showAppBar = true,
    this.customAppBar,
    this.customSuccessOverlay,
    this.showStatusIndicators = true,
    this.showCaptureImageButton = false,
    this.onManualImageCaptured,
    this.captureButtonText,
    this.useColorProgress = true,
    this.captureFinalImage = false,
    this.onFinalImageCaptured,
    this.onFaceDetected,
    this.onFaceNotDetected,
    this.onFaceQualityCheck,
    this.onBiometricTemplateGenerated,
  });

  @override
  State<LivenessDetectionScreen> createState() =>
      _LivenessDetectionScreenState();
}

class _LivenessDetectionScreenState extends State<LivenessDetectionScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  late LivenessController _controller;
  XFile? _finalImage;
  late double _zoomFactor;

  void _resetZoomFactor() {
    setState(() {
      _zoomFactor = widget.config?.initialZoomFactor ?? 1.0;
    });
  }

  void _syncZoomFactor() {
    final z = _controller.zoomFactor;
    if (z != _zoomFactor) setState(() => _zoomFactor = z);
  }

  LivenessController _buildController() => LivenessController(
        cameras: widget.cameras,
        vsync: this,
        config: widget.config,
        theme: widget.theme,
        onChallengeCompleted: widget.onChallengeCompleted,
        onLivenessCompleted: widget.onLivenessCompleted != null
            ? (id, ok, data) => widget.onLivenessCompleted!(id, ok, data!)
            : null,
        onFinalImageCaptured: _handleFinalImageCaptured,
        captureFinalImage: widget.captureFinalImage,
        onFaceDetected: widget.onFaceDetected,
        onFaceNotDetected: widget.onFaceNotDetected,
        onFaceQualityCheck: widget.onFaceQualityCheck,
        onBiometricTemplateGenerated: widget.onBiometricTemplateGenerated,
        onReset: _resetZoomFactor,
      );

  @override
  void initState() {
    super.initState();
    _resetZoomFactor();
    _controller = _buildController();
    WidgetsBinding.instance.addObserver(this);
  }

  void _handleFinalImageCaptured(
      String sessionId, XFile imageFile, Map<String, dynamic> metadata) {
    setState(() => _finalImage = imageFile);
    widget.onFinalImageCaptured?.call(sessionId, imageFile, metadata);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _controller.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _controller = _buildController();
      _controller.addListener(_syncZoomFactor);
      setState(() => _finalImage = null);
    }
  }

  Future<void> _handleManualCapture(String sessionId) async {
    final imageFile = await _controller.captureImage();
    if (imageFile != null) {
      widget.onManualImageCaptured?.call(sessionId, imageFile);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _controller,
      child: Builder(builder: (context) {
        Widget? successOverlay = widget.customSuccessOverlay;
        if (successOverlay == null &&
            _finalImage != null &&
            widget.captureFinalImage) {
          successOverlay = _buildSuccessWithImage(context);
        }

        final flashColor =
            context.watch<LivenessController>().activeFlashColor;

        return Stack(
          children: [
            LivenessDetectionView(
              initializingMessage:
                  widget.config?.messages.initializingCamera,
              showAppBar: widget.showAppBar,
              customAppBar: widget.customAppBar,
              customSuccessOverlay: successOverlay,
              showStatusIndicators: widget.showStatusIndicators,
              showCaptureImageButton: widget.showCaptureImageButton,
              onImageCaptured: _handleManualCapture,
              captureButtonText: widget.captureButtonText,
              useColorProgress: widget.useColorProgress,
            ),
            if (flashColor != null)
              Positioned.fill(
                child: IgnorePointer(
                  child:
                      ColoredBox(color: flashColor.withValues(alpha: 0.85)),
                ),
              ),
          ],
        );
      }),
    );
  }

  Widget _buildSuccessWithImage(BuildContext context) {
    final controller = Provider.of<LivenessController>(context);
    final theme = controller.theme;
    if (_finalImage == null) return const SizedBox.shrink();

    return Stack(
      children: [
        SuccessOverlay(
          sessionId: controller.sessionId,
          onReset: controller.resetSession,
          theme: theme,
          isSuccessful: controller.isVerificationSuccessful,
          showCaptureImageButton: widget.showCaptureImageButton,
          captureButtonText: widget.captureButtonText,
          onCaptureImage:
              widget.showCaptureImageButton ? _handleManualCapture : null,
        ),
        Positioned(
          bottom: 120,
          left: 0,
          right: 0,
          child: Column(
            children: [
              const Text(
                'Verification Image Captured',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.successColor, width: 2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Image.file(
                    File(_finalImage!.path),
                    height: 120,
                    width: 120,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// View widget
// ---------------------------------------------------------------------------

class LivenessDetectionView extends StatelessWidget {
  final bool showAppBar;
  final PreferredSizeWidget? customAppBar;
  final Widget? customSuccessOverlay;
  final bool showStatusIndicators;
  final bool showCaptureImageButton;
  final Function(String sessionId)? onImageCaptured;
  final String? captureButtonText;
  final bool useColorProgress;
  final String? initializingMessage;

  const LivenessDetectionView({
    super.key,
    this.showAppBar = true,
    this.customAppBar,
    this.customSuccessOverlay,
    this.showStatusIndicators = true,
    this.showCaptureImageButton = false,
    this.onImageCaptured,
    this.captureButtonText,
    this.useColorProgress = true,
    this.initializingMessage = 'Initializing camera...',
  });

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<LivenessController>(context);
    final theme = controller.theme;

    if (!controller.isInitialized) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator.adaptive(
                  backgroundColor: theme.primaryColor),
              const SizedBox(height: 20),
              Text(
                initializingMessage!,
                style: TextStyle(
                    fontSize: 16, color: theme.statusTextStyle.color),
              ),
            ],
          ),
        ),
      );
    }

    final appBar = showAppBar
        ? customAppBar ??
            AppBar(
              title: const Text('Face Liveness Detection'),
              backgroundColor: theme.appBarBackgroundColor,
              foregroundColor: theme.appBarTextColor,
              elevation: 0,
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: controller.resetSession,
                ),
              ],
            )
        : null;

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: appBar,
      body: SafeArea(
        child: Stack(
          children: [
            _LivenessBody(
              controller: controller,
              theme: theme,
              showStatusIndicators: showStatusIndicators,
              useColorProgress: useColorProgress,
              showAppBar: showAppBar,
            ),
            if (controller.currentState == LivenessState.completed)
              customSuccessOverlay ??
                  SuccessOverlay(
                    sessionId: controller.sessionId,
                    onReset: controller.resetSession,
                    theme: theme,
                    isSuccessful: controller.isVerificationSuccessful,
                    showCaptureImageButton: showCaptureImageButton,
                    captureButtonText: captureButtonText,
                    onCaptureImage: showCaptureImageButton
                        ? (id) async => onImageCaptured?.call(id)
                        : null,
                  ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Body: column layout (camera circle + text below)
// ---------------------------------------------------------------------------

class _LivenessBody extends StatelessWidget {
  final LivenessController controller;
  final LivenessTheme theme;
  final bool showStatusIndicators;
  final bool useColorProgress;
  final bool showAppBar;

  const _LivenessBody({
    required this.controller,
    required this.theme,
    required this.showStatusIndicators,
    required this.useColorProgress,
    required this.showAppBar,
  });

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;

    // Camera circle diameter: full screen width so it fills horizontally
    final circleDiameter = screenWidth;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // ── Circular camera preview ─────────────────────────────────────────
        SizedBox(
          width: circleDiameter,
          height: circleDiameter,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Camera feed clipped to a circle
              ClipOval(
                child: _CameraPreview(controller: controller),
              ),

              // Oval border overlay drawn on top of camera — no dark fill
              CustomPaint(
                painter: _CircleBorderPainter(
                  isFaceDetected: controller.isFaceDetected,
                  progress: useColorProgress ? controller.progress : 0.0,
                  config: controller.config,
                  theme: theme,
                  zoomFactor: controller.zoomFactor,
                ),
              ),

              // Status pills inside the camera circle
              if (showStatusIndicators) ...[
                Positioned(
                  top: 20,
                  left: 20,
                  child: StatusIndicator.lighting(
                    isActive: controller.isLightingGood,
                    theme: theme,
                  ),
                ),
                Positioned(
                  top: 20,
                  right: 20,
                  child: StatusIndicator.faceDetection(
                    isActive: controller.isFaceDetected,
                    theme: theme,
                  ),
                ),
              ],

              // Challenge hints inside the camera area
              if (controller.currentState ==
                      LivenessState.performingChallenges &&
                  controller.session.currentChallenge != null)
                _buildChallengeHint(context, controller, mediaQuery),
            ],
          ),
        ),

        // ── Instruction / status message below camera ───────────────────────
        const SizedBox(height: 20),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: AnimatedStatusMessage(
            message: controller.statusMessage,
            theme: theme,
          ),
        ),

        // Face centering guidance
        if (controller.currentState == LivenessState.centeringFace) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              controller.faceCenteringMessage,
              style: theme.guidanceTextStyle,
              textAlign: TextAlign.center,
            ),
          ),
        ],

        // Progress bar (only when color-progress is disabled)
        if (!useColorProgress) ...[
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: LivenessProgressBar(progress: controller.progress),
          ),
        ],
      ],
    );
  }

  Widget _buildChallengeHint(BuildContext context, LivenessController controller,
      MediaQueryData mediaQuery) {
    final config = controller.config;
    final currentChallenge = controller.session.currentChallenge!;
    final hintConfig = config.challengeHints?[currentChallenge.type] ??
        config.defaultChallengeHintConfig;

    if (hintConfig == null || !hintConfig.enabled) {
      return const SizedBox.shrink();
    }

    return hintConfig.position.positionWidget(
      ChallengeHintWidget(
        challengeType: currentChallenge.type,
        config: hintConfig,
        key: ValueKey('hint_${currentChallenge.type}'),
      ),
      mediaQuery,
      showAppBar: showAppBar,
    );
  }
}

// ---------------------------------------------------------------------------
// Camera preview (fills its parent via FittedBox.cover)
// ---------------------------------------------------------------------------

class _CameraPreview extends StatelessWidget {
  final LivenessController controller;
  const _CameraPreview({required this.controller});

  @override
  Widget build(BuildContext context) {
    if (controller.isInitialized && controller.cameraController != null) {
      final preview = controller.cameraController!.value.previewSize;
      return FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          // previewSize is rotated: height = native width, width = native height
          width: preview!.height,
          height: preview.width,
          child: CameraPreview(controller.cameraController!),
        ),
      );
    }
    return const Center(child: CircularProgressIndicator.adaptive());
  }
}

// ---------------------------------------------------------------------------
// Painter: draws only the oval/circle border + progress arc, no dark fill
// ---------------------------------------------------------------------------

class _CircleBorderPainter extends CustomPainter {
  final bool isFaceDetected;
  final double progress;
  final LivenessConfig config;
  final LivenessTheme theme;
  final double zoomFactor;

  const _CircleBorderPainter({
    required this.isFaceDetected,
    required this.progress,
    required this.config,
    required this.theme,
    required this.zoomFactor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Scale the oval the same way OvalColorProgressPainter does
    final ovalHeight = size.height * config.ovalHeightRatio;
    final ovalWidth = ovalHeight * config.ovalWidthRatio;
    const double initialScale = 0.7;
    final double scale =
        initialScale + (1.0 - initialScale) * zoomFactor;

    final ovalRect = Rect.fromCenter(
      center: center,
      width: ovalWidth * scale,
      height: ovalHeight * scale,
    );

    // Choose border color
    final Color borderColor = isFaceDetected
        ? Color.lerp(theme.primaryColor, theme.successColor, progress) ??
            theme.primaryColor
        : theme.ovalGuideColor;

    // Draw oval border only (no fill / no dark overlay)
    canvas.drawOval(
      ovalRect,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = config.strokeWidth,
    );

    // Draw progress arc outside the oval
    if (progress > 0 && isFaceDetected) {
      canvas.drawArc(
        ovalRect.inflate(5.0),
        -math.pi / 2,
        progress * math.pi * 2,
        false,
        Paint()
          ..color = theme.successColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = config.strokeWidth / 2
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_CircleBorderPainter old) =>
      old.isFaceDetected != isFaceDetected ||
      old.progress != progress ||
      old.zoomFactor != zoomFactor;
}
