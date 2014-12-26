unit wordpress_news_controller;

{$mode objfpc}{$H+}
{$include define.inc}

interface

uses
  wordpress_news_model, wordpress_terms_model, wordpress_featuredimage_model,
  fpcgi, fastplaz_handler, httpdefs, fpHTTP,
  Classes, SysUtils;

type

  { TWPNewsWebModule }

  TWPNewsWebModule = class(TMyCustomWebModule)
    procedure RequestHandler(Sender: TObject; ARequest: TRequest; AResponse: TResponse; var Handled: boolean);
  private
    NewsTitle: string;
    News: TWordpressNews;
    Terms: TWordpressTerms;
    Featuredimage: TFeaturedimage;
    function GetLastNews(FunctionName: string = ''; Parameter: TStrings = nil): string;
    function GetRandomNews(FunctionName: string = ''; Parameter: TStrings = nil): string;
    function GeneratePagesMenu(ParentMenu: integer; Parameter: TStrings = nil;
      ParentBaseURL: string = ''; IsParent: boolean = True): string;

    function Tag_MainContent_Handler(const TagName: string; Params: TStringList): string;
  public
    constructor CreateNew(AOwner: TComponent; CreateMode: integer); override;
    destructor Destroy; override;
    function View: string;
    function GetOptions(const KeyName: string): string;

    // Handler / Controller
    procedure DoBlockController(Sender: TObject; FunctionName: string; Parameter: TStrings;
      var ResponseString: string);

  end;


implementation

uses database_lib, common, language_lib, html_lib, theme_controller,
  wordpress_options_model, wordpress_nggallery_model, wordpress_pages_model,
  wordpress_category_controller;

{ TWPNewsWebModule }

// example:
// http://domain/2014/04/dialog-keajaiban-silat-silat-untuk-kehidupan/
procedure TWPNewsWebModule.RequestHandler(Sender: TObject; ARequest: TRequest; AResponse: TResponse;
  var Handled: boolean);
begin
  DataBaseInit;
  LanguageInit;

  Tags['$maincontent'] := @Tag_MainContent_Handler;
  Response.Content := ThemeUtil.Render(nil, '', True);

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

function TWPNewsWebModule.GetLastNews(FunctionName: string; Parameter: TStrings): string;
var
  lst: TStringList;
  _News: TWordpressNews;
  limit: integer;
  url, title: string;
  s, div_id, div_class, item_class: string;
  category_id: integer;
  category_title, category_permalink: string;
  first_news: boolean;
