//
//  TableViewController.swift
//  MarkdownTextView
//
//  Created by Jesper Christensen on 13/04/15.
//  Copyright (c) 2015 Jesper Christensen. All rights reserved.
//

import UIKit

class TableViewController: UITableViewController {

    let markdownTexts = [[
        "Go download [RayGay on GitHub](https://github.com/thabz/RayGay) if you're into raytracing.",
        "",
        "An `NSAttributedString` spread over multiple lines. ",
        "A section spread over multiple lines. ",
        ],[
        "Short line.",
        "* Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.",
        "* Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.",
        ""
        ],[
        "```",
        "func square(x) { ",
        "    // Simple square func!",
        "    return x * x",
        "}",
        "```",
        ],[
        "",
        "![An image](http://www.kalliope.org/gfx/icons/iphone-icon.png)",
        "",
        "With some text directly under it. ",
        ],[
        
        "Normal, *bold*, ~~strikethrough~~, __underline__ and /italic/.",
        "",
        "1. First item",
        "2. Second item",
        ""
        ]]
    let font = UIFont.systemFontOfSize(13)
    let italicFont = UIFont.italicSystemFontOfSize(13)
    let boldFont = UIFont.boldSystemFontOfSize(13)
    let monospaceFont = UIFont(name: "Menlo-Regular", size: 11)!

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    // MARK: - Table view data source

    override func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        return UITableViewAutomaticDimension
    }
    
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let rows = markdownTexts.count
        println("Rows", rows)
        return rows
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("MarkdownCell", forIndexPath: indexPath) as! MarkdownCell
        let markdown = "\n".join(markdownTexts[indexPath.row])
        println("Markdown:", markdown)
        let markdownTextStorage = MarkdownTextStorage(markdown: markdown, font: font, monospaceFont: monospaceFont, boldFont: boldFont, italicFont: italicFont, color: UIColor.blackColor())
        cell.markdownTextView.markdownTextStorage = markdownTextStorage
        return cell
    }
}

class MarkdownCell : UITableViewCell {
    @IBOutlet weak var markdownTextView: MarkdownTextView!
}
