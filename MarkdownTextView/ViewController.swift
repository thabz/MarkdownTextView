//
//  ViewController.swift
//  MarkdownTextView
//
//  Created by Jesper Christensen on 04/04/15.
//  Copyright (c) 2015 Jesper Christensen. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    @IBOutlet weak var textView: UITextView!
    var textStorage: MarkdownTextStorage?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        let markdownExample = [
            "Go download [RayGay on GitHub](https://github.com/thabz/RayGay) if you're into raytracing.",
            "",
            "An `NSAttributedString` spread over multiple lines. ",
            "A section spread over multiple lines. ",
            "",
            "Short line.",
            "* Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.",
            "* Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.",
            "",
            "```",
            "func square(x) { ",
            "    // Simple square func!",
            "    return x * x",
            "}",
            "```",
            "",
            "![An image](http://www.kalliope.org/gfx/icons/iphone-icon.png)",
            "With some text directly under it. ",
            "Normal, *bold*, ~~strikethrough~~, __underline__ and /italic/.",
            "",
            "1. First item",
            "2. Second item",
            ""
        ]
        let font = UIFont.systemFontOfSize(13)
        let italicFont = UIFont.italicSystemFontOfSize(13)
        let boldFont = UIFont.boldSystemFontOfSize(13)
        let monospaceFont = UIFont(name: "Menlo-Regular", size: 11)!
        let joinedMarkdown = "\n".join(markdownExample)
        
        textStorage = MarkdownTextStorage(markdown: joinedMarkdown, font: font, monospaceFont: monospaceFont, boldFont: boldFont, italicFont: italicFont, color: UIColor.blackColor())
        
        setUpAttributedString()
//        setUpNewTextView()
    }


    func setUpNewTextView() {
        
        var layoutManager = NSLayoutManager()
        textStorage?.addLayoutManager(layoutManager)
        
        let containerSize = CGSizeMake(self.view.bounds.size.width, CGFloat.max)
        let textContainer = NSTextContainer(size: containerSize)
        textContainer.widthTracksTextView = true
        textContainer.heightTracksTextView = true
        layoutManager.addTextContainer(textContainer)
        
        var newTextView = UITextView(frame: CGRectInset(self.view.bounds, 0, 0), textContainer: textContainer)
        newTextView.backgroundColor = UIColor.greenColor()
        newTextView.editable = false
        view.addSubview(newTextView)
        
        self.textView.hidden = true
    }
    
    func setUpAttributedString() {
        textView.attributedText = textStorage
    }
}

