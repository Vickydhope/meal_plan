/// The camera-scan screen's four states: live camera, a captured photo
/// awaiting "Analyze", ingredients streaming in, and the settled result
/// ready for review/confirm.
enum Phase { idle, captured, analyzing, reviewing }
