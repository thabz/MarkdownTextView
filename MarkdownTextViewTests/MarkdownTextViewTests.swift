//
//  MarkdownTextViewTests.swift
//  MarkdownTextViewTests
//
//  Created by Jesper Christensen on 04/04/15.
//  Copyright (c) 2015 Jesper Christensen. All rights reserved.
//

import UIKit
import XCTest
import MarkdownTextViewKit

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
        XCTAssertTrue(MarkdownTextStorage(markdown: "__bold__").isBoldAtIndex(0))
        XCTAssertTrue(MarkdownTextStorage(markdown: "**bold**").isBoldAtIndex(0))
        XCTAssertFalse(MarkdownTextStorage(markdown: "*italic*").isBoldAtIndex(0))
        XCTAssertFalse(MarkdownTextStorage(markdown: "_italic_").isBoldAtIndex(0))
        XCTAssertEqual("bold", MarkdownTextStorage(markdown: "**bold**").string)
        XCTAssertEqual("bold", MarkdownTextStorage(markdown: "__bold__").string)
        XCTAssertEqual("🐞", MarkdownTextStorage(markdown: "__🐞__").string)
        XCTAssertEqual("🐞 bold", MarkdownTextStorage(markdown: "🐞 __bold__").string)
        XCTAssertEqual("🐞 bold 🐞", MarkdownTextStorage(markdown: "🐞 __bold__ 🐞").string)
        XCTAssertTrue(MarkdownTextStorage(markdown: "Z **bold**").isBoldAtIndex(2))
        XCTAssertTrue(MarkdownTextStorage(markdown: "🐞 **bold**").isBoldAtIndex(3))
        XCTAssertTrue(MarkdownTextStorage(markdown: "__b__ _i_").isBoldAtIndex(0))
        XCTAssertEqual("*bold*", MarkdownTextStorage(markdown: "\\*bold\\*").string)
    }

    func testItalic() {
        XCTAssertTrue(MarkdownTextStorage(markdown: "_italic_").isItalicAtIndex(0))
        XCTAssertTrue(MarkdownTextStorage(markdown: "*italic*").isItalicAtIndex(0))
        XCTAssertFalse(MarkdownTextStorage(markdown: "__bold__").isItalicAtIndex(0))
        XCTAssertFalse(MarkdownTextStorage(markdown: "**bold**").isItalicAtIndex(0))
        XCTAssertTrue(MarkdownTextStorage(markdown: "__b__ _i_").isItalicAtIndex(2))
        XCTAssertFalse(MarkdownTextStorage(markdown: "__b__ _i_").isItalicAtIndex(0))
        XCTAssertEqual("italic", MarkdownTextStorage(markdown: "_italic_").string)
        XCTAssertEqual("🐞", MarkdownTextStorage(markdown: "_🐞_").string)
        XCTAssertEqual("🐞 italic", MarkdownTextStorage(markdown: "🐞 _italic_").string)
        XCTAssertEqual("🐞 italic 🐞", MarkdownTextStorage(markdown: "🐞 _italic_ 🐞").string)
        XCTAssertTrue(MarkdownTextStorage(markdown: "🐞 *italic*").isItalicAtIndex(3))
        XCTAssertFalse(MarkdownTextStorage(markdown: "a_b_c_d").isItalicAtIndex(1))
        XCTAssertFalse(MarkdownTextStorage(markdown: "a_b_c_d").isItalicAtIndex(2))
        XCTAssertEqual("a_b_c_d", MarkdownTextStorage(markdown: "a_b_c_d").string)
        XCTAssertFalse(MarkdownTextStorage(markdown: "/italic/").isItalicAtIndex(0), "This is wiki italic. Not supported by either GitHub or Bitbucket.")
    }

    func testStrikethrough() {
        XCTAssertTrue(MarkdownTextStorage(markdown: "~~strikethrough~~").isStrikethroughAtIndex(0))
        XCTAssertFalse(MarkdownTextStorage(markdown: "~strikethrough~").isStrikethroughAtIndex(0))
        XCTAssertEqual("strikethrough", MarkdownTextStorage(markdown: "~~strikethrough~~").string)
        XCTAssertEqual("🐞strikethrough🐞", MarkdownTextStorage(markdown: "🐞~~strikethrough~~🐞").string)
        XCTAssertEqual("🐞", MarkdownTextStorage(markdown: "~~🐞~~").string)
        XCTAssertTrue(MarkdownTextStorage(markdown: "X ~~XX~~").isStrikethroughAtIndex(2))
        XCTAssertTrue(MarkdownTextStorage(markdown: "🐞 ~~XX~~").isStrikethroughAtIndex(3))
    }
    
    func testNormalLinks() {
        XCTAssertTrue(MarkdownTextStorage(markdown: "[Link](http://www.kalliope.org/suburl/)").string.characters.count == 4)
        let boldLink = MarkdownTextStorage(markdown: "[**Bold** link](http://www.kalliope.org/suburl/)")
        XCTAssertEqual("Bold link", boldLink.string)
        XCTAssertTrue(boldLink.isBoldAtIndex(0))
        XCTAssertTrue(boldLink.isLinkAtIndex(0))
        XCTAssertFalse(boldLink.isBoldAtIndex(6))
        XCTAssertTrue(boldLink.isLinkAtIndex(6))
        XCTAssertTrue(MarkdownTextStorage(markdown: "[XXX](http://www.kalliope.org/suburl/)  ").isLinkAtIndex(1))
        // The following test exposes issue #18. The "#3835772" part gets recognized as a commit sha which causes problems.
        XCTAssertTrue(MarkdownTextStorage(markdown: "[Static Overflow](http://stackoverflow.com/questions/1637332/static-const-vs-define/3835772#3835772)").string.rangeOfString(")") == nil)
        XCTAssertTrue(MarkdownTextStorage(markdown: "[Static Overflow](http://stackoverflow.com/questions/1637332/static-const-vs-define/3835772#383)").string.rangeOfString(")") == nil)
        XCTAssertEqual("]", MarkdownTextStorage(markdown: "[\\]](http://www.kalliope.org/)").string, "Escapes in links")
        XCTAssertEqual("🐞", MarkdownTextStorage(markdown: "[🐞](http://www.kalliope.org/)").string, "Emojis in links")
        XCTAssertEqual("🐞🐞", MarkdownTextStorage(markdown: "[🐞](http://www.kalliope.org/)🐞").string, "Emojis in links")
        XCTAssertEqual("🐞🐞🐞", MarkdownTextStorage(markdown: "🐞[🐞](http://www.kalliope.org/)🐞").string, "Emojis in links")
        XCTAssertEqual("🐞X🐞", MarkdownTextStorage(markdown: "🐞[X](http://www.kalliope.org/)🐞").string, "Emojis in links")
        XCTAssertTrue(MarkdownTextStorage(markdown: "[🐞](http://www.kalliope.org/)").isLinkAtIndex(0), "Emojis in links")
        XCTAssertTrue(MarkdownTextStorage(markdown: "A [🐞](http://www.kalliope.org/)").isLinkAtIndex(2), "Emojis in links")
        XCTAssertFalse(MarkdownTextStorage(markdown: "A [🐞](http://www.kalliope.org/)").isLinkAtIndex(1), "Emojis in links")
        XCTAssertTrue(MarkdownTextStorage(markdown: "🐞[A](http://www.kalliope.org/)").isLinkAtIndex(2), "This is the real culprit of a bunch of failing tests below")
        XCTAssertTrue(MarkdownTextStorage(markdown: "🐞 [A](http://www.kalliope.org/)").isLinkAtIndex(3), "This is the real culprit of a bunch of failing tests below")
        XCTAssertTrue(MarkdownTextStorage(markdown: "[A](http://www.kalliope.org/)🐞").isLinkAtIndex(0))
        XCTAssertEqual("...XXX...", MarkdownTextStorage(markdown: "...[XXX]( https://appsto.re/dk/VxQbN.i)...").string, "Leading whitespace in the URL part")
        XCTAssertEqual("...XXX...", MarkdownTextStorage(markdown: "...[XXX](\nhttps://appsto.re/dk/VxQbN.i)...").string, "Leading whitespace (newline) in the URL part")
        XCTAssertEqual("...XXX...", MarkdownTextStorage(markdown: "...[XXX]( https://appsto.re/dk/VxQbN.i )...").string, "Leading and trailing whitespace in the URL part")
    }
    
    func testRawLinks() {
        XCTAssertTrue(MarkdownTextStorage(markdown: "XXX http://www.kalliope.org/suburl/").isLinkAtIndex(5))
        XCTAssertTrue(MarkdownTextStorage(markdown: "http://www.kalliope.org/suburl/ http://www.kalliope.org/suburl/").isLinkAtIndex(5), "Two raw links side by side")
        XCTAssertTrue(MarkdownTextStorage(markdown: "http://www.kalliope.org/suburl/").isLinkAtIndex(5))
        XCTAssertTrue(MarkdownTextStorage(markdown: "https://www.kalliope.org/suburl/#anchor").isLinkAtIndex(5))
        XCTAssertFalse(MarkdownTextStorage(markdown: "(http://www.kalliope.org/suburl/").isLinkAtIndex(5))
        XCTAssertTrue(MarkdownTextStorage(markdown: "X https://www.kalliope.org/suburl/#anchor").isLinkAtIndex(2))
        XCTAssertEqual("🐞 https://www.kalliope.org/", MarkdownTextStorage(markdown: "🐞 https://www.kalliope.org/").string)
        XCTAssertEqual("🐞 https://www.kalliope.org/ 🐞", MarkdownTextStorage(markdown: "🐞 https://www.kalliope.org/ 🐞").string)
        XCTAssertTrue(MarkdownTextStorage(markdown: "🐞 https://www.kalliope.org/").isLinkAtIndex(3))
        XCTAssertTrue(MarkdownTextStorage(markdown: "https://www.kalliope.org/ 🐞").isLinkAtIndex(0))
        XCTAssertTrue(MarkdownTextStorage(markdown: "🐞 https://www.kalliope.org/suburl/#anchor").isLinkAtIndex(3))
        XCTAssertEqual("http://www.kalliope.org/suburl/", MarkdownTextStorage(markdown: "http://www.kalliope.org/suburl/").linkAtIndex(0) ?? "No link found")
        let linkInludingSha = MarkdownTextStorage(markdown: "http://stackoverflow.com/questions/1637332/static-const-vs-define/3835772#3835772")
        XCTAssertEqual("http://stackoverflow.com/questions/1637332/static-const-vs-define/3835772#3835772", linkInludingSha.linkAtIndex(0) ?? "No link found")
        XCTAssertEqual("http://stackoverflow.com/questions/1637332/static-const-vs-define/3835772#3835772", linkInludingSha.string)
        XCTAssertEqual(MarkdownTextStorage(markdown: "(http://www.kalliope.org/suburl)").string, "(http://www.kalliope.org/suburl)")
        XCTAssertEqual(MarkdownTextStorage(markdown: "A (http://www.kalliope.org/suburl/) B").string, "A (http://www.kalliope.org/suburl/) B")
        XCTAssertEqual(MarkdownTextStorage(markdown: "(See https://api.imgur.com/#authentication)").string, "(See https://api.imgur.com/#authentication)")
        XCTAssertEqual("https://www.branchesapp.co/", MarkdownTextStorage(markdown: "https://www.branchesapp.co/").linkAtIndex(0) ?? "No link found")
        XCTAssertEqual("https://www.branchesapp.co/test", MarkdownTextStorage(markdown: "https://www.branchesapp.co/test").linkAtIndex(0) ?? "No link found")
        XCTAssertEqual("https://www.branchesapp.co/test#test", MarkdownTextStorage(markdown: "https://www.branchesapp.co/test#test").linkAtIndex(0) ?? "No link found")
        XCTAssertEqual("https://www.branchesapp.co/", MarkdownTextStorage(markdown: "https://www.branchesapp.co/.").linkAtIndex(0) ?? "No link found")
        XCTAssertEqual("https://www.branchesapp.co/test", MarkdownTextStorage(markdown: "https://www.branchesapp.co/test.").linkAtIndex(0) ?? "No link found")
        XCTAssertEqual("https://www.branchesapp.co/test#test", MarkdownTextStorage(markdown: "https://www.branchesapp.co/test#test.").linkAtIndex(0) ?? "No link found")
        XCTAssertEqual("https://www.branchesapp.co/", MarkdownTextStorage(markdown: "https://www.branchesapp.co/,").linkAtIndex(0) ?? "No link found")
        XCTAssertEqual("https://www.branchesapp.co/test", MarkdownTextStorage(markdown: "https://www.branchesapp.co/test,").linkAtIndex(0) ?? "No link found")
        XCTAssertEqual("https://www.branchesapp.co/test#test", MarkdownTextStorage(markdown: "https://www.branchesapp.co/test#test,").linkAtIndex(0) ?? "No link found")
        XCTAssertEqual("https://www.branchesapp.co/.test", MarkdownTextStorage(markdown: "https://www.branchesapp.co/.test.").linkAtIndex(0) ?? "No link found")
    }

    func testUnicodeInRawLinks() {
        XCTAssertEqual("🐞 https://www.kalliope.org/", MarkdownTextStorage(markdown: "🐞 [https://www.kalliope.org/](https://www.kalliope.org/)").string)
        XCTAssertTrue(MarkdownTextStorage(markdown: "🐞 [XX](https://www.kalliope.org/)").isLinkAtIndex(3))
        XCTAssertTrue(MarkdownTextStorage(markdown: "🐞 [https://www.kalliope.org/](https://www.kalliope.org/)").isLinkAtIndex(3))
        XCTAssertTrue(MarkdownTextStorage(markdown: "🐞 https://www.kalliope.org/").isLinkAtIndex(3))
    }
    
    func testIssueLinks() {
        print(MarkdownTextStorage(markdown: "#123").string)
        XCTAssertTrue(MarkdownTextStorage(markdown: "#123").isLinkAtIndex(0))
        XCTAssertFalse(MarkdownTextStorage(markdown: " #123 ").isLinkAtIndex(0))
        XCTAssertTrue(MarkdownTextStorage(markdown: " #123 ").isLinkAtIndex(1))
        XCTAssertTrue(MarkdownTextStorage(markdown: " #123 ").isLinkAtIndex(2))
        XCTAssertTrue(MarkdownTextStorage(markdown: "X #123 ").isLinkAtIndex(2))
        XCTAssertTrue(MarkdownTextStorage(markdown: "🐞 #123 ").isLinkAtIndex(3))
        XCTAssertTrue(MarkdownTextStorage(markdown: "#123 🐞").isLinkAtIndex(0))
        XCTAssertTrue(MarkdownTextStorage(markdown: "🐞 #123 🐞").isLinkAtIndex(3))
        XCTAssertEqual("🐞 #123 🐞", MarkdownTextStorage(markdown: "🐞 #123 🐞").string)
        XCTAssertEqual("(#123)", MarkdownTextStorage(markdown: "(#123)").string, "Should keep prefix and postfix")
        XCTAssertEqual("#123?", MarkdownTextStorage(markdown: "#123?").string, "Should postfix")
        XCTAssertFalse(MarkdownTextStorage(markdown: "#acd").isLinkAtIndex(0))
        XCTAssertFalse(MarkdownTextStorage(markdown: "#123x").isLinkAtIndex(0))
        XCTAssertTrue(MarkdownTextStorage(markdown: "#123?").isLinkAtIndex(0))
    }

    func testCommitLinks() {
        XCTAssertTrue(MarkdownTextStorage(markdown: " deadbeef ").isLinkAtIndex(1))
        XCTAssertTrue(MarkdownTextStorage(markdown: "deadbeef").isLinkAtIndex(0))
        XCTAssertTrue(MarkdownTextStorage(markdown: "X deadbeef").isLinkAtIndex(2))
        XCTAssertTrue(MarkdownTextStorage(markdown: "🐞 deadbeef").isLinkAtIndex(3))
        XCTAssertFalse(MarkdownTextStorage(markdown: " cafebabes ").isLinkAtIndex(1))
        XCTAssertTrue(MarkdownTextStorage(markdown: " deadbee ").string.characters.count == 9, "Should keep prefix and postfix")
        XCTAssertEqual("(deadbee)", MarkdownTextStorage(markdown: "(deadbeefcafebabe)").string, "Should keep prefix and postfix")
        XCTAssertTrue(MarkdownTextStorage(markdown: "cafebabedeadbeef").string.characters.count == 7, "Should truncate link text to 7 hex chars")
        XCTAssertFalse(MarkdownTextStorage(markdown: "deadbe").isLinkAtIndex(0), "A recognized SHA is between 7 and 40 hex chars. Not 6.")
        XCTAssertTrue(MarkdownTextStorage(markdown: "1dafd76e861262f609db7786b64406101f942f53").isLinkAtIndex(0), "A recognized SHA is between 7 and 40 hex chars. Like 40.")
        XCTAssertFalse(MarkdownTextStorage(markdown: "1dafd76e861262f609db7786b64406101f942f530").isLinkAtIndex(0), "A recognized SHA is between 7 and 40 hex chars. Not 41.")
        
    }

    func testParagraphs() {
        XCTAssertEqual("Five Guy Burgers", MarkdownTextStorage(markdown: "Five\nGuy\nBurgers").string, "Should join lines.")
        XCTAssertEqual("Five Guy 🐞 Burgers", MarkdownTextStorage(markdown: "Five\nGuy 🐞\nBurgers").string, "Should join lines with emojis")
        XCTAssertEqual("🐞 Five Guy Burgers", MarkdownTextStorage(markdown: "🐞 Five\nGuy\nBurgers").string, "Should join lines with emojis")
    }
    
    func testInlineCode() {
        XCTAssertEqual("ABC", MarkdownTextStorage(markdown: "`ABC`").string)
        XCTAssertTrue(MarkdownTextStorage(markdown: "`ABC`").isMonospaceAtIndex(0))
        XCTAssertEqual("*ABC*", MarkdownTextStorage(markdown: "`*ABC*`").string)
        XCTAssertEqual("A *bold* B", MarkdownTextStorage(markdown: "A `*bold*` B").string)
        XCTAssertEqual("A *bold* B /italic/", MarkdownTextStorage(markdown: "A `*bold*` B `/italic/`").string)
        XCTAssertEqual("A *bold* B", MarkdownTextStorage(markdown: "A `*bold*` B").string)
        XCTAssertEqual("[Link](http://apple.com/)", MarkdownTextStorage(markdown: "`[Link](http://apple.com/)`").string)
        XCTAssertEqual("A [Link](http://apple.com/) B", MarkdownTextStorage(markdown: "A `[Link](http://apple.com/)` B").string)
        XCTAssertEqual("A🐞B🐞C", MarkdownTextStorage(markdown: "`A🐞B🐞C`").string)
        XCTAssertEqual("💣A🐞B🐞C💣", MarkdownTextStorage(markdown: "💣`A🐞B🐞C`💣").string)
        XCTAssertTrue(MarkdownTextStorage(markdown: "💣`ABC`").isMonospaceAtIndex(2))
        XCTAssertTrue(MarkdownTextStorage(markdown: "`ABC`💣").isMonospaceAtIndex(2))
        XCTAssertFalse(MarkdownTextStorage(markdown: "`ABC`💣").isMonospaceAtIndex(3))
    }
    
    func testBackslashEscaping() {
        XCTAssertEqual("*", MarkdownTextStorage(markdown: "\\*").string, "Basic escape")
        XCTAssertEqual("&", MarkdownTextStorage(markdown: "\\&").string, "Basic escape")
        XCTAssertEqual("X\\Y", MarkdownTextStorage(markdown: "X\\\\Y").string, "Backslash escapes")
        XCTAssertEqual("*", MarkdownTextStorage(markdown: "*\\**").string, "Escaped * inside italic marks")
        XCTAssertTrue(MarkdownTextStorage(markdown: "*\\**").isItalicAtIndex(0), "Escaped * inside italic marks")
        XCTAssertEqual("[]", MarkdownTextStorage(markdown: "\\[\\]").string, "Two escapes next to each other")
        XCTAssertFalse(MarkdownTextStorage(markdown: "\\*A\\*").isItalicAtIndex(0), "Escaped italic is not italic")
        XCTAssertEqual("\\*", MarkdownTextStorage(markdown: "`\\*`").string, "Don't escape in code sections")
        XCTAssertEqual("💣*🐞", MarkdownTextStorage(markdown: "💣\\*🐞").string, "Basic escape with emojis")
        XCTAssertEqual("💣*🐞", MarkdownTextStorage(markdown: "*💣\\*🐞*").string, "Basic escape with emojis in italic")
    }
    
    func testRawLinksInBrackets() {
        XCTAssertTrue(MarkdownTextStorage(markdown: "<http://www.kalliope.org/>").isLinkAtIndex(1))
        XCTAssertTrue(MarkdownTextStorage(markdown: "<http://www.kalliope.org/>").isLinkAtIndex(0))
        XCTAssertEqual("http://www.kalliope.org/", MarkdownTextStorage(markdown: "<http://www.kalliope.org/>").string)
        XCTAssertTrue("http://www.kalliope.org/" == MarkdownTextStorage(markdown: "<http://www.kalliope.org/>").linkAtIndex(0))
        XCTAssertEqual("X http://www.kalliope.org/", MarkdownTextStorage(markdown: "X <http://www.kalliope.org/>").string)
    }

    func testNormalLinksWithURLInBrackets() {
        XCTAssertTrue(MarkdownTextStorage(markdown: "[XX](<http://www.kalliope.org/>)").isLinkAtIndex(0))
        XCTAssertEqual("XX", MarkdownTextStorage(markdown: "[XX](<http://www.kalliope.org/>)").string)
        XCTAssertTrue("http://www.kalliope.org/" == MarkdownTextStorage(markdown: "[XX](<http://www.kalliope.org/>)").linkAtIndex(0))
        XCTAssertEqual("X XX", MarkdownTextStorage(markdown: "X [XX](<http://www.kalliope.org/>)").string)
    }
    
    func testRemovingDoubleSpaces() {
        XCTAssertEqual("A B C", MarkdownTextStorage(markdown: "A  B  C").string)
        XCTAssertEqual("A B C", MarkdownTextStorage(markdown: "A  B \nC").string)
        XCTAssertEqual("A B C", MarkdownTextStorage(markdown: "**A  B  C**").string)
        XCTAssertEqual("A B C", MarkdownTextStorage(markdown: "[A  B  C](http://www.kalliope.org/)").string, "Spaces in links")
        XCTAssertEqual("A  B  C D", MarkdownTextStorage(markdown: "`A  B  C D`").string)
    }
    
    func testHTMLEntityEscapes() {
        XCTAssertEqual("Blåbærgrød", MarkdownTextStorage(markdown: "Bl&aring;b&aelig;rgr&oslash;d").string)
        XCTAssertEqual("← ⇐", MarkdownTextStorage(markdown: "&larr; &lArr;").string, "Beyond ASCII")
        XCTAssertEqual("∞", MarkdownTextStorage(markdown: "*&infin;*").string, "Inside italic")
        XCTAssertTrue(MarkdownTextStorage(markdown: "*&infin;*").isItalicAtIndex(0), "Inside italic")
        XCTAssertEqual("&times;", MarkdownTextStorage(markdown: "\\&times;").string, "Escaping")
        XCTAssertEqual("&times;", MarkdownTextStorage(markdown: "`&times;`").string, "No entity escaping inside code blocks")
        XCTAssertEqual("&xxxxxx;", MarkdownTextStorage(markdown: "&xxxxxx;").string, "Unrecognized entity escape")
        XCTAssertEqual("AT&T", MarkdownTextStorage(markdown: "[AT&amp;T](http://www.att.com/)").string, "HTML escapes in links")
    }
    
    func testEmojiSynonyms() {
        XCTAssertEqual("A 💣 B", MarkdownTextStorage(markdown: "A :bomb: B").string)
        XCTAssertEqual("💣🐞", MarkdownTextStorage(markdown: ":bomb::beetle:").string)
        XCTAssertEqual("\\💣", MarkdownTextStorage(markdown: "\\:bomb:").string, "No backslash escaping")
        XCTAssertEqual(":💣:🐞:", MarkdownTextStorage(markdown: "::bomb:::beetle::").string)
        XCTAssertEqual("👍👎", MarkdownTextStorage(markdown: ":+1::-1:").string, "Reg exp escaping")
        XCTAssertEqual("A💣B", MarkdownTextStorage(markdown: "*A:bomb:B*").string, "Inside italic")
        XCTAssertTrue(MarkdownTextStorage(markdown: "*:bomb:*").isItalicAtIndex(0), "Inside italic")
        XCTAssertEqual("X:bomb:Y", MarkdownTextStorage(markdown: "`X:bomb:Y`").string, "No emoji synonyms inside code blocks")
        XCTAssertEqual(":xxxxxx:", MarkdownTextStorage(markdown: ":xxxxxx:").string, "Unrecognized emoji synonym")
        XCTAssertEqual(":bombs:", MarkdownTextStorage(markdown: ":bombs:").string, "Unrecognized emoji synonym")
        XCTAssertEqual("A💣B", MarkdownTextStorage(markdown: "[A:bomb:B](http://www.att.com/)").string, "Emojis synonyms in links")
    }
}

