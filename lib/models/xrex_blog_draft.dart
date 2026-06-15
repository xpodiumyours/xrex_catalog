class XRexBlogSection {
  final String title;
  final String content;

  const XRexBlogSection({
    required this.title,
    required this.content,
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title.trim(),
      'content': content.trim(),
    };
  }

  factory XRexBlogSection.fromJson(Map<String, dynamic> json) {
    return XRexBlogSection(
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
    );
  }
}

class XRexBlogFaq {
  final String question;
  final String answer;

  const XRexBlogFaq({
    required this.question,
    required this.answer,
  });

  Map<String, dynamic> toJson() {
    return {
      'question': question.trim(),
      'answer': answer.trim(),
    };
  }

  factory XRexBlogFaq.fromJson(Map<String, dynamic> json) {
    return XRexBlogFaq(
      question: json['question'] as String? ?? '',
      answer: json['answer'] as String? ?? '',
    );
  }
}

class XRexBlogDraft {
  final String title;
  final String summary;
  final List<XRexBlogSection> sections;
  final List<XRexBlogFaq> faq;
  final String metaDescription;
  final List<String> keywords;
  final String suggestedStoreCategory;

  const XRexBlogDraft({
    required this.title,
    required this.summary,
    required this.sections,
    required this.faq,
    required this.metaDescription,
    required this.keywords,
    required this.suggestedStoreCategory,
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title.trim(),
      'summary': summary.trim(),
      'sections': sections.map((s) => s.toJson()).toList(),
      'faq': faq.map((f) => f.toJson()).toList(),
      'metaDescription': metaDescription.trim(),
      'keywords': keywords,
      'suggestedStoreCategory': suggestedStoreCategory.trim(),
    };
  }

  factory XRexBlogDraft.fromJson(Map<String, dynamic> json) {
    return XRexBlogDraft(
      title: json['title'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      sections: (json['sections'] as List<dynamic>?)
              ?.map((s) => XRexBlogSection.fromJson(s as Map<String, dynamic>))
              .toList() ??
          const [],
      faq: (json['faq'] as List<dynamic>?)
              ?.map((f) => XRexBlogFaq.fromJson(f as Map<String, dynamic>))
              .toList() ??
          const [],
      metaDescription: json['metaDescription'] as String? ?? '',
      keywords: (json['keywords'] as List<dynamic>?)
              ?.map((k) => k as String)
              .toList() ??
          const [],
      suggestedStoreCategory: json['suggestedStoreCategory'] as String? ?? '',
    );
  }
}
