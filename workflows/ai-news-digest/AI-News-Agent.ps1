# ============================================================
#  Everyday-AI News Agent
#  - Searches the web for the top 5 latest AI news articles
#  - Summarizes each article into 5 lines
#  - Saves a well-formatted Word (.docx) report to the Everyday-AI folder
#  Runs daily via Task Scheduler (works even when not logged in).
# ============================================================

$ErrorActionPreference = 'Continue'
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

# ------------------------------------------------------------
# Paths & logging
# ------------------------------------------------------------
$Desktop = [Environment]::GetFolderPath('Desktop')
$OutDir  = Join-Path $Desktop 'Everyday-AI'
$LogFile = Join-Path $OutDir 'runtime.log'

if (-not (Test-Path -LiteralPath $OutDir)) { New-Item -ItemType Directory -Path $OutDir -Force | Out-Null }

function Write-Log {
    param([string]$Msg)
    $line = "[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Msg
    try { Add-Content -LiteralPath $LogFile -Value $line -Encoding UTF8 } catch {}
    Write-Host $line
}

function ConvertTo-Date {
    param([string]$S)
    if ([string]::IsNullOrWhiteSpace($S)) { return $null }
    try {
        return [datetime]::Parse($S,
            [System.Globalization.CultureInfo]::InvariantCulture,
            [System.Globalization.DateTimeStyles]::AllowWhiteSpaces -bor [System.Globalization.DateTimeStyles]::RoundtripKind)
    }
    catch { return $null }
}

# XPath-based XML child text reader (avoids PS XML adapter quirks)
function Get-XText {
    param($Node, [string]$Name)
    if ($null -eq $Node) { return '' }
    $child = $Node.SelectSingleNode('*[local-name() = "' + $Name + '"]')
    if ($null -eq $child) { return '' }
    return ([string]$child.InnerText).Trim()
}

# ------------------------------------------------------------
# News sources
#   kind 'ai'     -> AI-specific feed (fetchable, full text)
#   kind 'broad'  -> general tech feed, filtered by AI keywords
#   kind 'google' -> Google News aggregator (backup only)
# ------------------------------------------------------------
$UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36'

$Feeds = @(
    @{ Url = 'https://techcrunch.com/category/artificial-intelligence/feed/'    ; Kind = 'ai' },
    @{ Url = 'https://www.theverge.com/rss/ai-artificial-intelligence/index.xml' ; Kind = 'ai' },
    @{ Url = 'https://www.wired.com/feed/tag/ai/latest/rss'                      ; Kind = 'ai' },
    @{ Url = 'https://venturebeat.com/category/ai/feed/'                         ; Kind = 'ai' },
    @{ Url = 'https://feeds.arstechnica.com/arstechnica/technology-lab'          ; Kind = 'broad' },
    @{ Url = 'https://feeds.bbci.co.uk/news/technology/rss.xml'                  ; Kind = 'broad' }
)

function Invoke-FeedRequest {
    param([string]$Url)
    for ($attempt = 1; $attempt -le 2; $attempt++) {
        try {
            return Invoke-WebRequest -Uri $Url -Headers @{ 'User-Agent' = $UA } -TimeoutSec 25
        }
        catch {
            if ($attempt -lt 2) { Start-Sleep -Seconds 4 } else { throw }
        }
    }
}

$AiKeywords = @('artificial intelligence', 'machine learning', 'deep learning', 'openai', 'anthropic', 'gemini',
    'chatgpt', 'deepmind', 'copilot', 'chatbot', 'language model', 'neural', ' nvidia', 'generative',
    'llm', ' gpt', 'transformer', 'agi', 'ai robot', 'ai model', ' ai ')

# ------------------------------------------------------------
# Fetch feeds -> collect items
# ------------------------------------------------------------
Write-Log "Starting Everyday-AI News Agent (report date $(Get-Date -Format 'yyyy-MM-dd'))"
$items = @()

