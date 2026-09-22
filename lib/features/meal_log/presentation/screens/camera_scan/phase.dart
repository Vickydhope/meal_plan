/// [CameraScanScreen]'s two states: live camera, and a captured photo
/// awaiting confirmation ("Use Photo").
enum CapturePhase { idle, captured }

/// [ScanResultScreen]'s two states: ingredients streaming in, and the
/// settled result ready for review/confirm.
enum ScanPhase { analyzing, reviewing }
