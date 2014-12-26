unit wordpress_category_controller;

{$mode objfpc}{$H+}
{$include define.inc}

interface

uses
  fpcgi, fastplaz_handler, httpdefs, fpHTTP,
  Classes, SysUtils;

type

  { TWPCategoryWebModule }

  TWPCategoryWebModule = class(TMyCustomWebModule)
    procedure RequestHandler(Sender: TObject; ARequest: TRequest; AResponse: TResponse; var Handled: boolean);
  private
    CategoryTitle, CategoryURL: string;
    function GetCategoryList(FunctionName: string; Parameter: TStrings): string;
    function Tag_MainContent_Handler(const TagName: string; Params: TStringList): string;
    function Tag_Category_Handler(const TagName: string; Params: TStringList): string;
  public
    constructor CreateNew(AOwner: TComponent; CreateMode: integer); override;
    destructor Destroy; override;

    // Handler / Controller
    procedure DoBlockController(Sender: TObject; FunctionName: string; Parameter: TStrings;
      var ResponseString: string);
  end;

implementation

uses wordpress_terms_model, wordpress_news_model, database_lib, html_lib,
  common, language_lib, theme_controller;

{ TWPCategoryWebModule }

procedure TWPCategoryWebModule.RequestHandler(Sender: TObject; ARequest: TRequest;
  AResponse: TResponse; var Handled: boolean);
begin
  DataBaseInit;
  LanguageInit;

  if _GET['name'] = '' then
    Redirect(BaseURL);

  Tags['$maincontent'] := @Tag_MainContent_Handler;
  Response.Content := ThemeUtil.Render(@TagController, '', True);
  Handled := True;
end;

function TWPCategoryWebModule.GetCategoryList(FunctionName: string; Parameter: TStrings): string;
var
  lst: TStringList;
  Terms: TWordpressTerms;
  url, title: string;
  div_class: string;
begin
  div_class := StringReplace(Parameter.Values['class'], '"', '', [rfReplaceAll]);
  Terms := TWordpressTerms.Create();
  Terms.AddJoin( 'term_taxonomy', 'term_id', 'terms.term_id', ['taxonomy']);
  Terms.Find(['taxonomy="category"'], 'name');
  if Terms.RecordCount > 0 then
  begin
    lst := TStringList.Create;
    lst.Add('<div class="category-list">');
    if Parameter.Values['title'] <> '' then
    begin
      title := StringReplace(Parameter.Values['title'], '"', '', [rfReplaceAll]);
      lst.Add('<h3>' + title + '</h3>');
    end;
    lst.Add('<ul class="' + div_class + '">');
    while not Terms.Data.EOF do
    begin
      url := BaseURL + 'category/' + Terms['slug'].AsString + '/';
      lst.Add('<li><a href="' + url + '">' + Terms['name'].AsString + '</a></li>');
      Terms.Data.Next;
    end;
    lst.Add('</ul>');
    lst.Add('</div>');
    Result := lst.Text;
    FreeAndNil(lst);
  end;
  FreeAndNil(Terms);
end;

function TWPCategoryWebModule.Tag_MainContent_Handler(const TagName: string; Params: TStringList): string;
var
  category_id: integer;
  News: TWordpressNews;
begin

  with TWordpressTerms.Create() do
  begin
    AddJoin( 'term_taxonomy', 'term_id', 'terms.term_id', ['taxonomy']);
    FindFirst(['taxonomy="category"', 'slug="' + _GET['name'] + '"'], 'name');
    if RecordCount = 0 then
    begin
      Result := H2(__(__Content_Not_Found), 'center');
      Free;
      Exit;
    end;
    category_id := Value['term_id'];
    CategoryTitle := Value['name'];
    CategoryURL := BaseURL + 'category/' + Value['slug'] + '/';
    Free;
  end;

  News := TWordpressNews.Create();
  News.AddJoin( 'term_relationships', 'object_id', 'posts.ID', ['object_id']);
  News.Find(['post_status="publish"', 'post_type="post"', AppData.tablePrefix +
    'term_relationships.term_taxonomy_id=' + i2s(category_id)], 'post_date desc', 10);


  Tags['$category_title'] := @Tag_Category_Handler;
  Tags['$category_url'] := @Tag_Category_Handler;


  ThemeUtil.AssignVar['$news'] := @News.Data;
  //or use this
  //ThemeUtil.Assign('$news', @News.Data);

  Result := ThemeUtil.RenderFromContent(@TagController, '', 'modules/wpnews/category.html');
  FreeAndNil(News);
end;

function TWPCategoryWebModule.Tag_Category_Handler(const TagName: string; Params: TStringList): string;
begin
  case TagName of
    '$category_title':
    begin
      Result := CategoryTitle;
    end;
    '$category_url':
    begin
      Result := CategoryURL;
    end;
  end;
end;

constructor TWPCategoryWebModule.CreateNew(AOwner: TComponent; CreateMode: integer);
begin
  inherited CreateNew(AOwner, CreateMode);
  CreateSession := True;
  OnRequest := @RequestHandler;
  OnBlockController := @DoBlockController;
end;

destructor TWPCategoryWebModule.Destroy;
begin
  inherited Destroy;
end;

procedure TWPCategoryWebModule.DoBlockController(Sender: TObject; FunctionName: string;
  Parameter: TStrings; var ResponseString: string);
begin
  case FunctionName of
    'categorylist':
    begin
      ResponseString := GetCategoryList(FunctionName, Parameter);
    end;
  end;

end;

{$ifdef wordpress}
initialization
  Route.Add( 'category', TWPCategoryWebModule);

{$endif}

end.
