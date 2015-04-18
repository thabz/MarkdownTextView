//
//  MarkdownTextViewTests.swift
//  MarkdownTextViewTests
//
//  Created by Jesper Christensen on 04/04/15.
//  Copyright (c) 2015 Jesper Christensen. All rights reserved.
//

import UIKit
import XCTest
import MarkdownTextView

class MarkdownTextViewTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testBold() {
        XCTAssertTrue(MarkdownTextStorage(markdown: "*bold*").isBoldAtIndex(0))
        XCTAssertTrue(MarkdownTextStorage(markdown: "__bold__").isBoldAtIndex(0))
        XCTAssertEqual("bold", MarkdownTextStorage(markdown: "*bold*").string)
        XCTAssertEqual("bold", MarkdownTextStorage(markdown: "__bold__").string)
        XCTAssertTrue(MarkdownTextStorage(markdown: "__b__ _i_").isBoldAtIndex(0))
        //XCTAssertEqual("*bold*", MarkdownTextStorage(markdown: "\\*bold\\*").string)
    }

    func testItalic() {
        XCTAssertTrue(MarkdownTextStorage(markdown: "/italic/").isItalicAtIndex(0))
        XCTAssertTrue(MarkdownTextStorage(markdown: "_italic_").isItalicAtIndex(0))
        XCTAssertTrue(MarkdownTextStorage(markdown: "__b__ _i_").isItalicAtIndex(2))
        XCTAssertEqual("italic", MarkdownTextStorage(markdown: "/italic/").string)
        XCTAssertEqual("italic", MarkdownTextStorage(markdown: "_italic_").string)
        XCTAssertFalse(MarkdownTextStorage(markdown: "a_b_c_d").isItalicAtIndex(1))
        XCTAssertFalse(MarkdownTextStorage(markdown: "a_b_c_d").isItalicAtIndex(2))
        XCTAssertEqual("a_b_c_d", MarkdownTextStorage(markdown: "a_b_c_d").string)
    }

    func testBackslashEscape() {
        XCTAssertTrue(true)
    }
    
    func testNormalLinks() {
        XCTAssertTrue(count(MarkdownTextStorage(markdown: "[Link](http://www.kalliope.org/suburl/)").string) == 4)
        XCTAssertTrue(MarkdownTextStorage(markdown: "[XXX](http://www.kalliope.org/suburl/)  ").isLinkAtIndex(1))
    }
    
    func testRawLinks() {
        XCTAssertTrue(MarkdownTextStorage(markdown: "XXX http://www.kalliope.org/suburl/").isLinkAtIndex(5))
        XCTAssertTrue(MarkdownTextStorage(markdown: "http://www.kalliope.org/suburl/").isLinkAtIndex(5))
        XCTAssertTrue(MarkdownTextStorage(markdown: "https://www.kalliope.org/suburl/#anchor").isLinkAtIndex(5))
        XCTAssertFalse(MarkdownTextStorage(markdown: "(http://www.kalliope.org/suburl/").isLinkAtIndex(5))
    }

    func testIssueLinks() {
        println(MarkdownTextStorage(markdown: "#123").string)
        XCTAssertTrue(MarkdownTextStorage(markdown: "#123").isLinkAtIndex(0))
        XCTAssertFalse(MarkdownTextStorage(markdown: " #123 ").isLinkAtIndex(0))
        XCTAssertTrue(MarkdownTextStorage(markdown: " #123 ").isLinkAtIndex(1))
        XCTAssertTrue(MarkdownTextStorage(markdown: " #123 ").isLinkAtIndex(2))
        XCTAssertEqual("(#123)", MarkdownTextStorage(markdown: "(#123)").string, "Should keep prefix and postfix")
        XCTAssertEqual("#123?", MarkdownTextStorage(markdown: "#123?").string, "Should postfix")
        XCTAssertFalse(MarkdownTextStorage(markdown: "#acd").isLinkAtIndex(0))
        XCTAssertFalse(MarkdownTextStorage(markdown: "#123x").isLinkAtIndex(0))
        XCTAssertTrue(MarkdownTextStorage(markdown: "#123?").isLinkAtIndex(0))
    }

    func testCommitLinks() {
        XCTAssertTrue(MarkdownTextStorage(markdown: " deadbeef ").isLinkAtIndex(1))
        XCTAssertTrue(MarkdownTextStorage(markdown: "deadbeef").isLinkAtIndex(0))
        XCTAssertFalse(MarkdownTextStorage(markdown: " cafebabes ").isLinkAtIndex(1))
        XCTAssertTrue(count(MarkdownTextStorage(markdown: " deadbee ").string) == 9, "Should keep prefix and postfix")
        XCTAssertEqual("(deadbee)", MarkdownTextStorage(markdown: "(deadbeefcafebabe)").string, "Should keep prefix and postfix")
        XCTAssertTrue(count(MarkdownTextStorage(markdown: "cafebabedeadbeef").string) == 7, "Should truncate link text to 7 hex chars")
        XCTAssertFalse(MarkdownTextStorage(markdown: "deadbe").isLinkAtIndex(0), "Must be 7 hex chars to mach")
    }

}

extension MarkdownTextStorage {
    func isBoldAtIndex(index: Int) -> Bool {
        let attrs = attributesAtIndex(index, effectiveRange: nil)
        if let font = attrs[NSFontAttributeName] as? UIFont {
            
            return font.fontName.rangeOfString("Medium") != nil
        } else {
            return false
        }
        /*
        let traits = font.fontDescriptor().symbolicTraits
        let r = traits
        let b = UIFontDescriptorSymbolicTraits.TraitBold
        return (r & b) ? true : false
        */
    }
    
    func isItalicAtIndex(index: Int) -> Bool {
        let attrs = attributesAtIndex(index, effectiveRange: nil)
        if let font = attrs[NSFontAttributeName] as? UIFont {
            return font.fontName.rangeOfString("Italic") != nil
        } else {
            return false
        }
    }
    
    func isLinkAtIndex(index: Int) -> Bool {
        let attrs = attributesAtIndex(index, effectiveRange: nil)
        return attrs[NSLinkAttributeName] != nil
    }

}