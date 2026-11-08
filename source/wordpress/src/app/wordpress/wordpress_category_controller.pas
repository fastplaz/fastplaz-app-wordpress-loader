unit wordpress_category_controller;

{$mode objfpc}{$H+}
{$include define.inc}

interface

uses
  fastplaz_app, fastplaz_handler, httpdefs, fpHTTP,
  Classes, SysUtils;

type

  { TWPCategoryWebModule }

  TWPCategoryWebModule = class(TMyCustomController)
  private
    CategoryTitle, CategoryURL: string;
    function GetCategoryList(FunctionName: string; Parameter: TStrings): string;
    function Tag_MainContent_Handler(const TagName: string; Params: TStringList): string;
    function Tag_Category_Handler(const TagName: string; Params: TStringList): string;
  public
    constructor CreateNew(AOwner: TComponent; CreateMode: integer); override;
    destructor Destroy; override;

    procedure Get; override;

    // Handler / Controller
    procedure DoBlockController(Sender: TObject; FunctionName: string; Parameter: TStrings;
      var ResponseString: string);
  end;

implementation

uses wordpress_terms_model, wordpress_news_model, database_lib, html_lib,
  common, language_lib, theme_controller;

{ TWPCategoryWebModule }

// example:
// http://domain/category/the-slug/
procedure TWPCategoryWebModule.Get;
begin
  if _GET['name'] = '' then
  begin
    Redirect(BaseURL);
    Exit; // Redirect does not leave the method
  end;

  DataBaseInit;
  LanguageInit;
  QueryExec('SET CHARACTER SET utf8mb4;');

  Tags['$maincontent'] := @Tag_MainContent_Handler;
  Response.Content := ThemeUtil.Render(@TagController, '', True);
end;

function TWPCategoryWebModule.GetCategoryList(FunctionName: string; Parameter: TStrings): string;
var
  lst: TStringList;
  Terms: TWordpressTerms;
  url, title: string;
  div_class: string;
begin
  Result := '';
  div_class := HTMLEncode(StringReplace(Parameter.Values['class'], '"', '', [rfReplaceAll]));
  Terms := TWordpressTerms.Create();
  try
    Terms.AddJoin( 'term_taxonomy', 'term_id', 'terms.term_id', ['taxonomy']);
    Terms.Find(['taxonomy="category"'], 'name');
    if Terms.RecordCount > 0 then
    begin
      lst := TStringList.Create;
      try
        lst.Add('<div class="category-list">');
        if Parameter.Values['title'] <> '' then
        begin
          title := StringReplace(Parameter.Values['title'], '"', '', [rfReplaceAll]);
          lst.Add('<h3>' + title + '</h3>');
        end;
        lst.Add('<ul class="' + div_class + '">');
        while not Terms.Data.EOF do
        begin
          url := BaseURL + 'category/' + string(Terms['slug']) + '/';
          lst.Add('<li><a href="' + url + '">' + string(Terms['name']) + '</a></li>');
          Terms.Data.Next;
        end;
        lst.Add('</ul>');
        lst.Add('</div>');
        Result := lst.Text;
      finally
        FreeAndNil(lst);
      end;
    end;
  finally
    FreeAndNil(Terms);
  end;
end;

function TWPCategoryWebModule.Tag_MainContent_Handler(const TagName: string; Params: TStringList): string;
var
  category_id: integer;
  News: TWordpressNews;
  Terms: TWordpressTerms;
begin
  Terms := TWordpressTerms.Create();
  try
    Terms.AddJoin( 'term_taxonomy', 'term_id', 'terms.term_id', ['taxonomy']);
    // the slug comes from the request: always quote it
    Terms.FindFirst(['taxonomy="category"', 'slug=' + Terms.QuoteValue(_GET['name'])], 'name');
    if Terms.RecordCount = 0 then
    begin
      Result := H2(__(__Content_Not_Found), 'center');
      Exit;
    end;
    category_id := Terms.Value['term_id'];
    CategoryTitle := Terms.Value['name'];
    CategoryURL := BaseURL + 'category/' + string(Terms.Value['slug']) + '/';
  finally
    FreeAndNil(Terms);
  end;

  News := TWordpressNews.Create();
  try
    News.AddJoin( 'term_relationships', 'object_id', 'posts.ID', ['object_id']);
    News.Find(['post_status="publish"', 'post_type="post"', AppData.tablePrefix +
      'term_relationships.term_taxonomy_id=' + i2s(category_id)], 'post_date desc', 10);

    Tags['$category_title'] := @Tag_Category_Handler;
    Tags['$category_url'] := @Tag_Category_Handler;

    ThemeUtil.AssignVar['$news'] := @News.Data;
    //or use this
    //ThemeUtil.Assign('$news', @News.Data);

    Result := ThemeUtil.RenderFromContent(@TagController, '', 'modules/wpnews/category.html');
  finally
    FreeAndNil(News);
  end;
end;

function TWPCategoryWebModule.Tag_Category_Handler(const TagName: string; Params: TStringList): string;
begin
  Result := '';
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

// route: see routes.pas

end.
