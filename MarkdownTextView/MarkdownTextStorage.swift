//
//  NSAttributedStringMarkdownExtension.swift
//  MarkdownTextView
//
//  Created by Jesper Christensen on 04/04/15.
//  Copyright (c) 2015 Jesper Christensen. All rights reserved.
//
// Notes
// See http://www.unicode.org/standard/reports/tr13/tr13-5.html on the distinction between line separator \u{2028} and paragraph separator \u{2029}.
//
// Image vertical align: https://discussions.apple.com/thread/2788687?start=0&tstart=0
// http://stackoverflow.com/questions/25301404/ios-nstextattachment-image-not-showing/28319519#28319519
//
// Dynamic load image: http://stackoverflow.com/questions/25766562/showing-image-from-url-with-placeholder-in-uitextview-with-attributed-string

import Foundation
import UIKit

let MarkdownTextAttachmentChangedNotification = "MarkdownTextAttachmentChangedNotification"

public enum MarkdownStylesName {
    case Normal
    case Bold
    case Italic
    case Monospace
    case Quote
    case Headline
    case Subheadline
    case Subsubheadline
    case Subsubsubheadline
}

public typealias StylesDict = [MarkdownStylesName: [String:AnyObject]]

public class MarkdownTextStorage : NSTextStorage
{
    private var styles: StylesDict
    private let bulletIndent: CGFloat = 20.0
    private let bulletTextIndent: CGFloat = 25.0

    private var attributedStringBackend: NSMutableAttributedString!
    
    override public var string: String {
        return attributedStringBackend.string
    }
    
    override public func attributesAtIndex(location: Int, effectiveRange range: NSRangePointer) -> [String : AnyObject] {
        return attributedStringBackend.attributesAtIndex(location, effectiveRange: range) ?? [String: AnyObject]()
    }
    
    override public func replaceCharactersInRange(range: NSRange, withString str: String) {
        if let attributedStringBackend = attributedStringBackend {
            attributedStringBackend.replaceCharactersInRange(range, withString: str)
            let delta = (str as NSString).length - range.length
            edited(NSTextStorageEditActions.EditedCharacters, range: range, changeInLength: delta)
        }
    }

    override public func setAttributes(attrs: [String : AnyObject]?, range: NSRange) {
        attributedStringBackend?.setAttributes(attrs, range: range)
        edited(NSTextStorageEditActions.EditedAttributes, range: range, changeInLength: 0)
    }
    
    static private let headerLineExtractRegExp = try! NSRegularExpression(pattern: "^(#+)\\s*(.*?)\\s*#*\\s*$", options: [])
    static private let blankLineMatchRegExp = try! NSRegularExpression(pattern: "^\\s*$", options: [])
    static private let orderedListLineMatchRegExp = try! NSRegularExpression(pattern: "^\\d+\\.\\s", options: [])
    static private let orderedListLineExtractRegExp = try! NSRegularExpression(pattern: "^\\d+\\.\\s*(.*)", options: [])
    static private let unorderedListLineMatchRegExp = try! NSRegularExpression(pattern: "^[\\*\\+\\-]\\s", options: [])
    static private let unorderedListLineExtractRegExp = try! NSRegularExpression(pattern: "^[\\*\\+\\-]\\s*(.*)", options: [])
    static private let checkedListLineMatchRegExp = try! NSRegularExpression(pattern: "^- \\[[\\sxX]\\]\\s", options: [])
    static private let checkedListLineExtractRegExp = try! NSRegularExpression(pattern: "^- \\[([\\sxX])\\]\\s*(.*)", options: [])
    static private let quoteLineMatchRegExp = try! NSRegularExpression(pattern: "^(>+)\\s*(.*?)\\s*?$", options: .CaseInsensitive)
    static private let quoteLineExtractRegExp = try! NSRegularExpression(pattern: "^(>+)\\s*(.*?)\\s*?$", options: .CaseInsensitive)
    static private let boldMatchRegExp = try! NSRegularExpression(pattern: "(\\*\\*|__)(.*?)\\1", options: [])
    static private let italicMatchRegExp = try! NSRegularExpression(pattern: "(^|[\\W_/])(?:(?!\\1)|(?=^))(\\*|_)(?=\\S)((?:(?!\\2).)*?\\S)\\2(?!\\2)(?=[\\W_]|$)", options: [])
    static private let monospaceMatchRegExp = try! NSRegularExpression(pattern: "`(.*?)`", options: [])
    static private let htmlCommentMatchRegExp = try! NSRegularExpression(pattern: "<!--.*?-->", options: [])
    static private let strikethroughMatchRegExp = try! NSRegularExpression(pattern: "~~(.*?)~~", options: [])
    static private let linkMatchRegExp =  try! NSRegularExpression(pattern: "\\[(.*?)\\]\\(\\s*<?\\s*(\\S*?)\\s*>?\\s*\\)", options: [])
    
    static private let rawLinkMatchRegExp: NSRegularExpression = {
        let charsInsideURL = "[-A-Z0-9+&@#/%?=~_|\\[\\]\\(\\)!:,\\.;\u{1a}]"
        let charEndingURL = "[-A-Z0-9+&@#/%=~_|\\[\\])]"
        return try! NSRegularExpression(pattern: "([^(\\[<]|^)<?(https?://\(charsInsideURL)*\(charEndingURL))>?", options: .CaseInsensitive)
    }()
    static private let issueLinkMatchRegExp =  try! NSRegularExpression(pattern: "([^\\/\\[\\w]|^)#(\\d+)(\\W|$)", options: [])
    static private let commitLinkMatchRegExp =  try! NSRegularExpression(pattern: "([^\\/\\[\\w]|^)([0-9a-fA-F]{7,40})(\\W|$)", options: [])
    static private let imageMatchRegExp = try! NSRegularExpression(pattern: "\\!\\[(.*?)\\]\\(\\s*<?\\s*(\\S*?)\\s*>?\\s*\\)", options: [])
    static private let doubleSpaceRegExp = try! NSRegularExpression(pattern: "\\s{2,}", options: [])

    static private var escapeTable = [String:String]() // \[ -> \u{1A}6\u{1A}
    static private var invertedEscapeTable = [String:String]() // \u{1A}6\u{1A} -> [
    static private var invertedEscapesRegExp: NSRegularExpression!
    static private var escapesRegExp: NSRegularExpression = {
        var escapesPatternParts = [String]()
        var invertedEscapesPatternParts = [String]()
        for (index, c) in "\\`*_{}[]()>#+-.!/&".characters.enumerate() {
            let key = String(c)
            let replacement = "\u{1A}" + String(index) + "\u{1A}"
            escapeTable["\\" + key] = replacement
            invertedEscapeTable[replacement] = key
            escapesPatternParts.append(NSRegularExpression.escapedPatternForString("\\" + key))
            invertedEscapesPatternParts.append(NSRegularExpression.escapedPatternForString(replacement))
        }
        let invertedEscapePattern = "(" + invertedEscapesPatternParts.joinWithSeparator("|") + ")"
        // Build (\]|\[|...) but properly escaped ofcourse
        let escapePattern = "(" + escapesPatternParts.joinWithSeparator("|") + ")"
        invertedEscapesRegExp = try! NSRegularExpression(pattern: invertedEscapePattern, options: [])
        return try! NSRegularExpression(pattern: escapePattern, options: [])
    }()
    static private var HTMLEntititesEscapeTable = [String:Int]() // "aring" -> 229
    static private var HTMLEntitiesRegExp: NSRegularExpression = {
        var escapesPatternParts = [String]()
        var invertedEscapesPatternParts = [String]()
        for item in HTMLEscapeMap {
            let pattern = item[0] as! String
            let unicodeValue = item[1] as! Int
            escapesPatternParts.append(pattern)
            HTMLEntititesEscapeTable[pattern] = unicodeValue
        }
        // Build &(aring|mdash|bullet|copy|...);
        let escapePattern = "&(" + escapesPatternParts.joinWithSeparator("|") + ");"
        return try! NSRegularExpression(pattern: escapePattern, options: [])
    }()
    static private var EmojiSynonymsRegExp: NSRegularExpression = {
        var escapesPatternParts = [String]()
        var invertedEscapesPatternParts = [String]()
        for (synonym, emoji) in EmojiSynonymMap {
            escapesPatternParts.append(NSRegularExpression.escapedPatternForString(synonym))
        }
        // Build :(happy|mad|apple|\\+1|...):
        let escapePattern = ":(" + escapesPatternParts.joinWithSeparator("|") + "):"
        return try! NSRegularExpression(pattern: escapePattern, options: [])
        }()
    
    func formatBoldParts(line: NSAttributedString) -> NSAttributedString {
        var done = false
        let mutable = NSMutableAttributedString(attributedString: line)
        while !done {
            let range = NSMakeRange(0, mutable.length)
            if let match = MarkdownTextStorage.boldMatchRegExp.firstMatchInString(mutable.string as String, options: NSMatchingOptions(), range: range) {
                let italicPart = NSMutableAttributedString(attributedString: mutable.attributedSubstringFromRange(match.rangeAtIndex(2)))
                italicPart.addAttributes(styles[.Bold]!, range: NSMakeRange(0, italicPart.length))
                mutable.replaceCharactersInRange(match.range, withAttributedString: italicPart)
            } else {
                done = true
            }
        }
        return mutable
    }
    
    func formatItalicParts(line: NSAttributedString) -> NSAttributedString {
        var done = false
        let mutable = NSMutableAttributedString(attributedString: line)
        while !done {
            let range = NSMakeRange(0, mutable.length)
            if let match = MarkdownTextStorage.italicMatchRegExp.firstMatchInString(mutable.string as String, options: NSMatchingOptions(), range: range) {
                let italicPart = NSMutableAttributedString(attributedString: mutable.attributedSubstringFromRange(match.rangeAtIndex(1)))
                italicPart.appendAttributedString(mutable.attributedSubstringFromRange(match.rangeAtIndex(3)))
                italicPart.addAttributes(styles[.Italic]!, range: NSMakeRange(0, italicPart.length))
                mutable.replaceCharactersInRange(match.range, withAttributedString: italicPart)
            } else {
                done = true
            }
        }
        return mutable
    }
    
    func formatMonospaceParts(line: NSAttributedString) -> NSAttributedString {
        var done = false
        let mutable = NSMutableAttributedString(attributedString: line)
        while !done {
            let range = NSMakeRange(0, mutable.length)
            if let match = MarkdownTextStorage.monospaceMatchRegExp.firstMatchInString(mutable.string as String, options: NSMatchingOptions(), range: range) {
                let italicPart = NSMutableAttributedString(attributedString: mutable.attributedSubstringFromRange(match.rangeAtIndex(1)))
                italicPart.addAttributes(styles[.Monospace]!, range: NSMakeRange(0, italicPart.length))
                mutable.replaceCharactersInRange(match.range, withAttributedString: italicPart)
            } else {
                done = true
            }
        }
        return mutable
    }
    
    func formatStrikethroughParts(line: NSAttributedString) -> NSAttributedString {
        var done = false
        let mutable = NSMutableAttributedString(attributedString: line)
        while !done {
            let range = NSMakeRange(0, mutable.length)
            if let match = MarkdownTextStorage.strikethroughMatchRegExp.firstMatchInString(mutable.string as String, options: NSMatchingOptions(), range: range) {
                let italicPart = NSMutableAttributedString(attributedString: mutable.attributedSubstringFromRange(match.rangeAtIndex(1)))
                var attrs = styles[.Normal]!
                attrs[NSStrikethroughStyleAttributeName] = NSUnderlineStyle.StyleSingle.rawValue
                italicPart.addAttributes(attrs, range: NSMakeRange(0, italicPart.length))
                mutable.replaceCharactersInRange(match.range, withAttributedString: italicPart)
            } else {
                done = true
            }
        }
        return mutable
    }
    
    func formatLinkParts(line: NSAttributedString) -> NSAttributedString {
        let result = NSMutableAttributedString(string: "")
        self.splitString(line.string, regexp: MarkdownTextStorage.linkMatchRegExp) {
            (substring, range, match, delimiter) -> Void in
            if delimiter {
                let linked = NSMutableAttributedString(attributedString: line.attributedSubstringFromRange(match!.rangeAtIndex(1)))
                let href = (line.string as NSString).substringWithRange(match!.rangeAtIndex(2))
                linked.addAttribute(NSLinkAttributeName, value: href, range: NSMakeRange(0, linked.length))
                result.appendAttributedString(linked)
            } else {
                result.appendAttributedString(line.attributedSubstringFromRange(range))
            }
        }
        return result
    }
    
    // Convert raw standalone URLs into [url](url)
    func formatRawLinkParts(line: NSAttributedString) -> NSAttributedString {
        let mutable = NSMutableAttributedString(attributedString: line)
        let range = NSMakeRange(0, mutable.length)
        let matches = Array(MarkdownTextStorage.rawLinkMatchRegExp.matchesInString(mutable.string as String, options: [], range: range).reverse())
        
        for match in matches {
            let preample = mutable.attributedSubstringFromRange(match.rangeAtIndex(1))
            let hrefString = (mutable.string as NSString).substringWithRange(match.rangeAtIndex(2))
            let hrefFormatted = mutable.attributedSubstringFromRange(match.rangeAtIndex(2)).mutableCopy() as! NSMutableAttributedString
            hrefFormatted.addAttribute(NSLinkAttributeName, value: hrefString, range: NSMakeRange(0, hrefFormatted.length))
            let replacement = NSMutableAttributedString(attributedString: preample)
            replacement.appendAttributedString(hrefFormatted)
            mutable.replaceCharactersInRange(match.range, withAttributedString: replacement)
        }
        return mutable
    }
    
