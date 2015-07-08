# Usage 

Drag the `MarkdownTextStorage.swift` into your XCode project.
 
```swift
let markdown = "See [GitHub](https://github.com/)"
let storage = MarkdownTextStorage(markdown)
let textView = MarkdownTextView()
textView.markdownTextStorage = storage
subviews.append(textView)
```

# Links

* [GitHub flavoured Markdown](https://guides.github.com/features/mastering-markdown/)
* [Bitbucket flavoured Markdown](https://confluence.atlassian.com/display/BITBUCKET/Mark+up+comments)

Besides a few extensions, detection of links to commits and issues, Bitbucket is using [Python Markdown](https://pypi.python.org/pypi/Markdown) which is compliant to [John Gruber's Markdown](http://daringfireball.net/projects/markdown/)

