unit wordpress_news_controller;

{$mode objfpc}{$H+}
{$include define.inc}

interface

uses
  wordpress_news_model, wordpress_terms_model, wordpress_featuredimage_model,
  fastplaz_app, fastplaz_handler, httpdefs, fpHTTP,
  Classes, SysUtils;

type

  { TWPNewsWebModule }

  TWPNewsWebModule = class(TMyCustomController)
  private
    NewsTitle: string;
    News: TWordpressNews;
    Terms: TWordpressTerms;
    Featuredimage: TFeaturedimage;
    function GetLastNews(FunctionName: string = ''; Parameter: TStrings = nil; LimitNews:integer=10): string;
    function GetRandomNews(FunctionName: string = ''; Parameter: TStrings = nil): string;
    function GeneratePagesMenu(ParentMenu: integer; Parameter: TStrings = nil;
      ParentBaseURL: string = ''; IsParent: boolean = True): string;
    // year + month from the request, '' when they are not a valid yyyymm
    function RequestYearMonth: string;

    function Tag_MainContent_Handler(const TagName: string; Params: TStringList): string;
  public
    constructor CreateNew(AOwner: TComponent; CreateMode: integer); override;
    destructor Destroy; override;

    procedure Get; override;

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

function IsDigits(const AValue: string): boolean;
var
  i: integer;
begin
  Result := AValue <> '';
  for i := 1 to Length(AValue) do
    if not (AValue[i] in ['0'..'9']) then
      Exit(False);
end;

{ TWPNewsWebModule }

// example:
// http://domain/2014/04/dialog-keajaiban-silat-silat-untuk-kehidupan/
procedure TWPNewsWebModule.Get;
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
end;

function TWPNewsWebModule.RequestYearMonth: string;
begin
  Result := '';
  if (Length(_GET['year']) = 4) and IsDigits(_GET['year']) and
    (Length(_GET['month']) = 2) and IsDigits(_GET['month']) then
    Result := _GET['year'] + _GET['month'];
end;

function TWPNewsWebModule.GetLastNews(FunctionName: string; Parameter: TStrings; LimitNews: integer): string;
var
  lst: TStringList;
  _News: TWordpressNews;
  url, title: string;
  s, div_id, div_class, item_class, news_option: string;
  category_id: integer;
  //category_title,
  category_permalink: string;
  first_news: boolean;
begin
  Result := '';
  div_id := '';
  div_class := '';
  title := '';
  news_option := '';
  category_permalink := '';
  if Parameter <> nil then
  begin
    div_id := HTMLEncode(StringReplace(Parameter.Values['id'], '"', '', [rfReplaceAll]));
    div_class := HTMLEncode(StringReplace(Parameter.Values['class'], '"', '', [rfReplaceAll]));
    category_permalink := StringReplace(Parameter.Values['category'], '"', '', [rfReplaceAll]);
    title := StringReplace(Parameter.Values['title'], '"', '', [rfReplaceAll]);
    news_option := Parameter.Values['options'];
  end;

  category_id := 0;
  if category_permalink <> '' then
  begin
    with TWordpressTerms.Create() do
    begin
      AddJoin('term_taxonomy', 'term_id', 'terms.term_id', ['taxonomy']);
      FindFirst(['taxonomy="category"', 'slug=' + QuoteValue(category_permalink)], 'name');
      if RecordCount > 0 then
      begin
        category_id := Value['term_id'];
        //category_title := Value['name'];
      end;
      Free;
    end;
  end;

  _News := TWordpressNews.Create();
  try
    if category_id = 0 then
      _News.Find(['post_type="post"', 'post_status="publish"'], 'post_date desc', LimitNews)
    else
    begin
      _News.AddJoin('term_relationships', 'object_id', AppData.tablePrefix + 'posts.ID', ['object_id']);
      _News.Find(['post_type="post"', 'post_status="publish"', AppData.tablePrefix +
        'term_relationships.term_taxonomy_id=' + i2s(category_id)],
        'post_date desc', LimitNews);
    end;

    if _News.RecordCount > 0 then
    begin
      lst := TStringList.Create;
      try
        lst.Add('<header class="entry-header">');
        lst.Add('<h1 class="archive-title">Last News:</h1>');
        lst.Add('</header>');
        lst.Add('<article id="post-34" class="post-34 post type-post status-publish format-standard hentry category-general tag-hello"><div class="entry-content ">');
        if title <> '' then
        begin
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
          url := '/' + FormatDateTime('YYYY', TDateTime(_News['post_date'])) + '/' +
            FormatDateTime('mm', TDateTime(_News['post_date'])) + '/' + string(_News['post_name']) + '/';
          lst.Add('<li' + item_class + '><a href="' + url + '">' + string(_News['post_title']) + '</a>');
          case news_option of
            'summary':
            begin
              s := StripTags(string(_News['post_content']));
              s := StripTagsCustom(s, '[', ']');
              s := '<p>' + MoreLess(s) + '</p>';
              lst.Add(s);
            end;
            'full':
            begin
              s := string(_News['post_content']);
              s := StripTagsCustom(s, '[', ']');
              lst.Add( s);
            end;
          end;
          lst.Add('</li>');

          if first_news then
          begin
            first_news := False;
            item_class := '';
          end;
          _News.Data.Next;
        end;
        lst.Add('</ul>');
        if title <> '' then
          lst.Add('</div>');

        lst.Add('</div></article>');
        Result := lst.Text;
      finally
        FreeAndNil(lst);
      end;
    end;
  finally
    FreeAndNil(_News);
  end;
