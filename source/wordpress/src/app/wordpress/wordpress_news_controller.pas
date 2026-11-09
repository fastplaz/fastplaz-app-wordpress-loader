unit wordpress_news_controller;

{$mode objfpc}{$H+}
{$include define.inc}

interface

uses
  wordpress_news_model, wordpress_terms_model, wordpress_featuredimage_model,
  fastplaz_app, fastplaz_handler, httpdefs, fpHTTP,
  Classes, SysUtils;

type

  { TWPNewsWebModule }

  TWPNewsWebModule = class(TMyCustomController)
  private
    NewsTitle: string;
    News: TWordpressNews;
    Terms: TWordpressTerms;
    Featuredimage: TFeaturedimage;
    function GetLastNews(FunctionName: string = ''; Parameter: TStrings = nil; LimitNews:integer=10): string;
    // home page / news list / search: cards (thumbnail, date, excerpt) + pagination
    function GetNewsCards(const Keyword: string = ''): string;
    function NewsImageURL(const NewsID: integer; const Content: string): string;
    // term_taxonomy_id of a category slug, 0 when it does not exist
    function CategoryTaxonomyID(const Slug: string): integer;
    // [text mod=wpnews func=newslist category=slug number=6 thumb=1 summary=1]
    function GetNewsList(Parameter: TStrings): string;
    // [text mod=wpnews func=newshero category=slug belowbanner=1 excerpt=420]: the newest
    // post, large; excerpt: characters of the story shown (default 420);
    // belowbanner=1: a herobanner is above it, so it does not take the image priority
    // while the banner has images
    function GetNewsHero(Parameter: TStrings): string;
    // [text mod=wpnews func=herobanner ratio=16:9]: image carousel from config.json "hero_banner"
    function GetHeroBanner(Parameter: TStrings): string;
    // [text mod=wpnews func=rightbanner]: stacked banners from config.json "right_top_banner"
    function GetRightBanner(Parameter: TStrings): string;
    procedure PrepareModels;
    function GetRandomNews(FunctionName: string = ''; Parameter: TStrings = nil): string;
    function GeneratePagesMenu(ParentMenu: integer; Parameter: TStrings = nil;
      ParentBaseURL: string = ''; IsParent: boolean = True): string;
    // year + month from the request, '' when they are not a valid yyyymm
    function RequestYearMonth: string;

    function Tag_MainContent_Handler(const TagName: string; Params: TStringList): string;
  public
    constructor CreateNew(AOwner: TComponent; CreateMode: integer); override;
    destructor Destroy; override;

    procedure Get; override;

    function View: string;
    // news search (?s=keyword), as cards
    function Search(const Keyword: string): string;
    function GetOptions(const KeyName: string): string;

    // Handler / Controller
    procedure DoBlockController(Sender: TObject; FunctionName: string; Parameter: TStrings;
      var ResponseString: string);

  end;


implementation

uses database_lib, common, language_lib, html_lib, theme_controller, RegExpr,
  fpjson, jsonparser, strutils,
  wordpress_options_model, wordpress_nggallery_model, wordpress_pages_model,
  wordpress_category_controller, wordpress_site_lib;

const
  NEWS_PER_PAGE = 9;        // cards per page; page 1 shows one extra (hero)
  NEWS_MAX_PAGE = 10000;
  NEWS_EXCERPT_LENGTH = 180;
  NEWS_HERO_EXCERPT_LENGTH = 420;   // newshero: a longer part of the story
  // English names are the msgid, locale/fastplaz.<lang>.po translates them
  NEWS_MONTHS: array[1..12] of string = ('Jan', 'Feb', 'Mar', 'Apr', 'May',
    'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec');

function FormatNewsDate(const ADate: TDateTime): string;
var
  y, m, d: word;
begin
  DecodeDate(ADate, y, m, d);
  Result := IntToStr(d) + ' ' + __(NEWS_MONTHS[m]) + ' ' + IntToStr(y);
end;

// src of the first <img> in the post content, '' when there is none
function FirstImageURL(const Content: string): string;
begin
  Result := '';
  with TRegExpr.Create do
  try
    Expression := '<img\s[^>]*?src\s*=\s*["'']([^"'']+)["'']';
    ModifierI := True;
    if Exec(Content) then
      // the attribute is html: decode &amp; so the url is not encoded twice
      Result := StringReplace(Match[1], '&amp;', '&', [rfReplaceAll]);
  finally
    Free;
  end;
end;

