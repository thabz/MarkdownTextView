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

    private class func blankLineMatchRegExp() -> NSRegularExpression {
        return NSRegularExpression(pattern: "^\\s*$", options: nil, error: nil)!
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
        var sectionLines = [String]()
        var curSection: MarkdownSection = MarkdownSection.None
        var sections = [MarkdownSectionData]()


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
                        println("Ends paragraph")
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
            let newline = NSAttributedString(string: "\n")
            // TODO: Sæt en paragraph spacing 8 på ovenstående newline, så alle sections har en spacing. Lige nu mangler Code sections efterfølgende spacing.
            // TODO: Alternativ, findes der et unicode soft-newline som laver "lineSpacing" men ikke "paragraphSpacing"?
            switch section {
            case .Paragraph(let lines):
                sectionAttributedString = formatParagraphLines(lines)
                paragraph.alignment = .Natural
                paragraph.paragraphSpacing = 8
                paragraph.lineSpacing = 0
                paragraph.paragraphSpacingBefore = 0
                paragraph.lineBreakMode = .ByWordWrapping
            case .Code(let lines):
                sectionAttributedString = formatCodeLines(lines, font: monospaceFont)
                paragraph.alignment = .Natural
                paragraph.paragraphSpacing = 0
                paragraph.lineSpacing = 0
                paragraph.paragraphSpacingBefore = 0
                paragraph.lineBreakMode = .ByWordWrapping
            case .Headline(let size, let title):
                sectionAttributedString = formatHeadline(size, title: title)
                paragraph.alignment = .Natural
                paragraph.paragraphSpacing = 8
                paragraph.lineSpacing = 0
                paragraph.paragraphSpacingBefore = 0
                paragraph.lineBreakMode = .ByWordWrapping
            case .UnorderedList(let lines):
                sectionAttributedString = formatUnorderedList(lines)
                paragraph.alignment = .Natural
                paragraph.paragraphSpacing = 4
                paragraph.lineSpacing = 0
                paragraph.paragraphSpacingBefore = 0
                paragraph.lineBreakMode = .ByWordWrapping
            case .OrderedList(let lines):
                sectionAttributedString = formatOrderedList(lines)
                paragraph.alignment = .Natural
                paragraph.paragraphSpacing = 4
                paragraph.lineSpacing = 0
                paragraph.paragraphSpacingBefore = 0
                paragraph.lineBreakMode = .ByWordWrapping
            }
            
            var mutableSection = NSMutableAttributedString(attributedString: sectionAttributedString)
            mutableSection.appendAttributedString(newline)
            let attrs = [NSParagraphStyleAttributeName: paragraph, NSKernAttributeName: 0, NSBackgroundColorAttributeName: UIColor.greenColor()]
            mutableSection.addAttributes(attrs, range: NSMakeRange(0, mutableSection.length))
            //mutableSection.insertAttributedString(NSAttributedString(string: "\(section): "), atIndex: 0)
            result.appendAttributedString(mutableSection)
        }

        return result
    }
    
    private class func formatParagraphLine(line: String) -> NSAttributedString {
        return NSAttributedString(string: line)
    }
    
    private class func formatCodeLine(line: String, font: UIFont) -> NSAttributedString {
        let attributes = [NSFontAttributeName: font]
        return NSAttributedString(string: line, attributes: attributes)
    }
    
    private class func formatHeadline(size: Int, title: String) -> NSAttributedString {
        return NSAttributedString(string: title)
    }
    
    private class func formatParagraphLines(lines: [String]) -> NSAttributedString {
        let formattedLines = lines.map { return self.formatParagraphLine($0) }
        return "".join(formattedLines)
    }
    
    private class func formatOrderedList(lines: [String]) -> NSAttributedString {
        var result = NSMutableAttributedString(string: "")
        for (index,line) in enumerate(lines) {
            var prefixed = NSMutableAttributedString(string: "\(index+1) ")
            prefixed.appendAttributedString(formatParagraphLine(line))
            result.appendAttributedString(prefixed)
        }
        return result
    }
    
    private class func formatUnorderedList(lines: [String]) -> NSAttributedString {
        var parts = [NSAttributedString]()
        for line in lines {
            var prefixed = NSMutableAttributedString(string: "● ")
            prefixed.appendAttributedString(formatParagraphLine(line))
            parts.append(prefixed)
        }
        var joined =  NSMutableAttributedString(attributedString: "\n".join(parts))
        
        var paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .Natural
        paragraph.paragraphSpacing = 0
        paragraph.lineSpacing = 0
        paragraph.paragraphSpacingBefore = 0
        paragraph.lineBreakMode = .ByWordWrapping
        let attrs = [NSParagraphStyleAttributeName: paragraph, NSKernAttributeName: 0, NSBackgroundColorAttributeName: UIColor.redColor()]
        joined.addAttributes(attrs, range: NSMakeRange(0, joined.length))
        return joined
    }
    
    private class func formatCodeLines(lines: [String], font: UIFont) -> NSAttributedString {
        var joinedLines = "\n".join(lines)
        let attributes = [NSFontAttributeName: font]
        return NSAttributedString(string: joinedLines, attributes: attributes)
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
