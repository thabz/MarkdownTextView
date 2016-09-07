//
//  ViewController.swift
//  MarkdownTextView
//
//  Created by Jesper Christensen on 04/04/15.
//  Copyright (c) 2015 Jesper Christensen. All rights reserved.
//

import UIKit
import MarkdownTextViewKit

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
            "",
            "With some text directly under it. ",
            "Normal, *italic*, ~~strikethrough~~, __bold__ and _italic_.",
            "",
            "1. First item",
            "2. Second item",
            ""
        ]
        let joinedMarkdown = markdownExample.joined(separator: "\n")
        
        textStorage = MarkdownTextStorage(markdown: joinedMarkdown)
  
        textView.attributedText = NSAttributedString(string: "")
        
//        setUpReusedLayoutManager()
//        setUpAttributedString()
//        setUpNewTextView()
        setUpWithNotifications()
    }


    func setUpNewTextView() {
        
        let layoutManager = NSLayoutManager()
        textStorage?.addLayoutManager(layoutManager)
        
        let containerSize = CGSize(width: self.view.bounds.size.width, height: CGFloat.greatestFiniteMagnitude)
        let textContainer = NSTextContainer(size: containerSize)
        textContainer.widthTracksTextView = true
        textContainer.heightTracksTextView = true
        layoutManager.addTextContainer(textContainer)
        
        let newTextView = UITextView(frame: (self.view.bounds).insetBy(dx: 0, dy: 0), textContainer: textContainer)
        newTextView.backgroundColor = UIColor.green
        newTextView.isEditable = false
        view.addSubview(newTextView)
        
        self.textView.isHidden = true
    }
    
    func setUpAttributedString() {
        textView.attributedText = textStorage
    }
    
    func setUpReusedLayoutManager() {
        let layoutManager = textView.layoutManager
        let existingTextStorage = layoutManager.textStorage
        existingTextStorage?.removeLayoutManager(layoutManager)
        textStorage?.addLayoutManager(layoutManager)

        //textView.attributedText = textStorage
    }
    
    func setUpWithNotifications() {
        let markdownTextView = MarkdownTextView(frame: self.view.bounds)
        markdownTextView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        markdownTextView.isEditable = false
        markdownTextView.markdownTextStorage = textStorage
        view.addSubview(markdownTextView)
        self.textView.isHidden = true
    }
}