begin
  div_id := StringReplace(Parameter.Values['id'], '"', '', [rfReplaceAll]);
  div_class := StringReplace(Parameter.Values['class'], '"', '', [rfReplaceAll]);
  category_permalink := StringReplace(Parameter.Values['category'], '"', '', [rfReplaceAll]);

  category_id := 0;
  if category_permalink <> '' then
  begin
    die('err: category_permalink');
    with TWordpressTerms.Create() do
    begin
      AddJoin( 'term_taxonomy', 'term_id', '_terms.term_id', ['taxonomy']);
      FindFirst(['taxonomy="category"', 'slug="' + category_permalink + '"'], 'name');
      if RecordCount > 0 then
      begin
        category_id := Value['term_id'];
        category_title := Value['name'];
      end;
      Free;
    end;
  end;

  limit := 0;
  if Parameter <> nil then
    limit := s2i(Parameter.Values['number']);
  if limit = 0 then
    limit := 20;
  _News := TWordpressNews.Create();
  if category_id = 0 then
    _News.Find(['post_type="post"', 'post_status="publish"'], 'post_date desc', limit)
  else
  begin
    _News.AddJoin( 'term_relationships', 'object_id', 'posts.ID', ['object_id']);
    _News.Find(['post_type="post"', 'post_status="publish"', AppData.tablePrefix +
      '_term_relationships.term_taxonomy_id=' + i2s(category_id)],
      'post_date desc', limit);
  end;

  if _News.RecordCount > 0 then
  begin
    lst := TStringList.Create;
    lst.Add( '<header class="entry-header">');
    lst.Add( '<h1 class="archive-title">Last News:</h1>');
    lst.Add( '</header>');
    lst.Add( '<article id="post-34" class="post-34 post type-post status-publish format-standard hentry category-general tag-hello"><div class="entry-content ">');
    if Parameter <> nil then
      if Parameter.Values['title'] <> '' then
      begin
        title := StringReplace(Parameter.Values['title'], '"', '', [rfReplaceAll]);
        lst.Add('<div class="news-lastnews entry-content">');
        lst.Add('<h3>' + title + '</h3>');
      end;

    first_news := True;
    item_class := ' class="first-post"';
    if div_id <> '' then
      lst.Add('<ul id="' + div_id + '" class="' + div_class + '">')
    else
      lst.Add('<ul class="' + div_class + '">');
    while not _News.Data.EOF do
    begin
      url := '/' + FormatDateTime('YYYY', _News['post_date']) + '/' +
        FormatDateTime('mm', _News['post_date']) + '/' + _News['post_name'] + '/';
      lst.Add('<li' + item_class + '><a href="' + url + '">' + _News['post_title'] + '</a>');
      if Parameter.Values['options'] <> '' then
      begin
        case Parameter.Values['options'] of
          'summary':
          begin
            s := StripTags(_News['post_content']);
            s := StripTagsCustom(s, '[', ']');
            s := '<p>' + MoreLess(s) + '</p>';
            lst.Add(s);
          end;
        end;
      end;//-- if Parameter.Values['options'] <> ''
      lst.Add('</li>');

      if first_news then
      begin
        first_news := False;
        item_class := '';
      end;
      ;
      _News.Data.Next;
    end;
    lst.Add('</ul>');
    if Parameter.Values['title'] <> '' then
      lst.Add('</div>');

    lst.Add( '</div></article>');
    Result := lst.Text;
    FreeAndNil(lst);
  end;
  FreeAndNil(_News);
end;

function TWPNewsWebModule.GetRandomNews(FunctionName: string; Parameter: TStrings): string;
var
  lst: TStringList;
  _News: TWordpressNews;
  limit: integer;
  url, title: string;
  div_class: string;
begin
  div_class := StringReplace(Parameter.Values['class'], '"', '', [rfReplaceAll]);
  ;
  limit := 0;
  if Parameter <> nil then
    limit := s2i(Parameter.Values['number']);
  if limit = 0 then
    limit := 20;
  _News := TWordpressNews.Create();
  _News.Find(['post_type="post"', 'post_status="publish"'], 'rand()', limit);
  if _News.RecordCount > 0 then
  begin
    lst := TStringList.Create;
    if Parameter <> nil then
      if Parameter.Values['title'] <> '' then
      begin
        lst.Add('<div class="news-lastnews">');
        title := StringReplace(Parameter.Values['title'], '"', '', [rfReplaceAll]);
        lst.Add('<h3>' + title + '</h3>');
      end;

    lst.Add('<ul class="' + div_class + '">');
    while not _News.Data.EOF do
    begin
      url := '/' + FormatDateTime('YYYY', _News['post_date'].AsDateTime) + '/' +
        FormatDateTime('mm', _News['post_date'].AsDateTime) + '/' + _News['post_name'].AsString + '/';
      lst.Add('<li><a href="' + url + '">' + _News['post_title'].AsString + '</a></li>');

      _News.Next;
    end;
    lst.Add('</ul>');
    if Parameter.Values['title'] <> '' then
      lst.Add('</div>');

    Result := lst.Text;
    FreeAndNil(lst);
  end;
  FreeAndNil(_News);
end;

function TWPNewsWebModule.GeneratePagesMenu(ParentMenu: integer; Parameter: TStrings;
  ParentBaseURL: string; IsParent: boolean): string;
var
  where, html, title, submenu, url, page_item_has_children: string;
  nav_id, nav_class: string;
