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