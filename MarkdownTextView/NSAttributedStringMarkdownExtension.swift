//
//  NSAttributedStringMarkdownExtension.swift
//  MarkdownTextView
//
//  Created by Jesper Christensen on 04/04/15.
//  Copyright (c) 2015 Jesper Christensen. All rights reserved.
//

import Foundation
import UIKit

extension NSAttributedString
{
    private class func headerLineExtractRegExp() -> NSRegularExpression {
        return NSRegularExpression(pattern: "^(#+)\\s*?(.*)", options: nil, error: nil)!
    }

    private class func orderedListLineMatchRegExp() -> NSRegularExpression {
        return NSRegularExpression(pattern: "^\\d+\\s", options: nil, error: nil)!
    }

    private class func orderedListLineExtractRegExp() -> NSRegularExpression {
        return NSRegularExpression(pattern: "^(\\d+)\\s*?(.*)", options: nil, error: nil)!
    }
    
    private class func unorderedListLineMatchRegExp() -> NSRegularExpression {
        return NSRegularExpression(pattern: "^\\*\\s", options: nil, error: nil)!
    }
    
    private class func unorderedListLineExtractRegExp() -> NSRegularExpression {
        return NSRegularExpression(pattern: "^\\*\\s*?(.*)", options: nil, error: nil)!
    }
    
    enum MarkdownSectionData {
        case Headline(Int, String)
        case Paragraph([String])
        case Code([String])
        case UnorderedList([String])
        case OrderedList([String])
    }
    
    enum MarkdownSection {
        case Headline
        case Paragraph
        case Code
        case UnorderedList
        case OrderedList
        case None
    }
    
    class func attributedStringFromMarkdown(markdown: String, font: UIFont, monospaceFont: UIFont, boldFont: UIFont, italicFont: UIFont, color: UIColor) -> NSAttributedString {

        func formatParagraphLine(line: String) -> NSAttributedString {
            return NSAttributedString(string: line)
        }
        
        func formatCodeLine(line: String, font: UIFont) -> NSAttributedString {
            let attributes = [NSFontAttributeName: font]
            return NSAttributedString(string: line, attributes: attributes)
        }

        func formatHeadline(size: Int, title: String) -> NSAttributedString {
            return NSAttributedString(string: title)
        }
        
        func formatParagraphLines(lines: [String]) -> NSAttributedString {
            var result = NSMutableAttributedString(string: "")
            for line in lines {
                result.appendAttributedString(formatParagraphLine(line))
            }
            return result
        }
        
        func formatOrderedList(lines: [String]) -> NSAttributedString {
            var result = NSMutableAttributedString(string: "")
            for (index,line) in enumerate(lines) {
                var prefixed = NSMutableAttributedString(string: "\(index+1) ")
                prefixed.appendAttributedString(formatParagraphLine(line))
                result.appendAttributedString(prefixed)
            }
            return result
        }

        func formatUnorderedList(lines: [String]) -> NSAttributedString {
            var result = NSMutableAttributedString(string: "")
            for (index,line) in enumerate(lines) {
                var prefixed = NSMutableAttributedString(string: "● ")
                prefixed.appendAttributedString(formatParagraphLine(line))
                result.appendAttributedString(prefixed)
            }
            return result
        }

        func formatCodeLines(lines: [String]) -> NSAttributedString {
            var result = NSMutableAttributedString(string: "")
            for line in lines {
                result.appendAttributedString(formatCodeLine(line, monospaceFont))
            }
            return result
        }

        var sections = [MarkdownSectionData]()
        
        var sectionLines = [String]()
        var curSection: MarkdownSection = .None
        
        // Group the text into sections

        (markdown+"\n").enumerateLines { (line,stop) in
            var lineHandled: Bool?
            var i = 0
            do {
                lineHandled = nil
                switch curSection {
                case .Code:
                    if self.endsCodeSection(line) {
                        sectionLines.append(line)
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
                        curSection = .OrderedList
                        lineHandled = false
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
                        sectionLines.append(line)
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
                        sectionLines.append(line)
                        lineHandled = true
                    } else {
                        let sectionData = MarkdownSectionData.UnorderedList(sectionLines)
                        sections.append(sectionData)
                        sectionLines = []
                        curSection = .None
                        lineHandled = false
                    }
                }
            } while lineHandled != nil || lineHandled! == false
            assert(lineHandled != nil, "linedHandled bool was not set after processing line (\(line))")
        }
        
        // Convert each section into an NSAttributedString
        var result = NSMutableAttributedString(string: "")
        for section in sections {
            switch section {
            case .Paragraph(let lines):
                result.appendAttributedString(formatParagraphLines(lines))
            case .Code(let lines):
                result.appendAttributedString(formatCodeLines(lines))
            case .Headline(let size, let title):
                result.appendAttributedString(formatHeadline(size, title))
            case .UnorderedList(let lines):
                result.appendAttributedString(formatUnorderedList(lines))
            case .OrderedList(let lines):
                result.appendAttributedString(formatOrderedList(lines))
            }
        }
        return NSAttributedString(string: markdown)
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
        return line.hasPrefix("\n") || line.hasPrefix("\r\n") || line.hasPrefix("\n\r") || (line as NSString).length == 0
    }

    private class func beginsUnorderedListSection(line: String) -> Bool {
        return line.hasPrefix("* ")
    }

    private class func isUnorderedListSection(line: NSString) -> Bool {
        let range = NSMakeRange(0, line.length)
        if let match = self.orderedListLineMatchRegExp().firstMatchInString(line, options: NSMatchingOptions(), range: range) {
            return true
        } else {
            return false
        }
    }

    private class func isOrderedListSection(line: NSString) -> Bool {
        let range = NSMakeRange(0, line.length)
        if let match = self.orderedListLineMatchRegExp().firstMatchInString(line, options: NSMatchingOptions(), range: range) {
            return true
        } else {
            return false
        }
    }

    private class func extractOrderedListLine(line: NSString) -> String {
        var hashmarks: String?
        var title: String?
        let range = NSMakeRange(0, line.length)
        if let match = self.orderedListLineExtractRegExp().firstMatchInString(line, options: NSMatchingOptions(), range: range) {
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
        if let match = self.unorderedListLineExtractRegExp().firstMatchInString(line, options: NSMatchingOptions(), range: range) {
            if match.range.location != NSNotFound {
                return line.substringWithRange(match.rangeAtIndex(0))
            }
        }
        assertionFailure("We should be here if we don't match isUnorderedListSection")
    }

    private class func extractHeaderLine(line: NSString) -> MarkdownSectionData {
        var hashmarks: String?
        var title: String?
        let range = NSMakeRange(0, line.length)
        if let match = self.headerLineExtractRegExp().firstMatchInString(line, options: NSMatchingOptions(), range: range) {
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