begin
  nav_id := StringReplace(Parameter.Values['id'], '"', '', [rfReplaceAll]);
  nav_class := StringReplace(Parameter.Values['class'], '"', '', [rfReplaceAll]);
  if nav_id = '' then
    nav_id := 'nav';
  with TWordpressPages.Create() do
  begin
    {$ifdef wordpress_polylang}
    if Config.GetValue(_WORDPRESS_PLUGINS_POLYLANG, False) then
    begin
      AddJoin('term_relationships', 'object_id', 'posts.ID', ['term_taxonomy_id']);
      AddJoin('terms', 'term_id', 'term_relationships.term_taxonomy_id', ['slug']);
      where := AppData.tablePrefix + 'terms.slug = "' + LANG + '"';
    end;
    {$endif}
    Find(['post_type="page"', 'post_status="publish"', 'post_parent=' + i2s(ParentMenu), where],
      'post_parent, menu_order', 0,
      'ID,post_title,post_name,post_parent');

    if RecordCount > 0 then
    begin
      if ((Parameter.Values['header'] <> '') and (ParentMenu = 0)) then
        html := Parameter.Values['header'];
      if ((Parameter.Values['type'] = 'nav') and (ParentMenu = 0)) then
        html := html + '<nav>';
      if Parameter.Values['type'] = 'nav' then
      begin
        if IsParent then
        begin
          html := html + #13#10'<ul id="' + nav_id + '" class="' + nav_class + '">';
          html := html + #13#10'  <li><a href="' + BaseURL + '" class="on">' + __('Home') + '</a></li>';
        end
        else
        begin
          html := html + #13#10'<ul class="children sub-menu">';
        end;
      end;
      while not Data.EOF do
      begin
        submenu := '';
        title := '';
        url := '#';
        submenu := GeneratePagesMenu(Value['ID'], Parameter, ParentBaseURL + Value['post_name'] + '/', False);
        if submenu = '' then
          page_item_has_children := ''
        else
          page_item_has_children := 'menu-item-has-children';
        if Parameter.Values['type'] = 'nav' then
        begin
          if IsParent then
          begin
            html := html + #13#10'<li id="menu-item-' + string(Value['ID']) +
              '" class="menu-item ' + page_item_has_children + '">';
          end
          else
          begin
            html := html + #13#10'  <li id="menu-item-' + string(Value['ID']) +
              '" class="menu-item ' + page_item_has_children + '">';
          end;
        end;
        title := Value['post_title'];
        url := BaseURL + 'pages/' + ParentBaseURL + Value['post_name'];
        html := html + '<a href="' + url + '">' + title + '</a>' + submenu;
        if Parameter.Values['type'] = 'nav' then
          html := html + '</li>';
        Data.Next;
      end;
      Parameter.Values['parent_baseurl'] := '';
      if Parameter.Values['type'] = 'nav' then
        html := html + #13#10'</ul>';
      if ((Parameter.Values['type'] = 'nav') and (ParentMenu = 0)) then
        html := html + #13#10'</nav>';
      if ((Parameter.Values['footer'] <> '') and (ParentMenu = 0)) then
        html := html + Parameter.Values['footer'];
    end;
    Free;
    Result := html;
  end;
end;

constructor TWPNewsWebModule.CreateNew(AOwner: TComponent; CreateMode: integer);
begin
  inherited CreateNew(AOwner, CreateMode);
  CreateSession := True;
  OnRequest := @RequestHandler;
  OnBlockController := @DoBlockController;
  News := TWordpressNews.Create();
  Terms := TWordpressTerms.Create();
  Featuredimage := TFeaturedimage.Create();
end;

destructor TWPNewsWebModule.Destroy;
begin
  FreeAndNil(Featuredimage);
  FreeAndNil(Terms);
  FreeAndNil(News);
  inherited Destroy;
end;

function TWPNewsWebModule.View: string;
var
  thumbnail_url, title: string;
  lst : TStringList;
