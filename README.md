# AMP WP Theme Compatability Analysis - GitHub Action

[![Project Status: Active – The project has reached a stable, usable state and is being actively developed.](https://www.repostatus.org/badges/latest/active.svg)](https://www.repostatus.org/#active)

A [GitHub Action](https://github.com/features/actions) to add AMP Theme Compatability Analysis on pull requests as a comment to depict the comptaibility change percentages by that PR vs base branch. It is based on [amp-wp-theme-compat-analysis](https://github.com/westonruter/amp-wp-theme-compat-analysis/).

The action does this following:

1. Analysis is done on pull request for the theme(s) that are involved in it. 
2. Analysis is done against the changes in pull request as well as the base branch of the pull request.
3. It is posted as a comment and only for the theme being updated in the pull request.
4. If the Pull request is updated, i.e., new commits are added, then analysis will be re-computed and the comment will be updated with the latest commit's data.

This action requires the repository in a certain way, it needs to have all the themes in parent directory of the repository, like [this](https://github.com/rtCamp/themes) repository.

## Usage

1. Create a `.github/workflows/amp-analysis.yml` in your GitHub repo, if one doesn't exist already.
2. Add the following code to the `amp-analysis.yml` file.

```yaml
on: pull_request

name: Run amp-theme-compat-analysis
jobs:
  Run-amp-theme-compat-analysis:
    name: Run amp-theme-compat-analysis
    runs-on: ubuntu-18.04
    steps:
    - name: Checkout PR
      uses: actions/checkout@v2
      with:
        ref: ${{ github.event.pull_request.head.sha }}
        path: main
    - name: Checkout Base Branch
      uses: actions/checkout@v2
      with:
        ref: ${{ github.event.pull_request.base.sha }}
        path: base
    - name: Run amp-theme-compat-analysis
      uses: rtCamp/action-amp-wp-theme-compat-analysis@master
      env:
        GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

## Screenshot

**AMP WP Theme Compatability Analysis in action**

<img width="560" alt="AMP WP Theme Compatability Analysis" src="https://user-images.githubusercontent.com/25586785/81568541-89e6e780-93bb-11ea-9746-a45a610530b2.png">

## License

[MIT](LICENSE) © 2019 rtCamp

## Does this interest you?

<a href="https://rtcamp.com/"><img src="https://rtcamp.com/wp-content/uploads/2019/04/github-banner@2x.png" alt="Join us at rtCamp, we specialize in providing high performance enterprise WordPress solutions"></a>