    // Convert issues refs (#123) into [#123](http://issue/123)
    func formatIssueLinkParts(line: NSAttributedString) -> NSAttributedString {
        var done = false
        let mutable = NSMutableAttributedString(attributedString: line)
        while !done {
            let range = NSMakeRange(0, mutable.length)
            if let match = MarkdownTextStorage.issueLinkMatchRegExp.firstMatchInString(mutable.string as String, options: NSMatchingOptions(), range: range) {
                let preample = mutable.attributedSubstringFromRange(match.rangeAtIndex(1))
                let postample = mutable.attributedSubstringFromRange(match.rangeAtIndex(3))
                let issueNumber = mutable.attributedSubstringFromRange(match.rangeAtIndex(2))
                let href = String(format: "http://issue/%@", issueNumber.string)
                let title = NSMutableAttributedString(attributedString: mutable.attributedSubstringFromRange(match.rangeAtIndex(2)))
                let hash = NSAttributedString(string: "#", attributes: title.attributesAtIndex(0, effectiveRange: nil))
                let replacement = NSMutableAttributedString(attributedString: preample)
                replacement.appendAttributedString(NSAttributedString(string: "["))
                replacement.appendAttributedString(hash)
                replacement.appendAttributedString(title)
                replacement.appendAttributedString(NSAttributedString(string: "]"))
                replacement.appendAttributedString(NSAttributedString(string: "("))
                replacement.appendAttributedString(NSAttributedString(string: href))
                replacement.appendAttributedString(NSAttributedString(string: ")"))
                replacement.appendAttributedString(postample)
                mutable.replaceCharactersInRange(match.range, withAttributedString: replacement)
            } else {
                done = true
            }
        }
        return mutable
    }

    // Convert commit refs (cafebabe) into [cafebab](http://commit/cafebabe)
    func formatCommitLinkParts(line: NSAttributedString) -> NSAttributedString {
        let result = NSMutableAttributedString(string: "")
        self.splitString(line.string, regexp: MarkdownTextStorage.commitLinkMatchRegExp) {
            (substring, range, match, delimiter) -> Void in
            if delimiter {
                let preample = line.attributedSubstringFromRange(match!.rangeAtIndex(1))
                let postample = line.attributedSubstringFromRange(match!.rangeAtIndex(3))
                let sha = line.attributedSubstringFromRange(match!.rangeAtIndex(2))
                let shortShaString = sha.string.substringToIndex(sha.string.startIndex.advancedBy(7))
                let shortShaAttributed = NSMutableAttributedString(string: shortShaString, attributes: sha.attributesAtIndex(0, effectiveRange: nil))
                let href = String(format: "http://commit/%@", sha.string)
                shortShaAttributed.addAttribute(NSLinkAttributeName, value: href, range: NSMakeRange(0, shortShaAttributed.length))
                let replacement = NSMutableAttributedString(attributedString: preample)
                replacement.appendAttributedString(shortShaAttributed)
                replacement.appendAttributedString(postample)
                result.appendAttributedString(replacement)
            } else {
                let middle = line.attributedSubstringFromRange(range)
                result.appendAttributedString(middle)
            }
        }
        return result
    }

    func formatImageParts(line: NSAttributedString) -> NSAttributedString {
        var done = false
        let mutable = NSMutableAttributedString(attributedString: line)
        while !done {
            let range = NSMakeRange(0, mutable.length)
            if let match = MarkdownTextStorage.imageMatchRegExp.firstMatchInString(mutable.string as String, options: NSMatchingOptions(), range: range) {
                let src = (mutable.string as NSString).substringWithRange(match.rangeAtIndex(2))
                if let srcURL = NSURL(string: src) {
                    let attachment = MarkdownTextAttachment(url: srcURL, textStorage: self)
                    let textWithAttachment = NSMutableAttributedString(attributedString: NSAttributedString(attachment: attachment))
                    mutable.replaceCharactersInRange(match.range, withAttributedString: textWithAttachment)
                }
            } else {
                done = true
            }
        }
        return mutable
    }
    
    func formatDoubleSpaces(line: NSAttributedString) -> NSAttributedString {
        var done = false
        let mutable = NSMutableAttributedString(attributedString: line)
        while !done {
            let range = NSMakeRange(0, mutable.length)
            if let match = MarkdownTextStorage.doubleSpaceRegExp.firstMatchInString(mutable.string as String, options: NSMatchingOptions(), range: range) {
                let range = match.range
                let firstSpaceRange = NSMakeRange(range.location, 1)
                let firstSpace = mutable.attributedSubstringFromRange(firstSpaceRange)
                mutable.replaceCharactersInRange(range, withAttributedString: firstSpace)
            } else {
                done = true
            }
        }
        return mutable
    }

    func formatHTMLEscapes(line: NSAttributedString) -> NSAttributedString {
        var done = false
        let mutable = NSMutableAttributedString(attributedString: line)
        while !done {
            let range = NSMakeRange(0, mutable.length)
            if let match = MarkdownTextStorage.HTMLEntitiesRegExp.firstMatchInString(mutable.string as String, options: NSMatchingOptions(), range: range) {
                let range = match.range // Whole matched range encompasses "&aring;"
                let escape = (mutable.string as NSString).substringWithRange(match.rangeAtIndex(1)) // Submatch is just "aring"
                let replacementUnicodeValue = MarkdownTextStorage.HTMLEntititesEscapeTable[escape] as Int!
                let replacement = String(Character(UnicodeScalar(replacementUnicodeValue)))
                mutable.replaceCharactersInRange(range, withString: replacement)
            } else {
                done = true
            }
        }
        return mutable
    }

    func formatEmojiSynomyms(line: NSAttributedString) -> NSAttributedString {
        var done = false
        let mutable = NSMutableAttributedString(attributedString: line)
        while !done {
            let range = NSMakeRange(0, mutable.length)
            if let match = MarkdownTextStorage.EmojiSynonymsRegExp.firstMatchInString(mutable.string as String, options: NSMatchingOptions(), range: range) {
                let range = match.range // Whole matched range encompasses ":happy:"
                let synonym = (mutable.string as NSString).substringWithRange(match.rangeAtIndex(1)) // Submatch is just "happy"
                let replacement = MarkdownTextStorage.EmojiSynonymMap[synonym]!
                mutable.replaceCharactersInRange(range, withString: replacement)
            } else {
                done = true
            }
        }
        return mutable
    }
    
    func formatParagraphLine(line: String) -> NSAttributedString {
        
        // Split code sections out
        let result = NSMutableAttributedString(string: "")
        self.splitString(line, regexp: MarkdownTextStorage.monospaceMatchRegExp) {
            (substring, range, match, delimiter) -> Void in
            if delimiter {
                let insidePingsRange = match!.rangeAtIndex(1)
                let insidePingsString = (line as NSString).substringWithRange(insidePingsRange)
                let monospaceString = NSAttributedString(string: insidePingsString as String, attributes: self.styles[.Monospace])
                result.appendAttributedString(monospaceString)
            } else {
                var escaped = self.hideBackslashEscapes(substring as String)
                escaped = self.trimHTMLComments(escaped)
                var attributedLine = NSAttributedString(string: escaped as String, attributes: self.styles[.Normal])
                attributedLine = self.formatImageParts(attributedLine)
                attributedLine = self.formatIssueLinkParts(attributedLine)
                attributedLine = self.formatLinkParts(attributedLine)
                attributedLine = self.formatRawLinkParts(attributedLine)
                attributedLine = self.formatCommitLinkParts(attributedLine)
                attributedLine = self.formatBoldParts(attributedLine)
                attributedLine = self.formatItalicParts(attributedLine)
                attributedLine = self.formatStrikethroughParts(attributedLine)
                attributedLine = self.formatHTMLEscapes(attributedLine)
                attributedLine = self.formatEmojiSynomyms(attributedLine)
                attributedLine = self.formatDoubleSpaces(attributedLine)
                attributedLine = self.restoreBackslashEscapes(attributedLine)
                result.appendAttributedString(attributedLine)
            }
        }
        return result
    }
    
    func hideBackslashEscapes(line: String) -> String {
        let varline = NSMutableString(string: line)
        let matches = MarkdownTextStorage.escapesRegExp.matchesInString(line, options: [], range:  NSMakeRange(0,line.characters.count))
        for match in Array(matches.reverse()) {
            let matchedString = varline.substringWithRange(match.rangeAtIndex(1))
            if let replacement = MarkdownTextStorage.escapeTable[matchedString] {
                varline.replaceCharactersInRange(match.range, withString: replacement)
            }
        }
        
        return varline as String
    }
    
    func trimHTMLComments(line: String) -> String {
        let varline = NSMutableString(string: line)
        let matches = MarkdownTextStorage.htmlCommentMatchRegExp.matchesInString(line, options: [], range:  NSMakeRange(0,line.characters.count))
        for match in Array(matches.reverse()) {
            varline.replaceCharactersInRange(match.range, withString: "")
        }
        return varline as String
    }
    
    func restoreBackslashEscapes(attributedString: NSAttributedString) -> NSAttributedString {
        let varline = NSMutableAttributedString(attributedString: attributedString)
        let matches = MarkdownTextStorage.invertedEscapesRegExp.matchesInString(attributedString.string, options: [], range:  NSMakeRange(0,attributedString.length))
        for match in Array(matches.reverse()) {
            let matchedString = (attributedString.string as NSString).substringWithRange(match.rangeAtIndex(1))
            if let replacement = MarkdownTextStorage.invertedEscapeTable[matchedString] {
                varline.replaceCharactersInRange(match.range, withString: replacement)
            }
        }
        return varline
    }
    
    func formatCodeLine(line: String, font: UIFont) -> NSAttributedString {
        let attributes = [NSFontAttributeName: font]
        return NSAttributedString(string: line, attributes: attributes)
    }
    
    func formatHeadline(size: Int, title: String) -> NSAttributedString {
        let stylesName: MarkdownStylesName
        switch size {
        case 1: stylesName = MarkdownStylesName.Headline
        case 2: stylesName = MarkdownStylesName.Subheadline
        case 3: stylesName = MarkdownStylesName.Subsubheadline
        case 4: stylesName = MarkdownStylesName.Subsubsubheadline
        default: stylesName = MarkdownStylesName.Headline
        }
        let line = NSAttributedString(string: title, attributes: styles[stylesName])
        let paragraph = copyDefaultParagrapStyle()
        paragraph.alignment = .Natural
        paragraph.paragraphSpacing = 8
        paragraph.lineSpacing = 0
        paragraph.paragraphSpacingBefore = 0
        paragraph.lineBreakMode = .ByWordWrapping
        return applyParagraphStyle(line, paragraphStyle: paragraph)
    }
    
    
    func formatParagraphLines(lines: [String], styles: StylesDict) -> NSAttributedString {
        let linesJoined = lines.joinWithSeparator(" ")
        let formattedLines = self.formatParagraphLine(linesJoined)
        let paragraph = copyDefaultParagrapStyle()
        paragraph.alignment = .Natural
        paragraph.paragraphSpacing = 8
        paragraph.lineSpacing = 2
        paragraph.paragraphSpacingBefore = 0
        paragraph.lineBreakMode = .ByWordWrapping
        return applyParagraphStyle(formattedLines, paragraphStyle: paragraph)
    }
    
    func formatOrderedList(lines: [String]) -> NSAttributedString {
        var parts = [NSAttributedString]()
        for (index,line) in lines.enumerate() {
            let isLastLine = index == lines.count - 1
            let prefixed = NSMutableAttributedString(string: "\t\(index+1).\t", attributes: styles[.Normal])
            prefixed.appendAttributedString(formatParagraphLine(line))
            let paragraph = copyDefaultParagrapStyle()
            paragraph.tabStops = [
                NSTextTab(textAlignment: NSTextAlignment.Right, location: bulletIndent, options: [String:AnyObject]()),
                NSTextTab(textAlignment: NSTextAlignment.Left, location: bulletTextIndent, options: [String:AnyObject]())]
            paragraph.defaultTabInterval = bulletIndent
            paragraph.firstLineHeadIndent = 0
            paragraph.headIndent = bulletTextIndent
            paragraph.alignment = .Natural
            paragraph.paragraphSpacing = isLastLine ? 8 : 2
            paragraph.lineSpacing = 2
            paragraph.paragraphSpacingBefore = 0
            paragraph.lineBreakMode = .ByWordWrapping
            
            parts.append(applyParagraphStyle(prefixed, paragraphStyle: paragraph))
        }
        let separator = NSAttributedString(string: "\u{2029}", attributes: styles[.Normal])
        let joined = separator.join(parts)
        return joined
    }
    
    func formatUnorderedList(lines: [String]) -> NSAttributedString {
        var parts = [NSAttributedString]()
        for (index, line) in lines.enumerate() {
            let isLastLine = index == lines.count - 1
            let prefixed = NSMutableAttributedString(string: "\t●\t", attributes: styles[.Normal])
            prefixed.appendAttributedString(formatParagraphLine(line))
            let paragraph = copyDefaultParagrapStyle()
            paragraph.tabStops = [
                NSTextTab(textAlignment: NSTextAlignment.Right, location: bulletIndent, options: [String:AnyObject]()),
                NSTextTab(textAlignment: NSTextAlignment.Left, location: bulletTextIndent, options: [String:AnyObject]())]
            paragraph.defaultTabInterval = bulletIndent
            paragraph.firstLineHeadIndent = 0
            paragraph.headIndent = bulletTextIndent
            paragraph.alignment = .Natural
            paragraph.paragraphSpacing = isLastLine ? 8 : 2
            paragraph.lineSpacing = 2
            paragraph.paragraphSpacingBefore = 0
            paragraph.lineBreakMode = .ByWordWrapping
            parts.append(applyParagraphStyle(prefixed, paragraphStyle: paragraph))
        }
        let separator = NSAttributedString(string: "\u{2029}", attributes: styles[.Normal])
        let joined = separator.join(parts)
        return joined
    }
    
