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
  wordpress_options_model, wordpress_nggallery_model, wordpress_pages_model,
  wordpress_category_controller;

const
  NEWS_PER_PAGE = 9;        // cards per page; page 1 shows one extra (hero)
  NEWS_MAX_PAGE = 10000;
  NEWS_EXCERPT_LENGTH = 180;
  NEWS_MONTHS: array[1..12] of string = ('Jan', 'Feb', 'Mar', 'Apr', 'Mei',
    'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des');

function FormatNewsDate(const ADate: TDateTime): string;
var
  y, m, d: word;
begin
  DecodeDate(ADate, y, m, d);
  Result := IntToStr(d) + ' ' + NEWS_MONTHS[m] + ' ' + IntToStr(y);
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
function NewsExcerpt(const Excerpt, Content: string; const Keyword: string = ''): string;
var
  s: string;
  p, start: integer;
  cut: boolean;
begin
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
      Result := CutText(Copy(s, start, MaxInt), NEWS_EXCERPT_LENGTH, cut);
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
  Result := CutText(PlainText(s), NEWS_EXCERPT_LENGTH, cut);
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

{ TWPNewsWebModule }

// example:
// http://domain/2014/04/dialog-keajaiban-silat-silat-untuk-kehidupan/
procedure TWPNewsWebModule.Get;
begin
  DataBaseInit;
  LanguageInit;
  QueryExec('SET CHARACTER SET utf8mb4;');

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
const
  UPLOADS = 'wp-content/uploads/';
var
  upload_url: string;
