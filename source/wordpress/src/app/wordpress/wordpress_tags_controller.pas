unit wordpress_tags_controller;

{$mode objfpc}{$H+}
{$include define.inc}

interface

uses
  fastplaz_app, fastplaz_handler, httpdefs, fpHTTP,
  Classes, SysUtils;

type

  { TWPTagsWebModule }

  TWPTagsWebModule = class(TMyCustomController)
  private
    function GetTagCloud(Parameter: TStrings): string;
  public
    constructor CreateNew(AOwner: TComponent; CreateMode: integer); override;
    destructor Destroy; override;

    procedure Get; override;
    function View: string;
    procedure TagController(Sender: TObject; const TagString: string;
      TagParams: TStringList; Out ReplaceText: string);

    // Handler / Controller
    procedure DoBlockController(Sender: TObject; FunctionName: string;
      Parameter: TStrings; var ResponseString: string);
  end;

implementation

uses database_lib, common, language_lib, html_lib, theme_controller,
  wordpress_news_model, wordpress_tags_model;

{ TWPTagsWebModule }

// example:
// http://domain/tag/the-slug/
procedure TWPTagsWebModule.Get;
begin
  DataBaseInit;
  LanguageInit;

  Response.Content := ThemeUtil.Render(@TagController, '', true);
end;

function TWPTagsWebModule.GetTagCloud(Parameter: TStrings): string;
var
  tags_news: TWordpressTags;
  lst: TStringList;
  url, title, style: string;
  number: integer;
begin
  Result := '';
  number := s2i(Parameter.Values['number']);
  if (number <= 0) or (number > 200) then
    number := 50;
  tags_news := TWordpressTags.Create();
  tags_news.AddInnerJoin( 'term_taxonomy', 'term_id', 'terms.term_id', []);
  tags_news.Find([ AppData.tablePrefix+'term_taxonomy.taxonomy IN ("post_tag")'],
    'rand()', number);
  if tags_news.RecordCount > 0 then
  begin
    lst := TStringList.Create;
    lst.Add('<div class="tagcloud">');
    if Parameter.Values['title'] <> '' then
    begin
      title := StringReplace(Parameter.Values['title'], '"', '', [rfReplaceAll]);
      lst.Add('<h3>' + title + '</h3>');
    end;
    Randomize;
    while not tags_news.Data.EOF do
    begin
      url := BaseURL + 'tag/' + string(tags_news['slug']) + '/';
      title := string(tags_news['name']);
      // style=none: no random font size, the theme styles the tags
      if Parameter.Values['style'] = 'none' then
        lst.Add('<a href="' + url + '">' + LowerCase(title) + '</a> ')
      else
      begin
        style := 'font-size:' + i2s(7 + random(8)) + 'pt;';
        lst.Add('<a href="' + url + '" title="' + title + '" style="' + style + '">' +
          LowerCase(title) + '</a> ');
      end;
      //style="font-size: 9.92660550459pt;">

      tags_news.Data.Next;
    end;
    lst.Add('</div>');
    Result := lst.Text;
    FreeAndNil(lst);
  end;

  FreeAndNil(tags_news);
end;

constructor TWPTagsWebModule.CreateNew(AOwner: TComponent; CreateMode: integer);
begin
  inherited CreateNew(AOwner, CreateMode);
  CreateSession := True;
  OnBlockController := @DoBlockController;
end;

destructor TWPTagsWebModule.Destroy;
begin
  inherited Destroy;
end;

function TWPTagsWebModule.View: string;
var
  url, tags_news: string;
  News: TWordpressNews;
begin
  // set by the route pattern (routes.pas); the path is the fallback
  tags_news := _GET['tag'];
  if tags_news = '' then
  begin
    tags_news := StringReplace(Application.Request.PathInfo, '/tags/', '', [rfReplaceAll]);
    tags_news := StringReplace(tags_news, '/tag/', '', [rfReplaceAll]);
    tags_news := StringReplace(tags_news, '/', '', [rfReplaceAll]);
  end;
  if tags_news = '' then
  begin
    Result := 'Last Tags Lists';
    exit;
  end;

  News := TWordpressNews.Create();
  if not News.FindByTags(tags_news) then
  begin
    // tags_news comes from the URL: encode it before it goes into the page
    Result := H2( format( __( __Tag_Content_Not_Found), [HTMLEncode(tags_news)]));
    FreeAndNil(News);
    Exit;
  end;

  Result := '<div class="entry-content">'
    + h2('Article for "' + HTMLEncode(tags_news) + '"')
    + '<ul class="list recentposts-widget">';
  while not News.Data.EOF do
  begin
    url := '/' + FormatDateTime('YYYY', TDateTime(News.Value['post_date'])) +
      '/' + FormatDateTime('mm', TDateTime(News.Value['post_date'])) +
      '/' + string(News.Value['post_name']) + '/';
    Result := Result + '<li><a href="' + url + '">' + string(News.Value['post_title']) +
      '</a></li>';
    News.Data.Next;
  end;
  Result := Result + '</ul></div>';


  FreeAndNil(News);
end;

procedure TWPTagsWebModule.TagController(Sender: TObject; const TagString: string;
  TagParams: TStringList; out ReplaceText: string);
var
  tags_news: TStringList;
begin
  inherited TagController(Sender, TagString, TagParams, ReplaceText);
  tags_news := ExplodeTags(TagString);
  if tags_news.Count = 0 then
  begin
    ReplaceText := '[]';
    FreeAndNil(tags_news);
    Exit;
  end;
  case tags_news[0] of
    '$maincontent':
    begin
      ReplaceText := View;
    end;
  end;

  FreeAndNil(tags_news);
end;

procedure TWPTagsWebModule.DoBlockController(Sender: TObject;
  FunctionName: string; Parameter: TStrings; var ResponseString: string);
begin
  case FunctionName of
    'tagcloud':
    begin
      ResponseString := GetTagCloud(Parameter);
    end;
  end;
end;

// route: see routes.pas

end.