    func formatCheckedList(checks: [Bool], lines: [String]) -> NSAttributedString {
        var parts = [NSAttributedString]()
        for (index,line) in lines.enumerate() {
            let isLastLine = index == lines.count - 1
            let prefixString = checks[index] ? "\t☑︎\t" : "\t☐\t"
            let prefixed = NSMutableAttributedString(string: prefixString, attributes: styles[.Normal])
            prefixed.appendAttributedString(formatParagraphLine(line))
            let paragraph = copyDefaultParagrapStyle()
            paragraph.tabStops = [
                NSTextTab(textAlignment: NSTextAlignment.Right, location: bulletIndent, options: [String:AnyObject]()),
                NSTextTab(textAlignment: NSTextAlignment.Left, location: bulletTextIndent, options: [String:AnyObject]())]
            paragraph.defaultTabInterval = bulletIndent
            paragraph.firstLineHeadIndent = 0
            paragraph.headIndent = bulletTextIndent
            paragraph.alignment = .Natural
            paragraph.paragraphSpacing = isLastLine ? 8 : 2
            paragraph.lineSpacing = 2
            paragraph.paragraphSpacingBefore = 0
            paragraph.lineBreakMode = .ByWordWrapping
            parts.append(applyParagraphStyle(prefixed, paragraphStyle: paragraph))
        }
        let separator = NSAttributedString(string: "\u{2029}", attributes: styles[.Normal])
        let joined = separator.join(parts)
        return joined
    }

    func formatQuoteList(levels: [Int], lines: [String]) -> NSAttributedString {
        var parts = [NSAttributedString]()
        for line in lines {
            let prefixed = NSMutableAttributedString(string: "", attributes: styles[.Normal])
            prefixed.appendAttributedString(formatParagraphLine(line))
            prefixed.addAttributes(styles[.Quote]!, range: NSMakeRange(0, prefixed.length))
            parts.append(prefixed)
        }
        let separator = NSAttributedString(string: "\u{2028}", attributes: styles[.Quote])
        let joined = separator.join(parts)
        let paragraph = copyDefaultParagrapStyle()
        paragraph.alignment = .Natural
        paragraph.paragraphSpacing = 6
        paragraph.lineSpacing = 2
        paragraph.paragraphSpacingBefore = 0
        paragraph.headIndent = bulletTextIndent
        paragraph.firstLineHeadIndent = bulletTextIndent
        paragraph.lineBreakMode = .ByWordWrapping
        return applyParagraphStyle(joined, paragraphStyle: paragraph)
    }

    func formatCodeLines(lines: [String], styles: StylesDict) -> NSAttributedString {
        let joinedLines = lines.joinWithSeparator("\u{2028}")
        let lines = NSAttributedString(string: joinedLines, attributes: styles[.Monospace])
        let paragraph = copyDefaultParagrapStyle()
        paragraph.alignment = .Natural
        paragraph.paragraphSpacing = 8
        paragraph.lineSpacing = 2
        paragraph.paragraphSpacingBefore = 0
        paragraph.lineBreakMode = .ByWordWrapping
        return applyParagraphStyle(lines, paragraphStyle: paragraph)
    }
    
    func applyParagraphStyle(attributedString: NSAttributedString, paragraphStyle: NSMutableParagraphStyle) -> NSAttributedString {
        let mutableSection = NSMutableAttributedString(attributedString: attributedString)
        let attrs = [NSParagraphStyleAttributeName: paragraphStyle, NSKernAttributeName: 0]
        mutableSection.addAttributes(attrs, range: NSMakeRange(0, mutableSection.length))
        return mutableSection
    }
    
    func copyDefaultParagrapStyle() -> NSMutableParagraphStyle {
        return NSMutableParagraphStyle.defaultParagraphStyle().mutableCopy() as! NSMutableParagraphStyle
    }
    
    enum MarkdownSectionData: CustomStringConvertible {
        case Headline(Int, String)
        case Paragraph([String])
        case Code([String])
        case UnorderedList([String])
        case OrderedList([String])
        case CheckedList([Bool], [String])
        case Quote([Int], [String])
        
        var description: String {
            get {
                switch self {
                case .Headline(_, _): return "h"
                case .Paragraph(_): return "p"
                case .Code(_): return "pre"
                case .UnorderedList(_): return "ul"
                case .OrderedList(_): return "ol"
                case .CheckedList(_,_): return "olc"
                case .Quote(_, _): return "q"
                }
            }
        }
    }
    
    enum MarkdownSection: String {
        case Headline = "h"
        case Paragraph = "p"
        case Code = "pre"
        case UnorderedList = "ul"
        case OrderedList = "ol"
        case None = "none"
        case CheckedList = "olc"
        case Quote = "q"
    }
   
    public init(markdown: String, styles: StylesDict? = nil) {
        let font = UIFont.systemFontOfSize(13)
        let italicFont = UIFont.italicSystemFontOfSize(13)
        let boldFont = UIFont.boldSystemFontOfSize(13)
        let monospaceFont = UIFont(name: "Menlo-Regular", size: 11)!
        var defaultStyles: StylesDict = [
            MarkdownStylesName.Normal: [NSFontAttributeName: font],
            MarkdownStylesName.Bold: [NSFontAttributeName: boldFont],
            MarkdownStylesName.Italic: [NSFontAttributeName: italicFont],
            MarkdownStylesName.Quote: [NSFontAttributeName: font, NSForegroundColorAttributeName: UIColor.grayColor()],
            MarkdownStylesName.Monospace: [NSFontAttributeName: monospaceFont],
            MarkdownStylesName.Headline: [NSFontAttributeName: boldFont],
            MarkdownStylesName.Subheadline: [NSFontAttributeName: boldFont],
            MarkdownStylesName.Subsubheadline: [NSFontAttributeName: boldFont],
            MarkdownStylesName.Subsubsubheadline: [NSFontAttributeName: boldFont]
        ]
        if let styles = styles {
            for (key,value) in styles {
                defaultStyles[key] = value
            }
        }
        self.styles = defaultStyles
        
        super.init()
        
        parse(markdown)
    }
    
    private func parse(markdown: String) {
        
        var sectionLines = [String]()
        var sectionBools = [Bool]()
        var sectionInts = [Int]() // Used for indents in quotes
        var curSection: MarkdownSection = MarkdownSection.None
        var sections = [MarkdownSectionData]()

        // Group the text into sections
        (markdown+"\n\n").enumerateLines { (line,stop) in
            var lineHandled: Bool?
            repeat {
                //println("CurSection: \(curSection.rawValue): line: \(line)")
                lineHandled = nil
                switch curSection {
                case .Code:
                    if self.endsCodeSection(line) {
                        let sectionData = MarkdownSectionData.Code(sectionLines)
                        sections.append(sectionData)
                        sectionLines = []
                        curSection = .None
                    } else {
                        sectionLines.append(line)
                    }
                    lineHandled = true
                case .Headline: fallthrough
                case .None:
                    if self.beginsCodeSection(line) {
                        curSection = .Code
                        lineHandled = true
                    } else if self.beginsHeaderSection(line) {
                        let headerData = self.extractHeaderLine(line)
                        sections.append(headerData)
                        curSection = .None
                        lineHandled = true
                    } else if self.isCheckedListSection(line) {
                        curSection = .CheckedList
                        lineHandled = false
                    } else if self.isOrderedListSection(line) {
                        curSection = .OrderedList
                        lineHandled = false
                    } else if self.isUnorderedListSection(line) {
                        curSection = .UnorderedList
                        lineHandled = false
                    } else if self.isQuoteSection(line) {
                        curSection = .Quote
                        lineHandled = false
                    } else if self.isBlankLine(line) {
                        //println("Ignoring blank line")
                        lineHandled = true
                    } else {
                        curSection = .Paragraph
                        lineHandled = false
                    }
                case .Paragraph:
                    if self.beginsCodeSection(line) {
                        if curSection == .Paragraph {
                            let sectionData = MarkdownSectionData.Paragraph(sectionLines)
                            sections.append(sectionData)
                        } else if curSection == .Code {
                            let sectionData = MarkdownSectionData.Code(sectionLines)
                            sections.append(sectionData)
                        } else if curSection == .UnorderedList {
                            let sectionData = MarkdownSectionData.UnorderedList(sectionLines)
                            sections.append(sectionData)
                        } else if curSection == .CheckedList {
                            let sectionData = MarkdownSectionData.CheckedList(sectionBools, sectionLines)
                            sections.append(sectionData)
                        } else if curSection == .Quote {
                            let sectionData = MarkdownSectionData.Quote(sectionInts, sectionLines)
                            sections.append(sectionData)
                        } else if curSection == .OrderedList {
                            let sectionData = MarkdownSectionData.OrderedList(sectionLines)
                            sections.append(sectionData)
                        }
                        sectionLines = []
                        curSection = .Code
                        lineHandled = true
                    } else if self.beginsHeaderSection(line) {
                        if curSection == .Paragraph {
                            let sectionData = MarkdownSectionData.Paragraph(sectionLines)
                            sections.append(sectionData)
                        } else if curSection == .Code {
                            let sectionData = MarkdownSectionData.Code(sectionLines)
                            sections.append(sectionData)
                        } else if curSection == .UnorderedList {
                            let sectionData = MarkdownSectionData.UnorderedList(sectionLines)
                            sections.append(sectionData)
                        } else if curSection == .CheckedList {
                            let sectionData = MarkdownSectionData.CheckedList(sectionBools, sectionLines)
                            sections.append(sectionData)
                        } else if curSection == .Quote {
                            let sectionData = MarkdownSectionData.Quote(sectionInts, sectionLines)
                            sections.append(sectionData)
                        } else if curSection == .OrderedList {
                            let sectionData = MarkdownSectionData.OrderedList(sectionLines)
                            sections.append(sectionData)
                        }
                        sectionLines = []
                        let headerData = self.extractHeaderLine(line)
                        sections.append(headerData)
                        curSection = .None
                        lineHandled = true
                    } else if self.endsParagraphSection(line) {
                        let sectionData = MarkdownSectionData.Paragraph(sectionLines)
                        sections.append(sectionData)
                        sectionLines = []
                        curSection = .None
                        lineHandled = true
                    } else if self.isCheckedListSection(line) {
                        let sectionData = MarkdownSectionData.Paragraph(sectionLines)
                        sections.append(sectionData)
                        sectionLines = []
                        sectionBools = []
                        curSection = .CheckedList
                        lineHandled = false
                    } else if self.isQuoteSection(line) {
                        let sectionData = MarkdownSectionData.Paragraph(sectionLines)
                        sections.append(sectionData)
                        sectionLines = []
                        sectionInts = []
                        curSection = .Quote
                        lineHandled = false
                    } else if self.isOrderedListSection(line) {
                        let sectionData = MarkdownSectionData.Paragraph(sectionLines)
                        sections.append(sectionData)
                        sectionLines = []
                        curSection = .OrderedList
                        lineHandled = false
                    } else if self.isUnorderedListSection(line) {
                        let sectionData = MarkdownSectionData.Paragraph(sectionLines)
                        sections.append(sectionData)
                        sectionLines = []
                        curSection = .UnorderedList
                        lineHandled = false
                    } else {
                        sectionLines.append(line)
                        lineHandled = true
                    }
                case .OrderedList:
                    if self.isOrderedListSection(line) {
                        let listLine = self.extractOrderedListLine(line)
                        sectionLines.append(listLine)
                        lineHandled = true
                    } else {
                        let sectionData = MarkdownSectionData.OrderedList(sectionLines)
                        sections.append(sectionData)
                        sectionLines = []
                        curSection = .None
                        lineHandled = false
                    }
                case .CheckedList:
                    if self.isCheckedListSection(line) {
                        let (listBool, listLine) = self.extractCheckedListLine(line)
                        sectionLines.append(listLine)
                        sectionBools.append(listBool)
                        lineHandled = true
                    } else {
                        let sectionData = MarkdownSectionData.CheckedList(sectionBools,sectionLines)
                        sections.append(sectionData)
                        sectionLines = []
                        sectionBools = []
                        curSection = .None
                        lineHandled = false
                    }
                case .UnorderedList:
                    if self.isUnorderedListSection(line) && !self.isCheckedListSection(line) {
                        let listLine = self.extractUnorderedListLine(line)
                        sectionLines.append(listLine)
                        lineHandled = true
                    } else {
                        let sectionData = MarkdownSectionData.UnorderedList(sectionLines)
                        sections.append(sectionData)
                        sectionLines = []
                        curSection = .None
                        lineHandled = false
                    }
                case .Quote:
                    if self.isQuoteSection(line) {
                        let (level, listLine) = self.extractQuoteLine(line)
                        sectionLines.append(listLine)
                        sectionInts.append(level)
                        lineHandled = true
                    } else {
                        let sectionData = MarkdownSectionData.Quote(sectionInts,sectionLines)
                        sections.append(sectionData)
                        sectionLines = []
                        sectionInts = []
                        curSection = .None
                        lineHandled = false
                    }
                }
            } while lineHandled == false
            assert(lineHandled != nil, "linedHandled bool was not set after processing line (\(line))")
        }
        
        // Convert each section into an NSAttributedString
        var attributedSections = [NSAttributedString]()
        for section in sections {
            var sectionAttributedString: NSAttributedString
            switch section {
            case .Paragraph(let lines):
                sectionAttributedString = formatParagraphLines(lines, styles: styles)
            case .Code(let lines):
                sectionAttributedString = formatCodeLines(lines, styles: styles)
            case .Headline(let size, let title):
                sectionAttributedString = formatHeadline(size, title: title)
            case .UnorderedList(let lines):
                sectionAttributedString = formatUnorderedList(lines)
            case .OrderedList(let lines):
                sectionAttributedString = formatOrderedList(lines)
            case .CheckedList(let checks, let lines):
                sectionAttributedString = formatCheckedList(checks, lines: lines)
            case .Quote(let levels, let lines):
                sectionAttributedString = formatQuoteList(levels, lines: lines)
            }
            attributedSections.append(sectionAttributedString)
        }
        let paragraphSeparator = NSAttributedString(string: "\u{2029}", attributes: styles[.Normal])
        let joinedSections = paragraphSeparator.join(attributedSections)
        attributedStringBackend = NSMutableAttributedString(attributedString: joinedSections)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        self.attributedStringBackend = aDecoder.decodeObjectForKey("attributedStringBackend") as? NSMutableAttributedString
        self.styles = aDecoder.decodeObjectForKey("styles") as! StylesDict
        super.init()
    }

