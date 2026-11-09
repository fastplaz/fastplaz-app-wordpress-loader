unit wordpress_pages_controller;

{$mode objfpc}{$H+}
{$include define.inc}

interface

uses
  wordpress_pages_model,
  fastplaz_app, fastplaz_handler, httpdefs, fpHTTP,
  Classes, SysUtils;

{$ifdef wordpress}
type

  { TWPPagesWebModule }

  TWPPagesWebModule = class(TMyCustomController)
  private
    Posts, Pages: TWordpressPages;
    procedure PrepareModels;
    function Tag_MainContent_Handler(const TagName: string; Params: TStringList): string;
  public
    constructor CreateNew(AOwner: TComponent; CreateMode: integer); override;
    destructor Destroy; override;

    procedure Get; override;
    function View: string;

    // Handler / Controller
    procedure DoBlockController(Sender: TObject; FunctionName: string; Parameter: TStrings;
      var ResponseString: string);
  end;

{$endif wordpress}

implementation

uses database_lib, common, html_lib, language_lib, theme_controller,
  wordpress_nggallery_model, wordpress_news_model, wordpress_site_lib;

{$ifdef wordpress}

{ TWPPagesWebModule }

// example:
// http://domain/pages/about/hubungi-kami/
procedure TWPPagesWebModule.Get;
begin
  DataBaseInit;
  LanguageInit;

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
end;

function TWPPagesWebModule.Tag_MainContent_Handler(const TagName: string; Params: TStringList): string;
begin
  Result := View;
end;

constructor TWPPagesWebModule.CreateNew(AOwner: TComponent; CreateMode: integer);
begin
  inherited CreateNew(AOwner, CreateMode);
  CreateSession := True;
  OnBlockController := @DoBlockController;
  // the models are created by PrepareModels, not here: a model takes the
  // table prefix when it is created, and the prefix is only known after
  // DataBaseInit (Get runs it after this constructor). Created here, the
  // queries went to "posts" instead of "<prefix>posts" and failed.
end;

procedure TWPPagesWebModule.PrepareModels;
begin
  if Pages = nil then
    Pages := TWordpressPages.Create();
  if Posts = nil then
    Posts := TWordpressPages.Create();
end;

destructor TWPPagesWebModule.Destroy;
begin
  FreeAndNil(Posts);
  FreeAndNil(Pages);
  inherited Destroy;
end;

function TWPPagesWebModule.View: string;
var
  post_filter, title, page_name, summary, logo_url: string;
  logo_w, logo_h: integer;
  str: TStrings;
  i: integer;
begin
  PrepareModels;
  str := Explode(Application.Request.PathInfo, '/');
  try
    if str.Count < 3 then
    begin
      Result := NotFoundContent;
      Exit;
    end;

    str.Delete(0);
    str.Delete(0);
    page_name := str[str.Count - 1];

    // post info; every name comes from the URL, so each one is quoted
    post_filter := '';
    for i := 0 to str.Count - 1 do
    begin
      if post_filter <> '' then
        post_filter := post_filter + ',';
      post_filter := post_filter + Posts.QuoteValue(str[i]);
    end;
  finally
    FreeAndNil(str);
  end;
  Posts.Find(['post_type IN (''page'',''attachment'')', 'post_name IN (' + post_filter + ')']);
  // post info - end

  Pages.Find(['post_status="publish"', 'post_type="page"', 'post_name=' + Pages.QuoteValue(page_name)]);
  if Pages.RecordCount = 0 then
  begin
    Result := NotFoundContent;
    Exit;
  end;

  //-- old style: Tags['$page'] := @Tag_PageVar_Handler;
  ThemeUtil.AssignVar['$page'] := @Pages.Data;
  ThemeUtil.AssignVar['$posts'] := @Posts.Data;

  // share preview (WhatsApp, Facebook, X ...)
  title := MetaText(Pages.Data.FieldByName('post_title').AsString, 0);
  summary := MetaText(Pages.Data.FieldByName('post_content').AsString);
  if summary <> '' then
    ThemeUtil.AddMeta('description', summary, 'name');
  ThemeUtil.AddMeta('og:type', 'article', 'property');
  ThemeUtil.AddMeta('og:title', title, 'property');
  ThemeUtil.AddMeta('og:site_name', MetaText(WPOption('blogname'), 0), 'property');
  if summary <> '' then
    ThemeUtil.AddMeta('og:description', summary, 'property');
  if WPSiteLogo(logo_url, logo_w, logo_h) then
    ThemeUtil.AddMeta('og:image', MetaText(logo_url, 0), 'property');

  Result := ThemeUtil.RenderFromContent(@TagController, '', 'modules/pages/detail.html');
end;

procedure TWPPagesWebModule.DoBlockController(Sender: TObject; FunctionName: string;
  Parameter: TStrings; var ResponseString: string);
begin

end;

// route: see routes.pas

{$endif wordpress}

end.