foreach ($feed in $Feeds) {
    try {
        $resp = Invoke-FeedRequest -Url $feed.Url
        [xml]$doc = $resp.Content
        $root = $doc.DocumentElement.LocalName.ToLowerInvariant()

        if ($root -eq 'rss') {
            $chanNode = $doc.SelectSingleNode('//*[local-name() = "channel"]')
            $channelTitle = Get-XText $chanNode 'title'
            foreach ($node in @($doc.SelectNodes('//*[local-name() = "item"]'))) {
                $title = Get-XText $node 'title'
                $link  = Get-XText $node 'link'
                $desc  = ([System.Net.WebUtility]::HtmlDecode((Get-XText $node 'description' -replace '<[^>]+>', ' ')) -replace '\s+', ' ').Trim()
                $date  = ConvertTo-Date (Get-XText $node 'pubDate')
                $items += [PSCustomObject]@{ Title = $title; Link = $link; Date = $date; Source = $channelTitle; Desc = $desc; Kind = $feed.Kind }
            }
        }
        elseif ($root -eq 'feed') {
            $feedTitle = Get-XText $doc 'title'
            foreach ($node in @($doc.SelectNodes('//*[local-name() = "entry"]'))) {
                $title = Get-XText $node 'title'
                $dateTxt = Get-XText $node 'published'
                if ([string]::IsNullOrWhiteSpace($dateTxt)) { $dateTxt = Get-XText $node 'updated' }
                $link = $null
                foreach ($l in @($node.SelectNodes('*[local-name() = "link"]'))) {
                    $rel = $l.GetAttribute('rel')
                    if ([string]::IsNullOrWhiteSpace($rel) -or $rel -eq 'alternate') { $link = $l.GetAttribute('href'); break }
                }
                $desc = ([System.Net.WebUtility]::HtmlDecode((Get-XText $node 'summary' -replace '<[^>]+>', ' ')) -replace '\s+', ' ').Trim()
                $date = ConvertTo-Date $dateTxt
                $items += [PSCustomObject]@{ Title = $title; Link = $link; Date = $date; Source = $feedTitle; Desc = $desc; Kind = $feed.Kind }
            }
        }
    }
    catch { Write-Log "Feed error [$($feed.Url)] : $($_.Exception.Message)" }
}
Write-Log "Fetched $($items.Count) raw items."

# Filter: require title + link; keyword-filter broad feeds
$filtered = @()
foreach ($it in $items) {
    if ([string]::IsNullOrWhiteSpace($it.Title)) { continue }
    if ([string]::IsNullOrWhiteSpace($it.Link)) { continue }
    if ($it.Kind -eq 'broad') {
        $tl = ' ' + $it.Title.ToLowerInvariant() + ' '
        $matched = $false
        foreach ($k in $AiKeywords) { if ($tl.Contains($k)) { $matched = $true; break } }
        if (-not $matched) { continue }
    }
    $filtered += $it
}
Write-Log "$($filtered.Count) items after filtering."

# Deduplicate by title (keep the newest)
$seen = @{}
$unique = @()
foreach ($it in ($filtered | Sort-Object -Property @{ Expression = 'Date'; Descending = $true })) {
    $key = $it.Title.ToLowerInvariant()
    if (-not $seen.ContainsKey($key)) {
        $seen[$key] = $true
        $unique += $it
    }
}
Write-Log "$($unique.Count) unique articles."

# ----- Story-diversity selection (avoid 5 stories about the same event) -----
function Get-TitleKey {
    param([string]$T)
    $stop = @('the','a','an','and','or','for','of','to','in','on','as','at','by','with','from','its','his','her','this','that','are','were','been','being','is','it','new','news','says','said','how','what','where','when','if','but','not','you','your','their','they','he','she','will','has','have','had','over','into','about','after','than','world','first','latest','out','now','get','one','two')
    $ws = @()
    foreach ($w in ($T.ToLowerInvariant() -split '[^a-z0-9]')) {
        if ($w.Length -ge 4 -and $stop -notcontains $w) { $ws += $w.Substring(0, [Math]::Min(5, $w.Length)) }
    }
    return @($ws | Sort-Object -Unique)
}

