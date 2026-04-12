/// Utility class for parsing and cleaning HTML content from WordPress
class HtmlUtils {
  /// Extracts list items (<li>...</li>) from an HTML string
  /// and returns them as a list of plain strings.
  /// If no <li> tags found, splits by <br> or newlines.
  static List<String> extractListItems(String html) {
    if (html.isEmpty) return [];

    List<String> items = [];

    // 1. Try matching <li>...</li> content
    if (html.contains('<li')) {
      final regExp = RegExp(r'<li>(.*?)</li>', dotAll: true);
      final matches = regExp.allMatches(html);
      items = matches.map((match) => match.group(1) ?? '').toList();
    } 
    
    // 2. If no <li>, or as a combined approach, split by block tags and breaks
    if (items.isEmpty) {
      // Replace block tags with a consistent delimiter then split
      // We handle <p>, <br>, <div>, and <li> (if not already handled)
      String cleaned = html.replaceAll(RegExp(r'</?(p|br|div|li)\s*/?>', caseSensitive: false), '\n');
      items = cleaned.split('\n');
    }

    return items
        .map((text) => stripHtmlTags(text)) // Strip tags from each item
        .map((text) => _cleanPrefixes(text)) // Strip numbers like /1 or 1.
        .where((text) => text.trim().length > 2) // Filter out very short lines/empty
        .map((text) => text.trim())
        .toList();
  }

  /// Removes all HTML tags from a string
  static String stripHtmlTags(String html) {
    if (html.isEmpty) return '';
    
    // Replace <br> and <p> with spaces/newlines before stripping
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

  /// Internal helper to remove prefixes like "/1", "1.", "-", etc.
  static String _cleanPrefixes(String text) {
    if (text.isEmpty) return '';
    
    // Match common list prefixes: "/", "/1 ", "1. ", "1- ", "- ", etc.
    final prefixPattern = RegExp(r'^\s*([/\d\.\-\s]+)(.*)$');
    final match = prefixPattern.firstMatch(text);
    
    if (match != null) {
      final prefix = match.group(1) ?? '';
      final content = match.group(2) ?? '';
      
      // If the prefix actually looks like a numbering/delimiter prefix
      if (RegExp(r'[\d/\.\-]').hasMatch(prefix)) {
        return content.trim();
      }
    }
    
    return text.trim();
  }
}
