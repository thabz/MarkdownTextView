![](https://travis-ci.org/thabz/MarkdownTextView.svg?branch=master)
# README

Display Markdown in a UITextView on iOS 8+ without converting to HTML first. 

## Features
* Handle asynchronous download of inline images.
* Handle most [GitHub](https://guides.github.com/features/mastering-markdown/) and [Bitbucket](https://confluence.atlassian.com/display/BITBUCKET/Mark+up+comments) extensions for basic Markdown.

## Usage 

Drag the `MarkdownTextStorage.swift` into your XCode project.
 
```swift
let markdown = "See [GitHub](https://github.com/)"
let storage = MarkdownTextStorage(markdown)
let textView = MarkdownTextView()
textView.markdownTextStorage = storage
subviews.append(textView)
```

## Contact

[@thabz](https://twitter.com/thabz) on Twitter.


## License

MarkdownTextView is licensed under the MIT License. See `LICENSE` for more information.