$sorted = @($unique | Sort-Object -Property @{ Expression = 'Date'; Descending = $true })
$selected = @()
foreach ($cand in $sorted) {
    if ($selected.Count -ge 5) { break }
    $dup = $false
    foreach ($ch in $selected) {
        $sa = @(Get-TitleKey $ch.Title); $sb = @(Get-TitleKey $cand.Title)
        $inter = [Math]::Max(0, @($sa | Where-Object { $sb -contains $_ }).Count)
        $union = @($sa + $sb | Sort-Object -Unique).Count
        $jac = if ($union -gt 0) { [double]$inter / [double]$union } else { 0.0 }
        if ($jac -ge 0.30 -or ($inter -ge 3 -and $jac -ge 0.15)) { $dup = $true; break }
    }
    if (-not $dup) { $selected += $cand }
}
$top = @($selected | Select-Object -First 5)
Write-Log "Selected top $($top.Count) articles."

# ------------------------------------------------------------
# Article text extraction
# ------------------------------------------------------------
function Get-ArticleText {
    param([string]$Url)
    try {
        $resp = Invoke-WebRequest -Uri $Url -Headers @{ 'User-Agent' = $UA; 'Accept-Language' = 'en-US,en;q=0.9' } -TimeoutSec 25 -MaximumRedirection 8
        $html = [string]$resp.Content
        foreach ($pat in @('(?is)<script.*?</script>', '(?is)<style.*?</style>', '(?is)<noscript.*?</noscript>', '(?is)<svg.*?</svg>', '(?is)<header.*?</header>', '(?is)<footer.*?</footer>', '(?is)<nav.*?</nav>', '(?is)<form.*?</form>')) {
            $html = [regex]::Replace($html, $pat, ' ')
        }
        $html = [System.Net.WebUtility]::HtmlDecode(($html -replace '<[^>]+>', ' '))
        return (($html -replace '\s+', ' ').Trim())
    }
    catch { return '' }
}

