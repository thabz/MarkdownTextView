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

import Foundation
import UIKit

extension NSAttributedString
{
    private class func headerLineExtractRegExp() -> NSRegularExpression {
        return NSRegularExpression(pattern: "^(#+)\\s*?(.*)", options: nil, error: nil)!
    }

    private class func blankLineMatchRegExp() -> NSRegularExpression {
        return NSRegularExpression(pattern: "^\\s*$", options: nil, error: nil)!
    }

    private class func orderedListLineMatchRegExp() -> NSRegularExpression {
        return NSRegularExpression(pattern: "^\\d+\\.\\s", options: nil, error: nil)!
    }

    private class func orderedListLineExtractRegExp() -> NSRegularExpression {
        return NSRegularExpression(pattern: "^\\d+\\.\\s*?(.*)", options: nil, error: nil)!
    }
    
    private class func unorderedListLineMatchRegExp() -> NSRegularExpression {
        return NSRegularExpression(pattern: "^\\*\\s", options: nil, error: nil)!
    }
    
    private class func unorderedListLineExtractRegExp() -> NSRegularExpression {
        return NSRegularExpression(pattern: "^\\*\\s*?(.*)", options: nil, error: nil)!
    }

    enum MarkdownSectionData: Printable {
        case Headline(Int, String)
        case Paragraph([String])
        case Code([String])
        case UnorderedList([String])
        case OrderedList([String])
        