begin
  if Application.Request.QueryString = '' then
  begin
    lst := TStringList.Create;
    Result := GetLastNews('', lst);
    FreeAndNil( lst);
    Exit;
  end;

  News.AddJoin( 'users', 'ID', 'posts.post_author', ['display_name']);
  News.Find(['date_format( post_date, "%Y%m") = "' + _GET['year'] + _GET['month'] + '"',
    'post_status="publish"', 'post_type="post"', 'post_name = "' + _GET['permalink'] + '"'],
    AppData.tablePrefix + 'posts.post_date DESC');
  if News.RecordCount = 0 then
  begin
    Result := H2(__(__Content_Not_Found));
    Exit;
  end;

  Terms.GetObjectTerms(News['ID'], ['post_tag']);
  thumbnail_url := Featuredimage.GetFeaturedImageURLByID(News['ID']);
  if thumbnail_url = '' then
    thumbnail_url := Config.GetValue('wordpress/base_url', '') + '/logo.png'
  else
  begin
    thumbnail_url := Config.GetValue('wordpress/base_url', '') + Config.GetValue('wordpress/path', '') +
      '/' + thumbnail_url;
    ThemeUtil.Assign('featured_image', thumbnail_url);
  end;

  ThemeUtil.Assign('$news', @News.Data);
  ThemeUtil.Assign('$terms', @Terms.Data);
  //or use this : ThemeUtil.AssignVar['$news'] := @News.Data;

  // facebook content sharing
  title := News['post_title'];
  ThemeUtil.AddMeta('og:type', 'article', 'property');
  ThemeUtil.AddMeta('og:title', title, 'property');
  ThemeUtil.AddMeta('og:site_name', GetOptions('blogname'), 'property');
  ThemeUtil.AddMeta('og:description', GetOptions('blogdescription') + ', ' + title, 'property');
  ThemeUtil.AddMeta('og:image', thumbnail_url, 'property');
  // facebook content sharing - end

  Result := ThemeUtil.RenderFromContent(@TagController, '', 'modules/wpnews/detail.html');
  News.AddHit(News['ID']);
end;

function TWPNewsWebModule.GetOptions(const KeyName: string): string;
begin
  with TWordpressOptions.Create() do
  begin
    FindFirst(['option_name="' + KeyName + '"'], '', 'option_value');
    if RecordCount > 0 then
    begin
      Result := Value['option_value'];
    end;
    Free;
  end;
end;

function TWPNewsWebModule.Tag_MainContent_Handler(const TagName: string; Params: TStringList): string;
begin
  Result := View;
end;

procedure TWPNewsWebModule.DoBlockController(Sender: TObject; FunctionName: string;
  Parameter: TStrings; var ResponseString: string);
begin
  case FunctionName of
    'getoption':
    begin
      ResponseString := GetOptions(Parameter.Values['name']);
    end;
    'newstitle':
    begin
      if _GET['permalink'] <> '' then
      begin
        if NewsTitle = '' then
        begin
          with TWordpressNews.Create() do
          begin
            FindFirst(['date_format( post_date, "%Y%m") = "' + _GET['year'] + _GET['month'] +
              '"', 'post_status="publish"', 'post_type="post"', 'post_name = "' + _GET['permalink'] + '"'],
              '', 'post_title');
            if RecordCount > 0 then
            begin
              NewsTitle := Value['post_title'];
            end;
            Free;
          end;
        end;
        if NewsTitle <> '' then
          ResponseString := ' - ' + NewsTitle;
      end;
    end; //-- newstitle
    'lastnews':
    begin
      ResponseString := GetLastNews(FunctionName, Parameter);
    end;
    'randomnews':
    begin
      ResponseString := GetRandomNews(FunctionName, Parameter);
    end;
    'pagesmenu':
    begin
      ResponseString := GeneratePagesMenu(0, Parameter);
    end;

  end;

end;

{$ifdef wordpress}
initialization
  Route.Add('wpnews', TWPNewsWebModule);

{$endif}

end.
