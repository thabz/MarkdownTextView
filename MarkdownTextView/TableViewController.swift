//
//  TableViewController.swift
//  MarkdownTextView
//
//  Created by Jesper Christensen on 13/04/15.
//  Copyright (c) 2015 Jesper Christensen. All rights reserved.
//

import UIKit
import MarkdownTextViewKit

class TableViewController: UITableViewController {

    let markdownTexts = [[
        "Paragrah",
        "### Header between",
        "Paragraph"
        ],[
        "Go download 💣 [RayGay on GitHub](https://github.com/thabz/RayGay) if you're into raytracing.",
        "",
        "An `NSAttributedString` spread over multiple lines. ",
        "A section spread over multiple lines. ",
        ],[
            "A checked list",
            "- [x] Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.",
            "- [ ] Line two. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.",
            "- [X] Line.",
            "With a new paragraph after"
        ],[
            "#   Short headline with [link](http://www.apple.com)",
        ],[
        "###   Short headline. ### ",
        "* Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.",
        "- Link to commit deadbeef and issue #1. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.",
        "+ Line.",
        "There should be nice spacing between this paragrah and the list above.",
            "",
            "And a slight text after. There should be nice spacing between this paragrah and the list above."
        ],[
            "#### Demonstrating quotes",
            "> Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.",
            "> Link to commit 💣 deadbeef and issue 💣 #1.",
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
        "Normal, **bold**, ~~strikethrough~~, __bold__, _italic_ and *italic*.",
        "",
        "1. First item",
        "2. Second item",
            "1. First item",
            "2. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.",
            "1. First item",
            "2. Second item",
            "1. First item",
            "2. Second item",
            "1. First item",
            "2. Second item",
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
        let fontSize = CGFloat(13)
        let boldFont = UIFont.boldSystemFont(ofSize: fontSize)
        return [
            MarkdownStylesName.normal: [NSFontAttributeName: UIFont.systemFont(ofSize: fontSize)],
            MarkdownStylesName.bold: [NSFontAttributeName: boldFont],
            MarkdownStylesName.italic: [NSFontAttributeName: UIFont.italicSystemFont(ofSize: fontSize)],
            MarkdownStylesName.quote: [NSFontAttributeName: UIFont.systemFont(ofSize: fontSize), NSForegroundColorAttributeName: UIColor.gray],
            MarkdownStylesName.monospace: [NSFontAttributeName: UIFont(name: "Menlo-Regular", size: fontSize-2)!],
            MarkdownStylesName.headline: [NSFontAttributeName: boldFont],
            MarkdownStylesName.subheadline: [NSFontAttributeName: boldFont],
            MarkdownStylesName.subsubheadline: [NSFontAttributeName: boldFont],
            MarkdownStylesName.subsubsubheadline: [NSFontAttributeName: boldFont]]
    }()
    
    var markdownTextStorages = [MarkdownTextStorage]()

    override func viewDidLoad() {
        super.viewDidLoad()
        for section in markdownTexts {
            let markdown = section.joined(separator: "\n")
            let markdownTextStorage = MarkdownTextStorage(markdown: markdown, styles: defaultStyles)
            markdownTextStorages.append(markdownTextStorage)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

    // MARK: - Table view data source

    override func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return 100
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableViewAutomaticDimension
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return markdownTexts.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "MarkdownCell", for: indexPath) as! MarkdownCell
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
