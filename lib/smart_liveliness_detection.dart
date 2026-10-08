library;

import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:smart_liveliness_detection/src/controllers/liveness_controller.dart';
import 'package:smart_liveliness_detection/src/models/biometric_template.dart';
import 'package:smart_liveliness_detection/src/models/face_quality_result.dart';
import 'package:smart_liveliness_detection/src/utils/enums.dart';

// Configuration
export 'src/config/app_config.dart';
export 'src/config/depth_detection_config.dart';
export 'src/config/screen_flash_config.dart';
export 'src/config/template_config.dart';
// Models
export 'src/models/biometric_template.dart';
export 'src/models/depth_detection_result.dart';
export 'src/models/face_quality_result.dart';
export 'src/models/screen_flash_result.dart';
export 'src/config/messages_config.dart';
export 'src/config/theme_config.dart';
export 'src/config/challenge_hint_config.dart';
export 'src/config/voice_guidance_config.dart';
// Controllers
export 'src/controllers/liveness_controller.dart';
// Models (continued)
export 'src/models/challenge.dart';
export 'src/models/liveness_session.dart';
// Utilities
export 'src/utils/biometric_matcher.dart';
export 'src/utils/constants.dart';
export 'src/utils/enums.dart';
export 'src/utils/math_utils.dart';

// Main widget
export 'src/widgets/liveliness_detection_screen.dart';

// Callback types
typedef LivenessCompletedCallback = void Function(String sessionId, bool isSuccessful, Map<String, dynamic>? metadata);
typedef ChallengeCompletedCallback = void Function(ChallengeType challengeType);
typedef FinalImageCapturedCallback = void Function(String sessionId, XFile imageFile, Map<String, dynamic> metadata);

typedef FaceDetectedCallback = void Function(ChallengeType challengeType, bool firstChallengePassed, CameraImage image, List<Face> faces, CameraDescription camera);
typedef FaceNotDetectedCallback = void Function(ChallengeType challengeType, LivenessController controller);
typedef FaceQualityCallback = void Function(FaceQualityResult result);
typedef BiometricTemplateCallback = void Function(BiometricTemplate template);
