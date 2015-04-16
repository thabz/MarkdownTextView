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
// TODO: http://stackoverflow.com/questions/18560412/uitextview-content-inset

import Foundation
import UIKit

let MarkdownTextAttachmentChangedNotification = "MarkdownTextAttachmentChangedNotification"

class MarkdownTextStorage : NSTextStorage
{
    enum StylesName {
        case Normal
        case Bold
        case Italic
        case Monospace
    }

    typealias StylesDict = [StylesName: [String:AnyObject]]

    private var attributedStringBackend: NSMutableAttributedString!
    
    override var string: String {
        return attributedStringBackend.string
    }
    
    override func attributesAtIndex(location: Int, effectiveRange range: NSRangePointer) -> [NSObject : AnyObject] {
        return attributedStringBackend.attributesAtIndex(location, effectiveRange: range) ?? [NSObject: AnyObject]()
    }
    
    override func replaceCharactersInRange(range: NSRange, withString str: String) {
        if let attributedStringBackend = attributedStringBackend {
            attributedStringBackend.replaceCharactersInRange(range, withString: str)
            let delta = (str as NSString).length - range.length
            edited(NSTextStorageEditActions.EditedCharacters, range: range, changeInLength: delta)
        }
    }

    override func setAttributes(attrs: [NSObject : AnyObject]?, range: NSRange) {
        attributedStringBackend?.setAttributes(attrs, range: range)
        edited(NSTextStorageEditActions.EditedAttributes, range: range, changeInLength: 0)
    }
    
    func addPrefix(prefix: String) {
        
    }
    
    static private let headerLineExtractRegExp = NSRegularExpression(pattern: "^(#+)\\s*?(.*)", options: nil, error: nil)!
    static private let blankLineMatchRegExp = NSRegularExpression(pattern: "^\\s*$", options: nil, error: nil)!
    static private let orderedListLineMatchRegExp = NSRegularExpression(pattern: "^\\d+\\.\\s", options: nil, error: nil)!
    static private let orderedListLineExtractRegExp = NSRegularExpression(pattern: "^\\d+\\.\\s*?(.*)", options: nil, error: nil)!
    static private let unorderedListLineMatchRegExp = NSRegularExpression(pattern: "^\\*\\s", options: nil, error: nil)!
    static private let unorderedListLineExtractRegExp = NSRegularExpression(pattern: "^\\*\\s*?(.*)", options: nil, error: nil)!
    static private let checkboxListLineMatchRegExp = NSRegularExpression(pattern: "^\\[[x\\s]\\]\\s", options: .CaseInsensitive, error: nil)!
    static private let checkboxListLineExtractRegExp = NSRegularExpression(pattern: "^\\[([x\\s])\\]\\s*?(.*)", options: .CaseInsensitive, error: nil)!
    static private let boldMatchRegExp = NSRegularExpression(pattern: "\\*(.*?)\\*", options: nil, error: nil)!
    static private let italicMatchRegExp = NSRegularExpression(pattern: "/(.*?)/", options: nil, error: nil)!
    static private let monospaceMatchRegExp = NSRegularExpression(pattern: "`(.*?)`", options: nil, error: nil)!
    static private let strikethroughMatchRegExp = NSRegularExpression(pattern: "~~(.*?)~~", options: nil, error: nil)!
    static private let underlineMatchRegExp = NSRegularExpression(pattern: "__(.*?)__", options: nil, error: nil)!
    static private let linkMatchRegExp =  NSRegularExpression(pattern: "\\[(.*?)\\]\\((.*?)\\)", options: nil, error: nil)!
    static private let imageMatchRegExp = NSRegularExpression(pattern: "\\!\\[(.*?)\\]\\((.*?)\\)", options: nil, error: nil)!
    