        var description: String {
            get {
                switch self {
                case .Headline(_, _): return "h"
                case .Paragraph(_): return "p"
                case .Code(_): return "pre"
                case .UnorderedList(_): return "ul"
                case .OrderedList(_): return "ol"
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
    }
    
    class func attributedStringFromMarkdown(markdown: String, font: UIFont, monospaceFont: UIFont, boldFont: UIFont, italicFont: UIFont, color: UIColor) -> NSAttributedString
    {
        func boldMatchRegExp() -> NSRegularExpression {
            return NSRegularExpression(pattern: "\\*(.*?)\\*", options: nil, error: nil)!
        }
        
        func italicMatchRegExp() -> NSRegularExpression {
            return NSRegularExpression(pattern: "/(.*?)/", options: nil, error: nil)!
        }

        func linkMatchRegExp() -> NSRegularExpression {
            return NSRegularExpression(pattern: "\\[(.*?)\\]\\((.*?)\\)", options: nil, error: nil)!
        }

        func monospaceMatchRegExp() -> NSRegularExpression {
            return NSRegularExpression(pattern: "`(.*?)`", options: nil, error: nil)!
        }

        func strikethroughMatchRegExp() -> NSRegularExpression {
            return NSRegularExpression(pattern: "~~(.*?)~~", options: nil, error: nil)!
        }

        func underlineMatchRegExp() -> NSRegularExpression {
            return NSRegularExpression(pattern: "__(.*?)__", options: nil, error: nil)!
        }

        func formatItalicParts(line: NSAttributedString, styles: StylesDict) -> NSAttributedString {
            var done = false
            var mutable = NSMutableAttributedString(attributedString: line)
            while !done {
                let range = NSMakeRange(0, mutable.length)
                if let match = italicMatchRegExp().firstMatchInString(mutable.string as String, options: NSMatchingOptions(), range: range) {
                    let range = match.range
                    let italicPart = NSMutableAttributedString(attributedString: mutable.attributedSubstringFromRange(match.rangeAtIndex(1)))
                    italicPart.addAttributes(styles[.Italic]!, range: NSMakeRange(0, italicPart.length))
                    mutable.replaceCharactersInRange(match.range, withAttributedString: italicPart)
                } else {
                    done = true
                }
            }
            return mutable
        }

        func formatBoldParts(line: NSAttributedString, styles: StylesDict) -> NSAttributedString {
            var done = false
            var mutable = NSMutableAttributedString(attributedString: line)
            while !done {
                let range = NSMakeRange(0, mutable.length)
                if let match = boldMatchRegExp().firstMatchInString(mutable.string as String, options: NSMatchingOptions(), range: range) {
                    let range = match.range
                    let italicPart = NSMutableAttributedString(attributedString: mutable.attributedSubstringFromRange(match.rangeAtIndex(1)))
                    italicPart.addAttributes(styles[.Bold]!, range: NSMakeRange(0, italicPart.length))
                    mutable.replaceCharactersInRange(match.range, withAttributedString: italicPart)
                } else {
                    done = true
                }
            }
            return mutable
        }

        func formatMonospaceParts(line: NSAttributedString, styles: StylesDict) -> NSAttributedString {
            var done = false
            var mutable = NSMutableAttributedString(attributedString: line)
            while !done {
                let range = NSMakeRange(0, mutable.length)
                if let match = monospaceMatchRegExp().firstMatchInString(mutable.string as String, options: NSMatchingOptions(), range: range) {
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

        func formatStrikethroughParts(line: NSAttributedString, styles: StylesDict) -> NSAttributedString {
            var done = false
            var mutable = NSMutableAttributedString(attributedString: line)
            while !done {
                let range = NSMakeRange(0, mutable.length)
                if let match = strikethroughMatchRegExp().firstMatchInString(mutable.string as String, options: NSMatchingOptions(), range: range) {
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

        func formatUnderlineParts(line: NSAttributedString, styles: StylesDict) -> NSAttributedString {
            var done = false
            var mutable = NSMutableAttributedString(attributedString: line)
            while !done {
                let range = NSMakeRange(0, mutable.length)
                if let match = underlineMatchRegExp().firstMatchInString(mutable.string as String, options: NSMatchingOptions(), range: range) {
                    let range = match.range
                    let italicPart = NSMutableAttributedString(attributedString: mutable.attributedSubstringFromRange(match.rangeAtIndex(1)))
                    var attrs = styles[.Normal]!
                    attrs[NSUnderlineStyleAttributeName] = NSUnderlineStyle.StyleSingle.rawValue
                    italicPart.addAttributes(attrs, range: NSMakeRange(0, italicPart.length))
                    mutable.replaceCharactersInRange(match.range, withAttributedString: italicPart)
                } else {
                    done = true
                }
            }
            return mutable
        }

        func formatLinkParts(line: NSAttributedString, styles: StylesDict) -> NSAttributedString {
            var done = false
            var mutable = NSMutableAttributedString(attributedString: line)
            while !done {
                let range = NSMakeRange(0, mutable.length)
                if let match = linkMatchRegExp().firstMatchInString(mutable.string as String, options: NSMatchingOptions(), range: range) {
                    let range = match.range
                    let text = NSMutableAttributedString(attributedString: mutable.attributedSubstringFromRange(match.rangeAtIndex(1)))
                    let href = (mutable.string as NSString).substringWithRange(match.rangeAtIndex(2))
                    text.addAttribute(NSLinkAttributeName, value: href, range: NSMakeRange(0, text.length))
                    mutable.replaceCharactersInRange(match.range, withAttributedString: text)
                } else {
                    done = true
                }
            }
            return mutable
        }
        
        func formatParagraphLine(line: String, styles: StylesDict) -> NSAttributedString {
            var attributedLine = NSAttributedString(string: line)
            attributedLine = formatLinkParts(attributedLine, styles)
            attributedLine = formatMonospaceParts(attributedLine, styles)
            attributedLine = formatBoldParts(attributedLine, styles)
            attributedLine = formatItalicParts(attributedLine, styles)
            attributedLine = formatStrikethroughParts(attributedLine, styles)
            attributedLine = formatUnderlineParts(attributedLine, styles)
            return attributedLine
        }
        
        func formatCodeLine(line: String, font: UIFont, styles: StylesDict) -> NSAttributedString {
            let attributes = [NSFontAttributeName: font]
            return NSAttributedString(string: line, attributes: attributes)
        }
        
        func formatHeadline(size: Int, title: String, styles: StylesDict) -> NSAttributedString {
            return NSAttributedString(string: title)
        }
        
        func formatParagraphLines(lines: [String], styles: StylesDict) -> NSAttributedString {
            let formattedLines = lines.map { return formatParagraphLine($0, styles) }
            return "".join(formattedLines)
        }
        
        func formatOrderedList(lines: [String], styles: StylesDict) -> NSAttributedString {
            var parts = [NSAttributedString]()
            var result = NSMutableAttributedString(string: "")
            for (index,line) in enumerate(lines) {
                var prefixed = NSMutableAttributedString(string: "\(index+1). ")
                prefixed.appendAttributedString(formatParagraphLine(line, styles))
                parts.append(prefixed)
            }
            var joined =  NSMutableAttributedString(attributedString: "\u{2028}".join(parts))
            return joined
        }
        
        func formatUnorderedList(lines: [String], styles: StylesDict) -> NSAttributedString {
            var parts = [NSAttributedString]()
            for line in lines {
                var prefixed = NSMutableAttributedString(string: "● ")
                prefixed.appendAttributedString(formatParagraphLine(line, styles))
                parts.append(prefixed)
            }
            var joined =  NSMutableAttributedString(attributedString: "\u{2028}".join(parts))
            return joined
        }
        
        func formatCodeLines(lines: [String], styles: StylesDict) -> NSAttributedString {
            var joinedLines = "\u{2028}".join(lines)
            return NSAttributedString(string: joinedLines, attributes: styles[.Monospace])
        }
        
        var sectionLines = [String]()
        var curSection: MarkdownSection = MarkdownSection.None
        var sections = [MarkdownSectionData]()

        typealias StylesDict = [StylesName: [String:AnyObject]]
        
        enum StylesName {
            case Normal
            case Bold
            case Italic
            case Monospace
        }
        
        let styles: StylesDict = [
            StylesName.Normal: [NSFontAttributeName: font],
            StylesName.Bold: [NSFontAttributeName: boldFont],
            StylesName.Italic: [NSFontAttributeName: italicFont],
            StylesName.Monospace: [NSFontAttributeName: monospaceFont]
        ]
        
        // Group the text into sections
        (markdown+"\n\n").enumerateLines { (line,stop) in
            var lineHandled: Bool?
            var i = 0
            do {
                println("CurSection: \(curSection.rawValue): line: \(line)")
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
                case .Headline: break /* Can't be here */
                case .None:
                    if self.beginsCodeSection(line) {
                        curSection = .Code
                        lineHandled = true
                    } else if self.beginsHeaderSection(line) {
                        let headerData = self.extractHeaderLine(line)
                        sections.append(headerData)
                        curSection = .None
                        lineHandled = true
                    } else if self.isOrderedListSection(line) {
                        curSection = .OrderedList
                        lineHandled = false
                    } else if self.isUnorderedListSection(line) {
                        curSection = .UnorderedList
                        lineHandled = false
                    } else if self.isBlankLine(line) {
                        println("Ignoring blank line")
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
                        } else if curSection == .OrderedList {
                            let sectionData = MarkdownSectionData.OrderedList(sectionLines)
                            sections.append(sectionData)
                        }
                        sectionLines = []
                        curSection = .Code
                        lineHandled = true
                    } else if self.beginsHeaderSection(line) {
                        let headerData = self.extractHeaderLine(line)
                        sections.append(headerData)
                        curSection = .None
                        lineHandled = true
                    } else if self.endsParagraphSection(line) {
                        println("Ends paragraph")
                        let sectionData = MarkdownSectionData.Paragraph(sectionLines)
                        sections.append(sectionData)
                        sectionLines = []
                        curSection = .None
                        lineHandled = true
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
                case .UnorderedList:
                    if self.isUnorderedListSection(line) {
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
                }
            } while lineHandled == false
            assert(lineHandled != nil, "linedHandled bool was not set after processing line (\(line))")
        }
        
        // Convert each section into an NSAttributedString
        var result = NSMutableAttributedString(string: "\n")
        for (index,section) in enumerate(sections) {
            var sectionAttributedString: NSAttributedString
            var paragraph = NSMutableParagraphStyle()
            let newline = NSAttributedString(string: "\u{2029}")
            // TODO: Sæt en paragraph spacing 8 på ovenstående newline, så alle sections har en spacing. Lige nu mangler Code sections efterfølgende spacing.
            // TODO: Alternativ, findes der et unicode soft-newline som laver "lineSpacing" men ikke "paragraphSpacing"? Jeps! Se http://www.unicode.org/standard/reports/tr13/tr13-5.html
            // prøv at joine intern i sektioner med 0x2028 og join sektioner med 0x2029
            switch section {
            case .Paragraph(let lines):
                sectionAttributedString = formatParagraphLines(lines, styles)
                paragraph.alignment = .Natural
                paragraph.paragraphSpacing = 8
                paragraph.lineSpacing = 2
                paragraph.paragraphSpacingBefore = 0
                paragraph.lineBreakMode = .ByWordWrapping
            case .Code(let lines):
                sectionAttributedString = formatCodeLines(lines, styles)
                paragraph.alignment = .Natural
                paragraph.paragraphSpacing = 8
                paragraph.lineSpacing = 0
                paragraph.paragraphSpacingBefore = 0
                paragraph.lineBreakMode = .ByWordWrapping
            case .Headline(let size, let title):
                sectionAttributedString = formatHeadline(size, title, styles)
                paragraph.alignment = .Natural
                paragraph.paragraphSpacing = 8
                paragraph.lineSpacing = 0
                paragraph.paragraphSpacingBefore = 0
                paragraph.lineBreakMode = .ByWordWrapping
            case .UnorderedList(let lines):
                sectionAttributedString = formatUnorderedList(lines, styles)
                paragraph.alignment = .Natural
                paragraph.paragraphSpacing = 6
                paragraph.lineSpacing = 4
                paragraph.paragraphSpacingBefore = 0
                paragraph.headIndent = 8
                paragraph.firstLineHeadIndent = 8
                paragraph.lineBreakMode = .ByWordWrapping
            case .OrderedList(let lines):
                sectionAttributedString = formatOrderedList(lines, styles)
                paragraph.alignment = .Natural
                paragraph.paragraphSpacing = 6
                paragraph.lineSpacing = 4
                paragraph.paragraphSpacingBefore = 0
                paragraph.headIndent = 8
                paragraph.firstLineHeadIndent = 8
                paragraph.lineBreakMode = .ByWordWrapping
            }
            
            var mutableSection = NSMutableAttributedString(attributedString: sectionAttributedString)
            mutableSection.appendAttributedString(newline)
            let attrs = [NSParagraphStyleAttributeName: paragraph, NSKernAttributeName: 0]
            mutableSection.addAttributes(attrs, range: NSMakeRange(0, mutableSection.length))
            //mutableSection.insertAttributedString(NSAttributedString(string: "\(section): "), atIndex: 0)
            result.appendAttributedString(mutableSection)
        }

        return result
    }

    private class func beginsHeaderSection(line: String) -> Bool {
        return line.hasPrefix("# ") || line.hasPrefix("## ") || line.hasPrefix("### ")
    }
    
    private class func beginsCodeSection(line: String) -> Bool {
        return line.hasPrefix("```")
    }
    
    private class func endsCodeSection(line: String) -> Bool {
        return line.hasPrefix("```")
    }

    private class func endsParagraphSection(line: String) -> Bool {
        return isBlankLine(line)
    }

    private class func beginsUnorderedListSection(line: String) -> Bool {
        return line.hasPrefix("* ")
    }

    private class func isUnorderedListSection(line: NSString) -> Bool {
        let range = NSMakeRange(0, line.length)
        if let match = self.unorderedListLineMatchRegExp().firstMatchInString(line as String, options: NSMatchingOptions(), range: range) {
            return true
        } else {
            return false
        }
    }

    private class func isOrderedListSection(line: NSString) -> Bool {
        let range = NSMakeRange(0, line.length)
        if let match = self.orderedListLineMatchRegExp().firstMatchInString(line as String, options: NSMatchingOptions(), range: range) {
            return true
        } else {
            return false
        }
    }

    private class func isBlankLine(line: NSString) -> Bool {
        let range = NSMakeRange(0, line.length)
        if let match = self.blankLineMatchRegExp().firstMatchInString(line as String, options: NSMatchingOptions(), range: range) {
            return true
        } else {
            return false
        }
    }

    
    private class func extractOrderedListLine(line: NSString) -> String {
        var hashmarks: String?
        var title: String?
        let range = NSMakeRange(0, line.length)
        if let match = self.orderedListLineExtractRegExp().firstMatchInString(line as String, options: NSMatchingOptions(), range: range) {
            if match.range.location != NSNotFound {
                return line.substringWithRange(match.rangeAtIndex(1))
            }
        }
        assertionFailure("We should be here if we don't match isOrderedListSection")
    }

    private class func extractUnorderedListLine(line: NSString) -> String {
        var hashmarks: String?
        var title: String?
        let range = NSMakeRange(0, line.length)
        if let match = self.unorderedListLineExtractRegExp().firstMatchInString(line as String, options: NSMatchingOptions(), range: range) {
            if match.range.location != NSNotFound {
                return line.substringWithRange(match.rangeAtIndex(1))
            }
        }
        assertionFailure("We should be here if we don't match isUnorderedListSection")
    }

    private class func extractHeaderLine(line: NSString) -> MarkdownSectionData {
        var hashmarks: String?
        var title: String?
        let range = NSMakeRange(0, line.length)
        if let match = self.headerLineExtractRegExp().firstMatchInString(line as String, options: NSMatchingOptions(), range: range) {
            if match.range.location != NSNotFound {
                hashmarks = line.substringWithRange(match.rangeAtIndex(1))
                title = line.substringWithRange(match.rangeAtIndex(2))
            }
        }
        if hashmarks != nil && title != nil {
            return MarkdownSectionData.Headline((hashmarks! as NSString).length, title!)
        } else {
            return MarkdownSectionData.Headline(1, "")
        }
    }
}

extension NSAttributedString {
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

extension String {
    func join(parts: [NSAttributedString]) -> NSAttributedString {
        let joiner = NSAttributedString(string: self)
        return joiner.join(parts)
    }
}
