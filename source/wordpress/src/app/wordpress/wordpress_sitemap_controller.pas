unit wordpress_sitemap_controller;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, html_lib, fastplaz_app, fpjson, json_lib, HTTPDefs,
    fastplaz_handler, database_lib, dateutils, string_helpers,
    datetime_helpers, array_helpers, json_helpers;

type
  TSitemapController = class(TMyCustomController)
  private
    FRoot: string;
    FLines: TStringList;
    procedure BeforeRequestHandler(Sender: TObject; ARequest: TRequest);
    procedure AddURL(const APath, ALastMod: string);
    procedure AddNews(AModel: TSimpleModel);
    procedure AddPages(AModel: TSimpleModel);
    procedure AddTerms(AModel: TSimpleModel);
  public
    constructor CreateNew(AOwner: TComponent; CreateMode: integer); override;
    destructor Destroy; override;

    procedure Get; override;
  end;

implementation

uses theme_controller, common, wordpress_news_model;

const
  // the sitemap protocol allows 50,000 URLs per file
  MAX_NEWS = 45000;
  // tags are left out for now; set to True to list /tag/the-slug/ again
  INCLUDE_TAGS = False;

function XMLText(const S: string): string;
begin
  Result := StringReplace(S, '&', '&amp;', [rfReplaceAll]);
  Result := StringReplace(Result, '<', '&lt;', [rfReplaceAll]);
  Result := StringReplace(Result, '>', '&gt;', [rfReplaceAll]);
  Result := StringReplace(Result, '"', '&quot;', [rfReplaceAll]);
  Result := StringReplace(Result, '''', '&apos;', [rfReplaceAll]);
end;

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

// APath is relative to the site root, without the leading slash
procedure TSitemapController.AddURL(const APath, ALastMod: string);
begin
  FLines.Add('<url>');
  FLines.Add('  <loc>' + XMLText(FRoot + APath) + '</loc>');
  if ALastMod <> '' then
    FLines.Add('  <lastmod>' + ALastMod + '</lastmod>');
  FLines.Add('</url>');
end;

// /2014/04/the-permalink/ (same address as the wpnews route)
procedure TSitemapController.AddNews(AModel: TSimpleModel);
begin
  AModel.Data.SQL.Text := 'SELECT post_name,' +
    ' DATE_FORMAT(post_date, ''%Y/%m'') AS ym,' +
    ' DATE_FORMAT(post_modified, ''%Y-%m-%d'') AS lastmod' +
    ' FROM ' + AppData.tablePrefix + 'posts' +
    ' WHERE post_type = ''post'' AND post_status = ''publish''' +
    ' AND post_password = '''' AND post_name <> ''''' +
    ' ORDER BY post_date DESC LIMIT ' + IntToStr(MAX_NEWS);
  AModel.Data.Open;
  while not AModel.Data.EOF do
  begin
    AddURL(AModel.Data.FieldByName('ym').AsString + '/' +
      AModel.Data.FieldByName('post_name').AsString + '/',
      AModel.Data.FieldByName('lastmod').AsString);
    AModel.Data.Next;
  end;
  AModel.Data.Close;
end;

// /pages/parent/child/ : the parents come from post_parent. All pages are
// read, so a published child under an unpublished parent still gets its
// full path; only the published ones are listed.
procedure TSitemapController.AddPages(AModel: TSimpleModel);
var
  ids, names, parents, lastmods, published: TStringList;
  i, idx, guard: integer;
  path, parent: string;
begin
  ids := TStringList.Create;
  names := TStringList.Create;
  parents := TStringList.Create;
  lastmods := TStringList.Create;
  published := TStringList.Create;
  try
    AModel.Data.SQL.Text := 'SELECT ID, post_name, post_parent, post_status,' +
      ' post_password,' +
      ' DATE_FORMAT(post_modified, ''%Y-%m-%d'') AS lastmod' +
      ' FROM ' + AppData.tablePrefix + 'posts' +
      ' WHERE post_type = ''page'' AND post_status <> ''trash''' +
      ' AND post_name <> ''''';
    AModel.Data.Open;
    while not AModel.Data.EOF do
    begin
      ids.Add(AModel.Data.FieldByName('ID').AsString);
      names.Add(AModel.Data.FieldByName('post_name').AsString);
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

    for i := 0 to ids.Count - 1 do
    begin
      if published[i] <> '1' then
        Continue;
      path := names[i] + '/';
      parent := parents[i];
      // guard: a broken post_parent loop must not hang the request
      guard := 0;
      while (parent <> '0') and (parent <> '') and (guard < 20) do
      begin
        idx := ids.IndexOf(parent);
        if idx < 0 then
          Break;
        path := names[idx] + '/' + path;
        parent := parents[idx];
        Inc(guard);
      end;
      AddURL('pages/' + path, lastmods[i]);
    end;
  finally
    FreeAndNil(published);
    FreeAndNil(lastmods);
    FreeAndNil(parents);
    FreeAndNil(names);
    FreeAndNil(ids);
  end;
end;

// /category/the-slug/ and /tag/the-slug/, only terms that have posts
procedure TSitemapController.AddTerms(AModel: TSimpleModel);
var
  taxonomies: string;
begin
  taxonomies := '''category''';
  if INCLUDE_TAGS then
    taxonomies := taxonomies + ', ''post_tag''';
  AModel.Data.SQL.Text := 'SELECT t.slug, tt.taxonomy' +
    ' FROM ' + AppData.tablePrefix + 'terms t' +
    ' INNER JOIN ' + AppData.tablePrefix + 'term_taxonomy tt' +
    ' ON tt.term_id = t.term_id' +
    ' WHERE tt.taxonomy IN (' + taxonomies + ') AND tt.count > 0' +
    // the category/tag routes accept only these characters; other slugs
    // (e.g. with an invisible %e2%80%8e) would be listed as 404 pages
    ' AND t.slug REGEXP ''^[A-Za-z0-9=_-]+$''' +
    ' ORDER BY tt.taxonomy, t.slug';
  AModel.Data.Open;
  while not AModel.Data.EOF do
  begin
    if AModel.Data.FieldByName('taxonomy').AsString = 'category' then
      AddURL('category/' + AModel.Data.FieldByName('slug').AsString + '/', '')
    else
      AddURL('tag/' + AModel.Data.FieldByName('slug').AsString + '/', '');
    AModel.Data.Next;
  end;
  AModel.Data.Close;
end;

// GET Method Handler
// http://domain/sitemap.xml
procedure TSitemapController.Get;
var
  model: TWordpressNews;
begin
  DataBaseInit;

  // the sitemap needs absolute addresses: config.json "baseurl" first
  FRoot := BaseURL;
  if FRoot = '' then
    FRoot := 'http://' + _SERVER['SERVER_NAME'] + '/';
  if not FRoot.EndsWith('/') then
    FRoot := FRoot + '/';

  FLines := TStringList.Create;
  model := TWordpressNews.Create();
  try
    FLines.Add('<?xml version="1.0" encoding="UTF-8"?>');
    FLines.Add('<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">');
    AddURL('', '');
    if model.Data.Active then
      model.Data.Close;
    AddPages(model);
    AddTerms(model);
    AddNews(model);
    FLines.Add('</urlset>');

    Response.ContentType := 'application/xml; charset=utf-8';
    Response.Content := FLines.Text;
  finally
    FreeAndNil(model);
    FreeAndNil(FLines);
  end;
end;


end.
