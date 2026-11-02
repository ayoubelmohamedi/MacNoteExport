import Foundation

/// Converts Apple Notes HTML into clean Markdown and plain text
public enum HTMLToMarkdown {
    
    /// Converts Apple Notes HTML body into readable Markdown
    public static func convertToMarkdown(html: String) -> String {
        var text = html
        
        // Normalize line breaks
        text = text.replacingOccurrences(of: "\r\n", with: "\n")
        text = text.replacingOccurrences(of: "\r", with: "\n")
        
        // Remove style and script tags if present
        text = text.replacingOccurrences(of: "(?is)<style.*?</style>", with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: "(?is)<script.*?</script>", with: "", options: .regularExpression)
        
        // Headers
        text = text.replacingOccurrences(of: "(?i)<h1[^>]*>(.*?)</h1>", with: "\n# $1\n", options: .regularExpression)
        text = text.replacingOccurrences(of: "(?i)<h2[^>]*>(.*?)</h2>", with: "\n## $1\n", options: .regularExpression)
        text = text.replacingOccurrences(of: "(?i)<h3[^>]*>(.*?)</h3>", with: "\n### $1\n", options: .regularExpression)
        text = text.replacingOccurrences(of: "(?i)<h4[^>]*>(.*?)</h4>", with: "\n#### $1\n", options: .regularExpression)
        text = text.replacingOccurrences(of: "(?i)<h5[^>]*>(.*?)</h5>", with: "\n##### $1\n", options: .regularExpression)
        text = text.replacingOccurrences(of: "(?i)<h6[^>]*>(.*?)</h6>", with: "\n###### $1\n", options: .regularExpression)
        
        // Checkboxes in Apple Notes:
        // Checked: <input type="checkbox" checked... or checked class...
        text = text.replacingOccurrences(of: "(?i)<input[^>]*checked[^>]*>", with: "- [x] ", options: .regularExpression)
        text = text.replacingOccurrences(of: "(?i)<input[^>]*type=[\"']checkbox[\"'][^>]*>", with: "- [ ] ", options: .regularExpression)
        
        // Bold & Strong
        text = text.replacingOccurrences(of: "(?i)<(b|strong)[^>]*>(.*?)</\\1>", with: "**$2**", options: .regularExpression)
        
        // Italic & Em
        text = text.replacingOccurrences(of: "(?i)<(i|em)[^>]*>(.*?)</\\1>", with: "*$2*", options: .regularExpression)
        
        // Strikethrough
        text = text.replacingOccurrences(of: "(?i)<(s|strike|del)[^>]*>(.*?)</\\1>", with: "~~$2~~", options: .regularExpression)
        
        // Code / Pre
        text = text.replacingOccurrences(of: "(?i)<pre[^>]*><code[^>]*>(.*?)</code></pre>", with: "\n```\n$1\n```\n", options: .regularExpression)
        text = text.replacingOccurrences(of: "(?i)<code[^>]*>(.*?)</code>", with: "`$1`", options: .regularExpression)
        
        // Blockquotes
        text = text.replacingOccurrences(of: "(?i)<blockquote[^>]*>(.*?)</blockquote>", with: "\n> $1\n", options: .regularExpression)
        
        // Links: <a href="URL">TEXT</a> -> [TEXT](URL)
        text = text.replacingOccurrences(of: "(?i)<a[^>]*href=[\"']([^\"']+)[\"'][^>]*>(.*?)</a>", with: "[$2]($1)", options: .regularExpression)
        
        // Lists
        text = text.replacingOccurrences(of: "(?i)<li[^>]*>(.*?)</li>", with: "\n- $1", options: .regularExpression)
        text = text.replacingOccurrences(of: "(?i)</?(ul|ol)[^>]*>", with: "\n", options: .regularExpression)
        
        // Horizontal rule
        text = text.replacingOccurrences(of: "(?i)<hr[^>]*>", with: "\n---\n", options: .regularExpression)
        
        // Line breaks & divs
        text = text.replacingOccurrences(of: "(?i)<br[^>]*>", with: "\n", options: .regularExpression)
        text = text.replacingOccurrences(of: "(?i)<p[^>]*>", with: "\n", options: .regularExpression)
        text = text.replacingOccurrences(of: "(?i)</p>", with: "\n", options: .regularExpression)
        text = text.replacingOccurrences(of: "(?i)<div[^>]*>", with: "\n", options: .regularExpression)
        text = text.replacingOccurrences(of: "(?i)</div>", with: "", options: .regularExpression)
        
        // Strip remaining HTML tags
        text = text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        
        // Decode HTML entities
        text = decodeEntities(text)
        
        // Clean up excessive blank lines (more than 2 consecutive newlines)
        text = text.replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
        
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Converts HTML to clean plain text
    public static func convertToPlainText(html: String) -> String {
        var text = html
        
        text = text.replacingOccurrences(of: "(?is)<style.*?</style>", with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: "(?is)<script.*?</script>", with: "", options: .regularExpression)
        
        // Checkboxes to bullet text
        text = text.replacingOccurrences(of: "(?i)<input[^>]*checked[^>]*>", with: "[x] ", options: .regularExpression)
        text = text.replacingOccurrences(of: "(?i)<input[^>]*type=[\"']checkbox[\"'][^>]*>", with: "[ ] ", options: .regularExpression)
        
        // Line breaks
        text = text.replacingOccurrences(of: "(?i)<br[^>]*>", with: "\n", options: .regularExpression)
        text = text.replacingOccurrences(of: "(?i)<li[^>]*>", with: "\n• ", options: .regularExpression)
        text = text.replacingOccurrences(of: "(?i)<div[^>]*>", with: "\n", options: .regularExpression)
        text = text.replacingOccurrences(of: "(?i)<p[^>]*>", with: "\n\n", options: .regularExpression)
        
        // Strip all tags
        text = text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        
        // Decode entities
        text = decodeEntities(text)
        
        // Clean up excessive blank lines
        text = text.replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
        
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Decodes common HTML entities
    public static func decodeEntities(_ input: String) -> String {
        var str = input
        str = str.replacingOccurrences(of: "&amp;", with: "&")
        str = str.replacingOccurrences(of: "&lt;", with: "<")
        str = str.replacingOccurrences(of: "&gt;", with: ">")
        str = str.replacingOccurrences(of: "&quot;", with: "\"")
        str = str.replacingOccurrences(of: "&#39;", with: "'")
        str = str.replacingOccurrences(of: "&apos;", with: "'")
        str = str.replacingOccurrences(of: "&nbsp;", with: " ")
        str = str.replacingOccurrences(of: "&#160;", with: " ")
        str = str.replacingOccurrences(of: "&mdash;", with: "—")
        str = str.replacingOccurrences(of: "&ndash;", with: "–")
        return str
    }
}
