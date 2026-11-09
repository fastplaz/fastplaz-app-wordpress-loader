unit main;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fastplaz_app, HTTPDefs, fastplaz_handler, html_lib, database_lib,
  wordpress_news_model;

type

  { TMainModule }

  TMainModule = class(TMyCustomController)
  private
    function Tag_Search_ContentHandler(const TagName: string; Params: TStringList): string;
    function Tag_MainContent_Handler(const TagName: string; Params: TStringList): string;
  public
    constructor CreateNew(AOwner: TComponent; CreateMode: integer); override;
    destructor Destroy; override;

    procedure Get; override;
  end;

  { TNotFoundModule: every address no other route knows (registered last) }

  TNotFoundModule = class(TMyCustomController)
  private
    function Tag_MainContent_Handler(const TagName: string; Params: TStringList): string;
  public
    procedure Get; override;
  end;

implementation

uses theme_controller, common, wordpress_news_controller, wordpress_site_lib;

constructor TMainModule.CreateNew(AOwner: TComponent; CreateMode: integer);
begin
  inherited CreateNew(AOwner, CreateMode);
end;

destructor TMainModule.Destroy;
begin
  inherited Destroy;
end;

// GET Method Handler
procedure TMainModule.Get;
var
  site_name, slogan, logo_url: string;
  logo_w, logo_h: integer;
begin
  DataBaseInit;
  LanguageInit;

  // share preview (WhatsApp, Facebook, X ...): the identity set in WordPress
  site_name := MetaText(WPOption('blogname'), 0);
  slogan := MetaText(WPOption('blogdescription'));
  if slogan <> '' then
    ThemeUtil.AddMeta('description', slogan, 'name');
  ThemeUtil.AddMeta('og:type', 'website', 'property');
  ThemeUtil.AddMeta('og:title', site_name, 'property');
  ThemeUtil.AddMeta('og:site_name', site_name, 'property');
  if slogan <> '' then
    ThemeUtil.AddMeta('og:description', slogan, 'property');
  if WPSiteLogo(logo_url, logo_w, logo_h) then
    ThemeUtil.AddMeta('og:image', MetaText(logo_url, 0), 'property');
  // share preview - end

  if _GET['s'] <> '' then
  begin
    Tags['$maincontent'] := @Tag_Search_ContentHandler; //<<-- tag search-content handler
    Response.Content := ThemeUtil.Render(nil, 'master');
  end
  else
  begin
    Tags['$maincontent'] := @Tag_MainContent_Handler; //<<-- tag $maincontent handler

    // the first page uses the theme's home layout; ?page=2.. the news list
    if s2i(_GET['page']) <= 1 then
      ThemeUtil.Layout := 'home'
    else
      ThemeUtil.Layout := 'master';
    Response.Content := ThemeUtil.Render;
  end;
end;

function TMainModule.Tag_Search_ContentHandler(const TagName: string; Params: TStringList): string;
var
  keyword: string;
begin
  // raw value, not _GET: _GET adds backslashes (\' \"), so a search for
  // "ta'zhim" would never match. Search escapes the LIKE wildcards, quotes
  // the value for SQL and html-encodes it for the page.
  keyword := Trim(Copy(Trim(Application.Request.QueryFields.Values['s']), 1, 100));
  with TWPNewsWebModule.CreateNew(self, 0) do
  begin
    Result := Search(keyword);
    Free;
  end;
end;

function TMainModule.Tag_MainContent_Handler(const TagName: string; Params: TStringList): string;
begin
  with TWPNewsWebModule.CreateNew(self, 0) do
  begin
    Result := View;
    Free;
  end;
end;

{ TNotFoundModule }

procedure TNotFoundModule.Get;
begin
  DataBaseInit;
  LanguageInit;
  Tags['$maincontent'] := @Tag_MainContent_Handler;
  ThemeUtil.Layout := 'master';
  Response.Content := ThemeUtil.Render;
  // set again after rendering: the status must be 404, not a redirect to "/"
  Response.Code := 404;
  Response.CodeText := 'Not Found';
end;

function TNotFoundModule.Tag_MainContent_Handler(const TagName: string; Params: TStringList): string;
begin
  Result := NotFoundContent;
end;

end.