extension MarkdownTextStorage {
    func isBoldAtIndex(index: Int) -> Bool {
        let attrs = attributesAtIndex(index, effectiveRange: nil)
        if let font = attrs[NSFontAttributeName] as? UIFont {
            let traits = font.fontDescriptor().symbolicTraits
            return traits.contains(.TraitBold)
        } else {
            return false
        }
    }
    
    func isItalicAtIndex(index: Int) -> Bool {
        let attrs = attributesAtIndex(index, effectiveRange: nil)
        if let font = attrs[NSFontAttributeName] as? UIFont {
            let traits = font.fontDescriptor().symbolicTraits
            return traits.contains(.TraitItalic)
        } else {
            return false
        }
    }

    func isMonospaceAtIndex(index: Int) -> Bool {
        let attrs = attributesAtIndex(index, effectiveRange: nil)
        if let font = attrs[NSFontAttributeName] as? UIFont {
            let traits = font.fontDescriptor().symbolicTraits
            return traits.contains(.TraitMonoSpace)
        } else {
            return false
        }
    }

    func isLinkAtIndex(index: Int) -> Bool {
        let attrs = attributesAtIndex(index, effectiveRange: nil)
        return attrs[NSLinkAttributeName] != nil
    }

    func isStrikethroughAtIndex(index: Int) -> Bool {
        let attrs = attributesAtIndex(index, effectiveRange: nil)
        return attrs[NSStrikethroughStyleAttributeName] != nil
    }

    
    func linkAtIndex(index: Int) -> String? {
        let attrs = attributesAtIndex(index, effectiveRange: nil)
        return attrs[NSLinkAttributeName] as? String
    }

}