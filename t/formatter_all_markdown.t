#!/usr/bin/perl -w
# Comprehensive/chained test of formatters, with the main formatter set to MultiMarkdown
use Test::More tests => 27;
use HTTP::Request::Common;
use Test::Differences;

my $original_formatter;    # current formatter set up in mojomojo.db
my $c;                     # the Catalyst object of this live server
my $test;                  # test description

BEGIN {
    $ENV{CATALYST_CONFIG} = 't/var/mojomojo.yml';
    use_ok 'MojoMojo::Formatter::Markdown';
    use_ok 'Catalyst::Test', 'MojoMojo';
}

END {
    ok( $c->pref( main_formatter => $original_formatter ),
        'restore original formatter' );
    done_testing;
}

( undef, $c ) = ctx_request('/');
ok( $original_formatter = $c->pref('main_formatter'),
    'save original formatter' );

ok( $c->pref( main_formatter => 'MojoMojo::Formatter::Markdown' ),
    'set preferred formatter to Markdown' );

#-------------------------------------------------------------------------------
$test = "empty body";
my $content = '';
my $body = get( POST '/.jsrpc/render', [ content => $content ] );
is( $body, 'Please type something', $test );


#-------------------------------------------------------------------------------
$test    = 'headings';
$content = <<'MARKDOWN';
# Heading 1
paragraph
## Heading 2
MARKDOWN
$body = get( POST '/.jsrpc/render', [ content => $content ] );
eq_or_diff( $body, <<'HTML', $test );
<h1>Heading 1</h1>

<p>paragraph</p>

<h2>Heading 2</h2>
HTML


#-------------------------------------------------------------------------------
$test = 'direct <http://url.com> hyperlinks';
$content = <<'MARKDOWN';
This should be linked: <http://mojomojo.org>.
MARKDOWN
$body = get( POST '/.jsrpc/render', [ content => $content ] );
eq_or_diff( $body, <<'HTML', $test );
<p>This should be linked: <a href="http://mojomojo.org">http://mojomojo.org</a>.</p>
HTML


#-------------------------------------------------------------------------------
$test = '<span>s need to be kept because they are the only way to specify text attributes';
$content = <<'MARKDOWN';
Print media uses <span style="font-family: Times New Roman">Times New Roman</span> fonts.
MARKDOWN
$body = get( POST '/.jsrpc/render', [ content => $content ] );
is( $body, <<HTML, $test );
<p>Print media uses <span style="font-family: Times New Roman">Times New Roman</span> fonts.</p>
HTML


#-------------------------------------------------------------------------------
$test = 'HTML entities must be preserved in code sections';
$content = <<'MARKDOWN';
Here's some code:

    1 < 2 && '4' > "3" &trade;

The 5 predefined XML entities must be escaped accordingly.
MARKDOWN
$body = get( POST '/.jsrpc/render', [ content => $content ] );
eq_or_diff( $body, <<'HTML', $test );
<p>Here's some code:</p>

<pre><code>1 &lt; 2 &amp;&amp; '4' &gt; "3" &amp;trade;
</code></pre>

<p>The 5 predefined XML entities must be escaped accordingly.</p>
HTML


#-------------------------------------------------------------------------------
$test = 'apparent HTML tags in Markdown code sections must be rendered verbatim';
$content = <<'MARKDOWN';
This is a Config::General example:

    <foo>
        <script>yes, even scripts must be left alone</script>
    </foo>

Ensure no angle brackets were stripped.
MARKDOWN
$body = get( POST '/.jsrpc/render', [ content => $content ] );
eq_or_diff( $body, <<'HTML', $test );
<p>This is a Config::General example:</p>

<pre><code>&lt;foo&gt;
    &lt;script&gt;yes, even scripts must be left alone&lt;/script&gt;
&lt;/foo&gt;
</code></pre>

<p>Ensure no angle brackets were stripped.</p>
HTML


#-------------------------------------------------------------------------------
$test = "don't escape the HTML of syntax highlighting";
$content = <<'MARKDOWN';
This is how you highlight HTML:

<pre lang="HTML">
HTML <b>text</b> here with some <div>tags</div>.
</pre>

HTML formatting generated by the SyntaxHighlight formatter must not be escaped by Markdown
MARKDOWN
$body = get( POST '/.jsrpc/render', [ content => $content ] );
eq_or_diff( $body, <<'HTML', $test );
<p>This is how you highlight HTML:</p>

<pre>
HTML&nbsp;<b>&lt;b&gt;</b>text<b>&lt;/b&gt;</b>&nbsp;here&nbsp;with&nbsp;some&nbsp;<b>&lt;div&gt;</b>tags<b>&lt;/div&gt;</b>.
</pre>

