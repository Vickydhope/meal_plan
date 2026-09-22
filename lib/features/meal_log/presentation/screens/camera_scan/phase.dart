/// [CameraScanScreen]'s two states: live camera, and a captured photo
/// awaiting confirmation ("Use Photo").
enum CapturePhase { idle, captured }

/// [ScanResultScreen]'s states: ingredients streaming in, the settled
/// result ready for review/confirm, and analysis having stopped early or
/// failed outright (offers Retry instead of a dead "Stop Analyzing").
enum ScanPhase { analyzing, reviewing, error }