    private func beginsHeaderSection(line: String) -> Bool {
        return line.hasPrefix("# ") || line.hasPrefix("## ") || line.hasPrefix("### ") || line.hasPrefix("#### ")
    }
    
    private func beginsCodeSection(line: String) -> Bool {
        return line.hasPrefix("```")
    }
    
    private func endsCodeSection(line: String) -> Bool {
        return line.hasPrefix("```")
    }

    private func endsParagraphSection(line: String) -> Bool {
        return isBlankLine(line)
    }

    private func beginsUnorderedListSection(line: String) -> Bool {
        return line.hasPrefix("* ")
    }

    private func isUnorderedListSection(line: NSString) -> Bool {
        let range = NSMakeRange(0, line.length)
        if let _ = MarkdownTextStorage.unorderedListLineMatchRegExp.firstMatchInString(line as String, options: NSMatchingOptions(), range: range) {
            return true
        } else {
            return false
        }
    }

    private func isOrderedListSection(line: NSString) -> Bool {
        let range = NSMakeRange(0, line.length)
        if let _ = MarkdownTextStorage.orderedListLineMatchRegExp.firstMatchInString(line as String, options: NSMatchingOptions(), range: range) {
            return true
        } else {
            return false
        }
    }

    private func isCheckedListSection(line: NSString) -> Bool {
        let range = NSMakeRange(0, line.length)
        if let _ = MarkdownTextStorage.checkedListLineMatchRegExp.firstMatchInString(line as String, options: NSMatchingOptions(), range: range) {
            return true
        } else {
            return false
        }
    }

    private func isQuoteSection(line: NSString) -> Bool {
        let range = NSMakeRange(0, line.length)
        if let _ = MarkdownTextStorage.quoteLineMatchRegExp.firstMatchInString(line as String, options: NSMatchingOptions(), range: range) {
            return true
        } else {
            return false
        }
    }

    private func isBlankLine(line: NSString) -> Bool {
        let range = NSMakeRange(0, line.length)
        if let _ = MarkdownTextStorage.blankLineMatchRegExp.firstMatchInString(line as String, options: NSMatchingOptions(), range: range) {
            return true
        } else {
            return false
        }
    }

    
    private func extractOrderedListLine(line: NSString) -> String {
        let range = NSMakeRange(0, line.length)
        if let match = MarkdownTextStorage.orderedListLineExtractRegExp.firstMatchInString(line as String, options: NSMatchingOptions(), range: range) {
            if match.range.location != NSNotFound {
                return line.substringWithRange(match.rangeAtIndex(1))
            }
        }
        preconditionFailure("We should be here if we don't match isOrderedListSection")
    }

    private func extractUnorderedListLine(line: NSString) -> String {
        let range = NSMakeRange(0, line.length)
        if let match = MarkdownTextStorage.unorderedListLineExtractRegExp.firstMatchInString(line as String, options: NSMatchingOptions(), range: range) {
            if match.range.location != NSNotFound {
                return line.substringWithRange(match.rangeAtIndex(1))
            }
        }
        preconditionFailure("We should be here if we don't match isUnorderedListSection")
    }

    private func extractCheckedListLine(line: NSString) -> (Bool, String) {
        var check: String?
        var title: String?
        let range = NSMakeRange(0, line.length)
        if let match = MarkdownTextStorage.checkedListLineExtractRegExp.firstMatchInString(line as String, options: NSMatchingOptions(), range: range) {
            if match.range.location != NSNotFound {
                check = line.substringWithRange(match.rangeAtIndex(1))
                title = line.substringWithRange(match.rangeAtIndex(2))
            }
        }
        if let check = check, let title = title {
            let checkBool: Bool = check == "x" || check == "X"
            return (checkBool, title)
        } else {
            return (false, "")
        }
    }

    private func extractQuoteLine(line: NSString) -> (Int, String) {
        var level: Int?
        var title: String?
        let range = NSMakeRange(0, line.length)
        if let match = MarkdownTextStorage.quoteLineExtractRegExp.firstMatchInString(line as String, options: NSMatchingOptions(), range: range) {
            if match.range.location != NSNotFound {
                let lessthans = line.substringWithRange(match.rangeAtIndex(1))
                level = lessthans.characters.count
                title = line.substringWithRange(match.rangeAtIndex(2))
            }
        }
        if let level = level, let title = title {
            return (level, title)
        } else {
            return (1, "")
        }
    }

    private func extractHeaderLine(line: NSString) -> MarkdownSectionData {
        var hashmarks: String?
        var title: String?
        let range = NSMakeRange(0, line.length)
        if let match = MarkdownTextStorage.headerLineExtractRegExp.firstMatchInString(line as String, options: NSMatchingOptions(), range: range) {
            if match.range.location != NSNotFound {
                hashmarks = line.substringWithRange(match.rangeAtIndex(1))
                title = line.substringWithRange(match.rangeAtIndex(2))
            }
        }
        if let hashmarks = hashmarks, let title = title {
            return MarkdownSectionData.Headline(hashmarks.characters.count, title)
        } else {
            return MarkdownSectionData.Headline(1, "")
        }
    }
    
    private func splitString(string: NSString, regexp: NSRegularExpression, callback: (substring: NSString, range: NSRange, match: NSTextCheckingResult?, delimiter: Bool) -> Void) {
        let allStringRange = NSMakeRange(0, string.length)
        var matches = regexp.matchesInString(string as String, options: [], range: allStringRange) 
        if matches.count == 0 {
            callback(substring: string, range: allStringRange, match: nil, delimiter: false)
        } else {
            // Handle string before first match
            let firstMatchRange = matches.first!.range
            let lastMatchRange = matches.last!.range
            if firstMatchRange.location > 0 {
                let preMatchRange = NSMakeRange(0, firstMatchRange.location)
                callback(substring: string.substringWithRange(preMatchRange), range: preMatchRange, match: nil, delimiter: false)
            }

            for (i, checkingResult) in matches.enumerate() {
                // Handle delimiter string
                let delimiterRange = checkingResult.range
                callback(substring: string.substringWithRange(delimiterRange), range: delimiterRange,  match: checkingResult, delimiter: true)
                
                // Handle string until next delimiter match
                if i < matches.count - 1 {
                    let nextDelimiterMatch = matches[i + 1]
                    let stringRangeStart = delimiterRange.location + delimiterRange.length
                    let stringRangeEnd = nextDelimiterMatch.range.location
                    let stringRange = NSMakeRange(stringRangeStart, stringRangeEnd - stringRangeStart)
                    callback(substring: string.substringWithRange(stringRange), range: stringRange, match: nil, delimiter: false)
                }
            }
            // Handle string after last match
            let postMatchStart = lastMatchRange.location + lastMatchRange.length
            if postMatchStart < string.length {
                let postMatchRange = NSMakeRange(postMatchStart, string.length - postMatchStart)
                callback(substring: string.substringWithRange(postMatchRange), range: postMatchRange, match: nil, delimiter: false)
            }

        }
        
    }
    
    // Taken from http://www.w3.org/TR/xhtml1/dtds.html#a_dtd_Special_characters
    static let HTMLEscapeMap: [[AnyObject]] = [
    // A.2.2. Special characters
    [ "quot", 34 ],
    [ "amp", 38 ],
    [ "apos", 39 ],
    [ "lt", 60 ],
    [ "gt", 62 ],
    
    // A.2.1. Latin-1 characters
    [ "nbsp", 160 ],
    [ "iexcl", 161 ],
    [ "cent", 162 ],
    [ "pound", 163 ],
    [ "curren", 164 ],
    [ "yen", 165 ],
    [ "brvbar", 166 ],
    [ "sect", 167 ],
    [ "uml", 168 ],
    [ "copy", 169 ],
    [ "ordf", 170 ],
    [ "laquo", 171 ],
    [ "not", 172 ],
    [ "shy", 173 ],
    [ "reg", 174 ],
    [ "macr", 175 ],
    [ "deg", 176 ],
    [ "plusmn", 177 ],
    [ "sup2", 178 ],
    [ "sup3", 179 ],
    [ "acute", 180 ],
    [ "micro", 181 ],
    [ "para", 182 ],
    [ "middot", 183 ],
    [ "cedil", 184 ],
    [ "sup1", 185 ],
    [ "ordm", 186 ],
    [ "raquo", 187 ],
    [ "frac14", 188 ],
    [ "frac12", 189 ],
    [ "frac34", 190 ],
    [ "iquest", 191 ],
    [ "Agrave", 192 ],
    [ "Aacute", 193 ],
    [ "Acirc", 194 ],
    [ "Atilde", 195 ],
    [ "Auml", 196 ],
    [ "Aring", 197 ],
    [ "AElig", 198 ],
    [ "Ccedil", 199 ],
    [ "Egrave", 200 ],
    [ "Eacute", 201 ],
    [ "Ecirc", 202 ],
    [ "Euml", 203 ],
    [ "Igrave", 204 ],
    [ "Iacute", 205 ],
    [ "Icirc", 206 ],
    [ "Iuml", 207 ],
    [ "ETH", 208 ],
    [ "Ntilde", 209 ],
    [ "Ograve", 210 ],
    [ "Oacute", 211 ],
    [ "Ocirc", 212 ],
    [ "Otilde", 213 ],
    [ "Ouml", 214 ],
    [ "times", 215 ],
    [ "Oslash", 216 ],
    [ "Ugrave", 217 ],
    [ "Uacute", 218 ],
    [ "Ucirc", 219 ],
    [ "Uuml", 220 ],
    [ "Yacute", 221 ],
    [ "THORN", 222 ],
    [ "szlig", 223 ],
    [ "agrave", 224 ],
    [ "aacute", 225 ],
    [ "acirc", 226 ],
    [ "atilde", 227 ],
    [ "auml", 228 ],
    [ "aring", 229 ],
    [ "aelig", 230 ],
    [ "ccedil", 231 ],
    [ "egrave", 232 ],
    [ "eacute", 233 ],
    [ "ecirc", 234 ],
    [ "euml", 235 ],
    [ "igrave", 236 ],
    [ "iacute", 237 ],
    [ "icirc", 238 ],
    [ "iuml", 239 ],
    [ "eth", 240 ],
    [ "ntilde", 241 ],
    [ "ograve", 242 ],
    [ "oacute", 243 ],
    [ "ocirc", 244 ],
    [ "otilde", 245 ],
    [ "ouml", 246 ],
    [ "divide", 247 ],
    [ "oslash", 248 ],
    [ "ugrave", 249 ],
    [ "uacute", 250 ],
    [ "ucirc", 251 ],
    [ "uuml", 252 ],
    [ "yacute", 253 ],
    [ "thorn", 254 ],
    [ "yuml", 255 ],
    
    // A.2.2. Special characters cont'd
    [ "OElig", 338 ],
    [ "oelig", 339 ],
    [ "Scaron", 352 ],
    [ "scaron", 353 ],
    [ "Yuml", 376 ],
    
    // A.2.3. Symbols
    [ "fnof", 402 ],
    
    // A.2.2. Special characters cont'd
    [ "circ", 710 ],
    [ "tilde", 732 ],
    
    // A.2.3. Symbols cont'd
    [ "Alpha", 913 ],
    [ "Beta", 914 ],
    [ "Gamma", 915 ],
    [ "Delta", 916 ],
    [ "Epsilon", 917 ],
    [ "Zeta", 918 ],
    [ "Eta", 919 ],
    [ "Theta", 920 ],
    [ "Iota", 921 ],
    [ "Kappa", 922 ],
    [ "Lambda", 923 ],
    [ "Mu", 924 ],
    [ "Nu", 925 ],
    [ "Xi", 926 ],
    [ "Omicron", 927 ],
    [ "Pi", 928 ],
    [ "Rho", 929 ],
    [ "Sigma", 931 ],
    [ "Tau", 932 ],
    [ "Upsilon", 933 ],
    [ "Phi", 934 ],
    [ "Chi", 935 ],
    [ "Psi", 936 ],
    [ "Omega", 937 ],
    [ "alpha", 945 ],
    [ "beta", 946 ],
    [ "gamma", 947 ],
    [ "delta", 948 ],
    [ "epsilon", 949 ],
    [ "zeta", 950 ],
    [ "eta", 951 ],
    [ "theta", 952 ],
    [ "iota", 953 ],
    [ "kappa", 954 ],
    [ "lambda", 955 ],
    [ "mu", 956 ],
    [ "nu", 957 ],
    [ "xi", 958 ],
    [ "omicron", 959 ],
    [ "pi", 960 ],
    [ "rho", 961 ],
    [ "sigmaf", 962 ],
    [ "sigma", 963 ],
    [ "tau", 964 ],
    [ "upsilon", 965 ],
    [ "phi", 966 ],
    [ "chi", 967 ],
    [ "psi", 968 ],
    [ "omega", 969 ],
    [ "thetasym", 977 ],
    [ "upsih", 978 ],
    [ "piv", 982 ],
    
    // A.2.2. Special characters cont'd
    [ "ensp", 8194 ],
    [ "emsp", 8195 ],
    [ "thinsp", 8201 ],
    [ "zwnj", 8204 ],
    [ "zwj", 8205 ],
    [ "lrm", 8206 ],
    [ "rlm", 8207 ],
    [ "ndash", 8211 ],
    [ "mdash", 8212 ],
    [ "lsquo", 8216 ],
    [ "rsquo", 8217 ],
    [ "sbquo", 8218 ],
    [ "ldquo", 8220 ],
    [ "rdquo", 8221 ],
    [ "bdquo", 8222 ],
    [ "dagger", 8224 ],
    [ "Dagger", 8225 ],
    // A.2.3. Symbols cont'd
    [ "bull", 8226 ],
    [ "hellip", 8230 ],
    
    // A.2.2. Special characters cont'd
    [ "permil", 8240 ],
    
    // A.2.3. Symbols cont'd
    [ "prime", 8242 ],
    [ "Prime", 8243 ],
    
    // A.2.2. Special characters cont'd
    [ "lsaquo", 8249 ],
    [ "rsaquo", 8250 ],
    
    // A.2.3. Symbols cont'd
    [ "oline", 8254 ],
    [ "frasl", 8260 ],
    
    // A.2.2. Special characters cont'd
    [ "euro", 8364 ],
    
    // A.2.3. Symbols cont'd
    [ "image", 8465 ],
    [ "weierp", 8472 ],
    [ "real", 8476 ],
    [ "trade", 8482 ],
    [ "alefsym", 8501 ],
    [ "larr", 8592 ],
    [ "uarr", 8593 ],
    [ "rarr", 8594 ],
    [ "darr", 8595 ],
    [ "harr", 8596 ],
    [ "crarr", 8629 ],
    [ "lArr", 8656 ],
    [ "uArr", 8657 ],
    [ "rArr", 8658 ],
    [ "dArr", 8659 ],
    [ "hArr", 8660 ],
    [ "forall", 8704 ],
    [ "part", 8706 ],
    [ "exist", 8707 ],
    [ "empty", 8709 ],
    [ "nabla", 8711 ],
    [ "isin", 8712 ],
    [ "notin", 8713 ],
    [ "ni", 8715 ],
    [ "prod", 8719 ],
    [ "sum", 8721 ],
    [ "minus", 8722 ],
    [ "lowast", 8727 ],
    [ "radic", 8730 ],
    [ "prop", 8733 ],
    [ "infin", 8734 ],
    [ "ang", 8736 ],
    [ "and", 8743 ],
    [ "or", 8744 ],
    [ "cap", 8745 ],
    [ "cup", 8746 ],
    [ "int", 8747 ],
    [ "there4", 8756 ],
    [ "sim", 8764 ],
    [ "cong", 8773 ],
    [ "asymp", 8776 ],
    [ "ne", 8800 ], 
    [ "equiv", 8801 ], 
    [ "le", 8804 ], 
    [ "ge", 8805 ], 
    [ "sub", 8834 ], 
    [ "sup", 8835 ], 
    [ "nsub", 8836 ], 
    [ "sube", 8838 ], 
    [ "supe", 8839 ], 
    [ "oplus", 8853 ], 
    [ "otimes", 8855 ], 
    [ "perp", 8869 ], 
    [ "sdot", 8901 ], 
    [ "lceil", 8968 ], 
    [ "rceil", 8969 ], 
    [ "lfloor", 8970 ], 
    [ "rfloor", 8971 ], 
    [ "lang", 9001 ], 
    [ "rang", 9002 ], 
    [ "loz", 9674 ], 
    [ "spades", 9824 ], 
    [ "clubs", 9827 ], 
    [ "hearts", 9829 ], 
    [ "diams", 9830 ]
    ];
    