end;

function TWPNewsWebModule.GetRandomNews(FunctionName: string; Parameter: TStrings): string;
var
  lst: TStringList;
  _News: TWordpressNews;
  limit: integer;
  url, title: string;
  div_class: string;
begin
  Result := '';
  div_class := '';
  title := '';
  limit := 0;
  if Parameter <> nil then
  begin
    div_class := HTMLEncode(StringReplace(Parameter.Values['class'], '"', '', [rfReplaceAll]));
    title := StringReplace(Parameter.Values['title'], '"', '', [rfReplaceAll]);
    limit := s2i(Parameter.Values['number']);
  end;
  if (limit <= 0) or (limit > 100) then
    limit := 20;
  _News := TWordpressNews.Create();
  try
    _News.Find(['post_type="post"', 'post_status="publish"'], 'rand()', limit);
    if _News.RecordCount > 0 then
    begin
      lst := TStringList.Create;
      try
        if title <> '' then
        begin
          lst.Add('<div class="news-lastnews">');
          lst.Add('<h3>' + title + '</h3>');
        end;

        lst.Add('<ul class="' + div_class + '">');
        while not _News.Data.EOF do
        begin
          url := '/' + FormatDateTime('YYYY', TDateTime(_News['post_date'])) + '/' +
            FormatDateTime('mm', TDateTime(_News['post_date'])) + '/' + string(_News['post_name']) + '/';
          lst.Add('<li><a href="' + url + '">' + string(_News['post_title']) + '</a></li>');

          _News.Next;
        end;
        lst.Add('</ul>');
        if title <> '' then
          lst.Add('</div>');

        Result := lst.Text;
      finally
        FreeAndNil(lst);
      end;
    end;
  finally
    FreeAndNil(_News);
  end;
end;

function TWPNewsWebModule.GeneratePagesMenu(ParentMenu: integer; Parameter: TStrings;
  ParentBaseURL: string; IsParent: boolean): string;
var
  whereSQL, html, title, submenu, url, page_item_has_children: string;
  nav_id, nav_class: string;
