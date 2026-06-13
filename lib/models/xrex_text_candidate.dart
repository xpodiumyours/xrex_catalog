class XRexTextCandidate {
  final String id;
  final String label;
  final String value;
  final XRexTextCandidateType type;

  const XRexTextCandidate({
    required this.id,
    required this.label,
    required this.value,
    required this.type,
  });
}

enum XRexTextCandidateType { price, text }