    // From https://github.com/arvida/emoji-cheat-sheet.com
    static let EmojiSynonymMap = [
        "+1"                                : "\u{0001f44d}",
        "-1"                                : "\u{0001f44e}",
        "100"                               : "\u{0001f4af}",
        "1234"                              : "\u{0001f522}",
        "8ball"                             : "\u{0001f3b1}",
        "a"                                 : "\u{0001f170}",
        "ab"                                : "\u{0001f18e}",
        "abc"                               : "\u{0001f524}",
        "abcd"                              : "\u{0001f521}",
        "accept"                            : "\u{0001f251}",
        "aerial_tramway"                    : "\u{0001f6a1}",
        "airplane"                          : "\u{00002708}",
        "alarm_clock"                       : "\u{000023f0}",
        "alien"                             : "\u{0001f47d}",
        "ambulance"                         : "\u{0001f691}",
        "anchor"                            : "\u{00002693}",
        "angel"                             : "\u{0001f47c}",
        "anger"                             : "\u{0001f4a2}",
        "angry"                             : "\u{0001f620}",
        "anguished"                         : "\u{0001f627}",
        "ant"                               : "\u{0001f41c}",
        "apple"                             : "\u{0001f34e}",
        "aquarius"                          : "\u{00002652}",
        "aries"                             : "\u{00002648}",
        "arrow_backward"                    : "\u{000025c0}",
        "arrow_double_down"                 : "\u{000023ec}",
        "arrow_double_up"                   : "\u{000023eb}",
        "arrow_down"                        : "\u{00002b07}",
        "arrow_down_small"                  : "\u{0001f53d}",
        "arrow_forward"                     : "\u{000025b6}",
        "arrow_heading_down"                : "\u{00002935}",
        "arrow_heading_up"                  : "\u{00002934}",
        "arrow_left"                        : "\u{00002b05}",
        "arrow_lower_left"                  : "\u{00002199}",
        "arrow_lower_right"                 : "\u{00002198}",
        "arrow_right"                       : "\u{000027a1}",
        "arrow_right_hook"                  : "\u{000021aa}",
        "arrow_up"                          : "\u{00002b06}",
        "arrow_up_down"                     : "\u{00002195}",
        "arrow_up_small"                    : "\u{0001f53c}",
        "arrow_upper_left"                  : "\u{00002196}",
        "arrow_upper_right"                 : "\u{00002197}",
        "arrows_clockwise"                  : "\u{0001f503}",
        "arrows_counterclockwise"           : "\u{0001f504}",
        "art"                               : "\u{0001f3a8}",
        "articulated_lorry"                 : "\u{0001f69b}",
        "astonished"                        : "\u{0001f632}",
        "athletic_shoe"                     : "\u{0001f45f}",
        "atm"                               : "\u{0001f3e7}",
        "b"                                 : "\u{0001f171}",
        "baby"                              : "\u{0001f476}",
        "baby_bottle"                       : "\u{0001f37c}",
        "baby_chick"                        : "\u{0001f424}",
        "baby_symbol"                       : "\u{0001f6bc}",
        "back"                              : "\u{0001f519}",
        "baggage_claim"                     : "\u{0001f6c4}",
        "balloon"                           : "\u{0001f388}",
        "ballot_box_with_check"             : "\u{00002611}",
        "bamboo"                            : "\u{0001f38d}",
        "banana"                            : "\u{0001f34c}",
        "bangbang"                          : "\u{0000203c}",
        "bank"                              : "\u{0001f3e6}",
        "bar_chart"                         : "\u{0001f4ca}",
        "barber"                            : "\u{0001f488}",
        "baseball"                          : "\u{000026be}",
        "basketball"                        : "\u{0001f3c0}",
        "bath"                              : "\u{0001f6c0}",
        "bathtub"                           : "\u{0001f6c1}",
        "battery"                           : "\u{0001f50b}",
        "bear"                              : "\u{0001f43b}",
        "bee"                               : "\u{0001f41d}",
        "beer"                              : "\u{0001f37a}",
        "beers"                             : "\u{0001f37b}",
        "beetle"                            : "\u{0001f41e}",
        "beginner"                          : "\u{0001f530}",
        "bell"                              : "\u{0001f514}",
        "bento"                             : "\u{0001f371}",
        "bicyclist"                         : "\u{0001f6b4}",
        "bike"                              : "\u{0001f6b2}",
        "bikini"                            : "\u{0001f459}",
        "bird"                              : "\u{0001f426}",
        "birthday"                          : "\u{0001f382}",
        "black_circle"                      : "\u{000026ab}",
        "black_joker"                       : "\u{0001f0cf}",
        "black_large_square"                : "\u{00002b1b}",
        "black_medium_small_square"         : "\u{000025fe}",
        "black_medium_square"               : "\u{000025fc}",
        "black_nib"                         : "\u{00002712}",
        "black_small_square"                : "\u{000025aa}",
        "black_square_button"               : "\u{0001f532}",
        "blossom"                           : "\u{0001f33c}",
        "blowfish"                          : "\u{0001f421}",
        "blue_book"                         : "\u{0001f4d8}",
        "blue_car"                          : "\u{0001f699}",
        "blue_heart"                        : "\u{0001f499}",
        "blush"                             : "\u{0001f60a}",
        "boar"                              : "\u{0001f417}",
        "boat"                              : "\u{000026f5}",
        "bomb"                              : "\u{0001f4a3}",
        "book"                              : "\u{0001f4d6}",
        "bookmark"                          : "\u{0001f516}",
        "bookmark_tabs"                     : "\u{0001f4d1}",
        "books"                             : "\u{0001f4da}",
        "boom"                              : "\u{0001f4a5}",
        "boot"                              : "\u{0001f462}",
        "bouquet"                           : "\u{0001f490}",
        "bow"                               : "\u{0001f647}",
        "bowling"                           : "\u{0001f3b3}",
        "boy"                               : "\u{0001f466}",
        "bread"                             : "\u{0001f35e}",
        "bride_with_veil"                   : "\u{0001f470}",
        "bridge_at_night"                   : "\u{0001f309}",
        "briefcase"                         : "\u{0001f4bc}",
        "broken_heart"                      : "\u{0001f494}",
        "bug"                               : "\u{0001f41b}",
        "bulb"                              : "\u{0001f4a1}",
        "bullettrain_front"                 : "\u{0001f685}",
        "bullettrain_side"                  : "\u{0001f684}",
        "bus"                               : "\u{0001f68c}",
        "busstop"                           : "\u{0001f68f}",
        "bust_in_silhouette"                : "\u{0001f464}",
        "busts_in_silhouette"               : "\u{0001f465}",
        "cactus"                            : "\u{0001f335}",
        "cake"                              : "\u{0001f370}",
        "calendar"                          : "\u{0001f4c6}",
        "calling"                           : "\u{0001f4f2}",
        "camel"                             : "\u{0001f42b}",
        "camera"                            : "\u{0001f4f7}",
        "cancer"                            : "\u{0000264b}",
        "candy"                             : "\u{0001f36c}",
        "capital_abcd"                      : "\u{0001f520}",
        "capricorn"                         : "\u{00002651}",
        "car"                               : "\u{0001f697}",
        "card_index"                        : "\u{0001f4c7}",
        "carousel_horse"                    : "\u{0001f3a0}",
        "cat"                               : "\u{0001f431}",
        "cat2"                              : "\u{0001f408}",
        "cd"                                : "\u{0001f4bf}",
        "chart"                             : "\u{0001f4b9}",
        "chart_with_downwards_trend"        : "\u{0001f4c9}",
        "chart_with_upwards_trend"          : "\u{0001f4c8}",
        "checkered_flag"                    : "\u{0001f3c1}",
        "cherries"                          : "\u{0001f352}",
        "cherry_blossom"                    : "\u{0001f338}",
        "chestnut"                          : "\u{0001f330}",
        "chicken"                           : "\u{0001f414}",
        "children_crossing"                 : "\u{0001f6b8}",
        "chocolate_bar"                     : "\u{0001f36b}",
        "christmas_tree"                    : "\u{0001f384}",
        "church"                            : "\u{000026ea}",
        "cinema"                            : "\u{0001f3a6}",
        "circus_tent"                       : "\u{0001f3aa}",
        "city_sunrise"                      : "\u{0001f307}",
        "city_sunset"                       : "\u{0001f306}",
        "cl"                                : "\u{0001f191}",
        "clap"                              : "\u{0001f44f}",
        "clapper"                           : "\u{0001f3ac}",
        "clipboard"                         : "\u{0001f4cb}",
        "clock1"                            : "\u{0001f550}",
        "clock10"                           : "\u{0001f559}",
        "clock1030"                         : "\u{0001f565}",
        "clock11"                           : "\u{0001f55a}",
        "clock1130"                         : "\u{0001f566}",
        "clock12"                           : "\u{0001f55b}",
        "clock1230"                         : "\u{0001f567}",
        "clock130"                          : "\u{0001f55c}",
        "clock2"                            : "\u{0001f551}",
        "clock230"                          : "\u{0001f55d}",
        "clock3"                            : "\u{0001f552}",
        "clock330"                          : "\u{0001f55e}",
        "clock4"                            : "\u{0001f553}",
        "clock430"                          : "\u{0001f55f}",
        "clock5"                            : "\u{0001f554}",
        "clock530"                          : "\u{0001f560}",
        "clock6"                            : "\u{0001f555}",
        "clock630"                          : "\u{0001f561}",
        "clock7"                            : "\u{0001f556}",
        "clock730"                          : "\u{0001f562}",
        "clock8"                            : "\u{0001f557}",
        "clock830"                          : "\u{0001f563}",
        "clock9"                            : "\u{0001f558}",
        "clock930"                          : "\u{0001f564}",
        "closed_book"                       : "\u{0001f4d5}",
        "closed_lock_with_key"              : "\u{0001f510}",
        "closed_umbrella"                   : "\u{0001f302}",
        "cloud"                             : "\u{00002601}",
        "clubs"                             : "\u{00002663}",
        "cocktail"                          : "\u{0001f378}",
        "coffee"                            : "\u{00002615}",
        "cold_sweat"                        : "\u{0001f630}",
        "collision"                         : "\u{0001f4a5}",
        "computer"                          : "\u{0001f4bb}",
        "confetti_ball"                     : "\u{0001f38a}",
        "confounded"                        : "\u{0001f616}",
        "confused"                          : "\u{0001f615}",
        "congratulations"                   : "\u{00003297}",
        "construction"                      : "\u{0001f6a7}",
        "construction_worker"               : "\u{0001f477}",
        "convenience_store"                 : "\u{0001f3ea}",
        "cookie"                            : "\u{0001f36a}",
        "cool"                              : "\u{0001f192}",
        "cop"                               : "\u{0001f46e}",
        "copyright"                         : "\u{000000a9}",
        "corn"                              : "\u{0001f33d}",
        "couple"                            : "\u{0001f46b}",
        "couple_with_heart"                 : "\u{0001f491}",
        "couplekiss"                        : "\u{0001f48f}",
        "cow"                               : "\u{0001f42e}",
        "cow2"                              : "\u{0001f404}",
        "credit_card"                       : "\u{0001f4b3}",
        "crescent_moon"                     : "\u{0001f319}",
        "crocodile"                         : "\u{0001f40a}",
        "crossed_flags"                     : "\u{0001f38c}",
        "crown"                             : "\u{0001f451}",
        "cry"                               : "\u{0001f622}",
        "crying_cat_face"                   : "\u{0001f63f}",
        "crystal_ball"                      : "\u{0001f52e}",
        "cupid"                             : "\u{0001f498}",
        "curly_loop"                        : "\u{000027b0}",
        "currency_exchange"                 : "\u{0001f4b1}",
        "curry"                             : "\u{0001f35b}",
        "custard"                           : "\u{0001f36e}",
        "customs"                           : "\u{0001f6c3}",
        "cyclone"                           : "\u{0001f300}",
        "dancer"                            : "\u{0001f483}",
        "dancers"                           : "\u{0001f46f}",
        "dango"                             : "\u{0001f361}",
        "dart"                              : "\u{0001f3af}",
        "dash"                              : "\u{0001f4a8}",
        "date"                              : "\u{0001f4c5}",
        "deciduous_tree"                    : "\u{0001f333}",
        "department_store"                  : "\u{0001f3ec}",
        "diamond_shape_with_a_dot_inside"   : "\u{0001f4a0}",
        "diamonds"                          : "\u{00002666}",
        "disappointed"                      : "\u{0001f61e}",
        "disappointed_relieved"             : "\u{0001f625}",
        "dizzy"                             : "\u{0001f4ab}",
        "dizzy_face"                        : "\u{0001f635}",
        "do_not_litter"                     : "\u{0001f6af}",
        "dog"                               : "\u{0001f436}",
        "dog2"                              : "\u{0001f415}",
        "dollar"                            : "\u{0001f4b5}",
        "dolls"                             : "\u{0001f38e}",
        "dolphin"                           : "\u{0001f42c}",
        "door"                              : "\u{0001f6aa}",
        "doughnut"                          : "\u{0001f369}",
        "dragon"                            : "\u{0001f409}",
        "dragon_face"                       : "\u{0001f432}",
        "dress"                             : "\u{0001f457}",
        "dromedary_camel"                   : "\u{0001f42a}",
        "droplet"                           : "\u{0001f4a7}",
        "dvd"                               : "\u{0001f4c0}",
        "e-mail"                            : "\u{0001f4e7}",
        "ear"                               : "\u{0001f442}",
        "ear_of_rice"                       : "\u{0001f33e}",
        "earth_africa"                      : "\u{0001f30d}",
        "earth_americas"                    : "\u{0001f30e}",
        "earth_asia"                        : "\u{0001f30f}",
        "egg"                               : "\u{0001f373}",
        "eggplant"                          : "\u{0001f346}",
        "eight_pointed_black_star"          : "\u{00002734}",
        "eight_spoked_asterisk"             : "\u{00002733}",
        "electric_plug"                     : "\u{0001f50c}",
        "elephant"                          : "\u{0001f418}",
        "email"                             : "\u{00002709}",
        "end"                               : "\u{0001f51a}",
        "envelope"                          : "\u{00002709}",
        "envelope_with_arrow"               : "\u{0001f4e9}",
        "euro"                              : "\u{0001f4b6}",
        "european_castle"                   : "\u{0001f3f0}",
        "european_post_office"              : "\u{0001f3e4}",
        "evergreen_tree"                    : "\u{0001f332}",
        "exclamation"                       : "\u{00002757}",
        "expressionless"                    : "\u{0001f611}",
        "eyeglasses"                        : "\u{0001f453}",
        "eyes"                              : "\u{0001f440}",
        "facepunch"                         : "\u{0001f44a}",
        "factory"                           : "\u{0001f3ed}",
        "fallen_leaf"                       : "\u{0001f342}",
        "family"                            : "\u{0001f46a}",
        "fast_forward"                      : "\u{000023e9}",
        "fax"                               : "\u{0001f4e0}",
        "fearful"                           : "\u{0001f628}",
        "feet"                              : "\u{0001f43e}",
        "ferris_wheel"                      : "\u{0001f3a1}",
        "file_folder"                       : "\u{0001f4c1}",
        "fire"                              : "\u{0001f525}",
        "fire_engine"                       : "\u{0001f692}",
        "fireworks"                         : "\u{0001f386}",
        "first_quarter_moon"                : "\u{0001f313}",
        "first_quarter_moon_with_face"      : "\u{0001f31b}",
        "fish"                              : "\u{0001f41f}",
        "fish_cake"                         : "\u{0001f365}",
        "fishing_pole_and_fish"             : "\u{0001f3a3}",
        "fist"                              : "\u{0000270a}",
        "flags"                             : "\u{0001f38f}",
        "flashlight"                        : "\u{0001f526}",
        "flipper"                           : "\u{0001f42c}",
        "floppy_disk"                       : "\u{0001f4be}",
        "flower_playing_cards"              : "\u{0001f3b4}",
        "flushed"                           : "\u{0001f633}",
        "foggy"                             : "\u{0001f301}",
        "football"                          : "\u{0001f3c8}",
        "footprints"                        : "\u{0001f463}",
        "fork_and_knife"                    : "\u{0001f374}",
        "fountain"                          : "\u{000026f2}",
        "four_leaf_clover"                  : "\u{0001f340}",
        "free"                              : "\u{0001f193}",
        "fried_shrimp"                      : "\u{0001f364}",
        "fries"                             : "\u{0001f35f}",
        "frog"                              : "\u{0001f438}",
        "frowning"                          : "\u{0001f626}",
        "fuelpump"                          : "\u{000026fd}",
        "full_moon"                         : "\u{0001f315}",
        "full_moon_with_face"               : "\u{0001f31d}",
        "game_die"                          : "\u{0001f3b2}",
        "gem"                               : "\u{0001f48e}",
        "gemini"                            : "\u{0000264a}",
        "ghost"                             : "\u{0001f47b}",
        "gift"                              : "\u{0001f381}",
        "gift_heart"                        : "\u{0001f49d}",
        "girl"                              : "\u{0001f467}",
        "globe_with_meridians"              : "\u{0001f310}",
        "goat"                              : "\u{0001f410}",
        "golf"                              : "\u{000026f3}",
        "grapes"                            : "\u{0001f347}",
        "green_apple"                       : "\u{0001f34f}",
        "green_book"                        : "\u{0001f4d7}",
        "green_heart"                       : "\u{0001f49a}",
        "grey_exclamation"                  : "\u{00002755}",
        "grey_question"                     : "\u{00002754}",
        "grimacing"                         : "\u{0001f62c}",
        "grin"                              : "\u{0001f601}",
        "grinning"                          : "\u{0001f600}",
        "guardsman"                         : "\u{0001f482}",
        "guitar"                            : "\u{0001f3b8}",
        "gun"                               : "\u{0001f52b}",
        "haircut"                           : "\u{0001f487}",
        "hamburger"                         : "\u{0001f354}",
        "hammer"                            : "\u{0001f528}",
        "hamster"                           : "\u{0001f439}",
        "hand"                              : "\u{0000270b}",
        "handbag"                           : "\u{0001f45c}",
        "hankey"                            : "\u{0001f4a9}",
        "hatched_chick"                     : "\u{0001f425}",
        "hatching_chick"                    : "\u{0001f423}",
        "headphones"                        : "\u{0001f3a7}",
        "hear_no_evil"                      : "\u{0001f649}",
        "heart"                             : "\u{00002764}",
        "heart_decoration"                  : "\u{0001f49f}",
        "heart_eyes"                        : "\u{0001f60d}",
        "heart_eyes_cat"                    : "\u{0001f63b}",
        "heartbeat"                         : "\u{0001f493}",
        "heartpulse"                        : "\u{0001f497}",
        "hearts"                            : "\u{00002665}",
        "heavy_check_mark"                  : "\u{00002714}",
        "heavy_division_sign"               : "\u{00002797}",
        "heavy_dollar_sign"                 : "\u{0001f4b2}",
        "heavy_exclamation_mark"            : "\u{00002757}",
        "heavy_minus_sign"                  : "\u{00002796}",
        "heavy_multiplication_x"            : "\u{00002716}",
        "heavy_plus_sign"                   : "\u{00002795}",
        "helicopter"                        : "\u{0001f681}",
        "herb"                              : "\u{0001f33f}",
        "hibiscus"                          : "\u{0001f33a}",
        "high_brightness"                   : "\u{0001f506}",
        "high_heel"                         : "\u{0001f460}",
        "hocho"                             : "\u{0001f52a}",
        "honey_pot"                         : "\u{0001f36f}",
        "honeybee"                          : "\u{0001f41d}",
        "horse"                             : "\u{0001f434}",
        "horse_racing"                      : "\u{0001f3c7}",
        "hospital"                          : "\u{0001f3e5}",
        "hotel"                             : "\u{0001f3e8}",
        "hotsprings"                        : "\u{00002668}",
        "hourglass"                         : "\u{0000231b}",
        "hourglass_flowing_sand"            : "\u{000023f3}",
        "house"                             : "\u{0001f3e0}",
        "house_with_garden"                 : "\u{0001f3e1}",
        "hushed"                            : "\u{0001f62f}",
        "ice_cream"                         : "\u{0001f368}",
        "icecream"                          : "\u{0001f366}",
        "id"                                : "\u{0001f194}",
        "ideograph_advantage"               : "\u{0001f250}",
        "imp"                               : "\u{0001f47f}",
        "inbox_tray"                        : "\u{0001f4e5}",
        "incoming_envelope"                 : "\u{0001f4e8}",
        "information_desk_person"           : "\u{0001f481}",
        "information_source"                : "\u{00002139}",
        "innocent"                          : "\u{0001f607}",
        "interrobang"                       : "\u{00002049}",
        "iphone"                            : "\u{0001f4f1}",
        "izakaya_lantern"                   : "\u{0001f3ee}",
        "jack_o_lantern"                    : "\u{0001f383}",
        "japan"                             : "\u{0001f5fe}",
        "japanese_castle"                   : "\u{0001f3ef}",
        "japanese_goblin"                   : "\u{0001f47a}",
        "japanese_ogre"                     : "\u{0001f479}",
        "jeans"                             : "\u{0001f456}",
        "joy"                               : "\u{0001f602}",
        "joy_cat"                           : "\u{0001f639}",
        "key"                               : "\u{0001f511}",
        "keycap_ten"                        : "\u{0001f51f}",
        "kimono"                            : "\u{0001f458}",
        "kiss"                              : "\u{0001f48b}",
        "kissing"                           : "\u{0001f617}",
        "kissing_cat"                       : "\u{0001f63d}",
        "kissing_closed_eyes"               : "\u{0001f61a}",
        "kissing_heart"                     : "\u{0001f618}",
        "kissing_smiling_eyes"              : "\u{0001f619}",
        "koala"                             : "\u{0001f428}",
        "koko"                              : "\u{0001f201}",
        "lantern"                           : "\u{0001f3ee}",
        "large_blue_circle"                 : "\u{0001f535}",
        "large_blue_diamond"                : "\u{0001f537}",
        "large_orange_diamond"              : "\u{0001f536}",
        "last_quarter_moon"                 : "\u{0001f317}",
        "last_quarter_moon_with_face"       : "\u{0001f31c}",
        "laughing"                          : "\u{0001f606}",
        "leaves"                            : "\u{0001f343}",
        "ledger"                            : "\u{0001f4d2}",
        "left_luggage"                      : "\u{0001f6c5}",
        "left_right_arrow"                  : "\u{00002194}",
        "leftwards_arrow_with_hook"         : "\u{000021a9}",
        "lemon"                             : "\u{0001f34b}",
        "leo"                               : "\u{0000264c}",
        "leopard"                           : "\u{0001f406}",
        "libra"                             : "\u{0000264e}",
        "light_rail"                        : "\u{0001f688}",
        "link"                              : "\u{0001f517}",
        "lips"                              : "\u{0001f444}",
        "lipstick"                          : "\u{0001f484}",
        "lock"                              : "\u{0001f512}",
        "lock_with_ink_pen"                 : "\u{0001f50f}",
        "lollipop"                          : "\u{0001f36d}",
        "loop"                              : "\u{000027bf}",
        "loudspeaker"                       : "\u{0001f4e2}",
        "love_hotel"                        : "\u{0001f3e9}",
        "love_letter"                       : "\u{0001f48c}",
        "low_brightness"                    : "\u{0001f505}",
        "m"                                 : "\u{000024c2}",
        "mag"                               : "\u{0001f50d}",
        "mag_right"                         : "\u{0001f50e}",
        "mahjong"                           : "\u{0001f004}",
        "mailbox"                           : "\u{0001f4eb}",
        "mailbox_closed"                    : "\u{0001f4ea}",
        "mailbox_with_mail"                 : "\u{0001f4ec}",
        "mailbox_with_no_mail"              : "\u{0001f4ed}",
        "man"                               : "\u{0001f468}",
        "man_with_gua_pi_mao"               : "\u{0001f472}",
        "man_with_turban"                   : "\u{0001f473}",
        "mans_shoe"                         : "\u{0001f45e}",
        "maple_leaf"                        : "\u{0001f341}",
        "mask"                              : "\u{0001f637}",
        "massage"                           : "\u{0001f486}",
        "meat_on_bone"                      : "\u{0001f356}",
        "mega"                              : "\u{0001f4e3}",
        "melon"                             : "\u{0001f348}",
        "memo"                              : "\u{0001f4dd}",
        "mens"                              : "\u{0001f6b9}",
        "metro"                             : "\u{0001f687}",
        "microphone"                        : "\u{0001f3a4}",
        "microscope"                        : "\u{0001f52c}",
        "milky_way"                         : "\u{0001f30c}",
        "minibus"                           : "\u{0001f690}",
        "minidisc"                          : "\u{0001f4bd}",
        "mobile_phone_off"                  : "\u{0001f4f4}",
        "money_with_wings"                  : "\u{0001f4b8}",
        "moneybag"                          : "\u{0001f4b0}",
        "monkey"                            : "\u{0001f412}",
        "monkey_face"                       : "\u{0001f435}",
        "monorail"                          : "\u{0001f69d}",
        "moon"                              : "\u{0001f314}",
        "mortar_board"                      : "\u{0001f393}",
        "mount_fuji"                        : "\u{0001f5fb}",
        "mountain_bicyclist"                : "\u{0001f6b5}",
        "mountain_cableway"                 : "\u{0001f6a0}",
        "mountain_railway"                  : "\u{0001f69e}",
        "mouse"                             : "\u{0001f42d}",
        "mouse2"                            : "\u{0001f401}",
        "movie_camera"                      : "\u{0001f3a5}",
        "moyai"                             : "\u{0001f5ff}",
        "muscle"                            : "\u{0001f4aa}",
        "mushroom"                          : "\u{0001f344}",
        "musical_keyboard"                  : "\u{0001f3b9}",
        "musical_note"                      : "\u{0001f3b5}",
        "musical_score"                     : "\u{0001f3bc}",
        "mute"                              : "\u{0001f507}",
        "nail_care"                         : "\u{0001f485}",
        "name_badge"                        : "\u{0001f4db}",
        "necktie"                           : "\u{0001f454}",
        "negative_squared_cross_mark"       : "\u{0000274e}",
        "neutral_face"                      : "\u{0001f610}",
        "new"                               : "\u{0001f195}",
        "new_moon"                          : "\u{0001f311}",
        "new_moon_with_face"                : "\u{0001f31a}",
        "newspaper"                         : "\u{0001f4f0}",
        "ng"                                : "\u{0001f196}",
        "no_bell"                           : "\u{0001f515}",
        "no_bicycles"                       : "\u{0001f6b3}",
        "no_entry"                          : "\u{000026d4}",
        "no_entry_sign"                     : "\u{0001f6ab}",
        "no_good"                           : "\u{0001f645}",
        "no_mobile_phones"                  : "\u{0001f4f5}",
        "no_mouth"                          : "\u{0001f636}",
        "no_pedestrians"                    : "\u{0001f6b7}",
        "no_smoking"                        : "\u{0001f6ad}",
        "non-potable_water"                 : "\u{0001f6b1}",
        "nose"                              : "\u{0001f443}",
        "notebook"                          : "\u{0001f4d3}",
        "notebook_with_decorative_cover"    : "\u{0001f4d4}",
        "notes"                             : "\u{0001f3b6}",
        "nut_and_bolt"                      : "\u{0001f529}",
        "o"                                 : "\u{00002b55}",
        "o2"                                : "\u{0001f17e}",
        "ocean"                             : "\u{0001f30a}",
        "octopus"                           : "\u{0001f419}",
        "oden"                              : "\u{0001f362}",
        "office"                            : "\u{0001f3e2}",
        "ok"                                : "\u{0001f197}",
        "ok_hand"                           : "\u{0001f44c}",
        "ok_woman"                          : "\u{0001f646}",
        "older_man"                         : "\u{0001f474}",
        "older_woman"                       : "\u{0001f475}",
        "on"                                : "\u{0001f51b}",
        "oncoming_automobile"               : "\u{0001f698}",
        "oncoming_bus"                      : "\u{0001f68d}",
        "oncoming_police_car"               : "\u{0001f694}",
        "oncoming_taxi"                     : "\u{0001f696}",
        "open_book"                         : "\u{0001f4d6}",
        "open_file_folder"                  : "\u{0001f4c2}",
        "open_hands"                        : "\u{0001f450}",
        "open_mouth"                        : "\u{0001f62e}",
        "ophiuchus"                         : "\u{000026ce}",
        "orange_book"                       : "\u{0001f4d9}",
        "outbox_tray"                       : "\u{0001f4e4}",
        "ox"                                : "\u{0001f402}",
        "package"                           : "\u{0001f4e6}",
        "page_facing_up"                    : "\u{0001f4c4}",
        "page_with_curl"                    : "\u{0001f4c3}",
        "pager"                             : "\u{0001f4df}",
        "palm_tree"                         : "\u{0001f334}",
        "panda_face"                        : "\u{0001f43c}",
        "paperclip"                         : "\u{0001f4ce}",
        "parking"                           : "\u{0001f17f}",
        "part_alternation_mark"             : "\u{0000303d}",
        "partly_sunny"                      : "\u{000026c5}",
        "passport_control"                  : "\u{0001f6c2}",
        "paw_prints"                        : "\u{0001f43e}",
        "peach"                             : "\u{0001f351}",
        "pear"                              : "\u{0001f350}",
        "pencil"                            : "\u{0001f4dd}",
        "pencil2"                           : "\u{0000270f}",
        "penguin"                           : "\u{0001f427}",
        "pensive"                           : "\u{0001f614}",
        "performing_arts"                   : "\u{0001f3ad}",
        "persevere"                         : "\u{0001f623}",
        "person_frowning"                   : "\u{0001f64d}",
        "person_with_blond_hair"            : "\u{0001f471}",
        "person_with_pouting_face"          : "\u{0001f64e}",
        "phone"                             : "\u{0000260e}",
        "pig"                               : "\u{0001f437}",
        "pig2"                              : "\u{0001f416}",
        "pig_nose"                          : "\u{0001f43d}",
        "pill"                              : "\u{0001f48a}",
        "pineapple"                         : "\u{0001f34d}",
        "pisces"                            : "\u{00002653}",
        "pizza"                             : "\u{0001f355}",
        "point_down"                        : "\u{0001f447}",
        "point_left"                        : "\u{0001f448}",
        "point_right"                       : "\u{0001f449}",
        "point_up"                          : "\u{0000261d}",
        "point_up_2"                        : "\u{0001f446}",
        "police_car"                        : "\u{0001f693}",
        "poodle"                            : "\u{0001f429}",
        "poop"                              : "\u{0001f4a9}",
        "post_office"                       : "\u{0001f3e3}",
        "postal_horn"                       : "\u{0001f4ef}",
        "postbox"                           : "\u{0001f4ee}",
        "potable_water"                     : "\u{0001f6b0}",
        "pouch"                             : "\u{0001f45d}",
        "poultry_leg"                       : "\u{0001f357}",
        "pound"                             : "\u{0001f4b7}",
        "pouting_cat"                       : "\u{0001f63e}",
        "pray"                              : "\u{0001f64f}",
        "princess"                          : "\u{0001f478}",
        "punch"                             : "\u{0001f44a}",
        "purple_heart"                      : "\u{0001f49c}",
        "purse"                             : "\u{0001f45b}",
        "pushpin"                           : "\u{0001f4cc}",
        "put_litter_in_its_place"           : "\u{0001f6ae}",
        "question"                          : "\u{00002753}",
        "rabbit"                            : "\u{0001f430}",
        "rabbit2"                           : "\u{0001f407}",
        "racehorse"                         : "\u{0001f40e}",
        "radio"                             : "\u{0001f4fb}",
        "radio_button"                      : "\u{0001f518}",
        "rage"                              : "\u{0001f621}",
        "railway_car"                       : "\u{0001f683}",
        "rainbow"                           : "\u{0001f308}",
        "raised_hand"                       : "\u{0000270b}",
        "raised_hands"                      : "\u{0001f64c}",
        "raising_hand"                      : "\u{0001f64b}",
        "ram"                               : "\u{0001f40f}",
        "ramen"                             : "\u{0001f35c}",
        "rat"                               : "\u{0001f400}",
        "recycle"                           : "\u{0000267b}",
        "red_car"                           : "\u{0001f697}",
        "red_circle"                        : "\u{0001f534}",
        "registered"                        : "\u{000000ae}",
        "relaxed"                           : "\u{0000263a}",
        "relieved"                          : "\u{0001f60c}",
        "repeat"                            : "\u{0001f501}",
        "repeat_one"                        : "\u{0001f502}",
        "restroom"                          : "\u{0001f6bb}",
        "revolving_hearts"                  : "\u{0001f49e}",
        "rewind"                            : "\u{000023ea}",
        "ribbon"                            : "\u{0001f380}",
        "rice"                              : "\u{0001f35a}",
        "rice_ball"                         : "\u{0001f359}",
        "rice_cracker"                      : "\u{0001f358}",
        "rice_scene"                        : "\u{0001f391}",
        "ring"                              : "\u{0001f48d}",
        "rocket"                            : "\u{0001f680}",
        "roller_coaster"                    : "\u{0001f3a2}",
        "rooster"                           : "\u{0001f413}",
        "rose"                              : "\u{0001f339}",
        "rotating_light"                    : "\u{0001f6a8}",
        "round_pushpin"                     : "\u{0001f4cd}",
        "rowboat"                           : "\u{0001f6a3}",
        "rugby_football"                    : "\u{0001f3c9}",
        "runner"                            : "\u{0001f3c3}",
        "running"                           : "\u{0001f3c3}",
        "running_shirt_with_sash"           : "\u{0001f3bd}",
        "sa"                                : "\u{0001f202}",
        "sagittarius"                       : "\u{00002650}",
        "sailboat"                          : "\u{000026f5}",
        "sake"                              : "\u{0001f376}",
        "sandal"                            : "\u{0001f461}",
        "santa"                             : "\u{0001f385}",
        "satellite"                         : "\u{0001f4e1}",
        "satisfied"                         : "\u{0001f606}",
        "saxophone"                         : "\u{0001f3b7}",
        "school"                            : "\u{0001f3eb}",
        "school_satchel"                    : "\u{0001f392}",
        "scissors"                          : "\u{00002702}",
        "scorpius"                          : "\u{0000264f}",
        "scream"                            : "\u{0001f631}",
        "scream_cat"                        : "\u{0001f640}",
        "scroll"                            : "\u{0001f4dc}",
        "seat"                              : "\u{0001f4ba}",
        "secret"                            : "\u{00003299}",
        "see_no_evil"                       : "\u{0001f648}",
        "seedling"                          : "\u{0001f331}",
        "shaved_ice"                        : "\u{0001f367}",
        "sheep"                             : "\u{0001f411}",
        "shell"                             : "\u{0001f41a}",
        "ship"                              : "\u{0001f6a2}",
        "shirt"                             : "\u{0001f455}",
        "shit"                              : "\u{0001f4a9}",
        "shoe"                              : "\u{0001f45e}",
        "shower"                            : "\u{0001f6bf}",
        "signal_strength"                   : "\u{0001f4f6}",
        "six_pointed_star"                  : "\u{0001f52f}",
        "ski"                               : "\u{0001f3bf}",
        "skull"                             : "\u{0001f480}",
        "sleeping"                          : "\u{0001f634}",
        "sleepy"                            : "\u{0001f62a}",
        "slot_machine"                      : "\u{0001f3b0}",
        "small_blue_diamond"                : "\u{0001f539}",
        "small_orange_diamond"              : "\u{0001f538}",
        "small_red_triangle"                : "\u{0001f53a}",
        "small_red_triangle_down"           : "\u{0001f53b}",
        "smile"                             : "\u{0001f604}",
        "smile_cat"                         : "\u{0001f638}",
        "smiley"                            : "\u{0001f603}",
        "smiley_cat"                        : "\u{0001f63a}",
        "smiling_imp"                       : "\u{0001f608}",
        "smirk"                             : "\u{0001f60f}",
        "smirk_cat"                         : "\u{0001f63c}",
        "smoking"                           : "\u{0001f6ac}",
        "snail"                             : "\u{0001f40c}",
        "snake"                             : "\u{0001f40d}",
        "snowboarder"                       : "\u{0001f3c2}",
        "snowflake"                         : "\u{00002744}",
        "snowman"                           : "\u{000026c4}",
        "sob"                               : "\u{0001f62d}",
        "soccer"                            : "\u{000026bd}",
        "soon"                              : "\u{0001f51c}",
        "sos"                               : "\u{0001f198}",
        "sound"                             : "\u{0001f509}",
        "space_invader"                     : "\u{0001f47e}",
        "spades"                            : "\u{00002660}",
        "spaghetti"                         : "\u{0001f35d}",
        "sparkle"                           : "\u{00002747}",
        "sparkler"                          : "\u{0001f387}",
        "sparkles"                          : "\u{00002728}",
        "sparkling_heart"                   : "\u{0001f496}",
        "speak_no_evil"                     : "\u{0001f64a}",
        "speaker"                           : "\u{0001f50a}",
        "speech_balloon"                    : "\u{0001f4ac}",
        "speedboat"                         : "\u{0001f6a4}",
        "star"                              : "\u{00002b50}",
        "star2"                             : "\u{0001f31f}",
        "stars"                             : "\u{0001f303}",
        "station"                           : "\u{0001f689}",
        "statue_of_liberty"                 : "\u{0001f5fd}",
        "steam_locomotive"                  : "\u{0001f682}",
        "stew"                              : "\u{0001f372}",
        "straight_ruler"                    : "\u{0001f4cf}",
        "strawberry"                        : "\u{0001f353}",
        "stuck_out_tongue"                  : "\u{0001f61b}",
        "stuck_out_tongue_closed_eyes"      : "\u{0001f61d}",
        "stuck_out_tongue_winking_eye"      : "\u{0001f61c}",
        "sun_with_face"                     : "\u{0001f31e}",
        "sunflower"                         : "\u{0001f33b}",
        "sunglasses"                        : "\u{0001f60e}",
        "sunny"                             : "\u{00002600}",
        "sunrise"                           : "\u{0001f305}",
        "sunrise_over_mountains"            : "\u{0001f304}",
        "surfer"                            : "\u{0001f3c4}",
        "sushi"                             : "\u{0001f363}",
        "suspension_railway"                : "\u{0001f69f}",
        "sweat"                             : "\u{0001f613}",
        "sweat_drops"                       : "\u{0001f4a6}",
        "sweat_smile"                       : "\u{0001f605}",
        "sweet_potato"                      : "\u{0001f360}",
        "swimmer"                           : "\u{0001f3ca}",
        "symbols"                           : "\u{0001f523}",
        "syringe"                           : "\u{0001f489}",
        "tada"                              : "\u{0001f389}",
        "tanabata_tree"                     : "\u{0001f38b}",
        "tangerine"                         : "\u{0001f34a}",
        "taurus"                            : "\u{00002649}",
        "taxi"                              : "\u{0001f695}",
        "tea"                               : "\u{0001f375}",
        "telephone"                         : "\u{0000260e}",
        "telephone_receiver"                : "\u{0001f4de}",
        "telescope"                         : "\u{0001f52d}",
        "tennis"                            : "\u{0001f3be}",
        "tent"                              : "\u{000026fa}",
        "thought_balloon"                   : "\u{0001f4ad}",
        "thumbsdown"                        : "\u{0001f44e}",
        "thumbsup"                          : "\u{0001f44d}",
        "ticket"                            : "\u{0001f3ab}",
        "tiger"                             : "\u{0001f42f}",
        "tiger2"                            : "\u{0001f405}",
        "tired_face"                        : "\u{0001f62b}",
        "tm"                                : "\u{00002122}",
        "toilet"                            : "\u{0001f6bd}",
        "tokyo_tower"                       : "\u{0001f5fc}",
        "tomato"                            : "\u{0001f345}",
        "tongue"                            : "\u{0001f445}",
        "top"                               : "\u{0001f51d}",
        "tophat"                            : "\u{0001f3a9}",
        "tractor"                           : "\u{0001f69c}",
        "traffic_light"                     : "\u{0001f6a5}",
        "train"                             : "\u{0001f683}",
        "train2"                            : "\u{0001f686}",
        "tram"                              : "\u{0001f68a}",
        "triangular_flag_on_post"           : "\u{0001f6a9}",
        "triangular_ruler"                  : "\u{0001f4d0}",
        "trident"                           : "\u{0001f531}",
        "triumph"                           : "\u{0001f624}",
        "trolleybus"                        : "\u{0001f68e}",
        "trophy"                            : "\u{0001f3c6}",
        "tropical_drink"                    : "\u{0001f379}",
        "tropical_fish"                     : "\u{0001f420}",
        "truck"                             : "\u{0001f69a}",
        "trumpet"                           : "\u{0001f3ba}",
        "tshirt"                            : "\u{0001f455}",
        "tulip"                             : "\u{0001f337}",
        "turtle"                            : "\u{0001f422}",
        "tv"                                : "\u{0001f4fa}",
        "twisted_rightwards_arrows"         : "\u{0001f500}",
        "two_hearts"                        : "\u{0001f495}",
        "two_men_holding_hands"             : "\u{0001f46c}",
        "two_women_holding_hands"           : "\u{0001f46d}",
        "u5272"                             : "\u{0001f239}",
        "u5408"                             : "\u{0001f234}",
        "u55b6"                             : "\u{0001f23a}",
        "u6307"                             : "\u{0001f22f}",
        "u6708"                             : "\u{0001f237}",
        "u6709"                             : "\u{0001f236}",
        "u6e80"                             : "\u{0001f235}",
        "u7121"                             : "\u{0001f21a}",
        "u7533"                             : "\u{0001f238}",
        "u7981"                             : "\u{0001f232}",
        "u7a7a"                             : "\u{0001f233}",
        "umbrella"                          : "\u{00002614}",
        "unamused"                          : "\u{0001f612}",
        "underage"                          : "\u{0001f51e}",
        "unlock"                            : "\u{0001f513}",
        "up"                                : "\u{0001f199}",
        "v"                                 : "\u{0000270c}",
        "vertical_traffic_light"            : "\u{0001f6a6}",
        "vhs"                               : "\u{0001f4fc}",
        "vibration_mode"                    : "\u{0001f4f3}",
        "video_camera"                      : "\u{0001f4f9}",
        "video_game"                        : "\u{0001f3ae}",
        "violin"                            : "\u{0001f3bb}",
        "virgo"                             : "\u{0000264d}",
        "volcano"                           : "\u{0001f30b}",
        "vs"                                : "\u{0001f19a}",
        "walking"                           : "\u{0001f6b6}",
        "waning_crescent_moon"              : "\u{0001f318}",
        "waning_gibbous_moon"               : "\u{0001f316}",
        "warning"                           : "\u{000026a0}",
        "watch"                             : "\u{0000231a}",
        "water_buffalo"                     : "\u{0001f403}",
        "watermelon"                        : "\u{0001f349}",
        "wave"                              : "\u{0001f44b}",
        "wavy_dash"                         : "\u{00003030}",
        "waxing_crescent_moon"              : "\u{0001f312}",
        "waxing_gibbous_moon"               : "\u{0001f314}",
        "wc"                                : "\u{0001f6be}",
        "weary"                             : "\u{0001f629}",
        "wedding"                           : "\u{0001f492}",
        "whale"                             : "\u{0001f433}",
        "whale2"                            : "\u{0001f40b}",
        "wheelchair"                        : "\u{0000267f}",
        "white_check_mark"                  : "\u{00002705}",
        "white_circle"                      : "\u{000026aa}",
        "white_flower"                      : "\u{0001f4ae}",
        "white_large_square"                : "\u{00002b1c}",
        "white_medium_small_square"         : "\u{000025fd}",
        "white_medium_square"               : "\u{000025fb}",
        "white_small_square"                : "\u{000025ab}",
        "white_square_button"               : "\u{0001f533}",
        "wind_chime"                        : "\u{0001f390}",
        "wine_glass"                        : "\u{0001f377}",
        "wink"                              : "\u{0001f609}",
        "wolf"                              : "\u{0001f43a}",
        "woman"                             : "\u{0001f469}",
        "womans_clothes"                    : "\u{0001f45a}",
        "womans_hat"                        : "\u{0001f452}",
        "womens"                            : "\u{0001f6ba}",
        "worried"                           : "\u{0001f61f}",
        "wrench"                            : "\u{0001f527}",
        "x"                                 : "\u{0000274c}",
        "yellow_heart"                      : "\u{0001f49b}",
        "yen"                               : "\u{0001f4b4}",
        "yum"                               : "\u{0001f60b}",
        "zap"                               : "\u{000026a1}",
        "zzz"                               : "\u{0001f4a4}"]

    
    
    
    class MarkdownTextAttachment : NSTextAttachment {
        
