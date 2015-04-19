# README #

* [GitHub flavoured Markdown](https://guides.github.com/features/mastering-markdown/)
* [Bitbucket flavoured Markdown](https://confluence.atlassian.com/display/BITBUCKET/Mark+up+comments)

Besides a few extensions, detection of links to commits and issues, Bitbucket is using [Python Markdown](https://pypi.python.org/pypi/Markdown) which is compliant to [John Gruber's Markdown](http://daringfireball.net/projects/markdown/)


### Manually

It is not recommended to install the framework manually, but if you prefer not to use either of the aforementioned dependency managers, you can integrate Kingfisher into your project manually. A regular way to use Kingfisher in your project would be using Embedded Framework.

- Add MarkdownTextView as a [submodule](http://git-scm.com/docs/git-submodule). In your favorite terminal, `cd` into your top-level project directory, and entering the following command:

```bash
$ git submodule add https://github.com/thabz/MarkdownTextView.git
```

- Open the `MarkdownTextView` folder, and drag `MarkdownTextView.xcodeproj` into the file navigator of your app project, under your app project.
- In Xcode, navigate to the target configuration window by clicking on the blue project icon, and selecting the application target under the "Targets" heading in the sidebar.
- In the tab bar at the top of that window, open the "Build Phases" panel.
- Expand the "Target Dependencies" group, and add `MarkdownTextView.framework`.
- Click on the `+` button at the top left of tdemohe panel and select "New Copy Files Phase". Rename this new phase to "Copy Frameworks", set the "Destination" to "Frameworks", and add `MarkdownTextView.framework`.