# ------------------------------------------------------------
# Summarizer (extractive -> up to 5 bullets)
# ------------------------------------------------------------
function Get-SummaryLines {
    param([string]$ArtText, [string]$FallbackDesc, [string]$Title)
    $maxLines = 5

    $stop = @('the','a','an','and','or','but','for','are','was','were','this','that','with','from','have','has','had','its','is','of','to','in','on','as','at','by','be','been','being','will','would','could','should','may','might','than','their','they','them','there','these','those','not','no','so','if','who','whom','which','when','where','how','what','over','under','into','about','after','before','between','more','most','said','says','say','also','us','uk','and','he','she','all','some','while','during','it','his','her','out','off','up','down','now','just','get','got','am','do','does','did','one','two')

    $sentences = @([regex]::Matches($ArtText, '[^.!?]+[.!?]+') |
        ForEach-Object { $_.Value.Trim() } |
        Where-Object { $_.Length -ge 35 } |
        Select-Object -First 120)

    $junk = @('sign in','sign up','subscribe','cookie','privacy policy','terms of service','newsletter','log in','register','advertisement','click here','read more','watch now','back to top','join the discussion','you might also like','introducing the app','skip to main content','save this story','see all','follow see all','posts from this author','daily email digest','most popular','image caption','image credits','photo credit','figure caption','related topics','more on this story','you are reading','play video','watch video','share this story','comments','trending now','related stories','sign out','get the app','we use cookies','by continuing')
    $junkStart = @('follow','see','comments','join','back','read','subscribe','sign','click','search','skip','related','watch','you may','load more','open image','up next','on topic','read next')

    $clean = @()
    foreach ($s in $sentences) {
        $ls = $s.ToLowerInvariant()
        $skip = $false
        foreach ($j in $junk) { if ($ls -like "*$j*") { $skip = $true; break } }
        if ($skip) { continue }
        $first = ($ls -split '\s+')[0].Trim(' ', '"', '(', '[', '''')
        if ($junkStart -contains $first) { continue }
        if ($ls -match '^\d{1,2}:\d{2}') { continue }
        if ($ls -match 'utc|gmt|\bam\b|\bpm\b') { continue }
        if ($ls -like '*-:-*' -or ($ls -match '\|' -and $ls.Length -lt 120)) { continue }
        if (($ls -split '\s+').Count -lt 6) { continue }
        $clean += $s
    }
    if ($clean.Count -eq 0) { $clean = @($ArtText) }

    # Content-word frequency
    $stopHash = @{}
    foreach ($w in $stop) { $stopHash[$w] = $true }

    $freq = @{}
    foreach ($s in $clean) {
        foreach ($w in ($s -split '[^A-Za-z0-9]')) {
            if ($w.Length -ge 4 -and -not $stopHash.ContainsKey($w.ToLowerInvariant())) {
                $k = $w.ToLowerInvariant()
                if ($freq.ContainsKey($k)) { $freq[$k]++ } else { $freq[$k] = 1 }
            }
        }
    }

    # Title tokens (sentences sharing words with the headline are the real story)
    $titleTokens = @{}
    foreach ($w in ($Title -split '[^A-Za-z0-9]')) {
        $w = $w.ToLowerInvariant()
        if ($w.Length -ge 4 -and -not $stopHash.ContainsKey($w)) { $titleTokens[$w] = $true }
    }

    $scored = @()
    for ($i = 0; $i -lt $clean.Count; $i++) {
        $score = 0.0
        $words = ($clean[$i] -split '[^A-Za-z0-9]')
        foreach ($w in $words) {
            $wl = $w.ToLowerInvariant()
            if ($w.Length -ge 4 -and $freq.ContainsKey($wl)) { $score += $freq[$wl] }
            if ($titleTokens.ContainsKey($wl)) { $score += 6.0 }
        }
        $score += 12.0 / ($i + 1)   # position bonus
        $scored += [PSCustomObject]@{ Score = $score; Index = $i; Text = $clean[$i] }
    }

    # Pick the best sentences, require a minimum size, cap at 5
    $candidates = @($scored | Sort-Object -Property @{ Expression = 'Score'; Descending = $true })
    $lines = @()
    foreach ($c in $candidates) {
        if ($lines.Count -ge $maxLines) { break }
        $t = ($c.Text -replace '\s+', ' ').Trim()
        if ($t.Length -lt 30 -or ($t -split '\s+').Count -lt 6) { continue }
        if ($t.Length -gt 220) { $t = $t.Substring(0, 217).TrimEnd() + '...' }
        $t = $t.Substring(0, 1).ToUpperInvariant() + $t.Substring(1)
        $lines += $t
    }

    # Pad with feed-description sentences if still short
    if ($lines.Count -lt 3 -and -not [string]::IsNullOrWhiteSpace($FallbackDesc)) {
        foreach ($f in @([regex]::Matches($FallbackDesc, '[^.!?]+[.!?]+') | ForEach-Object { $_.Value.Trim() } | Where-Object { $_.Length -ge 25 })) {
            if ($lines.Count -ge $maxLines) { break }
            $f = $f.Substring(0, 1).ToUpperInvariant() + $f.Substring(1)
            if ($f.Length -gt 220) { $f = $f.Substring(0, 217).TrimEnd() + '...' }
            $lines += $f
        }
    }

    if ($lines.Count -eq 0) { $lines = @('No summary available for this article.') }
    return $lines
}

# ------------------------------------------------------------
# Build summaries
# ------------------------------------------------------------
$report = @()
$n = 0
foreach ($art in $top) {
    $n++
    Write-Log "[$n/$($top.Count)] Processing: $($art.Title)"
    $body = Get-ArticleText -Url $art.Link
    if ([string]::IsNullOrWhiteSpace($body)) { Write-Log '  (full text unavailable, using feed description)' }
    $sum  = Get-SummaryLines -ArtText $body -FallbackDesc $art.Desc -Title $art.Title
    $pdate = if ($art.Date) { $art.Date.ToUniversalTime().ToString('d MMM yyyy') } else { 'recent' }
    $src = ([string]$art.Source) -replace '^Feed:\s*', ''
    if ([string]::IsNullOrWhiteSpace($src)) { $src = 'News' }
    $report += [PSCustomObject]@{
        Title  = $art.Title
        Link   = $art.Link
        Source = $src.Trim()
        PubDate= $pdate
        Lines  = @($sum)
    }
}

# ------------------------------------------------------------
# DOCX generation (OOXML, no external libraries)
# ------------------------------------------------------------
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

function Get-Esc {
    param($s)
    return ([string]$s) -replace '&', '&amp;' -replace '<', '&lt;' -replace '>', '&gt;' -replace '"', '&quot;'
}

function Add-ZipEntry {
    param($Archive, [string]$Name, [string]$Content)
    $entry = $Archive.CreateEntry($Name, [System.IO.Compression.CompressionLevel]::Optimal)
    $enc = New-Object System.Text.UTF8Encoding($true)
    $sw = New-Object System.IO.StreamWriter($entry.Open(), $enc)
    $sw.Write($Content)
    $sw.Close()
}

function New-AINewsDocx {
    param([string]$Path, $Articles)

    $subtitle = ("{0}   ·   Top 5 latest AI stories" -f (Get-Date).ToString('dddd, MMMM d, yyyy'))

    $body = New-Object System.Text.StringBuilder

    # Title bar
    [void]$body.Append(@'
<w:p><w:pPr><w:spacing w:before="120" w:after="60"/><w:pBdr><w:bottom w:val="single" w:sz="16" w:space="4" w:color="1F4E79"/></w:pBdr></w:pPr><w:r><w:rPr><w:rFonts w:ascii="Calibri Light" w:hAnsi="Calibri Light"/><w:b/><w:color w:val="1F4E79"/><w:sz w:val="60"/></w:rPr><w:t>Today's AI News</w:t></w:r></w:p>
'@)
    # Subtitle / date
    [void]$body.Append('<w:p><w:pPr><w:spacing w:after="280"/></w:pPr><w:r><w:rPr><w:i/><w:color w:val="808080"/><w:sz w:val="20"/></w:rPr><w:t>' + (Get-Esc $subtitle) + '</w:t></w:r></w:p>')

    $n = 0
    foreach ($a in $Articles) {
        $n++
        $linkId = 'rL{0}' -f $n

        # Article header (clickable title)
        [void]$body.Append('<w:p><w:pPr><w:spacing w:before="300" w:after="40"/></w:pPr><w:r><w:rPr><w:b/><w:color w:val="C00000"/><w:sz w:val="24"/></w:rPr><w:t>' + $n + '.</w:t></w:r><w:hyperlink r:id="' + $linkId + '" w:history="1"><w:r><w:rPr><w:b/><w:color w:val="1F4E79"/><w:sz w:val="26"/></w:rPr><w:t xml:space="preserve"> ' + (Get-Esc $a.Title) + '</w:t></w:r></w:hyperlink></w:p>')

        # Meta line
        $meta = ("{0}   ·   {1}" -f $a.Source, $a.PubDate)
        [void]$body.Append('<w:p><w:pPr><w:spacing w:after="120"/></w:pPr><w:r><w:rPr><w:i/><w:color w:val="808080"/><w:sz w:val="18"/></w:rPr><w:t>' + (Get-Esc $meta) + '</w:t></w:r></w:p>')

        # Summary label
        [void]$body.Append(@'
<w:p><w:pPr><w:spacing w:before="40" w:after="40"/></w:pPr><w:r><w:rPr><w:b/><w:color w:val="C55A11"/><w:sz w:val="18"/></w:rPr><w:t>SUMMARY</w:t></w:r></w:p>
'@)
        # Bullets
        foreach ($ln in $a.Lines) {
            [void]$body.Append('<w:p><w:pPr><w:spacing w:after="40"/><w:ind w:left="360"/></w:pPr><w:r><w:rPr><w:color w:val="1F4E79"/><w:sz w:val="20"/></w:rPr><w:t>▪</w:t></w:r><w:r><w:rPr><w:sz w:val="20"/></w:rPr><w:t xml:space="preserve"> ' + (Get-Esc $ln) + '</w:t></w:r></w:p>')
        }

        # Divider between articles
        if ($n -lt $Articles.Count) {
            [void]$body.Append(@'
<w:p><w:pPr><w:spacing w:before="80" w:after="0"/><w:pBdr><w:bottom w:val="single" w:sz="6" w:space="1" w:color="D9E2F3"/></w:pBdr></w:pPr></w:p>
'@)
        }
    }

    # Footer note
    [void]$body.Append(@'
<w:p><w:pPr><w:spacing w:before="320"/><w:pBdr><w:top w:val="single" w:sz="6" w:space="4" w:color="1F4E79"/></w:pBdr></w:pPr><w:r><w:rPr><w:i/><w:color w:val="808080"/><w:sz w:val="16"/></w:rPr><w:t>Report generated automatically by the Everyday-AI News Agent (Windows Task Scheduler).</w:t></w:r></w:p>
'@)

    [void]$body.Append('<w:sectPr><w:pgSz w:w="11906" w:h="16838"/><w:pgMar w:top="1080" w:right="1080" w:bottom="1080" w:left="1080" w:header="720" w:footer="720" w:gutter="0"/></w:sectPr>')

    $documentXml = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
        '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><w:body>' +
        $body.ToString() + '</w:body></w:document>'

    # Hyperlink relationships
    $relSb = New-Object System.Text.StringBuilder
    [void]$relSb.Append('<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">')
    for ($i = 0; $i -lt $Articles.Count; $i++) {
        $rid = 'rL{0}' -f ($i + 1)
        [void]$relSb.Append('<Relationship Id="' + $rid + '" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/hyperlink" Target="' + (Get-Esc $Articles[$i].Link) + '" TargetMode="External"/>')
    }
    [void]$relSb.Append('</Relationships>')

    $contentTypes = @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
<Default Extension="xml" ContentType="application/xml"/>
<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
</Types>
'@

    $relsRoot = @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>
'@

    $fs = [System.IO.File]::Open($Path, [System.IO.FileMode]::Create)
    $zip = New-Object System.IO.Compression.ZipArchive($fs, [System.IO.Compression.ZipArchiveMode]::Create)
    try {
        Add-ZipEntry -Archive $zip -Name '[Content_Types].xml' -Content $contentTypes
        Add-ZipEntry -Archive $zip -Name '_rels/.rels' -Content $relsRoot
        Add-ZipEntry -Archive $zip -Name 'word/document.xml' -Content $documentXml
        Add-ZipEntry -Archive $zip -Name 'word/_rels/document.xml.rels' -Content $relSb.ToString()
    }
    finally {
        $zip.Dispose()
        $fs.Close()
    }
}

# ------------------------------------------------------------
# Save report
# ------------------------------------------------------------
$reportPath = Join-Path $OutDir ("AI-News-{0}.docx" -f (Get-Date -Format 'yyyy-MM-dd'))

if ($report.Count -eq 0) {
    Write-Log 'No articles could be fetched. Writing notice report.'
    $notice = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:rPr><w:b/><w:color w:val="C00000"/><w:sz w:val="28"/></w:rPr><w:t>No AI news could be fetched today. Please check your internet connection.</w:t></w:r></w:p></w:body></w:document>'
    $ct = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/></Types>'
    $r1 = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/></Relationships>'
    $fs = [System.IO.File]::Open($reportPath, [System.IO.FileMode]::Create)
    $zip = New-Object System.IO.Compression.ZipArchive($fs, [System.IO.Compression.ZipArchiveMode]::Create)
    try {
        Add-ZipEntry -Archive $zip -Name '[Content_Types].xml' -Content $ct
        Add-ZipEntry -Archive $zip -Name '_rels/.rels' -Content $r1
        Add-ZipEntry -Archive $zip -Name 'word/document.xml' -Content $notice
    }
    finally {
        $zip.Dispose()
        $fs.Close()
    }
}
else {
    New-AINewsDocx -Path $reportPath -Articles $report
    Write-Log "Report saved: $reportPath"
}

Write-Log 'Everyday-AI News Agent finished.'