        static let cache: NSCache = NSCache()
        
        var textStorage: MarkdownTextStorage?
        
        convenience init(url: NSURL, textStorage: MarkdownTextStorage) {
            self.init()
            let cache = MarkdownTextAttachment.cache
            if let image = cache.objectForKey(url) as? UIImage {
                print("Using cached image for \(url.absoluteString)")
                self.image = image
            } else {
                self.textStorage = textStorage
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
                    if let data = NSData(contentsOfURL: url) {
                        if let downloadedImage = UIImage(data: data) {
                            dispatch_async(dispatch_get_main_queue()) {
                                self.image = downloadedImage
                                cache.setObject(downloadedImage, forKey: url)
                                
                                NSNotificationCenter.defaultCenter().postNotificationName(MarkdownTextAttachmentChangedNotification, object: textStorage, userInfo: ["textAttachment": self])
                                
                                //textStorage.replaceCharactersInRange(NSMakeRange(1, 2), withString: "XXY")
                                /*
                                if let layoutManager = textStorage.layoutManagers.first as? NSLayoutManager {
                                let charsCount = (textStorage.string as NSString).length
                                let range = NSMakeRange(0, charsCount)
                                layoutManager.invalidateDisplayForCharacterRange(range)
                                //                                layoutManager.invalidateDisplayForGlyphRange(range)
                                println("Invalidating display")
                                }
                                */
                            }
                        }
                    }
                }
            }
        }

