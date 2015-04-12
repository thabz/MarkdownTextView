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
            "    // Simple square func",
            "    // Simple square func",
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
        
        let myTextStorage = MarkdownTextStorage(markdown: joinedMarkdown, font: font, monospaceFont: monospaceFont, boldFont: boldFont, italicFont: italicFont, color: UIColor.blackColor())
        
//            let containerSize = CGSizeMake(textView.bounds.size.width, CGFloat.max)
//            let textContainer = NSTextContainer(size: containerSize)
//            textContainer.widthTracksTextView = true
//            var layoutManager = self.textView.layoutManager
//            layoutManager.addTextContainer(textContainer)
//            myTextStorage.addLayoutManager(layoutManager)

        textView.attributedText = myTextStorage
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