begin
  html := '';
  whereSQL := '';
  nav_id := HTMLEncode(StringReplace(Parameter.Values['id'], '"', '', [rfReplaceAll]));
  nav_class := HTMLEncode(StringReplace(Parameter.Values['class'], '"', '', [rfReplaceAll]));
  if nav_id = '' then
    nav_id := 'nav';
  with TWordpressPages.Create() do
  begin
    {$ifdef wordpress_polylang}
    if Config.GetValue(_WORDPRESS_PLUGINS_POLYLANG, False) then
    begin
      AddJoin('term_relationships', 'object_id', 'posts.ID', ['term_taxonomy_id']);
      AddJoin('terms', 'term_id', 'term_relationships.term_taxonomy_id', ['slug']);
      whereSQL := AppData.tablePrefix + 'terms.slug = ' + QuoteValue(LANG);
    end;
    {$endif}
    Find(['post_type="page"', 'post_status="publish"', 'post_parent=' + i2s(ParentMenu), whereSQL],
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
        submenu := GeneratePagesMenu(Value['ID'], Parameter, ParentBaseURL + string(Value['post_name']) + '/', False);
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
        url := BaseURL + 'pages/' + ParentBaseURL + string(Value['post_name']);
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
  OnBlockController := @DoBlockController;
  // created here, not per request: View is also called by TMainModule,
  // which never runs Get on this module
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
  thumbnail_url, title, year_month: string;
  lst: TStringList;
begin
  // no permalink (home page, /news/, /2014/04/): latest news.
  // The route variables come from the rewrite rule (CGI) or from the route
  // pattern (standalone), so do not look at the raw query string here.
  if _GET['permalink'] = '' then
  begin
    lst := TStringList.Create;
    try
      lst.Values['options'] := 'full';
      Result := GetLastNews('', lst);
    finally
      FreeAndNil(lst);
    end;
    Exit;
  end;

  year_month := RequestYearMonth;
  if year_month = '' then
  begin
    Result := H2(__(__Content_Not_Found));
    Exit;
  end;

  News.AddJoin('users', 'ID', 'posts.post_author', ['display_name']);
  News.Find(['date_format( post_date, "%Y%m") = ' + News.QuoteValue(year_month),
    'post_status="publish"', 'post_type="post"', 'post_name = ' + News.QuoteValue(_GET['permalink'])],
    AppData.tablePrefix + 'posts.post_date DESC');

  if News.RecordCount = 0 then
  begin
    Result := H2(__(__Content_Not_Found));
    Exit;
  end;

  Terms.GetObjectTerms(integer(News['ID']), ['post_tag']);
  thumbnail_url := Featuredimage.GetFeaturedImageURLByID(integer(News['ID']));
  if thumbnail_url = '' then
    thumbnail_url := string(Config.GetValue('wordpress/base_url', '')) + '/logo.png'
  else
  begin
    thumbnail_url := string(Config.GetValue('wordpress/base_url', '')) +
      string(Config.GetValue('wordpress/path', '')) + '/' + thumbnail_url;
    ThemeUtil.Assign('featured_image', thumbnail_url);
  end;

  ThemeUtil.Assign('$news', @News.Data);
  ThemeUtil.Assign('$terms', @Terms.Data);
  //or use this : ThemeUtil.AssignVar['$news'] := @News.Data;

  // facebook content sharing
  title := string(News['post_title']);
  ThemeUtil.AddMeta('description', title, 'property');
  ThemeUtil.AddMeta('og:type', 'article', 'property');
  ThemeUtil.AddMeta('og:title', title, 'property');
  ThemeUtil.AddMeta('og:site_name', GetOptions('blogname'), 'property');
  ThemeUtil.AddMeta('og:description', GetOptions('blogdescription') + ', ' + title, 'property');
  ThemeUtil.AddMeta('og:image', thumbnail_url, 'property');
  // facebook content sharing - end

  ThemeUtil.Assign('date01', '2014/12/30');
  ThemeUtil.Assign('date02', '2015/01/12');
  //<br />[date01 filter=nl2br]

  Result := ThemeUtil.RenderFromContent(@TagController, '', 'modules/wpnews/detail.html');
  News.AddHit(integer(News['ID']));
end;

function TWPNewsWebModule.GetOptions(const KeyName: string): string;
begin
  Result := '';
  with TWordpressOptions.Create() do
  begin
    FindFirst(['option_name=' + QuoteValue(KeyName)], '', 'option_value');
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
var
  str: TStrings;
  pageName, year_month : string;
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
        year_month := RequestYearMonth;
        if (NewsTitle = '') and (year_month <> '') then
        begin
          with TWordpressNews.Create() do
          begin
            FindFirst(['date_format( post_date, "%Y%m") = ' + QuoteValue(year_month),
              'post_status="publish"', 'post_type="post"',
              'post_name = ' + QuoteValue(_GET['permalink'])],
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
      end
      else
      begin // is pages ?
        str := Explode(Application.Request.PathInfo, '/');
        try
          if (str.Count>=2) then
          begin
            if str[1] = 'pages' then
            begin
              pageName := str[str.Count - 1];
              with TWordpressNews.Create() do
              begin
                FindFirst(['post_status="publish"', 'post_type="page"',
                  'post_name=' + QuoteValue(pageName)]);
                if RecordCount > 0 then
                begin
                  ResponseString := Value['post_title'];
                end;
                Free;
              end;
            end;
          end;
        finally
          FreeAndNil(str);
        end;
      end; // is pages - end

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

// route: see routes.pas

end.
