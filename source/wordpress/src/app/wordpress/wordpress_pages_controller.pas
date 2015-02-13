unit wordpress_pages_controller;

{$mode objfpc}{$H+}
{$include define.inc}

interface

uses
  wordpress_pages_model,
  fpcgi, fastplaz_handler, httpdefs, fpHTTP,
  Classes, SysUtils;

{$ifdef wordpress}
type

  { TWPPagesWebModule }

  TWPPagesWebModule = class(TMyCustomWebModule)
    procedure RequestHandler(Sender: TObject; ARequest: TRequest; AResponse: TResponse; var Handled: boolean);
  private
    Posts, Pages: TWordpressPages;
    function Tag_MainContent_Handler(const TagName: string; Params: TStringList): string;
  public
    constructor CreateNew(AOwner: TComponent; CreateMode: integer); override;
    destructor Destroy; override;
    function View: string;

    // Handler / Controller
    procedure DoBlockController(Sender: TObject; FunctionName: string; Parameter: TStrings;
      var ResponseString: string);
  end;

{$endif wordpress}

implementation

uses database_lib, common, html_lib, language_lib, theme_controller,
  wordpress_nggallery_model, wordpress_news_model;

{$ifdef wordpress}

{ TWPPagesWebModule }

// example:
// http://domain/page/about/hubungi-kami/
procedure TWPPagesWebModule.RequestHandler(Sender: TObject; ARequest: TRequest; AResponse: TResponse;
  var Handled: boolean);
begin
  DataBaseInit;
  LanguageInit;

  Pages := TWordpressPages.Create();
  Posts := TWordpressPages.Create();

  Tags['$maincontent'] := @Tag_MainContent_Handler;
  Response.Content := ThemeUtil.Render(@TagController, '', True);

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

  Handled := True;
end;

function TWPPagesWebModule.Tag_MainContent_Handler(const TagName: string; Params: TStringList): string;
begin
  Result := View;
end;

constructor TWPPagesWebModule.CreateNew(AOwner: TComponent; CreateMode: integer);
begin
  inherited CreateNew(AOwner, CreateMode);
  CreateSession := True;
  OnRequest := @RequestHandler;
  OnBlockController := @DoBlockController;
end;

destructor TWPPagesWebModule.Destroy;
begin
  FreeAndNil(Posts);
  FreeAndNil(Pages);
  inherited Destroy;
end;

function TWPPagesWebModule.View: string;
var
  post_filter, title, page_name: string;
  str: TStrings;
  i: integer;
begin
  str := Explode(Application.Request.PathInfo, '/');
  if str.Count < 3 then
  begin
    Result := H2(__(__Content_Not_Found), 'center');
    FreeAndNil(str);
    Redirect(BaseURL);
    Exit;
  end;

  str.Delete(0);
  str.Delete(0);
  page_name := str[str.Count - 1];

  // post info
  post_filter := '';
  for i := 1 to str.Count do
    post_filter := post_filter + '''' + str[i - 1] + ''',';
  post_filter := Copy(post_filter, 1, Length(post_filter) - 1);
  Posts.Find(['post_type IN (''page'',''attachment'')', 'post_name IN (' + post_filter + ')']);
  // post info - end

  Pages.Find(['post_status="publish"', 'post_type="page"', 'post_name="' + page_name + '"']);
  if Pages.RecordCount = 0 then
  begin
    Result := H2(__(__Content_Not_Found), 'center');
    Exit;
  end;

  //-- old style: Tags['$page'] := @Tag_PageVar_Handler;
  ThemeUtil.AssignVar['$page'] := @Pages.Data;
  ThemeUtil.AssignVar['$posts'] := @Posts.Data;

  // facebook content sharing
  title := Pages.Data.FieldByName('post_title').AsString;
  ThemeUtil.AddMeta('og:type', 'article', 'property');
  ThemeUtil.AddMeta('og:title', title, 'property');
  ThemeUtil.AddMeta('og:site_name', AppData.sitename, 'property');
  ThemeUtil.AddMeta('og:description', AppData.sitename + ', ' + title, 'property');
  ThemeUtil.AddMeta('og:image', BaseURL + '/logo.png', 'property');

  Result := ThemeUtil.RenderFromContent(@TagController, '', 'modules/pages/detail.html');
end;

procedure TWPPagesWebModule.DoBlockController(Sender: TObject; FunctionName: string;
  Parameter: TStrings; var ResponseString: string);
begin

end;

initialization
  Route.Add( 'pages', TWPPagesWebModule);

{$endif wordpress}

end.