begin
  // 1. featured image, 2. first image in the content
  Result := Featuredimage.GetFeaturedImageURLByID(NewsID);
  if Result = '' then
    Exit(FirstImageURL(Content));
  if Pos('://', Result) > 0 then
    Exit;

  // optional "wordpress/upload_url": the public url of wp-content/uploads,
  // for sites whose media live on another host (cdn / content domain)
  upload_url := Trim(string(Config.GetValue('wordpress/upload_url', '')));
  while (upload_url <> '') and (upload_url[Length(upload_url)] = '/') do
    System.Delete(upload_url, Length(upload_url), 1);
  if (upload_url <> '') and (Pos(UPLOADS, Result) = 1) then
    Result := upload_url + '/' + Copy(Result, Length(UPLOADS) + 1, MaxInt)
  else
    Result := string(Config.GetValue('wordpress/base_url', '')) +
      string(Config.GetValue('wordpress/path', '')) + '/' + Result;
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
      lst.Add('<h1 class="feed-title">Hasil pencarian: <q>' + keyword_html + '</q></h1>');
      if total > 0 then
        lst.Add('<p class="feed-meta">' + IntToStr(total) + ' berita ditemukan</p>');
      lst.Add('<form role="search" method="get" class="feed-search" action="/">' +
        '<label class="screen-reader-text" for="feed-search-field">Cari berita:</label>' +
        '<input type="search" id="feed-search-field" name="s" value="' + keyword_html +
        '" placeholder="Cari berita&hellip;">' +
        '<button type="submit">Cari</button></form>');
    end
    else if page = 1 then
      lst.Add('<h1 class="feed-title">Berita Terbaru</h1>')
    else
      lst.Add('<h1 class="feed-title">Berita Terbaru <span class="feed-page">Halaman ' +
        IntToStr(page) + '</span></h1>');
    lst.Add('</header>');

    if _News.RecordCount = 0 then
    begin
      if is_search and (page = 1) then
        lst.Add('<p class="feed-empty">Tidak ada berita yang cocok dengan <q>' + keyword_html +
          '</q>. Coba kata kunci lain.</p>')
      else if is_search then
        lst.Add('<p class="feed-empty">Halaman ini kosong. <a href="?s=' + UrlEncode(Keyword) +
          '">Kembali ke halaman pertama</a>.</p>')
      else
        lst.Add('<p class="feed-empty">Belum ada berita.</p>');
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
            thumb := thumb + ' loading="lazy"';
          thumb := thumb + ' decoding="async">';
        end
        else
          thumb := '<span class="news-card-noimg"></span>';

        lst.Add('<article class="' + card_class + '">');
        lst.Add('<a class="news-card-thumb" href="' + url + '" tabindex="-1" aria-hidden="true">' +
          thumb + '</a>');
        lst.Add('<div class="news-card-body">');
        lst.Add('<time class="news-card-date" datetime="' + FormatDateTime('YYYY-mm-dd', post_date) +
          '">' + FormatNewsDate(post_date) + '</time>');
        lst.Add('<h2 class="news-card-title"><a href="' + url + '">' + title + '</a></h2>');
        lst.Add('<p class="news-card-excerpt">' +
          NewsExcerpt(string(_News['post_excerpt']), string(_News['post_content']), Keyword) + '</p>');
        lst.Add('<a class="news-card-more" href="' + url + '">Baca selengkapnya</a>');
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
      lst.Add('<nav class="pagination" aria-label="Navigasi halaman">');
      if page > 1 then
        lst.Add('<a class="pagination-prev" href="' + page_url + IntToStr(page - 1) +
          '" rel="prev">&larr; Sebelumnya</a>');
      if total_page > 0 then
        lst.Add('<span class="pagination-current">Halaman ' + IntToStr(page) + ' dari ' +
          IntToStr(total_page) + '</span>')
      else
        lst.Add('<span class="pagination-current">Halaman ' + IntToStr(page) + '</span>');
      if has_next then
        lst.Add('<a class="pagination-next" href="' + page_url + IntToStr(page + 1) +
          '" rel="next">Berikutnya &rarr;</a>');
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
begin
  html := '';
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
      if Parameter.Values['type'] = 'nav' then
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
        if Parameter.Values['type'] = 'nav' then
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
        if Parameter.Values['type'] = 'nav' then
          html := html + '</li>';
        Data.Next;
      end;
      Parameter.Values['parent_baseurl'] := '';
      if Parameter.Values['type'] = 'nav' then
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
  thumbnail_url, title, year_month: string;
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
    Result := H2(__(__Content_Not_Found));
    Exit;
  end;

  News.AddJoin('users', 'ID', 'posts.post_author', ['display_name']);
  News.Find(['date_format( post_date, "%Y%m") = ' + News.QuoteValue(year_month),
    'post_status="publish"', 'post_type="post"', 'post_name = ' + News.QuoteValue(_GET['permalink'])],
    AppData.tablePrefix + 'posts.post_date DESC');

  if News.RecordCount = 0 then
  begin
    Result := H2(__(__Content_Not_Found));
    Exit;
  end;

  Terms.GetObjectTerms(integer(News['ID']), ['post_tag']);
  thumbnail_url := Featuredimage.GetFeaturedImageURLByID(integer(News['ID']));
  if thumbnail_url = '' then
    thumbnail_url := string(Config.GetValue('wordpress/base_url', '')) + '/logo.png'
  else
  begin
    thumbnail_url := string(Config.GetValue('wordpress/base_url', '')) +
      string(Config.GetValue('wordpress/path', '')) + '/' + thumbnail_url;
    ThemeUtil.Assign('featured_image', thumbnail_url);
  end;

  ThemeUtil.Assign('$news', @News.Data);
  ThemeUtil.Assign('$terms', @Terms.Data);
  //or use this : ThemeUtil.AssignVar['$news'] := @News.Data;

  // facebook content sharing
  title := string(News['post_title']);
  ThemeUtil.AddMeta('description', title, 'property');
  ThemeUtil.AddMeta('og:type', 'article', 'property');
  ThemeUtil.AddMeta('og:title', title, 'property');
  ThemeUtil.AddMeta('og:site_name', GetOptions('blogname'), 'property');
  ThemeUtil.AddMeta('og:description', GetOptions('blogdescription') + ', ' + title, 'property');
  ThemeUtil.AddMeta('og:image', thumbnail_url, 'property');
  // facebook content sharing - end

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
                  ResponseString := Value['post_title'];
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
    'randomnews':
    begin
      ResponseString := GetRandomNews(FunctionName, Parameter);
    end;
    'pagesmenu':
    begin
      ResponseString := GeneratePagesMenu(0, Parameter);
    end;

  end;

end;

// route: see routes.pas

end.
