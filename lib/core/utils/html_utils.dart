/// Utility class for parsing and cleaning HTML content from WordPress
class HtmlUtils {
  /// Extracts list items (<li>...</li>) from an HTML string
  /// and returns them as a list of plain strings.
  static List<String> extractListItems(String html) {
    if (html.isEmpty) return [];

    // Simple regex to match <li>...</li> content
    final regExp = RegExp(r'<li>(.*?)</li>', dotAll: true);
    final matches = regExp.allMatches(html);

    return matches.map((match) {
      // Get the inner text and strip any remaining internal HTML tags
      String text = match.group(1) ?? '';
      return stripHtmlTags(text).trim();
    }).where((text) => text.isNotEmpty).toList();
  }

  /// Removes all HTML tags from a string
  static String stripHtmlTags(String html) {
    if (html.isEmpty) return '';
    
    // Replace <br> and <p> with newlines before stripping
    String text = html.replaceAll(RegExp(r'<br\s*/?>|<p\s*/?>', caseSensitive: false), '\n');
    
    // Strip all other tags
    text = text.replaceAll(RegExp(r'<[^>]*>'), '');
    
    // Decode HTML entities (basic ones)
    return text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&nbsp;', ' ')
        .trim();
  }
}