<p>HTML formatting generated by the SyntaxHighlight formatter must not be escaped by Markdown</p>
HTML


#-------------------------------------------------------------------------------
TODO: {
    local $TODO = "priority of wiki link interpretation must be tweak with regards to <pre>";
    $test    = "no wiki link hyperlinking in multi-line <pre> sections";
    $content = <<'MARKDOWN';
<pre lang="Perl">
# A comment, not a heading
[this isn't](a link)
[[this isn't a wikilink]]

|| this is not | a table ||
|| this is | a <pre> element ||
</pre>
MARKDOWN
$body = get( POST '/.jsrpc/render', [ content => $content ] );
    eq_or_diff( $body, <<'HTML', $test );
<pre><span class="kateComment"><i>#&nbsp;A&nbsp;comment,&nbsp;not&nbsp;a&nbsp;heading</i></span><span class="kateComment"><i>
</i></span>[this&nbsp;isn<span class="kateOperator">'</span><span class="kateString">t](a&nbsp;link)</span><span class="kateString">
</span><span class="kateString">[[this&nbsp;isn</span><span class="kateOperator">'</span>t&nbsp;a&nbsp;wikilink]]

||&nbsp;this&nbsp;is&nbsp;<span class="kateOperator">not</span>&nbsp;|&nbsp;a&nbsp;table&nbsp;||
||&nbsp;this&nbsp;is&nbsp;|&nbsp;a&nbsp;&lt;pre&gt;&nbsp;element&nbsp;||

</pre>
HTML
}

#----------------------------------------------------------------------------
$test  = '<div> with HTML attribute in a code span';
$content = <<'MARKDOWN';
This is the code: `<div class="content">`.
MARKDOWN
$body = get( POST '/.jsrpc/render', [ content => $content ] );
eq_or_diff( $body, <<'HTML', $test );
<p>This is the code: <code>&lt;div class="content"&gt;</code>.</p>
HTML


$test = '<div> with non-standard HTML attribute> in a code span - the HTML scrubber should leave this alone';
$content = <<'MARKDOWN';
This quoted div has an ARIA role attribute: `<div role="content">`.
MARKDOWN
$body = get( POST '/.jsrpc/render', [ content => $content ] );
eq_or_diff( $body, <<'HTML', $test );
<p>This quoted div has an ARIA role attribute: <code>&lt;div role="content"&gt;</code>.</p>
HTML


$test    = '<br/>s need to be preserved';
$content = <<'MARKDOWN';
Roses are red<br/>
Violets are blue
MARKDOWN
$body = get( POST '/.jsrpc/render', [ content => $content ] );
eq_or_diff( $body, <<'HTML', $test );
<p>Roses are red<br/>
Violets are blue</p>
HTML


#-------------------------------------------------------------------------------
$test    = 'blockquotes';
$content = <<'MARKDOWN';
Below is a blockquote:

> quoted text

A quote is above.
MARKDOWN
$body = get( POST '/.jsrpc/render', [ content => $content ] );
eq_or_diff( $body, <<'HTML', $test );
<p>Below is a blockquote:</p>

<blockquote>
  <p>quoted text</p>
</blockquote>

<p>A quote is above.</p>
HTML


#-------------------------------------------------------------------------------
$test    = 'wikilink to ../new_sibling';
$content = <<'MARKDOWN';
This is a child page with a link to a [[../new_sibling]].
MARKDOWN
$body = get( POST '/parent/child.jsrpc/render', [ content => $content ] );
is( $body, <<'HTML', $test );
<p>This is a child page with a link to a <span class="newWikiWord"><a title="Not found. Click to create this page." href="/parent/new_sibling.edit">new sibling?</a></span>.</p>
HTML


#-------------------------------------------------------------------------------
$test    = '<div> with markdown="1"';
$content = <<'MARKDOWN';
We want to be able to have Markdown interpreted in `<div markdown="1">` sections
so that we can build sidebars, photo divs etc.

<div class="navbar" markdown="1">
* [[Home]]
* [[Products]]
* [[About]]

![alt text](/.static/catalyst.png "Image title")
<span style="color: green">This is an image caption</span>
</div>

The above should render as a list of items with an image and caption below.
MARKDOWN
$body = get( POST '/.jsrpc/render', [ content => $content ] );
    eq_or_diff( $body, <<'HTML', $test );
<p>We want to be able to have Markdown interpreted in <code>&lt;div markdown="1"&gt;</code> sections
so that we can build sidebars, photo divs etc.</p>

<div class="navbar">
<ul>
<li><span class="newWikiWord"><a title="Not found. Click to create this page." href="/Home.edit">Home?</a></span></li>
<li><span class="newWikiWord"><a title="Not found. Click to create this page." href="/Products.edit">Products?</a></span></li>
<li><span class="newWikiWord"><a title="Not found. Click to create this page." href="/About.edit">About?</a></span></li>
</ul>

<p><img src="/.static/catalyst.png" alt="alt text" title="Image title" />
<span style="color: green">This is an image caption</span></p>
</div>

<p>The above should render as a list of items with an image and caption below.</p>
HTML


#-------------------------------------------------------------------------------
$test = 'Markdown should not parse block-level markdown in <pre> tags';
$content = <<'MARKDOWN';
<pre lang="Perl">
# A comment, not a heading
</pre>
MARKDOWN
$body = get( POST '/.jsrpc/render', [ content => $content ] );
# note the newline enclosed in a kateComment. That's just the way Kate outputs it, even if perhaps not the most fortunate.
eq_or_diff( $body, <<'HTML', $test );
<pre>
<span class="kateComment"><i>#&nbsp;A&nbsp;comment,&nbsp;not&nbsp;a&nbsp;heading</i></span><span class="kateComment"><i>
</i></span></pre>
HTML



#-------------------------------------------------------------------------------
$test = 'in <pre>, 4 leading spaces should not be interpreted as another <pre>';
$content = <<'MARKDOWN';
<pre>
if (...) {

    foo();
}
</pre>
MARKDOWN
$body = get( POST '/.jsrpc/render', [ content => $content ] );
eq_or_diff( $body, <<'HTML', $test );
<pre>
if (...) {

    foo();
}
</pre>
HTML


#-------------------------------------------------------------------------------
$test = 'in <pre lang=...>, 4 leading spaces should not be interpreted as another <pre>';
$content = <<'MARKDOWN';
<pre lang="Perl">
if (...) {

    foo();
}
</pre>
MARKDOWN
$body = get( POST '/.jsrpc/render', [ content => $content ] );
# Kate has another bug here, that the 'if' should be in a <span class="kateOperator">,
# not simply in <b>if</b>
eq_or_diff( $body, <<'HTML', $test );
<pre>
<b>if</b>&nbsp;(...)&nbsp;{

&nbsp;&nbsp;&nbsp;&nbsp;foo();
}
</pre>
HTML


#-------------------------------------------------------------------------------
$test = 'POD while Markdown is the main formatter';
$content = <<'MARKDOWN';
{{pod}}

=head1 NAME

Some POD here
{{end}}
MARKDOWN
$body = get( POST '/.jsrpc/render', [ content => $content ] );
like($body, qr'<h1><a.*NAME.*/h1>'s, "POD: there is an h1 NAME");


#-------------------------------------------------------------------------------
# Formerly: Text::MultiMarkdown bug, see http://github.com/bobtfish/text-multimarkdown/commit/6600cef8e22a988b9a87750f1a144c7706784548";
$test = 'Underscore in code in footnotes becomes 128-bit hash';
$content = <<'MARKDOWN';
This is buggy[^bug].

[^bug]: Use `MYAPP_CONFIG_LOCAL_SUFFIX`.
MARKDOWN

$body = get( POST '/.jsrpc/render', [ content => $content ] );
like($body, qr/MYAPP_CONFIG_LOCAL_SUFFIX/s, "'MYAPP_CONFIG_LOCAL_SUFFIX' in footnote");


#-------------------------------------------------------------------------------
$test = '"<code>" and "<tt>" strings in <pre lang="Perl"> run through the JSRPC renderer';

$content = <<MARKDOWN;
<pre lang="Perl">
"Monotype: use <tt>.";
"Source code: <code>.";
</pre>
MARKDOWN

$expected = <<'HTML';
<pre>
<span class="kateOperator">"</span><span class="kateString">Monotype:&nbsp;use&nbsp;&lt;tt&gt;.</span><span class="kateOperator">"</span>;
<span class="kateOperator">"</span><span class="kateString">Source&nbsp;code:&nbsp;&lt;code&gt;.</span><span class="kateOperator">"</span>;
</pre>
HTML

$got = get( POST '/.jsrpc/render', [ content => $content ] );
eq_or_diff( $got, $expected, $test );


#-------------------------------------------------------------------------------
$test = "newline present before EOF";

$content = 'Markdown ensures the output ends with a newline';
$expected = "<p>Markdown ensures the output ends with a newline</p>\n";
$got = get( POST '/.jsrpc/render', [ content => $content ] );
is $got, $expected, $test;


$test = "multiple newlines at EOF collapsed into one";

$content = "Markdown ensures the output ends with *one* newline\n\n\n";
$expected = "<p>Markdown ensures the output ends with <em>one</em> newline</p>\n";
$got = get( POST '/.jsrpc/render', [ content => $content ] );
is $got, $expected, $test;
