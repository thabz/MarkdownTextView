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
    private let bulletIndent: CGFloat = 20
    private let bulletTextIndent: CGFloat = 25

    private var attributedStringBackend: NSMutableAttributedString!
    
    override public var string: String {
        return attributedStringBackend.string
    }
    
    override public func attributesAtIndex(location: Int, effectiveRange range: NSRangePointer) -> [NSObject : AnyObject] {
        return attributedStringBackend.attributesAtIndex(location, effectiveRange: range) ?? [NSObject: AnyObject]()
    }
    
    override public func replaceCharactersInRange(range: NSRange, withString str: String) {
        if let attributedStringBackend = attributedStringBackend {
            attributedStringBackend.replaceCharactersInRange(range, withString: str)
            let delta = (str as NSString).length - range.length
            edited(NSTextStorageEditActions.EditedCharacters, range: range, changeInLength: delta)
        }
    }

    override public func setAttributes(attrs: [NSObject : AnyObject]?, range: NSRange) {
        attributedStringBackend?.setAttributes(attrs, range: range)
        edited(NSTextStorageEditActions.EditedAttributes, range: range, changeInLength: 0)
    }
    
    func addPrefix(prefix: String) {
        
    }
    
    static private let headerLineExtractRegExp = NSRegularExpression(pattern: "^(#+)\\s*(.*?)\\s*#*\\s*$", options: nil, error: nil)!
    static private let blankLineMatchRegExp = NSRegularExpression(pattern: "^\\s*$", options: nil, error: nil)!
    static private let orderedListLineMatchRegExp = NSRegularExpression(pattern: "^\\d+\\.\\s", options: nil, error: nil)!
    static private let orderedListLineExtractRegExp = NSRegularExpression(pattern: "^\\d+\\.\\s*(.*)", options: nil, error: nil)!
    static private let unorderedListLineMatchRegExp = NSRegularExpression(pattern: "^[\\*\\+\\-]\\s", options: nil, error: nil)!
    static private let unorderedListLineExtractRegExp = NSRegularExpression(pattern: "^[\\*\\+\\-]\\s*(.*)", options: nil, error: nil)!
    static private let checkedListLineMatchRegExp = NSRegularExpression(pattern: "^- \\[[\\sxX]\\]\\s", options: nil, error: nil)!
    static private let checkedListLineExtractRegExp = NSRegularExpression(pattern: "^- \\[([\\sxX])\\]\\s*(.*)", options: nil, error: nil)!
    static private let quoteLineMatchRegExp = NSRegularExpression(pattern: "^(>+)\\s*(.*?)\\s*?$", options: .CaseInsensitive, error: nil)!
    static private let quoteLineExtractRegExp = NSRegularExpression(pattern: "^(>+)\\s*(.*?)\\s*?$", options: .CaseInsensitive, error: nil)!
    static private let boldMatchRegExp = NSRegularExpression(pattern: "(\\*\\*|__)(.*?)\\1", options: nil, error: nil)!
    static private let italicMatchRegExp = NSRegularExpression(pattern: "(^|[\\W_/])(?:(?!\\1)|(?=^))(\\*|_)(?=\\S)((?:(?!\\2).)*?\\S)\\2(?!\\2)(?=[\\W_/]|$)", options: nil, error: nil)!
    static private let monospaceMatchRegExp = NSRegularExpression(pattern: "`(.*?)`", options: nil, error: nil)!
    static private let strikethroughMatchRegExp = NSRegularExpression(pattern: "~~(.*?)~~", options: nil, error: nil)!
    static private let linkMatchRegExp =  NSRegularExpression(pattern: "\\[(.*?)\\]\\((.*?)\\)", options: nil, error: nil)!
    static private let rawLinkMatchRegExp =  NSRegularExpression(pattern: "([^(\\[]|^)(https?://[^#\\s]+(#[\\w\\-]+)?)", options: nil, error: nil)!
    static private let issueLinkMatchRegExp =  NSRegularExpression(pattern: "([^\\/\\[\\w]|^)#(\\d+)(\\W|$)", options: nil, error: nil)!
    static private let commitLinkMatchRegExp =  NSRegularExpression(pattern: "([^\\/\\[\\w]|^)([0-9a-fA-F]{7,40})(\\W|$)", options: nil, error: nil)!
    static private let imageMatchRegExp = NSRegularExpression(pattern: "\\!\\[(.*?)\\]\\((.*?)\\)", options: nil, error: nil)!
    
    func formatItalicParts(line: NSAttributedString) -> NSAttributedString {
        var done = false
        var mutable = NSMutableAttributedString(attributedString: line)
        while !done {
            let range = NSMakeRange(0, mutable.length)
            if let match = MarkdownTextStorage.italicMatchRegExp.firstMatchInString(mutable.string as String, options: NSMatchingOptions(), range: range) {
                let range = match.range
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
    
    func formatBoldParts(line: NSAttributedString) -> NSAttributedString {
        var done = false
        var mutable = NSMutableAttributedString(attributedString: line)
        while !done {
            let range = NSMakeRange(0, mutable.length)
            if let match = MarkdownTextStorage.boldMatchRegExp.firstMatchInString(mutable.string as String, options: NSMatchingOptions(), range: range) {
                let range = match.range
                let italicPart = NSMutableAttributedString(attributedString: mutable.attributedSubstringFromRange(match.rangeAtIndex(2)))
                italicPart.addAttributes(styles[.Bold]!, range: NSMakeRange(0, italicPart.length))
                mutable.replaceCharactersInRange(match.range, withAttributedString: italicPart)
            } else {
                done = true
            }
        }
        return mutable
    }
    
    func formatMonospaceParts(line: NSAttributedString) -> NSAttributedString {
        var done = false
        var mutable = NSMutableAttributedString(attributedString: line)
        while !done {
            let range = NSMakeRange(0, mutable.length)
            if let match = MarkdownTextStorage.monospaceMatchRegExp.firstMatchInString(mutable.string as String, options: NSMatchingOptions(), range: range) {
                let range = match.range
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
        var mutable = NSMutableAttributedString(attributedString: line)
        while !done {
            let range = NSMakeRange(0, mutable.length)
            if let match = MarkdownTextStorage.strikethroughMatchRegExp.firstMatchInString(mutable.string as String, options: NSMatchingOptions(), range: range) {
                let range = match.range
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
        var result = NSMutableAttributedString(string: "")
        self.splitString(line.string, regexp: MarkdownTextStorage.linkMatchRegExp) {
            (substring, range, match, delimiter) -> Void in
            if delimiter {
                var linked = NSMutableAttributedString(attributedString: line.attributedSubstringFromRange(match!.rangeAtIndex(1)))
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
        var done = false
        var mutable = NSMutableAttributedString(attributedString: line)
        while !done {
            let range = NSMakeRange(0, mutable.length)
            if let match = MarkdownTextStorage.rawLinkMatchRegExp.firstMatchInString(mutable.string as String, options: NSMatchingOptions(), range: range) {
                let range = match.range
                let preample = mutable.attributedSubstringFromRange(match.rangeAtIndex(1))
                let hrefString = (mutable.string as NSString).substringWithRange(match.rangeAtIndex(2))
                let hrefFormatted = mutable.attributedSubstringFromRange(match.rangeAtIndex(2))
                let replacement = NSMutableAttributedString(attributedString: preample)
                replacement.appendAttributedString(NSAttributedString(string:"["))
                replacement.appendAttributedString(hrefFormatted)
                replacement.appendAttributedString(NSAttributedString(string:"]"))
                replacement.appendAttributedString(NSAttributedString(string:"("))
                replacement.appendAttributedString(NSAttributedString(string: hrefString))
                replacement.appendAttributedString(NSAttributedString(string:")"))
                mutable.replaceCharactersInRange(match.range, withAttributedString: replacement)
            } else {
                done = true
            }
        }
        return mutable
    }
    
    // Convert issues refs (#123) into [#123](http://issue/123)
    func formatIssueLinkParts(line: NSAttributedString) -> NSAttributedString {
        var done = false
        var mutable = NSMutableAttributedString(attributedString: line)
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
        var result = NSMutableAttributedString(string: "")
        self.splitString(line.string, regexp: MarkdownTextStorage.commitLinkMatchRegExp) {
            (substring, range, match, delimiter) -> Void in
            if delimiter {
                let preample = line.attributedSubstringFromRange(match!.rangeAtIndex(1))
                let postample = line.attributedSubstringFromRange(match!.rangeAtIndex(3))
                let sha = line.attributedSubstringFromRange(match!.rangeAtIndex(2))
                let shortShaString = sha.string.substringToIndex(advance(sha.string.startIndex, 7))
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
        var mutable = NSMutableAttributedString(attributedString: line)
        while !done {
            let range = NSMakeRange(0, mutable.length)
            if let match = MarkdownTextStorage.imageMatchRegExp.firstMatchInString(mutable.string as String, options: NSMatchingOptions(), range: range) {
                let range = match.range
                let alt = NSMutableAttributedString(attributedString: mutable.attributedSubstringFromRange(match.rangeAtIndex(1)))
                let src = (mutable.string as NSString).substringWithRange(match.rangeAtIndex(2))
                if let srcURL = NSURL(string: src) {
                    var attachment = MarkdownTextAttachment(url: srcURL, textStorage: self)
                    var textWithAttachment = NSMutableAttributedString(attributedString: NSAttributedString(attachment: attachment))
                    mutable.replaceCharactersInRange(match.range, withAttributedString: textWithAttachment)
                }
            } else {
                done = true
            }
        }
        return mutable
    }
    
    func formatParagraphLine(line: String) -> NSAttributedString {
        var normalStyle = styles[.Normal]
        
        // Split code sections out
        var result = NSMutableAttributedString(string: "")
        self.splitString(line, regexp: MarkdownTextStorage.monospaceMatchRegExp) {
            (substring, range, match, delimiter) -> Void in
            if delimiter {
                let insidePingsRange = match!.rangeAtIndex(1)
                let insidePingsString = (line as NSString).substringWithRange(insidePingsRange)
                var monospaceString = NSAttributedString(string: insidePingsString as String, attributes: self.styles[.Monospace])
                result.appendAttributedString(monospaceString)
            } else {
                var attributedLine = NSAttributedString(string: substring as String, attributes: self.styles[.Normal])
                attributedLine = self.formatImageParts(attributedLine)
                attributedLine = self.formatRawLinkParts(attributedLine)
                attributedLine = self.formatIssueLinkParts(attributedLine)
                attributedLine = self.formatLinkParts(attributedLine)
                attributedLine = self.formatCommitLinkParts(attributedLine)
                attributedLine = self.formatBoldParts(attributedLine)
                attributedLine = self.formatItalicParts(attributedLine)
                attributedLine = self.formatStrikethroughParts(attributedLine)
                result.appendAttributedString(attributedLine)
            }
        }
        return result
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
        var line = NSAttributedString(string: title, attributes: styles[stylesName])
        var paragraph = copyDefaultParagrapStyle()
        paragraph.alignment = .Natural
        paragraph.paragraphSpacing = 8
        paragraph.lineSpacing = 0
        paragraph.paragraphSpacingBefore = 0
        paragraph.lineBreakMode = .ByWordWrapping
        return applyParagraphStyle(line, paragraphStyle: paragraph)
    }
    
    
    func formatParagraphLines(lines: [String], styles: StylesDict) -> NSAttributedString {
        let formattedLines = lines.map { return self.formatParagraphLine($0) }
        let separator = NSAttributedString(string: " ", attributes: styles[.Normal])
        var lines = separator.join(formattedLines)
        var paragraph = copyDefaultParagrapStyle()
        paragraph.alignment = .Natural
        paragraph.paragraphSpacing = 8
        paragraph.lineSpacing = 2
        paragraph.paragraphSpacingBefore = 0
        paragraph.lineBreakMode = .ByWordWrapping
        return applyParagraphStyle(lines, paragraphStyle: paragraph)
    }
    
    func formatOrderedList(lines: [String]) -> NSAttributedString {
        var parts = [NSAttributedString]()
        var result = NSMutableAttributedString(string: "", attributes: styles[.Normal])
        for (index,line) in enumerate(lines) {
            let isLastLine = index == lines.count - 1
            var prefixed = NSMutableAttributedString(string: "\t\(index+1).\t", attributes: styles[.Normal])
            prefixed.appendAttributedString(formatParagraphLine(line))
            var paragraph = copyDefaultParagrapStyle()
            paragraph.tabStops = [
                NSTextTab(textAlignment: .Right, location: bulletIndent, options: nil),
                NSTextTab(textAlignment: .Left, location: bulletTextIndent, options: nil)]
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
        for (index, line) in enumerate(lines) {
            let isLastLine = index == lines.count - 1
            var prefixed = NSMutableAttributedString(string: "\t●\t", attributes: styles[.Normal])
            prefixed.appendAttributedString(formatParagraphLine(line))
            var paragraph = copyDefaultParagrapStyle()
            paragraph.tabStops = [
                NSTextTab(textAlignment: .Right, location: bulletIndent, options: nil),
                NSTextTab(textAlignment: .Left, location: bulletTextIndent, options: nil)]
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
        for (index,line) in enumerate(lines) {
            let isLastLine = index == lines.count - 1
            let prefixString = checks[index] ? "\t☑︎\t" : "\t☐\t"
            var prefixed = NSMutableAttributedString(string: prefixString, attributes: styles[.Normal])
            prefixed.appendAttributedString(formatParagraphLine(line))
            var paragraph = copyDefaultParagrapStyle()
            paragraph.tabStops = [
                NSTextTab(textAlignment: .Right, location: bulletIndent, options: nil),
                NSTextTab(textAlignment: .Left, location: bulletTextIndent, options: nil)]
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
        for (index,line) in enumerate(lines) {
            var prefixed = NSMutableAttributedString(string: "", attributes: styles[.Normal])
            prefixed.appendAttributedString(formatParagraphLine(line))
            prefixed.addAttributes(styles[.Quote]!, range: NSMakeRange(0, prefixed.length))
            parts.append(prefixed)
        }
        let separator = NSAttributedString(string: "\u{2028}", attributes: styles[.Quote])
        let joined = separator.join(parts)
        var paragraph = copyDefaultParagrapStyle()
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
        var joinedLines = "\u{2028}".join(lines)
        var lines = NSAttributedString(string: joinedLines, attributes: styles[.Monospace])
        var paragraph = copyDefaultParagrapStyle()
        paragraph.alignment = .Natural
        paragraph.paragraphSpacing = 8
        paragraph.lineSpacing = 2
        paragraph.paragraphSpacingBefore = 0
        paragraph.lineBreakMode = .ByWordWrapping
        return applyParagraphStyle(lines, paragraphStyle: paragraph)
    }
    
    func applyParagraphStyle(attributedString: NSAttributedString, paragraphStyle: NSMutableParagraphStyle) -> NSAttributedString {
        var mutableSection = NSMutableAttributedString(attributedString: attributedString)
        let attrs = [NSParagraphStyleAttributeName: paragraphStyle, NSKernAttributeName: 0]
        mutableSection.addAttributes(attrs, range: NSMakeRange(0, mutableSection.length))
        return mutableSection
    }
    
    func copyDefaultParagrapStyle() -> NSMutableParagraphStyle {
        return NSMutableParagraphStyle.defaultParagraphStyle().mutableCopy() as! NSMutableParagraphStyle
    }
    
    enum MarkdownSectionData: Printable {
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
        let black = UIColor.blackColor()
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
            var i = 0
            do {
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
        var result = NSMutableAttributedString(string: "")
        for (index,section) in enumerate(sections) {
            var sectionAttributedString: NSAttributedString
            var paragraph = copyDefaultParagrapStyle()
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
    
    required public init(coder aDecoder: NSCoder) {
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
        if let match = MarkdownTextStorage.unorderedListLineMatchRegExp.firstMatchInString(line as String, options: NSMatchingOptions(), range: range) {
            return true
        } else {
            return false
        }
    }

    private func isOrderedListSection(line: NSString) -> Bool {
        let range = NSMakeRange(0, line.length)
        if let match = MarkdownTextStorage.orderedListLineMatchRegExp.firstMatchInString(line as String, options: NSMatchingOptions(), range: range) {
            return true
        } else {
            return false
        }
    }

    private func isCheckedListSection(line: NSString) -> Bool {
        let range = NSMakeRange(0, line.length)
        if let match = MarkdownTextStorage.checkedListLineMatchRegExp.firstMatchInString(line as String, options: NSMatchingOptions(), range: range) {
            return true
        } else {
            return false
        }
    }

    private func isQuoteSection(line: NSString) -> Bool {
        let range = NSMakeRange(0, line.length)
        if let match = MarkdownTextStorage.quoteLineMatchRegExp.firstMatchInString(line as String, options: NSMatchingOptions(), range: range) {
            return true
        } else {
            return false
        }
    }

    private func isBlankLine(line: NSString) -> Bool {
        let range = NSMakeRange(0, line.length)
        if let match = MarkdownTextStorage.blankLineMatchRegExp.firstMatchInString(line as String, options: NSMatchingOptions(), range: range) {
            return true
        } else {
            return false
        }
    }

    
    private func extractOrderedListLine(line: NSString) -> String {
        var hashmarks: String?
        var title: String?
        let range = NSMakeRange(0, line.length)
        if let match = MarkdownTextStorage.orderedListLineExtractRegExp.firstMatchInString(line as String, options: NSMatchingOptions(), range: range) {
            if match.range.location != NSNotFound {
                return line.substringWithRange(match.rangeAtIndex(1))
            }
        }
        preconditionFailure("We should be here if we don't match isOrderedListSection")
    }

    private func extractUnorderedListLine(line: NSString) -> String {
        var hashmarks: String?
        var title: String?
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
            var checkBool: Bool = check == "x" || check == "X"
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
                level = count(lessthans)
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
            return MarkdownSectionData.Headline(count(hashmarks), title)
        } else {
            return MarkdownSectionData.Headline(1, "")
        }
    }
    
    private func splitString(string: NSString, regexp: NSRegularExpression, callback: (substring: NSString, range: NSRange, match: NSTextCheckingResult?, delimiter: Bool) -> Void) {
        let allStringRange = NSMakeRange(0, string.length)
        var matches = regexp.matchesInString(string as String, options: nil, range: allStringRange) as! [NSTextCheckingResult]
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

            for (i, checkingResult) in enumerate(matches) {
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
    
    class MarkdownTextAttachment : NSTextAttachment {
        
        static let cache: NSCache = NSCache()
        
        var textStorage: MarkdownTextStorage?
        
        convenience init(url: NSURL, textStorage: MarkdownTextStorage) {
            self.init()
            let cache = MarkdownTextAttachment.cache
            if let image = cache.objectForKey(url) as? UIImage {
                println("Using cached image for \(url.absoluteString ?? nil)")
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

        override func attachmentBoundsForTextContainer(textContainer: NSTextContainer, proposedLineFragment lineFrag: CGRect, glyphPosition position: CGPoint, characterIndex charIndex: Int) -> CGRect {
            if let image = image {
                if image.size.width > lineFrag.width {
                    let ratio = image.size.width / image.size.height
                    let newHeight = lineFrag.width / ratio
                    return CGRectMake(0, 0, lineFrag.width, newHeight)
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
        var result = NSMutableAttributedString(string: "")
        for (index, part) in enumerate(parts) {
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
    
    weak var tableView: UITableView?
    
    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
    }

    public required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        // UITextView has a 5 point left and right inset somewhere I'd like to avoid.
        self.textContainerInset = UIEdgeInsetsMake(0, -5, 0, -5)
        self.contentInset = UIEdgeInsetsMake(0, 0, 0, 0)
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    var markdownTextStorage: MarkdownTextStorage? {
        didSet {
            if let markdownTextStorage = markdownTextStorage {
                self.attributedText = markdownTextStorage
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

