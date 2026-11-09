unit wordpress_sitemap_controller;

{
  Two views of the same list of published addresses:
  - /sitemap.xml  (TSitemapController)    : for search engines
  - /peta-situs/  (TSitemapPageController): for people, inside the theme,
    linked from the footer

  The list is read once per request into a TStringList, one row per
  address, fields separated by #9 (see the F_* constants).
}

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, html_lib, fastplaz_app, fpjson, json_lib, HTTPDefs,
    fastplaz_handler, database_lib, dateutils, string_helpers,
    datetime_helpers, array_helpers, json_helpers;

type
  TSitemapController = class(TMyCustomController)
  private
    procedure BeforeRequestHandler(Sender: TObject; ARequest: TRequest);
  public
    constructor CreateNew(AOwner: TComponent; CreateMode: integer); override;
    destructor Destroy; override;

    procedure Get; override;
  end;

  { TSitemapPageController }

  TSitemapPageController = class(TMyCustomController)
  private
    function Tag_MainContent_Handler(const TagName: string; Params: TStringList): string;
  public
    procedure Get; override;
    function View: string;
  end;

implementation

uses math, theme_controller, common, language_lib, wordpress_news_model,
  wordpress_news_controller;

const
  // the sitemap protocol allows 50,000 URLs per file
  MAX_NEWS = 45000;
  // tags are left out for now; set to True to list /tag/the-slug/ again
  INCLUDE_TAGS = False;

  KIND_PAGE = 'page';
  KIND_CATEGORY = 'category';
  KIND_TAG = 'tag';
  KIND_NEWS = 'news';

  // fields of one row
  F_KIND = 0;
  F_PATH = 1;     // relative to the site root, no leading slash
  F_LASTMOD = 2;  // yyyy-mm-dd or ''
  F_TITLE = 3;
  F_DATE = 4;     // news: post_date yyyy-mm-dd
  F_EXTRA = 5;    // page: depth in the page tree; category/tag: post count