        override func attachmentBoundsForTextContainer(textContainer: NSTextContainer?, proposedLineFragment lineFrag: CGRect, glyphPosition position: CGPoint, characterIndex charIndex: Int) -> CGRect {
            if let image = image {
                let maxWidth = lineFrag.width - 2 * (textContainer?.lineFragmentPadding ?? 0);
                if image.size.width > maxWidth {
                    let ratio = image.size.width / image.size.height
                    let newHeight = maxWidth / ratio
                    return CGRectMake(0, 0, maxWidth, newHeight)
                } else {
                    return CGRectMake(0, 0, image.size.width, image.size.height)
                }
            }
            return CGRectZero
        }
    }
}

private extension NSAttributedString {
    
    func join(parts: [NSAttributedString]) -> NSAttributedString {
        let result = NSMutableAttributedString(string: "")
        for (index, part) in parts.enumerate() {
            result.appendAttributedString(part)
            if index < parts.count - 1 {
                result.appendAttributedString(self)
            }
        }
        return result
    }
}

private extension String {
    func join(parts: [NSAttributedString]) -> NSAttributedString {
        let joiner = NSAttributedString(string: self)
        return joiner.join(parts)
    }
}

public class MarkdownTextView: UITextView, UITextViewDelegate {
    
    public weak var tableView: UITableView?
    
    override init(frame: CGRect, textContainer: NSTextContainer?) {
        textContainer?.lineFragmentPadding = 0;
        super.init(frame: frame, textContainer: textContainer)
    }

    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        textContainer.lineFragmentPadding = 0; // Default is 5 and we'd like to avoid that to make text flush.
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    public var markdownTextStorage: MarkdownTextStorage? {
        didSet {
            if let markdownTextStorage = markdownTextStorage {
                self.attributedText = markdownTextStorage
                self.sizeToFit();
                self.invalidateIntrinsicContentSize()
                NSNotificationCenter.defaultCenter().removeObserver(self)
                NSNotificationCenter.defaultCenter().addObserver(self, selector: "attributedTextAttachmentChanged:", name: MarkdownTextAttachmentChangedNotification, object: markdownTextStorage)
            } else {
                tableView = nil
                self.attributedText = nil
                self.invalidateIntrinsicContentSize()
                NSNotificationCenter.defaultCenter().removeObserver(self)
            }
        }
    }
    
    func attributedTextAttachmentChanged(notification: NSNotification) {
        self.attributedText = markdownTextStorage
        self.invalidateIntrinsicContentSize()
        tableView?.beginUpdates()
        tableView?.endUpdates()
    }
}

