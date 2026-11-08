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

implementation

uses theme_controller, common, wordpress_news_controller;

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
begin
  DataBaseInit;
  LanguageInit;

  // facebook content sharing
  ThemeUtil.AddMeta('og:type', 'article', 'property');
  ThemeUtil.AddMeta('og:title', 'FastPlaz, Fast Web Framework for Pascal', 'property');
  ThemeUtil.AddMeta('og:site_name', AppData.sitename, 'property');
  ThemeUtil.AddMeta('og:description', AppData.slogan, 'property');
  ThemeUtil.AddMeta('og:image', string(Config.GetValue('wordpress/base_url', '')) + '/logo.png', 'property');
  // facebook content sharing - end

  if _GET['s'] <> '' then
  begin
    Tags['$maincontent'] := @Tag_Search_ContentHandler; //<<-- tag search-content handler
    Response.Content := ThemeUtil.Render(nil, 'master');
  end
  else
  begin
    Tags['$maincontent'] := @Tag_MainContent_Handler; //<<-- tag $maincontent handler

    ThemeUtil.Layout := 'master'; // try with 'home'
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


end.