function XMLText(const S: string): string;
begin
  Result := StringReplace(S, '&', '&amp;', [rfReplaceAll]);
  Result := StringReplace(Result, '<', '&lt;', [rfReplaceAll]);
  Result := StringReplace(Result, '>', '&gt;', [rfReplaceAll]);
  Result := StringReplace(Result, '"', '&quot;', [rfReplaceAll]);
  Result := StringReplace(Result, '''', '&apos;', [rfReplaceAll]);
end;

// tabs and line breaks would break the row format
function OneLine(const S: string): string;
begin
  Result := StringReplace(S, #9, ' ', [rfReplaceAll]);
  Result := StringReplace(Result, #13, ' ', [rfReplaceAll]);
  Result := StringReplace(Result, #10, ' ', [rfReplaceAll]);
end;

procedure AddRow(AList: TStringList; const AKind, APath, ALastMod, ATitle: string;
  const ADate: string = ''; const AExtra: string = '');
begin
  AList.Add(AKind + #9 + APath + #9 + ALastMod + #9 + OneLine(ATitle) + #9 +
    ADate + #9 + AExtra);
end;

function Field(const ARow: string; AIndex: integer): string;
var
  parts: TStringArray;
begin
  Result := '';
  parts := ARow.Split([#9]);
  if AIndex < Length(parts) then
    Result := parts[AIndex];
end;

{ reading the list }

// /pages/parent/child/ : the parents come from post_parent. All pages are
// read, so a published child under an unpublished parent still gets its
// full path; only the published ones are listed, in tree order
// (menu order, then title) with their depth.
procedure ReadPages(AModel: TSimpleModel; AList: TStringList);
var
  ids, names, titles, parents, lastmods, published: TStringList;
  done: array of boolean;
  i: integer;

  function PathOf(AIndex: integer): string;
  var
    idx, guard: integer;
    parent: string;
  begin
    Result := names[AIndex] + '/';
    parent := parents[AIndex];
    // guard: a broken post_parent loop must not hang the request
    guard := 0;
    while (parent <> '0') and (guard < 20) do
    begin
      idx := ids.IndexOf(parent);
      if idx < 0 then
        Break;
      Result := names[idx] + '/' + Result;
      parent := parents[idx];
      Inc(guard);
    end;
    Result := 'pages/' + Result;
  end;

  procedure AddTree(AIndex, ADepth: integer);
  var
    j, child_depth: integer;
  begin
    if done[AIndex] then
      Exit;
    done[AIndex] := True;
    child_depth := ADepth;
    if published[AIndex] = '1' then
    begin
      AddRow(AList, KIND_PAGE, PathOf(AIndex), lastmods[AIndex], titles[AIndex],
        '', IntToStr(ADepth));
      child_depth := ADepth + 1;
    end;
    for j := 0 to ids.Count - 1 do
      if parents[j] = ids[AIndex] then
        AddTree(j, child_depth);
  end;

begin
  ids := TStringList.Create;
  names := TStringList.Create;
  titles := TStringList.Create;
  parents := TStringList.Create;
  lastmods := TStringList.Create;
  published := TStringList.Create;
  try
    AModel.Data.SQL.Text := 'SELECT ID, post_name, post_title, post_parent,' +
      ' post_status, post_password,' +
      ' DATE_FORMAT(post_modified, ''%Y-%m-%d'') AS lastmod' +
      ' FROM ' + AppData.tablePrefix + 'posts' +
      ' WHERE post_type = ''page'' AND post_status <> ''trash''' +
      ' AND post_name <> ''''' +
      ' ORDER BY menu_order, post_title';
    AModel.Data.Open;
    while not AModel.Data.EOF do
    begin
      ids.Add(AModel.Data.FieldByName('ID').AsString);
      names.Add(AModel.Data.FieldByName('post_name').AsString);
      titles.Add(AModel.Data.FieldByName('post_title').AsString);
      parents.Add(AModel.Data.FieldByName('post_parent').AsString);
      lastmods.Add(AModel.Data.FieldByName('lastmod').AsString);
      if (AModel.Data.FieldByName('post_status').AsString = 'publish') and
        (AModel.Data.FieldByName('post_password').AsString = '') then
        published.Add('1')
      else
        published.Add('0');
      AModel.Data.Next;
    end;
    AModel.Data.Close;

    SetLength(done, ids.Count);
    for i := 0 to ids.Count - 1 do
      done[i] := False;
    // roots: no parent, or a parent that is not a page any more
    for i := 0 to ids.Count - 1 do
      if (parents[i] = '0') or (ids.IndexOf(parents[i]) < 0) then
        AddTree(i, 0);
  finally
    FreeAndNil(published);
    FreeAndNil(lastmods);
    FreeAndNil(parents);
    FreeAndNil(titles);
    FreeAndNil(names);
    FreeAndNil(ids);
  end;
end;

// /category/the-slug/ and /tag/the-slug/, only terms that have posts
procedure ReadTerms(AModel: TSimpleModel; AList: TStringList);
var
  taxonomies: string;
begin
  taxonomies := '''category''';
  if INCLUDE_TAGS then
    taxonomies := taxonomies + ', ''post_tag''';
  AModel.Data.SQL.Text := 'SELECT t.slug, t.name, tt.taxonomy, tt.count' +
    ' FROM ' + AppData.tablePrefix + 'terms t' +
    ' INNER JOIN ' + AppData.tablePrefix + 'term_taxonomy tt' +
    ' ON tt.term_id = t.term_id' +
    ' WHERE tt.taxonomy IN (' + taxonomies + ') AND tt.count > 0' +
    // the category/tag routes accept only these characters; other slugs
    // (e.g. with an invisible %e2%80%8e) would be listed as 404 pages
    ' AND t.slug REGEXP ''^[A-Za-z0-9=_-]+$''' +
    ' ORDER BY tt.taxonomy, t.name';
  AModel.Data.Open;
  while not AModel.Data.EOF do
  begin
    if AModel.Data.FieldByName('taxonomy').AsString = 'category' then
      AddRow(AList, KIND_CATEGORY,
        'category/' + AModel.Data.FieldByName('slug').AsString + '/', '',
        AModel.Data.FieldByName('name').AsString, '',
        AModel.Data.FieldByName('count').AsString)
    else
      AddRow(AList, KIND_TAG,
        'tag/' + AModel.Data.FieldByName('slug').AsString + '/', '',
        AModel.Data.FieldByName('name').AsString, '',
        AModel.Data.FieldByName('count').AsString);
    AModel.Data.Next;
  end;
  AModel.Data.Close;
end;

// /2014/04/the-permalink/ (same address as the wpnews route), newest first
procedure ReadNews(AModel: TSimpleModel; AList: TStringList);
begin
  AModel.Data.SQL.Text := 'SELECT post_name, post_title,' +
    ' DATE_FORMAT(post_date, ''%Y/%m'') AS ym,' +
    ' DATE_FORMAT(post_date, ''%Y-%m-%d'') AS postdate,' +
    ' DATE_FORMAT(post_modified, ''%Y-%m-%d'') AS lastmod' +
    ' FROM ' + AppData.tablePrefix + 'posts' +
    ' WHERE post_type = ''post'' AND post_status = ''publish''' +
    ' AND post_password = '''' AND post_name <> ''''' +
    ' ORDER BY post_date DESC LIMIT ' + IntToStr(MAX_NEWS);
  AModel.Data.Open;
  while not AModel.Data.EOF do
  begin
    AddRow(AList, KIND_NEWS,
      AModel.Data.FieldByName('ym').AsString + '/' +
      AModel.Data.FieldByName('post_name').AsString + '/',
      AModel.Data.FieldByName('lastmod').AsString,
      AModel.Data.FieldByName('post_title').AsString,
      AModel.Data.FieldByName('postdate').AsString);
    AModel.Data.Next;
  end;
  AModel.Data.Close;
end;

// pages, categories (and tags), then news
procedure ReadSitemap(AList: TStringList);
var
  model: TWordpressNews;
begin
  model := TWordpressNews.Create();
  try
    if model.Data.Active then
      model.Data.Close;
    ReadPages(model, AList);
    ReadTerms(model, AList);
    ReadNews(model, AList);
  finally
    FreeAndNil(model);
  end;
end;

// the sitemap needs absolute addresses: config.json "baseurl" first
function SiteRoot(const ABaseURL: string): string;
begin
  Result := ABaseURL;
  if Result = '' then
    Result := 'http://' + _SERVER['SERVER_NAME'] + '/';
  if not Result.EndsWith('/') then
    Result := Result + '/';
end;

{ TSitemapController }

constructor TSitemapController.CreateNew(AOwner: TComponent; CreateMode: integer
  );
begin
  inherited CreateNew(AOwner, CreateMode);
  BeforeRequest := @BeforeRequestHandler;
end;

destructor TSitemapController.Destroy;
begin
  inherited Destroy;
end;

// Init First
procedure TSitemapController.BeforeRequestHandler(Sender: TObject;
  ARequest: TRequest);
begin
end;

// GET Method Handler
// http://domain/sitemap.xml
procedure TSitemapController.Get;
var
  rows, lines: TStringList;
  root, lastmod: string;
  i: integer;
begin
  DataBaseInit;
  root := SiteRoot(BaseURL);

  rows := TStringList.Create;
  lines := TStringList.Create;
  try
    ReadSitemap(rows);
    lines.Add('<?xml version="1.0" encoding="UTF-8"?>');
    lines.Add('<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">');
    lines.Add('<url>');
    lines.Add('  <loc>' + XMLText(root) + '</loc>');
    lines.Add('</url>');
    for i := 0 to rows.Count - 1 do
    begin
      lines.Add('<url>');
      lines.Add('  <loc>' + XMLText(root + Field(rows[i], F_PATH)) + '</loc>');
      lastmod := Field(rows[i], F_LASTMOD);
      if lastmod <> '' then
        lines.Add('  <lastmod>' + lastmod + '</lastmod>');
      lines.Add('</url>');
    end;
    lines.Add('</urlset>');

    Response.ContentType := 'application/xml; charset=utf-8';
    Response.Content := lines.Text;
  finally
    FreeAndNil(lines);
    FreeAndNil(rows);
  end;
end;

{ TSitemapPageController }

// http://domain/peta-situs/
procedure TSitemapPageController.Get;
begin
  DataBaseInit;
  LanguageInit;
  Tags['$maincontent'] := @Tag_MainContent_Handler;
  ThemeUtil.Layout := 'master';
  Response.Content := ThemeUtil.Render;
end;

function TSitemapPageController.Tag_MainContent_Handler(const TagName: string;
  Params: TStringList): string;
begin
  Result := View;
end;

function TSitemapPageController.View: string;
var
  rows, html: TStringList;
  i, count_pages, count_terms, count_news: integer;
  row, row_kind, title, month, last_month, date_text: string;
  y, m, d: word;

  // a section heading with the theme's archery-target motif
  procedure Heading(const AId, AText: string; ACount: integer);
  begin
    html.Add('<section class="sitemap-group" aria-labelledby="' + AId + '">');
    html.Add('<h2 class="ww-section-title" id="' + AId + '">' + AText +
      ' <span class="sitemap-count">' + IntToStr(ACount) + '</span></h2>');
  end;

  function LinkText(const ARow: string): string;
  begin
    Result := Trim(Field(ARow, F_TITLE));
    if Result = '' then
      Result := Field(ARow, F_PATH);
  end;

begin
  rows := TStringList.Create;
  html := TStringList.Create;
  try
    ReadSitemap(rows);
    count_pages := 0;
    count_terms := 0;
    count_news := 0;
    for i := 0 to rows.Count - 1 do
    begin
      row_kind := Field(rows[i], F_KIND);
      if row_kind = KIND_PAGE then
        Inc(count_pages)
      else if row_kind = KIND_NEWS then
        Inc(count_news)
      else
        Inc(count_terms);
    end;

    html.Add('<article class="sitemap">');
    html.Add('<header class="entry-header">');
    html.Add('<h1 class="entry-title">' + __('Sitemap') + '</h1>');
    html.Add('<p class="entry-meta">' +
      __('All pages, categories and news on this site.') + '</p>');
    html.Add('</header>');

    // pages, indented by their place in the page tree
    if count_pages > 0 then
    begin
      Heading('sitemap-pages', __('Pages'), count_pages + 1);
      html.Add('<ul class="sitemap-list">');
      html.Add('<li><a href="' + BaseURL + '">' + __('Home') + '</a></li>');
      for i := 0 to rows.Count - 1 do
        if Field(rows[i], F_KIND) = KIND_PAGE then
          html.Add('<li class="sitemap-depth-' +
            IntToStr(Min(s2i(Field(rows[i], F_EXTRA)), 4)) + '"><a href="/' +
            Field(rows[i], F_PATH) + '">' + LinkText(rows[i]) + '</a></li>');
      html.Add('</ul></section>');
    end;

    // categories (and tags), with the number of posts in each
    if count_terms > 0 then
    begin
      Heading('sitemap-terms', __('Categories'), count_terms);
      html.Add('<ul class="sitemap-terms">');
      for i := 0 to rows.Count - 1 do
      begin
        row_kind := Field(rows[i], F_KIND);
        if (row_kind = KIND_CATEGORY) or (row_kind = KIND_TAG) then
          html.Add('<li><a href="/' + Field(rows[i], F_PATH) + '">' +
            LinkText(rows[i]) + '</a> <span class="sitemap-count">' +
            Field(rows[i], F_EXTRA) + '</span></li>');
      end;
      html.Add('</ul></section>');
    end;

    // news, newest first, grouped by month
    Heading('sitemap-news', __('News'), count_news);
    if count_news = 0 then
      html.Add('<p class="feed-empty">' + __('No news published yet.') + '</p>')
    else
    begin
      last_month := '';
      for i := 0 to rows.Count - 1 do
      begin
        row := rows[i];
        if Field(row, F_KIND) <> KIND_NEWS then
          Continue;
        date_text := Field(row, F_DATE);
        month := Copy(date_text, 1, 7);
        y := s2i(Copy(date_text, 1, 4));
        m := s2i(Copy(date_text, 6, 2));
        d := s2i(Copy(date_text, 9, 2));
        if month <> last_month then
        begin
          if last_month <> '' then
            html.Add('</ul>');
          html.Add('<h3 class="sitemap-month">' + FormatMonthYear(y, m) + '</h3>');
          html.Add('<ul class="sitemap-list">');
          last_month := month;
        end;
        title := LinkText(row);
        if (y > 0) and (m in [1..12]) and (d in [1..31]) then
          html.Add('<li><a href="/' + Field(row, F_PATH) + '">' + title +
            '</a> <time datetime="' + date_text + '">' +
            FormatNewsDate(EncodeDate(y, m, d)) + '</time></li>')
        else
          html.Add('<li><a href="/' + Field(row, F_PATH) + '">' + title + '</a></li>');
      end;
      html.Add('</ul>');
    end;
    html.Add('</section>');

    html.Add('<p class="sitemap-xml">' +
      __('Search engines read the same list from') + ' <a href="' + BaseURL +
      'sitemap.xml">sitemap.xml</a>.</p>');
    html.Add('</article>');
    Result := html.Text;
  finally
    FreeAndNil(html);
    FreeAndNil(rows);
  end;
end;


end.