// plain text excerpt, cut on a word boundary
function PlainText(const Html: string): string;
begin
  // a space before every tag: "Amir<br>Sabdurrahman" must not become one word
  Result := StringReplace(Html, '<', ' <', [rfReplaceAll]);
  Result := StripTagsCustom(StripTags(Result), '[', ']');
  Result := StringReplace(Result, #13, ' ', [rfReplaceAll]);
  Result := StringReplace(Result, #10, ' ', [rfReplaceAll]);
  Result := StringReplace(Result, #9, ' ', [rfReplaceAll]);
  Result := StringReplace(Result, '&nbsp;', ' ', [rfReplaceAll, rfIgnoreCase]);
  while Pos('  ', Result) > 0 do
    Result := StringReplace(Result, '  ', ' ', [rfReplaceAll]);
  Result := Trim(Result);
end;

// true when position P of S is inside an html entity such as &amp; / &#8211;
function InsideEntity(const S: string; P: integer): boolean;
var
  q: integer;
begin
  q := P;
  while (q > 1) and (P - q < 10) and (S[q - 1] in ['a'..'z', 'A'..'Z', '0'..'9', '#']) do
    Dec(q);
  Result := (q > 1) and (S[q - 1] = '&');
end;

// wrap every match of Keyword (case-insensitive) in <mark>
function HighlightKeyword(const Text, Keyword: string): string;
var
  lt, lk: string;
  p, from: integer;
begin
  lk := LowerCase(Keyword);
  if Length(lk) < 2 then
    Exit(Text);
  lt := LowerCase(Text);   // ascii only: byte positions stay the same
  Result := '';
  from := 1;
  repeat
    p := Pos(lk, lt, from);
    if p = 0 then
      Break;
    if InsideEntity(lt, p) then
    begin
      Result := Result + Copy(Text, from, p - from + 1);
      from := p + 1;
      Continue;
    end;
    Result := Result + Copy(Text, from, p - from) + '<mark>' + Copy(Text, p, Length(lk)) + '</mark>';
    from := p + Length(lk);
  until False;
  Result := Result + Copy(Text, from, MaxInt);
end;

// cut S to about Len characters on a word boundary, without leaving a
// half cut html entity (&amp / &nbsp ...) at the end
function CutText(const S: string; Len: integer; out Cut: boolean): string;
var
  p: integer;
begin
  Result := MoreLess(S, Len, '');
  Cut := Length(Result) < Length(Trim(S));
  if Cut then
  begin
    p := LastDelimiter('&;', Result);
    if (p > 0) and (Result[p] = '&') then
      Result := TrimRight(Copy(Result, 1, p - 1));
  end;
end;

// plain text excerpt. With a keyword: the part of the content around the
// first match, with the matches highlighted.
// MaxLength: characters of plain text, 0 = NEWS_EXCERPT_LENGTH
function NewsExcerpt(const Excerpt, Content: string; const Keyword: string = '';
  MaxLength: integer = 0): string;
var
  s: string;
  p, start: integer;
  cut: boolean;
begin
  if MaxLength <= 0 then
    MaxLength := NEWS_EXCERPT_LENGTH;
  if Keyword <> '' then
  begin
    s := PlainText(Content);
    p := Pos(LowerCase(Keyword), LowerCase(s));
    if p > 0 then
    begin
      start := p - 60;
      if start <= 1 then
        start := 1
      else
      begin
        // start on a word
        while (start < p) and (s[start] <> ' ') do
          Inc(start);
        Inc(start);
      end;
      Result := CutText(Copy(s, start, MaxInt), MaxLength, cut);
      Result := HighlightKeyword(Result, Keyword);
      if start > 1 then
        Result := '&hellip; ' + Result;
      if cut then
        Result := Result + ' &hellip;';
      Exit;
    end;
  end;

  s := Excerpt;
  if Trim(StripTags(s)) = '' then
    s := Content;
  Result := CutText(PlainText(s), MaxLength, cut);
  if Keyword <> '' then
    Result := HighlightKeyword(Result, Keyword);
  if cut then
    Result := Result + ' &hellip;';
end;

function IsDigits(const AValue: string): boolean;
var
  i: integer;
begin
  Result := AValue <> '';
  for i := 1 to Length(AValue) do
    if not (AValue[i] in ['0'..'9']) then
      Exit(False);
end;

const
  // msgid, translated by locale/fastplaz.<lang>.po
  NEWS_DAYS: array[1..7] of string = ('Sunday', 'Monday', 'Tuesday', 'Wednesday',
    'Thursday', 'Friday', 'Saturday');
  NEWS_MONTHS_LONG: array[1..12] of string = ('January', 'February', 'March', 'April',
    'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December');

// "Senin, 9 November 2026" / "Monday, 9 November 2026"
function FormatLongDate(const ADate: TDateTime): string;
var
  y, m, d: word;
begin
  DecodeDate(ADate, y, m, d);
  Result := __(NEWS_DAYS[DayOfWeek(ADate)]) + ', ' + IntToStr(d) + ' ' +
    __(NEWS_MONTHS_LONG[m]) + ' ' + IntToStr(y);
end;

function NewsURL(const PostDate: TDateTime; const PostName: string): string;
begin
  Result := '/' + FormatDateTime('YYYY', PostDate) + '/' + FormatDateTime('mm', PostDate) +
    '/' + PostName + '/';
end;

{ TWPNewsWebModule }

// example:
// http://domain/2014/04/dialog-keajaiban-silat-silat-untuk-kehidupan/
// a banner list in config.json ("hero_banner", "right_top_banner") as an
// array, nil when missing or not an array. The caller frees the result.
function BannerData(const KeyName: string): TJSONArray;
var
  data: TJSONData;
begin
  Result := nil;
  try
    data := GetJSON(Config.GetString(KeyName));
  except
    data := nil;
  end;
  if not Assigned(data) then
    Exit;
  if data.JSONType = jtArray then
    Result := TJSONArray(data)
  else
    data.Free;
end;

function HeroBannerData: TJSONArray;
begin
  Result := BannerData('hero_banner');
end;

// banner link: only web links (http, https, site-relative), '' otherwise
// (javascript:, data:, ...)
function SafeBannerURL(const URL: string): string;
begin
  Result := Trim(URL);
  if (Result <> '') and not ((Pos('http://', LowerCase(Result)) = 1) or
    (Pos('https://', LowerCase(Result)) = 1) or (Pos('/', Result) = 1)) then
    Result := '';
end;

// True when at least one hero_banner item has an image
function HasHeroBanner: boolean;
var
  items: TJSONArray;
  i: integer;
begin
  Result := False;
  items := HeroBannerData;
  if not Assigned(items) then
    Exit;
  try
    for i := 0 to items.Count - 1 do
      if (items.Items[i].JSONType = jtObject) and
        (Trim(string(TJSONObject(items.Items[i]).Get('image', ''))) <> '') then
        Exit(True);
  finally
    items.Free;
  end;
end;

procedure TWPNewsWebModule.Get;
begin
  DataBaseInit;
  LanguageInit;

  Tags['$maincontent'] := @Tag_MainContent_Handler;
  Response.Content := ThemeUtil.Render(nil, '', True);

  //==================================== YOUR CUSTOM CMS/FRAMEWORK - START ===

  {$ifdef wordpress}
    {$ifdef wordpress_nggallery}
  with TWPNGGallery.Create() do
  begin
    Response.Content := Render(Response.Content);
    Free;
  end;
    {$endif}
  {$endif}

  //==================================== YOUR CUSTOM CMS/FRAMEWORK - END ===
end;

function TWPNewsWebModule.RequestYearMonth: string;
begin
  Result := '';
  if (Length(_GET['year']) = 4) and IsDigits(_GET['year']) and
    (Length(_GET['month']) = 2) and IsDigits(_GET['month']) then
    Result := _GET['year'] + _GET['month'];
end;

function TWPNewsWebModule.GetLastNews(FunctionName: string; Parameter: TStrings; LimitNews: integer): string;
var
  lst: TStringList;
  _News: TWordpressNews;
  url, title: string;
  s, div_id, div_class, item_class, news_option: string;
  category_id: integer;
  //category_title,
  category_permalink: string;
  first_news: boolean;
begin
  Result := '';
  div_id := '';
  div_class := '';
  title := '';
  news_option := '';
  category_permalink := '';
  if Parameter <> nil then
  begin
    div_id := HTMLEncode(StringReplace(Parameter.Values['id'], '"', '', [rfReplaceAll]));
    div_class := HTMLEncode(StringReplace(Parameter.Values['class'], '"', '', [rfReplaceAll]));
    category_permalink := StringReplace(Parameter.Values['category'], '"', '', [rfReplaceAll]);
    title := StringReplace(Parameter.Values['title'], '"', '', [rfReplaceAll]);
    news_option := Parameter.Values['options'];
  end;

  category_id := 0;
  if category_permalink <> '' then
  begin
    with TWordpressTerms.Create() do
    begin
      AddJoin('term_taxonomy', 'term_id', 'terms.term_id', ['taxonomy']);
      FindFirst(['taxonomy="category"', 'slug=' + QuoteValue(category_permalink)], 'name');
      if RecordCount > 0 then
      begin
        category_id := Value['term_id'];
        //category_title := Value['name'];
      end;
      Free;
    end;
  end;

  _News := TWordpressNews.Create();
  try
    if category_id = 0 then
      _News.Find(['post_type="post"', 'post_status="publish"'], 'post_date desc', LimitNews)
    else
    begin
      _News.AddJoin('term_relationships', 'object_id', AppData.tablePrefix + 'posts.ID', ['object_id']);
      _News.Find(['post_type="post"', 'post_status="publish"', AppData.tablePrefix +
        'term_relationships.term_taxonomy_id=' + i2s(category_id)],
        'post_date desc', LimitNews);
    end;

    if _News.RecordCount > 0 then
    begin
      lst := TStringList.Create;
      try
        lst.Add('<header class="entry-header">');
        lst.Add('<h1 class="archive-title">Last News:</h1>');
        lst.Add('</header>');
        lst.Add('<article id="post-34" class="post-34 post type-post status-publish format-standard hentry category-general tag-hello"><div class="entry-content ">');
        if title <> '' then
        begin
          lst.Add('<div class="news-lastnews entry-content">');
          lst.Add('<h3>' + title + '</h3>');
        end;

        first_news := True;
        item_class := ' class="first-post"';
        if div_id <> '' then
          lst.Add('<ul id="' + div_id + '" class="' + div_class + '">')
        else
          lst.Add('<ul class="' + div_class + '">');
        while not _News.Data.EOF do
        begin
          url := '/' + FormatDateTime('YYYY', TDateTime(_News['post_date'])) + '/' +
            FormatDateTime('mm', TDateTime(_News['post_date'])) + '/' + string(_News['post_name']) + '/';
          lst.Add('<li' + item_class + '><a href="' + url + '">' + string(_News['post_title']) + '</a>');
          case news_option of
            'summary':
            begin
              s := StripTags(string(_News['post_content']));
              s := StripTagsCustom(s, '[', ']');
              s := '<p>' + MoreLess(s) + '</p>';
              lst.Add(s);
            end;
            'full':
            begin
              s := string(_News['post_content']);
              s := StripTagsCustom(s, '[', ']');
              lst.Add( s);
            end;
          end;
          lst.Add('</li>');

          if first_news then
          begin
            first_news := False;
            item_class := '';
          end;
          _News.Data.Next;
        end;
        lst.Add('</ul>');
        if title <> '' then
          lst.Add('</div>');

        lst.Add('</div></article>');
        Result := lst.Text;
      finally
        FreeAndNil(lst);
      end;
    end;
  finally
    FreeAndNil(_News);
  end;
end;

function TWPNewsWebModule.NewsImageURL(const NewsID: integer; const Content: string): string;
begin
  // 1. featured image, 2. first image in the content
  Result := Featuredimage.GetFeaturedImageURLByID(NewsID);
  if Result = '' then
    Exit(FirstImageURL(Content));
  Result := WPUploadURL(Result);
end;

function TWPNewsWebModule.CategoryTaxonomyID(const Slug: string): integer;
begin
  Result := 0;
  if Slug = '' then
    Exit;
  with TWordpressTerms.Create() do
  try
    AddJoin('term_taxonomy', 'term_id', 'terms.term_id', ['taxonomy', 'term_taxonomy_id']);
    FindFirst(['taxonomy="category"', 'slug=' + QuoteValue(Slug)], 'name');
    if RecordCount > 0 then
      Result := integer(Value['term_taxonomy_id']);
  finally
    Free;
  end;
end;

function TWPNewsWebModule.GetNewsList(Parameter: TStrings): string;
var
  lst: TStringList;
  _News: TWordpressNews;
  number, offset, taxonomy_id, excerpt_len, latest_id, i, n: integer;
  with_thumb, with_summary, cut: boolean;
  skip_where, tax_ids: string;
  slugs, seen: TStringList;
  post_date: TDateTime;
  url, image, list_class, excerpt: string;
begin
  Result := '';
  PrepareModels;
  number := s2i(Parameter.Values['number']);
  if (number <= 0) or (number > 30) then
    number := 6;
  offset := s2i(Parameter.Values['offset']);
  if (offset < 0) or (offset > 100) then
    offset := 0;
  excerpt_len := s2i(Parameter.Values['excerpt']);
  if (excerpt_len <= 0) or (excerpt_len > 300) then
    excerpt_len := 110;
  with_thumb := Parameter.Values['thumb'] = '1';
  with_summary := Parameter.Values['summary'] = '1';
  list_class := HTMLEncode(StringReplace(Parameter.Values['class'], '"', '', [rfReplaceAll]));

  // excludelatest=1: leave out the newest post, it is already on the page (newshero)
  skip_where := '';
  if Parameter.Values['excludelatest'] = '1' then
  begin
    latest_id := 0;
    with TWordpressNews.Create() do
    try
      FindFirst(['post_type="post"', 'post_status="publish"'], 'post_date desc', 'ID');
      if RecordCount > 0 then
        latest_id := integer(Value['ID']);
    finally
      Free;
    end;
    if latest_id > 0 then
      skip_where := AppData.tablePrefix + 'posts.ID<>' + i2s(latest_id);
  end;

  // category=tips or category=tips,tutorial (several categories, no duplicates)
  tax_ids := '';
  if Parameter.Values['category'] <> '' then
  begin
    slugs := TStringList.Create;
    try
      slugs.CommaText := StringReplace(Parameter.Values['category'], ' ', '', [rfReplaceAll]);
      for i := 0 to slugs.Count - 1 do
      begin
        taxonomy_id := CategoryTaxonomyID(slugs[i]);
        if taxonomy_id > 0 then
        begin
          if tax_ids <> '' then
            tax_ids := tax_ids + ',';
          tax_ids := tax_ids + i2s(taxonomy_id);
        end;
      end;
    finally
      slugs.Free;
    end;
    if tax_ids = '' then
      Exit('<p class="ww-empty">' + __('No news yet.') + '</p>');
  end;

  _News := TWordpressNews.Create();
  lst := TStringList.Create;
  seen := TStringList.Create;
  try
    if tax_ids = '' then
      _News.Find(['post_type="post"', 'post_status="publish"', skip_where], 'post_date desc', number,
        'ID,post_title,post_name,post_date,post_excerpt,post_content', offset)
    else
    begin
      // a post in two of the categories comes twice: ask for more rows, skip repeats below
      _News.AddJoin('term_relationships', 'object_id', 'posts.ID', ['object_id']);
      _News.Find(['post_type="post"', 'post_status="publish"', AppData.tablePrefix +
        'term_relationships.term_taxonomy_id IN (' + tax_ids + ')', skip_where], 'post_date desc',
        number * 3, 'ID,post_title,post_name,post_date,post_excerpt,post_content', offset);
    end;

    if _News.RecordCount = 0 then
      Exit('<p class="ww-empty">' + __('No news yet.') + '</p>');

    lst.Add('<ul class="ww-list ' + list_class + '">');
    n := 0;
    while (not _News.Data.EOF) and (n < number) do
    begin
      if seen.IndexOf(string(_News['ID'])) >= 0 then
      begin
        _News.Data.Next;
        Continue;
      end;
      seen.Add(string(_News['ID']));
      Inc(n);
      post_date := TDateTime(_News['post_date']);
      url := NewsURL(post_date, string(_News['post_name']));
      lst.Add('<li class="ww-item"><a class="ww-item-link" href="' + url + '">');
      if with_thumb then
      begin
        image := NewsImageURL(integer(_News['ID']), string(_News['post_content']));
        if image <> '' then
          lst.Add('<span class="ww-thumb"><img src="' + HTMLEncode(image) +
            '" alt="" loading="lazy" decoding="async"></span>')
        else
          lst.Add('<span class="ww-thumb ww-thumb--empty"></span>');
      end;
      lst.Add('<span class="ww-item-body">');
      lst.Add('<span class="ww-item-title">' + string(_News['post_title']) + '</span>');
      //lst.Add('<time class="ww-date" datetime="' + FormatDateTime('YYYY-mm-dd', post_date) + '">' +
      //  FormatNewsDate(post_date) + '</time>');
      if with_summary then
      begin
        excerpt := CutText(PlainText(string(_News['post_excerpt'])), excerpt_len, cut);
        if excerpt = '' then
          excerpt := CutText(PlainText(string(_News['post_content'])), excerpt_len, cut)
        else
          cut := cut or (Trim(string(_News['post_content'])) <> '');
        if excerpt <> '' then
        begin
          if cut then
            excerpt := excerpt + ' &hellip;';
          lst.Add('<span class="ww-item-excerpt">' + excerpt + '</span>');
        end;
      end;
      lst.Add('</span></a></li>');
      _News.Data.Next;
    end;
    lst.Add('</ul>');
    Result := lst.Text;
  finally
    FreeAndNil(seen);
    FreeAndNil(lst);
    FreeAndNil(_News);
  end;
end;

function TWPNewsWebModule.GetNewsHero(Parameter: TStrings): string;
var
  _News: TWordpressNews;
  taxonomy_id: integer;
  post_date: TDateTime;
  url, image: string;
begin
  Result := '';
  PrepareModels;
  taxonomy_id := CategoryTaxonomyID(Parameter.Values['category']);
  _News := TWordpressNews.Create();
  try
    if taxonomy_id = 0 then
      _News.Find(['post_type="post"', 'post_status="publish"'], 'post_date desc', 1,
        'ID,post_title,post_name,post_date,post_excerpt,post_content')
    else
    begin
      _News.AddJoin('term_relationships', 'object_id', 'posts.ID', ['object_id']);
      _News.Find(['post_type="post"', 'post_status="publish"', AppData.tablePrefix +
        'term_relationships.term_taxonomy_id=' + i2s(taxonomy_id)], 'post_date desc', 1,
        'ID,post_title,post_name,post_date,post_excerpt,post_content');
    end;
    if _News.RecordCount = 0 then
      Exit('<p class="ww-empty">' + __('No news yet.') + '</p>');

    post_date := TDateTime(_News['post_date']);
    url := NewsURL(post_date, string(_News['post_name']));
    image := NewsImageURL(integer(_News['ID']), string(_News['post_content']));

    Result := '<article class="ww-hero">';
    if image <> '' then
      // the largest image on the home page: load it first, unless the
      // template says a hero banner sits above it and the banner has images
      Result := Result + '<a class="ww-hero-media" href="' + url +
        '" tabindex="-1" aria-hidden="true"><img src="' + HTMLEncode(image) + '" alt=""' +
        IfThen((Parameter.Values['belowbanner'] = '1') and HasHeroBanner, '',
        ' fetchpriority="high"') + ' decoding="async"></a>';
    Result := Result + '<div class="ww-hero-body"><div class="ww-hero-head">' +
      //'<time class="ww-date" datetime="' + FormatDateTime('YYYY-mm-dd', post_date) + '">' +
      //FormatNewsDate(post_date) + '</time>' +
      '<h2 class="ww-hero-title"><a href="' + url + '">' + string(_News['post_title']) +
      '</a></h2></div>' +
      '<p class="ww-hero-excerpt">' +
      NewsExcerpt(string(_News['post_excerpt']), string(_News['post_content']), '',
      StrToIntDef(Parameter.Values['excerpt'], NEWS_HERO_EXCERPT_LENGTH)) + '</p>' +
      '</div></article>';
  finally
    FreeAndNil(_News);
  end;
end;

// Banner carousel from config.json "hero_banner":
//   [{image, caption, url, alt, fit}, ...]
// alt: image description (falls back to caption); fit: "contain" shows the
// whole image (portrait posters), default fills the frame cropped from the center.
// Optional: ratio=21:9 (default 16:9). No usable item -> empty string, so the
// template shows nothing. Rotation, controls and swipe live in js/main.js.
function TWPNewsWebModule.GetHeroBanner(Parameter: TStrings): string;
var
  data: TJSONArray;
  item: TJSONObject;
  lst: TStringList;
  i, count, ratio_w, ratio_h: integer;
  image, caption, alt, url, ratio, tag_open, tag_close: string;
begin
  Result := '';
  data := HeroBannerData;
  if not Assigned(data) then
    Exit;
  lst := TStringList.Create;
  try

    // ratio=W:H, only digits accepted
    ratio_w := 16;
    ratio_h := 9;
    if Assigned(Parameter) then
    begin
      ratio := Trim(Parameter.Values['ratio']);
      i := Pos(':', ratio);
      if i > 0 then
      begin
        ratio_w := StrToIntDef(Copy(ratio, 1, i - 1), 0);
        ratio_h := StrToIntDef(Copy(ratio, i + 1, MaxInt), 0);
        if (ratio_w <= 0) or (ratio_h <= 0) then
        begin
          ratio_w := 16;
          ratio_h := 9;
        end;
      end;
    end;

    count := 0;
    for i := 0 to data.Count - 1 do
    begin
      if data.Items[i].JSONType <> jtObject then
        Continue;
      item := TJSONObject(data.Items[i]);
      image := Trim(string(item.Get('image', '')));
      if image = '' then
        Continue;
      caption := Trim(string(item.Get('caption', '')));
      alt := Trim(string(item.Get('alt', '')));
      if alt = '' then
        alt := caption;
      url := SafeBannerURL(string(item.Get('url', '')));

      if url <> '' then
      begin
        tag_open := '<a class="ww-carousel-link" href="' + HTMLEncode(url) + '">';
        tag_close := '</a>';
      end
      else
      begin
        tag_open := '<div class="ww-carousel-link">';
        tag_close := '</div>';
      end;

      lst.Add('<li class="ww-carousel-slide" data-index="' + i2s(count) + '">' +
        tag_open + '<span class="ww-carousel-frame' +
        IfThen(LowerCase(Trim(string(item.Get('fit', '')))) = 'contain', ' is-contain', '') +
        '"><img src="' + HTMLEncode(image) +
        '" alt="' + HTMLEncode(alt) + '" decoding="async"' +
        IfThen(count = 0, ' fetchpriority="high"', '') + '></span>' +
        IfThen(caption <> '', '<span class="ww-carousel-caption">' +
        HTMLEncode(caption) + '</span>', '') + tag_close + '</li>');
      Inc(count);
    end;
    if count = 0 then
      Exit;

    Result := '<section class="ww-carousel' + IfThen(count = 1, ' is-single', '') +
      '" aria-roledescription="carousel" aria-label="Banner" style="--ww-carousel-ratio: ' +
      i2s(ratio_w) + ' / ' + i2s(ratio_h) + '">' +
      '<div class="ww-carousel-viewport"><ul class="ww-carousel-track">' +
      lst.Text + '</ul></div></section>';
  finally
    FreeAndNil(lst);
    FreeAndNil(data);
  end;
end;

// Banners stacked at the top of column 4, from config.json "right_top_banner":
//   [{image, caption, url, alt}, ...]
// Each image keeps its own ratio. alt falls back to caption. No usable item
// -> empty string, so the column shows nothing.
function TWPNewsWebModule.GetRightBanner(Parameter: TStrings): string;
var
  data: TJSONArray;
  item: TJSONObject;
  lst: TStringList;
  i: integer;
  image, caption, alt, url, tag_open, tag_close: string;
begin
  Result := '';
  data := BannerData('right_top_banner');
  if not Assigned(data) then
    Exit;
  lst := TStringList.Create;
  try
    for i := 0 to data.Count - 1 do
    begin
      if data.Items[i].JSONType <> jtObject then
        Continue;
      item := TJSONObject(data.Items[i]);
      image := Trim(string(item.Get('image', '')));
      if image = '' then
        Continue;
      caption := Trim(string(item.Get('caption', '')));
      alt := Trim(string(item.Get('alt', '')));
      if alt = '' then
        alt := caption;
      url := SafeBannerURL(string(item.Get('url', '')));
      if url <> '' then
      begin
        tag_open := '<a class="ww-banner" href="' + HTMLEncode(url) + '">';
        tag_close := '</a>';
      end
      else
      begin
        tag_open := '<div class="ww-banner">';
        tag_close := '</div>';
      end;
      lst.Add('<li class="ww-banner-item">' + tag_open + '<img src="' + HTMLEncode(image) +
        '" alt="' + HTMLEncode(alt) + '" decoding="async">' +
        IfThen(caption <> '', '<span class="ww-banner-caption">' + HTMLEncode(caption) +
        '</span>', '') + tag_close + '</li>');
    end;
    if lst.Count = 0 then
      Exit;
    Result := '<section class="ww-block ww-banners-top" aria-label="Banner">' +
      '<ul class="ww-banners">' + lst.Text + '</ul></section>';
  finally
    FreeAndNil(lst);
    FreeAndNil(data);
  end;
end;

function TWPNewsWebModule.Search(const Keyword: string): string;
begin
  PrepareModels;
  Result := GetNewsCards(Keyword);
end;

function TWPNewsWebModule.GetNewsCards(const Keyword: string): string;
var
  lst: TStringList;
  _News: TWordpressNews;
  page, limit, offset, n, total, total_page: integer;
  post_date: TDateTime;
  keyword_html, page_url, pattern, order: string;
  url, title, image, card_class, thumb: string;
  has_next, is_search: boolean;
  where: array of string;
begin
  Result := '';
  is_search := Keyword <> '';
  keyword_html := HTMLEncode(Keyword);
  total := 0;
  total_page := 0;

  page := s2i(_GET['page']);
  if page < 1 then
    page := 1;
  if page > NEWS_MAX_PAGE then
    page := NEWS_MAX_PAGE;
  if is_search then
  begin
    // search: plain grid, no hero
    limit := NEWS_PER_PAGE;
    offset := (page - 1) * NEWS_PER_PAGE;
  end
  else if page = 1 then
  begin
    limit := NEWS_PER_PAGE + 1;
    offset := 0;
  end
  else
  begin
    limit := NEWS_PER_PAGE;
    offset := (NEWS_PER_PAGE + 1) + (page - 2) * NEWS_PER_PAGE;
  end;

  _News := TWordpressNews.Create();
  lst := TStringList.Create;
  try
    SetLength(where, 2);
    where[0] := 'post_type="post"';
    where[1] := 'post_status="publish"';
    order := 'post_date desc';
    if is_search then
    begin
      // the keyword comes from the request: escape the LIKE wildcards, then
      // quote the whole pattern (QuoteValue also escapes the backslashes)
      pattern := StringReplace(Keyword, '\', '\\', [rfReplaceAll]);
      pattern := StringReplace(pattern, '%', '\%', [rfReplaceAll]);
      pattern := StringReplace(pattern, '_', '\_', [rfReplaceAll]);
      pattern := _News.QuoteValue('%' + pattern + '%');
      SetLength(where, 3);
      where[2] := '(post_title LIKE ' + pattern + ' OR post_content LIKE ' + pattern + ')';
      // matches in the title first, then the newest
      order := '(post_title LIKE ' + pattern + ') desc, post_date desc';

      _News.Find(where, '', 0, 'COUNT(*) AS total');
      if _News.RecordCount > 0 then
        total := integer(_News['total']);
      total_page := (total + NEWS_PER_PAGE - 1) div NEWS_PER_PAGE;
    end;

    // one extra row tells whether there is a next page
    _News.Find(where, order, limit + 1,
      'ID,post_title,post_name,post_date,post_excerpt,post_content', offset);
    has_next := _News.RecordCount > limit;

    lst.Add('<section class="news-feed">');
    lst.Add('<header class="feed-header">');
    if is_search then
    begin
      lst.Add('<h1 class="feed-title">' + __('Search results:') + ' <q>' + keyword_html +
        '</q></h1>');
      if total = 1 then
        lst.Add('<p class="feed-meta">' + __('1 story found') + '</p>')
      else if total > 1 then
        lst.Add('<p class="feed-meta">' + Format(__('%d stories found'), [total]) + '</p>');
      lst.Add('<form role="search" method="get" class="feed-search" action="/">' +
        '<label class="screen-reader-text" for="feed-search-field">' + __('Search news') +
        '</label>' +
        '<input type="search" id="feed-search-field" name="s" value="' + keyword_html +
        '" placeholder="' + __('Search news') + '&hellip;">' +
        '<button type="submit">' + __('Search') + '</button></form>');
    end
    else if page = 1 then
      lst.Add('<h1 class="feed-title">' + __('Latest News') + '</h1>')
    else
      lst.Add('<h1 class="feed-title">' + __('Latest News') + ' <span class="feed-page">' +
        Format(__('Page %d'), [page]) + '</span></h1>');
    lst.Add('</header>');

    if _News.RecordCount = 0 then
    begin
      if is_search and (page = 1) then
        lst.Add('<p class="feed-empty">' +
          Format(__('No news matches %s. Try another keyword.'), ['<q>' + keyword_html + '</q>']) +
          '</p>')
      else if is_search then
        lst.Add('<p class="feed-empty">' + __('This page is empty.') + ' <a href="?s=' +
          UrlEncode(Keyword) + '">' + __('Back to the first page') + '</a>.</p>')
      else
        lst.Add('<p class="feed-empty">' + __('No news yet.') + '</p>');
    end
    else
    begin
      lst.Add('<div class="news-grid">');
      n := 0;
      while (not _News.Data.EOF) and (n < limit) do
      begin
        post_date := TDateTime(_News['post_date']);
        url := '/' + FormatDateTime('YYYY', post_date) + '/' +
          FormatDateTime('mm', post_date) + '/' + string(_News['post_name']) + '/';
        title := string(_News['post_title']);
        image := NewsImageURL(integer(_News['ID']), string(_News['post_content']));

        card_class := 'news-card';
        if (not is_search) and (page = 1) and (n = 0) then
          card_class := card_class + ' news-card--hero';

        if image <> '' then
        begin
          thumb := '<img src="' + HTMLEncode(image) + '" alt=""';
          if (n > 0) or is_search then
            thumb := thumb + ' loading="lazy"'
          else
            thumb := thumb + ' fetchpriority="high"';   // first card: the largest image on screen
          thumb := thumb + ' decoding="async">';
        end
        else
          thumb := '<span class="news-card-noimg"></span>';

        lst.Add('<article class="' + card_class + '">');
        lst.Add('<a class="news-card-thumb" href="' + url + '" tabindex="-1" aria-hidden="true">' +
          thumb + '</a>');
        lst.Add('<div class="news-card-body">');
        lst.Add('<h2 class="news-card-title"><a href="' + url + '">' + title + '</a></h2>');
        //lst.Add('<time class="news-card-date" datetime="' + FormatDateTime('YYYY-mm-dd', post_date) +
        //  '">' + FormatNewsDate(post_date) + '</time>');
        lst.Add('<p class="news-card-excerpt">' +
          NewsExcerpt(string(_News['post_excerpt']), string(_News['post_content']), Keyword) + '</p>');
        lst.Add('<a class="news-card-more" href="' + url + '">' + __('Read the full story') + '</a>');
        lst.Add('</div>');
        lst.Add('</article>');

        Inc(n);
        _News.Data.Next;
      end;
      lst.Add('</div>');
    end;

    // no pagination on a page past the last one (it shows a link back instead)
    if ((page > 1) or has_next) and (_News.RecordCount > 0) then
    begin
      if is_search then
        page_url := '?s=' + UrlEncode(Keyword) + '&amp;page='
      else
        page_url := '?page=';
      lst.Add('<nav class="pagination" aria-label="' + __('Page navigation') + '">');
      if page > 1 then
        lst.Add('<a class="pagination-prev" href="' + page_url + IntToStr(page - 1) +
          '" rel="prev">&larr; ' + __('Previous') + '</a>');
      if total_page > 0 then
        lst.Add('<span class="pagination-current">' +
          Format(__('Page %d of %d'), [page, total_page]) + '</span>')
      else
        lst.Add('<span class="pagination-current">' + Format(__('Page %d'), [page]) + '</span>');
      if has_next then
        lst.Add('<a class="pagination-next" href="' + page_url + IntToStr(page + 1) +
          '" rel="next">' + __('Next') + ' &rarr;</a>');
      lst.Add('</nav>');
    end;
    lst.Add('</section>');

    Result := lst.Text;
  finally
    FreeAndNil(lst);
    FreeAndNil(_News);
  end;
end;

function TWPNewsWebModule.GetRandomNews(FunctionName: string; Parameter: TStrings): string;
var
  lst: TStringList;
  _News: TWordpressNews;
  limit: integer;
  url, title: string;
  div_class: string;
begin
  Result := '';
  div_class := '';
  title := '';
  limit := 0;
  if Parameter <> nil then
  begin
    div_class := HTMLEncode(StringReplace(Parameter.Values['class'], '"', '', [rfReplaceAll]));
    title := StringReplace(Parameter.Values['title'], '"', '', [rfReplaceAll]);
    limit := s2i(Parameter.Values['number']);
  end;
  if (limit <= 0) or (limit > 100) then
    limit := 20;
  _News := TWordpressNews.Create();
  try
    _News.Find(['post_type="post"', 'post_status="publish"'], 'rand()', limit);
    if _News.RecordCount > 0 then
    begin
      lst := TStringList.Create;
      try
        if title <> '' then
        begin
          lst.Add('<div class="news-lastnews">');
          lst.Add('<h3>' + title + '</h3>');
        end;

        lst.Add('<ul class="' + div_class + '">');
        while not _News.Data.EOF do
        begin
          url := '/' + FormatDateTime('YYYY', TDateTime(_News['post_date'])) + '/' +
            FormatDateTime('mm', TDateTime(_News['post_date'])) + '/' + string(_News['post_name']) + '/';
          lst.Add('<li><a href="' + url + '">' + string(_News['post_title']) + '</a></li>');

          _News.Next;
        end;
        lst.Add('</ul>');
        if title <> '' then
          lst.Add('</div>');

        Result := lst.Text;
      finally
        FreeAndNil(lst);
      end;
    end;
  finally
    FreeAndNil(_News);
  end;
end;

function TWPNewsWebModule.GeneratePagesMenu(ParentMenu: integer; Parameter: TStrings;
  ParentBaseURL: string; IsParent: boolean): string;
var
  whereSQL, html, title, submenu, url, page_item_has_children: string;
  nav_id, nav_class: string;
  is_items, is_list: boolean;
begin
  html := '';
  is_items := Parameter.Values['type'] = 'items';
  is_list := (Parameter.Values['type'] = 'nav') or is_items;
  whereSQL := '';
  nav_id := HTMLEncode(StringReplace(Parameter.Values['id'], '"', '', [rfReplaceAll]));
  nav_class := HTMLEncode(StringReplace(Parameter.Values['class'], '"', '', [rfReplaceAll]));
  if nav_id = '' then
    nav_id := 'nav';
  with TWordpressPages.Create() do
  begin
    {$ifdef wordpress_polylang}
    if Config.GetValue(_WORDPRESS_PLUGINS_POLYLANG, False) then
    begin
      AddJoin('term_relationships', 'object_id', 'posts.ID', ['term_taxonomy_id']);
      AddJoin('terms', 'term_id', 'term_relationships.term_taxonomy_id', ['slug']);
      whereSQL := AppData.tablePrefix + 'terms.slug = ' + QuoteValue(LANG);
    end;
    {$endif}
    Find(['post_type="page"', 'post_status="publish"', 'post_parent=' + i2s(ParentMenu), whereSQL],
      'post_parent, menu_order', 0,
      'ID,post_title,post_name,post_parent');

    if RecordCount > 0 then
    begin
      if ((Parameter.Values['header'] <> '') and (ParentMenu = 0)) then
        html := Parameter.Values['header'];
      if ((Parameter.Values['type'] = 'nav') and (ParentMenu = 0)) then
        html := html + '<nav>';
      if is_items and IsParent then
        // type=items: the theme writes the <ul> and its own first items
      else if is_list then
      begin
        if IsParent then
        begin
          html := html + #13#10'<ul id="' + nav_id + '" class="' + nav_class + '">';
          html := html + #13#10'  <li><a href="' + BaseURL + '" class="on">' + __('Home') + '</a></li>';
        end
        else
        begin
          html := html + #13#10'<ul class="children sub-menu">';
        end;
      end;
      while not Data.EOF do
      begin
        submenu := '';
        title := '';
        url := '#';
        submenu := GeneratePagesMenu(Value['ID'], Parameter, ParentBaseURL + string(Value['post_name']) + '/', False);
        if submenu = '' then
          page_item_has_children := ''
        else
          page_item_has_children := 'menu-item-has-children';
        if is_list then
        begin
          if IsParent then
          begin
            html := html + #13#10'<li id="menu-item-' + string(Value['ID']) +
              '" class="menu-item ' + page_item_has_children + '">';
          end
          else
          begin
            html := html + #13#10'  <li id="menu-item-' + string(Value['ID']) +
              '" class="menu-item ' + page_item_has_children + '">';
          end;
        end;
        title := Value['post_title'];
        url := BaseURL + 'pages/' + ParentBaseURL + string(Value['post_name']);
        html := html + '<a href="' + url + '">' + title + '</a>' + submenu;
        if is_list then
          html := html + '</li>';
        Data.Next;
      end;
      Parameter.Values['parent_baseurl'] := '';
      if is_list and not (is_items and IsParent) then
        html := html + #13#10'</ul>';
      if ((Parameter.Values['type'] = 'nav') and (ParentMenu = 0)) then
        html := html + #13#10'</nav>';
      if ((Parameter.Values['footer'] <> '') and (ParentMenu = 0)) then
        html := html + Parameter.Values['footer'];
    end;
    Free;
    Result := html;
  end;
end;

constructor TWPNewsWebModule.CreateNew(AOwner: TComponent; CreateMode: integer);
begin
  inherited CreateNew(AOwner, CreateMode);
  CreateSession := True;
  OnBlockController := @DoBlockController;
  // the models are created by PrepareModels, not here: a model takes the
  // table prefix when it is created, and the prefix is only known after
  // DataBaseInit (Get runs it after this constructor)
end;

procedure TWPNewsWebModule.PrepareModels;
begin
  // View is also called by TMainModule, which never runs Get on this module
  if News = nil then
    News := TWordpressNews.Create();
  if Terms = nil then
    Terms := TWordpressTerms.Create();
  if Featuredimage = nil then
    Featuredimage := TFeaturedimage.Create();
end;

destructor TWPNewsWebModule.Destroy;
begin
  FreeAndNil(Featuredimage);
  FreeAndNil(Terms);
  FreeAndNil(News);
  inherited Destroy;
end;

function TWPNewsWebModule.View: string;
var
  thumbnail_url, title, summary, year_month: string;
  logo_w, logo_h: integer;
begin
  PrepareModels;

  // no permalink (home page, /news/, /2014/04/): latest news.
  // The route variables come from the rewrite rule (CGI) or from the route
  // pattern (standalone), so do not look at the raw query string here.
  if _GET['permalink'] = '' then
  begin
    Result := GetNewsCards;
    Exit;
  end;

  year_month := RequestYearMonth;
  if year_month = '' then
  begin
    Result := NotFoundContent;
    Exit;
  end;

  News.AddJoin('users', 'ID', 'posts.post_author', ['display_name']);
  News.Find(['date_format( post_date, "%Y%m") = ' + News.QuoteValue(year_month),
    'post_status="publish"', 'post_type="post"', 'post_name = ' + News.QuoteValue(_GET['permalink'])],
    AppData.tablePrefix + 'posts.post_date DESC');

  if News.RecordCount = 0 then
  begin
    Result := NotFoundContent;
    Exit;
  end;

  Terms.GetObjectTerms(integer(News['ID']), ['post_tag']);
  // featured image, else the first image in the post, else the site logo
  thumbnail_url := NewsImageURL(integer(News['ID']), string(News['post_content']));
  if thumbnail_url <> '' then
    ThemeUtil.Assign('featured_image', thumbnail_url)
  else
    WPSiteLogo(thumbnail_url, logo_w, logo_h);

  ThemeUtil.Assign('$news', @News.Data);
  ThemeUtil.Assign('$terms', @Terms.Data);
  //or use this : ThemeUtil.AssignVar['$news'] := @News.Data;

  // share preview (WhatsApp, Facebook, X ...)
  title := MetaText(string(News['post_title']), 0);
  summary := MetaText(NewsExcerpt(string(News['post_excerpt']), string(News['post_content'])));
  ThemeUtil.AddMeta('description', summary, 'name');
  ThemeUtil.AddMeta('og:type', 'article', 'property');
  ThemeUtil.AddMeta('og:title', title, 'property');
  ThemeUtil.AddMeta('og:site_name', MetaText(GetOptions('blogname'), 0), 'property');
  ThemeUtil.AddMeta('og:description', summary, 'property');
  if thumbnail_url <> '' then
    ThemeUtil.AddMeta('og:image', MetaText(thumbnail_url, 0), 'property');
  // share preview - end

  ThemeUtil.Assign('date01', '2014/12/30');
  ThemeUtil.Assign('date02', '2015/01/12');
  //<br />[date01 filter=nl2br]

  Result := ThemeUtil.RenderFromContent(@TagController, '', 'modules/wpnews/detail.html');
  News.AddHit(integer(News['ID']));
end;

function TWPNewsWebModule.GetOptions(const KeyName: string): string;
begin
  Result := '';
  with TWordpressOptions.Create() do
  begin
    FindFirst(['option_name=' + QuoteValue(KeyName)], '', 'option_value');
    if RecordCount > 0 then
    begin
      Result := Value['option_value'];
    end;
    Free;
  end;
end;

function TWPNewsWebModule.Tag_MainContent_Handler(const TagName: string; Params: TStringList): string;
begin
  Result := View;
end;

procedure TWPNewsWebModule.DoBlockController(Sender: TObject; FunctionName: string;
  Parameter: TStrings; var ResponseString: string);
var
  str: TStrings;
  pageName, year_month : string;
begin
  case FunctionName of
    'getoption':
    begin
      ResponseString := GetOptions(Parameter.Values['name']);
    end;
    // [text mod=wpnews func=sitelogo class=site-logo variant=light]: the logo
    // set in WordPress (Appearance > Customize > Site Identity), else
    // public_html/logo.png, '' when there is none. variant=light: for a dark
    // background, the fallback is logo-light.png when it exists
    'sitelogo':
    begin
      if Parameter.Values['class'] <> '' then
        ResponseString := WPSiteLogoHTML(Parameter.Values['class'],
          Parameter.Values['variant'] = 'light')
      else
        ResponseString := WPSiteLogoHTML('site-logo', Parameter.Values['variant'] = 'light');
    end;
    'newstitle':
    begin
      if _GET['permalink'] <> '' then
      begin
        year_month := RequestYearMonth;
        if (NewsTitle = '') and (year_month <> '') then
        begin
          with TWordpressNews.Create() do
          begin
            FindFirst(['date_format( post_date, "%Y%m") = ' + QuoteValue(year_month),
              'post_status="publish"', 'post_type="post"',
              'post_name = ' + QuoteValue(_GET['permalink'])],
              '', 'post_title');
            if RecordCount > 0 then
            begin
              NewsTitle := Value['post_title'];
            end;
            Free;
          end;
        end;
        if NewsTitle <> '' then
          ResponseString := ' - ' + NewsTitle;
      end
      else
      begin // is pages ?
        str := Explode(Application.Request.PathInfo, '/');
        try
          if (str.Count>=2) then
          begin
            if str[1] = 'pages' then
            begin
              pageName := str[str.Count - 1];
              with TWordpressNews.Create() do
              begin
                FindFirst(['post_status="publish"', 'post_type="page"',
                  'post_name=' + QuoteValue(pageName)]);
                if RecordCount > 0 then
                begin
                  ResponseString := ' - ' + string(Value['post_title']);
                end;
                Free;
              end;
            end;
          end;
        finally
          FreeAndNil(str);
        end;
      end; // is pages - end

    end; //-- newstitle
    'lastnews':
    begin
      ResponseString := GetLastNews(FunctionName, Parameter);
    end;
    'newslist':
    begin
      ResponseString := GetNewsList(Parameter);
    end;
    'newshero':
    begin
      ResponseString := GetNewsHero(Parameter);
    end;
    'herobanner':
    begin
      ResponseString := GetHeroBanner(Parameter);
    end;
    'rightbanner':
    begin
      ResponseString := GetRightBanner(Parameter);
    end;
    // [text mod=wpnews func=today]: "Senin, 9 November 2026"; format=year: "2026"
    'today':
    begin
      if Parameter.Values['format'] = 'year' then
        ResponseString := FormatDateTime('YYYY', Now)
      else
        ResponseString := FormatLongDate(Now);
    end;
    'randomnews':
    begin
      ResponseString := GetRandomNews(FunctionName, Parameter);
    end;
    'pagesmenu':
    begin
      ResponseString := GeneratePagesMenu(0, Parameter);
    end;
    // [text mod=wpnews func=langswitch class=ww-lang]: ID / EN links for the
    // theme labels; languages from config.json "languages"
    'langswitch':
    begin
      if Parameter.Values['class'] <> '' then
        ResponseString := LanguageSwitchHTML(Parameter.Values['class'])
      else
        ResponseString := LanguageSwitchHTML;
    end;

  end;

end;

// route: see routes.pas

end.
