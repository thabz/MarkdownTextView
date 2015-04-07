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
            "A section spread over multiple lines. ",
            "A section spread over multiple lines. ",
            "",
            "Short line.",
            "* Normal group",
            "* Placebo group",
            "",
            "```",
            "func square(x) { ",
            "    // Simple square func",
            "    // Simple square func",
            "    return x * x",
            "}",
            "```",
            "",
            "Normal, *bold* and /italic/."
        ]
        let font = UIFont.systemFontOfSize(13)
        let italicFont = UIFont.italicSystemFontOfSize(13)
        let boldFont = UIFont.boldSystemFontOfSize(13)
        let monospaceFont = UIFont(name: "Menlo-Regular", size: 11)!
        let joinedMarkdown = "\n".join(markdownExample)
        textView.attributedText = NSAttributedString.attributedStringFromMarkdown(joinedMarkdown, font: font, monospaceFont: monospaceFont, boldFont: boldFont, italicFont: italicFont, color: UIColor.blackColor())
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

