unit main;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcgi, HTTPDefs, fastplaz_handler, html_lib, database_lib, wordpress_news_model;

type

  { TMainModule }

  TMainModule = class(TMyCustomWebModule)
    procedure RequestHandler(Sender: TObject; ARequest: TRequest; AResponse: TResponse; var Handled: boolean);
  private
    News: TWordpressNews;
    function Tag_Search_ContentHandler(const TagName: string; Params: TStringList): string;
    function Tag_MainContent_Handler(const TagName: string; Params: TStringList): string;
  public
    constructor CreateNew(AOwner: TComponent; CreateMode: integer); override;
    destructor Destroy; override;
  end;

implementation

uses theme_controller, common, wordpress_news_controller;

constructor TMainModule.CreateNew(AOwner: TComponent; CreateMode: integer);
begin
  inherited CreateNew(AOwner, CreateMode);
  News := TWordpressNews.Create();
  OnRequest := @RequestHandler;
end;

destructor TMainModule.Destroy;
begin
  FreeAndNil(News);
  inherited Destroy;
end;

procedure TMainModule.RequestHandler(Sender: TObject; ARequest: TRequest; AResponse: TResponse; var Handled: boolean);
begin
  DataBaseInit;
  LanguageInit;

  // facebook content sharing
  ThemeUtil.AddMeta('og:type', 'article', 'property');
  ThemeUtil.AddMeta('og:title', 'FastPlaz, Fast Web Framework for Pascal', 'property');
  ThemeUtil.AddMeta('og:site_name', AppData.sitename, 'property');
  ThemeUtil.AddMeta('og:description', AppData.slogan, 'property');
  ThemeUtil.AddMeta('og:image', Config.GetValue('wordpress/base_url', '') + '/logo.png', 'property');
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


  Handled := True;
end;

function TMainModule.Tag_Search_ContentHandler(const TagName: string; Params: TStringList): string;
begin
  News.SearchNews(_GET['s']);
  ThemeUtil.AssignVar['$news'] := @News.Data;
  ThemeUtil.Assign('search', _GET['s']);
  Result := ThemeUtil.RenderFromContent(nil, '', 'modules/wpnews/search.html');
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