    func formatItalicParts(line: NSAttributedString, styles: StylesDict) -> NSAttributedString {
        var done = false
        var mutable = NSMutableAttributedString(attributedString: line)
        while !done {
            let range = NSMakeRange(0, mutable.length)
            if let match = MarkdownTextStorage.italicMatchRegExp.firstMatchInString(mutable.string as String, options: NSMatchingOptions(), range: range) {
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
            if let match = MarkdownTextStorage.boldMatchRegExp.firstMatchInString(mutable.string as String, options: NSMatchingOptions(), range: range) {
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
    
    func formatStrikethroughParts(line: NSAttributedString, styles: StylesDict) -> NSAttributedString {
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
    
    func formatUnderlineParts(line: NSAttributedString, styles: StylesDict) -> NSAttributedString {
        var done = false
        var mutable = NSMutableAttributedString(attributedString: line)
        while !done {
            let range = NSMakeRange(0, mutable.length)
            if let match = MarkdownTextStorage.underlineMatchRegExp.firstMatchInString(mutable.string as String, options: NSMatchingOptions(), range: range) {
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
            if let match = MarkdownTextStorage.linkMatchRegExp.firstMatchInString(mutable.string as String, options: NSMatchingOptions(), range: range) {
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
    
    func formatImageParts(line: NSAttributedString, styles: StylesDict) -> NSAttributedString {
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
    
    func formatParagraphLine(line: String, styles: StylesDict) -> NSAttributedString {
        var attributedLine = NSAttributedString(string: line)
        attributedLine = formatImageParts(attributedLine, styles: styles)
        attributedLine = formatLinkParts(attributedLine, styles: styles)
        attributedLine = formatMonospaceParts(attributedLine, styles: styles)
        attributedLine = formatBoldParts(attributedLine, styles: styles)
        attributedLine = formatItalicParts(attributedLine, styles: styles)
        attributedLine = formatStrikethroughParts(attributedLine, styles: styles)
        attributedLine = formatUnderlineParts(attributedLine, styles: styles)
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
        let formattedLines = lines.map { return self.formatParagraphLine($0, styles: styles) }
        return "".join(formattedLines)
    }
    
    func formatOrderedList(lines: [String], styles: StylesDict) -> NSAttributedString {
        var parts = [NSAttributedString]()
        var result = NSMutableAttributedString(string: "")
        for (index,line) in enumerate(lines) {
            var prefixed = NSMutableAttributedString(string: "\(index+1). ")
            prefixed.appendAttributedString(formatParagraphLine(line, styles: styles))
            parts.append(prefixed)
        }
        var joined =  NSMutableAttributedString(attributedString: "\u{2028}".join(parts))
        return joined
    }
    
    func formatUnorderedList(lines: [String], styles: StylesDict) -> NSAttributedString {
        var parts = [NSAttributedString]()
        for line in lines {
            var prefixed = NSMutableAttributedString(string: "● ")
            prefixed.appendAttributedString(formatParagraphLine(line, styles: styles))
            parts.append(prefixed)
        }
        var joined =  NSMutableAttributedString(attributedString: "\u{2028}".join(parts))
        return joined
    }
    
    func formatCodeLines(lines: [String], styles: StylesDict) -> NSAttributedString {
        var joinedLines = "\u{2028}".join(lines)
        return NSAttributedString(string: joinedLines, attributes: styles[.Monospace])
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
    
    init(markdown: String, font: UIFont, monospaceFont: UIFont, boldFont: UIFont, italicFont: UIFont, color: UIColor) {
        
        super.init()
        var sectionLines = [String]()
        var curSection: MarkdownSection = MarkdownSection.None
        var sections = [MarkdownSectionData]()

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
            switch section {
            case .Paragraph(let lines):
                sectionAttributedString = formatParagraphLines(lines, styles: styles)
                paragraph.alignment = .Natural
                paragraph.paragraphSpacing = 8
                paragraph.lineSpacing = 2
                paragraph.paragraphSpacingBefore = 0
                paragraph.lineBreakMode = .ByWordWrapping
            case .Code(let lines):
                sectionAttributedString = formatCodeLines(lines, styles: styles)
                paragraph.alignment = .Natural
                paragraph.paragraphSpacing = 8
                paragraph.lineSpacing = 0
                paragraph.paragraphSpacingBefore = 0
                paragraph.lineBreakMode = .ByWordWrapping
            case .Headline(let size, let title):
                sectionAttributedString = formatHeadline(size, title: title, styles:styles)
                paragraph.alignment = .Natural
                paragraph.paragraphSpacing = 8
                paragraph.lineSpacing = 0
                paragraph.paragraphSpacingBefore = 0
                paragraph.lineBreakMode = .ByWordWrapping
            case .UnorderedList(let lines):
                sectionAttributedString = formatUnorderedList(lines, styles: styles)
                paragraph.alignment = .Natural
                paragraph.paragraphSpacing = 6
                paragraph.lineSpacing = 4
                paragraph.paragraphSpacingBefore = 0
                paragraph.headIndent = 8
                paragraph.firstLineHeadIndent = 8
                paragraph.lineBreakMode = .ByWordWrapping
            case .OrderedList(let lines):
                sectionAttributedString = formatOrderedList(lines, styles: styles)
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
            let attrs = [NSParagraphStyleAttributeName: paragraph, NSKernAttributeName: 0, NSBackgroundColorAttributeName: UIColor.greenColor()]
            mutableSection.addAttributes(attrs, range: NSMakeRange(0, mutableSection.length))
            //mutableSection.insertAttributedString(NSAttributedString(string: "\(section): "), atIndex: 0)
            result.appendAttributedString(mutableSection)
        }

        attributedStringBackend = result
    }
    
    required init(coder aDecoder: NSCoder) {
        self.attributedStringBackend = aDecoder.decodeObjectForKey("attributedStringBackend") as? NSMutableAttributedString
        super.init()
    }

    private func beginsHeaderSection(line: String) -> Bool {
        return line.hasPrefix("# ") || line.hasPrefix("## ") || line.hasPrefix("### ")
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
        if hashmarks != nil && title != nil {
            return MarkdownSectionData.Headline((hashmarks! as NSString).length, title!)
        } else {
            return MarkdownSectionData.Headline(1, "")
        }
    }
    
    class MarkdownTextAttachment : NSTextAttachment {

        var textStorage: MarkdownTextStorage?
        
        convenience init(url: NSURL, textStorage: MarkdownTextStorage) {
            self.init()
            self.textStorage = textStorage
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
                if let data = NSData(contentsOfURL: url) {
                    if let downloadedImage = UIImage(data: data) {
                        dispatch_async(dispatch_get_main_queue()) {
                            self.image = downloadedImage
                            
                            NSNotificationCenter.defaultCenter().postNotificationName(MarkdownTextAttachmentChangedNotification, object: textStorage, userInfo: ["textAttachment": self])
                            
                            textStorage.replaceCharactersInRange(NSMakeRange(1, 2), withString: "XXY")
                            if let layoutManager = textStorage.layoutManagers.first as? NSLayoutManager {
                                let charsCount = (textStorage.string as NSString).length
                                let range = NSMakeRange(0, charsCount)
                                layoutManager.invalidateDisplayForCharacterRange(range)
//                                layoutManager.invalidateDisplayForGlyphRange(range)
                                println("Invalidating display")
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

class MarkdownTextView: UITextView, UITextViewDelegate {
    
    weak var tableView: UITableView?
    
    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
    }

    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.textContainerInset = UIEdgeInsetsMake(-15, -5, -22, -5)
        self.contentInset = UIEdgeInsetsMake(0, 0, 0, 0)
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    var markdownTextStorage: MarkdownTextStorage? {
        didSet {
            if let markdownTextStorage = markdownTextStorage {
                self.attributedText = markdownTextStorage
                NSNotificationCenter.defaultCenter().removeObserver(self)
                NSNotificationCenter.defaultCenter().addObserver(self, selector: "attributedTextAttachmentChanged:", name: MarkdownTextAttachmentChangedNotification, object: markdownTextStorage)
            } else {
                tableView = nil
                self.attributedText = NSAttributedString(string: "")
                NSNotificationCenter.defaultCenter().removeObserver(self)
            }
        }
    }
    
    func attributedTextAttachmentChanged(notification: NSNotification) {
        self.attributedText = markdownTextStorage
        tableView?.beginUpdates()
        tableView?.endUpdates()
    }
}

