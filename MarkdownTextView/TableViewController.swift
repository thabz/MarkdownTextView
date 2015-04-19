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
            "- [x] Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.",
            "- [ ] Line two",
            "- [X] Line three",
        ],[
        "###   Short headline. ### ",
        "* Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.",
        "- Link to commit deadbeef and issue #1.",
        "+ Line three",
        ],[
            "#### Demonstrating quotes",
            "> Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.",
            "> Link to commit deadbeef and issue #1.",
            "And this marks the end of the quote section."
        ],[
            "Examples from /Apple Mail/ on OS X:",
            "",
            "![skaermbillede 2015-03-19 kl 10 11 35](https://cloud.githubusercontent.com/assets/157777/6727236/752598ac-ce20-11e4-8f1d-6bd7536caa01.png)",
            "![skaermbillede 2015-03-19 kl 10 11 44](https://cloud.githubusercontent.com/assets/157777/6727235/75223612-ce20-11e4-8aac-f5bfb2d4dcd7.png)"
        ],[
        "```",
        "func square(x) { ",
        "    // Simple square func!",
        "    return x * x",
        "}",
        "```",
        ],[
        "![An image](http://www.kalliope.org/gfx/icons/iphone-icon.png) ",
        "![An image](http://www.kalliope.org/gfx/icons/iphone-icon.png)",
        "",
        "With some text directly under it. ",
        ],[
        "Normal, *bold*, ~~strikethrough~~, __bold__, _italic_ and /italic/.",
        "",
        "1. First item",
        "2. Second item",
        "",
        "And a small final paragraph, that should span a couple of lines if all goes according to plan. ",
        "Also it contains a raw URL http://www.kalliope.org/page/ inline"
        ],[
            "![An image](http://www.kalliope.org/gfx/icons/iphone-icon.png) ",
            "![An image](http://www.kalliope.org/gfx/icons/iphone-icon.png)",
            "",
            "With some text directly under it. ",
        ],[
            "An a simple single line. ",
            "An a simple single line. ",
            "An a simple single line. ",
        ]
    ]

    var defaultStyles: StylesDict = {
        let fontSize = CGFloat(10)
        let boldFont = UIFont.boldSystemFontOfSize(fontSize)
        return [
            MarkdownStylesName.Normal: [NSFontAttributeName: UIFont.systemFontOfSize(fontSize)],
            MarkdownStylesName.Bold: [NSFontAttributeName: boldFont],
            MarkdownStylesName.Italic: [NSFontAttributeName: UIFont.italicSystemFontOfSize(fontSize)],
            MarkdownStylesName.Quote: [NSFontAttributeName: UIFont.systemFontOfSize(fontSize), NSForegroundColorAttributeName: UIColor.grayColor()],
            MarkdownStylesName.Monospace: [NSFontAttributeName: UIFont(name: "Menlo-Regular", size: fontSize-2)!],
            MarkdownStylesName.Headline: [NSFontAttributeName: boldFont],
            MarkdownStylesName.Subheadline: [NSFontAttributeName: boldFont],
            MarkdownStylesName.Subsubheadline: [NSFontAttributeName: boldFont],
            MarkdownStylesName.Subsubsubheadline: [NSFontAttributeName: boldFont]]
    }()
    
    var markdownTextStorages = [MarkdownTextStorage]()

    override func viewDidLoad() {
        super.viewDidLoad()
        for section in markdownTexts {
            let markdown = "\n".join(section)
            let markdownTextStorage = MarkdownTextStorage(markdown: markdown, styles: defaultStyles)
            markdownTextStorages.append(markdownTextStorage)
        }
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
    }

    // MARK: - Table view data source

    override func tableView(tableView: UITableView, estimatedHeightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        return 100
    }
    
    override func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        return UITableViewAutomaticDimension
    }
    
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return markdownTexts.count
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("MarkdownCell", forIndexPath: indexPath) as! MarkdownCell
        cell.markdownTextView.tableView = self.tableView
        cell.markdownTextView.markdownTextStorage = markdownTextStorages[indexPath.row]
        return cell
    }
}

class MarkdownCell : UITableViewCell {
    @IBOutlet weak var markdownTextView: MarkdownTextView!
    
    override func prepareForReuse() {
        markdownTextView.markdownTextStorage = nil
        super.prepareForReuse()
    }
}
