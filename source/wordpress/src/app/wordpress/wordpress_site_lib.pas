unit wordpress_site_lib;

{
  Site identity read from WordPress itself (Settings > General and
  Appearance > Customize > Site Identity), so the header and the share
  metadata follow the WordPress site instead of config.json:
  - blogname / blogdescription  : site title and tagline
  - site_logo or theme_mods_*   : logo (attachment id); none set ->
                                  logo.png next to the app binary (public_html/),
                                  logo-light.png for dark backgrounds
  Plus the shared "page not found" content.
}

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

// value of a wp_options row, '' when it does not exist
function WPOption(const KeyName: string): string;
// public url of a file under wp-content/uploads ("wp-content/uploads/2026/03/a.png")
function WPUploadURL(const UploadPath: string): string;
// url + size of the site logo, False when the site has no logo
// (WordPress has none and there is no public_html/logo.png either)
// Light: for a dark background, the fallback prefers public_html/logo-light.png
// (a WordPress logo is used as it is)
function WPSiteLogo(out URL: string; out Width, Height: integer;
  Light: boolean = False): boolean;
// <img> of the site logo, '' when the site has no logo
function WPSiteLogoHTML(const CssClass: string = 'site-logo'; Light: boolean = False): string;
// text safe for a meta content="" attribute: no tags, no quotes, one line
function MetaText(const Text: string; MaxLength: integer = 200): string;
// sets the 404 status and returns the "page not found" content
function NotFoundContent: string;
// language switch for the theme labels (articles stay in one language):
// one link per language in config.json "languages" (default ["id", "en"]),
// the current one as plain text; '' when there is only one language
function LanguageSwitchHTML(const CssClass: string = 'lang-switch'): string;

implementation

uses fastplaz_app, fastplaz_handler, common, html_lib, language_lib, RegExpr,
  fpjson, jsonparser,
  wordpress_options_model, wordpress_featuredimage_model;

const
  UPLOADS = 'wp-content/uploads/';
  FALLBACK_LOGO = 'logo.png';   // in public_html/, beside the app binary
  FALLBACK_LOGO_LIGHT = 'logo-light.png';   // same logo for dark backgrounds

function WPOption(const KeyName: string): string;
begin
  Result := '';
  with TWordpressOptions.Create() do
  try
    FindFirst(['option_name=' + QuoteValue(KeyName)], '', 'option_value');
    if RecordCount > 0 then
      Result := string(Value['option_value']);
  finally
    Free;
  end;
end;

function WPUploadURL(const UploadPath: string): string;
var
  upload_url: string;
begin
  Result := UploadPath;
  if (Result = '') or (Pos('://', Result) > 0) then
    Exit;

  // optional "wordpress/upload_url": the public url of wp-content/uploads,
  // for sites whose media live on another host (cdn / content domain)
  upload_url := Trim(string(Config.GetValue('wordpress/upload_url', '')));
  while (upload_url <> '') and (upload_url[Length(upload_url)] = '/') do
    System.Delete(upload_url, Length(upload_url), 1);
  if (upload_url <> '') and (Pos(UPLOADS, Result) = 1) then
    Result := upload_url + '/' + Copy(Result, Length(UPLOADS) + 1, MaxInt)
  // other files under wp-content (NextGEN: wp-content/gallery/...) live on
  // the same host, when upload_url is ".../wp-content/uploads"
  else if (Pos('wp-content/', Result) = 1) and
    SameText(Copy(upload_url, Length(upload_url) - Length(UPLOADS) + 2, MaxInt), Copy(UPLOADS, 1, Length(UPLOADS) - 1)) then
    Result := Copy(upload_url, 1, Length(upload_url) - Length(UPLOADS) + 1) + Result
  else
    Result := string(Config.GetValue('wordpress/base_url', '')) +
      string(Config.GetValue('wordpress/path', '')) + '/' + Result;
end;

// first integer captured by Pattern in S, 0 when there is no match
function MatchInt(const Pattern, S: string): integer;
var
  reg: TRegExpr;
begin
  Result := 0;
  reg := TRegExpr.Create(Pattern);
  try
    if reg.Exec(S) then
      Result := StrToIntDef(reg.Match[1], 0);
  finally
    reg.Free;
  end;
end;

function SiteLogoID: integer;
var
  mods: string;
begin
  // WordPress 5.8+ (site logo block / Site Identity)
  Result := StrToIntDef(Trim(WPOption('site_logo')), 0);
  if Result > 0 then
    Exit;
  // classic themes: theme_mods_<active theme>, a serialized php array
  mods := WPOption('theme_mods_' + WPOption('stylesheet'));
  Result := MatchInt('s:11:"custom_logo";i:(\d+);', mods);
end;

// width/height from a PNG header (IHDR), False when the file is not a PNG
function PNGSize(const FileName: string; out Width, Height: integer): boolean;
var
  f: TFileStream;
  b: array[0..23] of byte;
begin
  Result := False;
  Width := 0;
  Height := 0;
  try
    f := TFileStream.Create(FileName, fmOpenRead or fmShareDenyNone);
    try
      if f.Read(b, SizeOf(b)) <> SizeOf(b) then
        Exit;
    finally
      f.Free;
    end;
  except
    Exit;
  end;
  // signature 89 'PNG', then the IHDR chunk: width and height, big endian
  if (b[0] <> $89) or (b[1] <> Ord('P')) or (b[2] <> Ord('N')) or (b[3] <> Ord('G')) then
    Exit;
  Width := (b[16] shl 24) or (b[17] shl 16) or (b[18] shl 8) or b[19];
  Height := (b[20] shl 24) or (b[21] shl 16) or (b[22] shl 8) or b[23];
  Result := True;
end;

// public_html/logo.png (Light: logo-light.png when it exists), used when
// WordPress has no logo
function FallbackLogo(out URL: string; out Width, Height: integer; Light: boolean): boolean;
var
  name, file_name, base_url: string;
begin
  URL := '';
  Width := 0;
  Height := 0;
  name := FALLBACK_LOGO;
  if Light and FileExists(ExtractFilePath(ParamStr(0)) + FALLBACK_LOGO_LIGHT) then
    name := FALLBACK_LOGO_LIGHT;
  file_name := ExtractFilePath(ParamStr(0)) + name;
  if not FileExists(file_name) then
    Exit(False);
  PNGSize(file_name, Width, Height);
  base_url := AppData.baseUrl;
  if (base_url <> '') and (base_url[Length(base_url)] <> '/') then
    base_url := base_url + '/';
  URL := base_url + name;
  Result := True;
end;

function WPSiteLogo(out URL: string; out Width, Height: integer; Light: boolean): boolean;
var
  logo_id: integer;
  meta: string;
begin
  URL := '';
  Width := 0;
  Height := 0;
  logo_id := SiteLogoID;
  if logo_id <= 0 then
    Exit(FallbackLogo(URL, Width, Height, Light));

  with TFeaturedimage.Create() do   // a postmeta model
  try
    FindFirst(['meta_key=''_wp_attached_file''', 'post_id=' + i2s(logo_id)], '', 'meta_value');
    if RecordCount > 0 then
      URL := WPUploadURL(UPLOADS + string(Value['meta_value']));
    FindFirst(['meta_key=''_wp_attachment_metadata''', 'post_id=' + i2s(logo_id)], '', 'meta_value');
    if RecordCount > 0 then
    begin
      meta := string(Value['meta_value']);
      // the first width/height in the array belong to the full size image
      Width := MatchInt('s:5:"width";i:(\d+);', meta);
      Height := MatchInt('s:6:"height";i:(\d+);', meta);
    end;
  finally
    Free;
  end;
  Result := URL <> '';
  // logo id points to a deleted attachment
  if not Result then
    Result := FallbackLogo(URL, Width, Height, Light);
end;

function WPSiteLogoHTML(const CssClass: string; Light: boolean): string;
var
  url, size: string;
  w, h: integer;
begin
  Result := '';
  if not WPSiteLogo(url, w, h, Light) then
    Exit;
  size := '';
  if (w > 0) and (h > 0) then
    size := ' width="' + IntToStr(w) + '" height="' + IntToStr(h) + '"';
  // alt is empty: the logo sits next to the site title inside the same link
  Result := '<img class="' + HTMLEncode(CssClass) + '" src="' + HTMLEncode(url) + '"' +
    size + ' alt="" decoding="async">';
end;

function MetaText(const Text: string; MaxLength: integer): string;
begin
  Result := StringReplace(Text, '<', ' <', [rfReplaceAll]);
  Result := StripTagsCustom(StripTags(Result), '[', ']');
  Result := StringReplace(Result, #13, ' ', [rfReplaceAll]);
  Result := StringReplace(Result, #10, ' ', [rfReplaceAll]);
  Result := StringReplace(Result, #9, ' ', [rfReplaceAll]);
  Result := StringReplace(Result, '&nbsp;', ' ', [rfReplaceAll, rfIgnoreCase]);
  while Pos('  ', Result) > 0 do
    Result := StringReplace(Result, '  ', ' ', [rfReplaceAll]);
  Result := Trim(Result);
  // WordPress keeps entities (&amp; &#8211;) in titles and content, so only
  // the characters that would break the attribute are encoded here
  Result := StringReplace(Result, '"', '&quot;', [rfReplaceAll]);
  Result := StringReplace(Result, '<', '&lt;', [rfReplaceAll]);
  Result := StringReplace(Result, '>', '&gt;', [rfReplaceAll]);
  if (MaxLength > 0) and (Length(Result) > MaxLength) then
  begin
    Result := MoreLess(Result, MaxLength, '');
    if (LastDelimiter('&;', Result) > 0) and (Result[LastDelimiter('&;', Result)] = '&') then
      Result := TrimRight(Copy(Result, 1, LastDelimiter('&;', Result) - 1));
    Result := Result + '...';
  end;
end;

function NotFoundContent: string;
begin
  Application.Response.Code := 404;
  Application.Response.CodeText := 'Not Found';
  Result :=
    '<section class="not-found">' +
    '<h1 class="entry-title">' + __('Page not found') + '</h1>' +
    '<p>' + __('The address you opened does not exist, or the story has moved.') + '</p>' +
    '<form role="search" method="get" class="feed-search" action="/">' +
    '<label class="screen-reader-text" for="notfound-search-field">' + __('Search news') + '</label>' +
    '<input type="search" id="notfound-search-field" name="s" placeholder="' +
    __('Search news') + '&hellip;">' +
    '<button type="submit">' + __('Search') + '</button></form>' +
    '<p class="not-found-home"><a href="/">' + __('See the latest news') + '</a></p>' +
    '</section>';
end;

const
  DEFAULT_LANGUAGES: array[0..1] of string = ('id', 'en');

// "id", "en", "pt-br": also used in a url, so nothing else gets through
function IsLanguageCode(const ACode: string): boolean;
var
  i: integer;
begin
  Result := (Length(ACode) >= 2) and (Length(ACode) <= 5);
  for i := 1 to Length(ACode) do
    if not (ACode[i] in ['a'..'z', '-']) then
      Exit(False);
end;

// the language's own name, so a reader finds it whatever the page language is
function LanguageName(const ACode: string): string;
begin
  case ACode of
    'id': Result := 'Bahasa Indonesia';
    'en': Result := 'English';
    else
      Result := '';
  end;
end;

// codes from config.json "languages", DEFAULT_LANGUAGES when missing
function SiteLanguages: TStringList;
var
  data: TJSONData;
  i: integer;
  code: string;
begin
  Result := TStringList.Create;
  try
    data := GetJSON(Config.GetString('languages'));
  except
    data := nil;
  end;
  try
    if Assigned(data) and (data.JSONType = jtArray) then
      for i := 0 to data.Count - 1 do
        if data.Items[i].JSONType = jtString then
        begin
          code := LowerCase(Trim(data.Items[i].AsString));
          if IsLanguageCode(code) and (Result.IndexOf(code) = -1) then
            Result.Add(code);
        end;
  finally
    data.Free;
  end;
  if Result.Count = 0 then
    for i := Low(DEFAULT_LANGUAGES) to High(DEFAULT_LANGUAGES) do
      Result.Add(DEFAULT_LANGUAGES[i]);
end;

// the current address with ?lang=<code>, other query values kept
// (search keyword, page number)
function URLWithLanguage(const ACode: string): string;
var
  uri, path, query, part, kept: string;
  p: integer;
begin
  uri := Application.Request.URI;
  p := Pos('?', uri);
  if p > 0 then
  begin
    path := Copy(uri, 1, p - 1);
    query := Copy(uri, p + 1, MaxInt);
  end
  else
  begin
    path := uri;
    query := '';
  end;
  // "//host/..." would become a link to another site
  while Pos('//', path) = 1 do
    System.Delete(path, 1, 1);
  if path = '' then
    path := '/';
  // the home route reads the language from the path (/en/), which would
  // win over ?lang=
  if ExecRegExpr('^/(id|en|us)/?$', path) then
    path := '/';

  kept := '';
  while query <> '' do
  begin
    p := Pos('&', query);
    if p = 0 then
      p := Length(query) + 1;
    part := Copy(query, 1, p - 1);
    System.Delete(query, 1, p);
    if (part = '') or SameText(Copy(part, 1, 5), 'lang=') or SameText(part, 'lang') then
      Continue;
    kept := kept + part + '&';
  end;
  Result := path + '?' + kept + 'lang=' + ACode;
end;

function LanguageSwitchHTML(const CssClass: string): string;
var
  codes: TStringList;
  i: integer;
  code, name, current: string;
begin
  Result := '';
  current := LANG;
  if current = 'us' then
    current := 'en';
  codes := SiteLanguages;
  try
    if codes.Count < 2 then
      Exit;
    Result := '<nav class="' + HTMLEncode(CssClass) + '" aria-label="' + __('Language') +
      '"><ul>';
    for i := 0 to codes.Count - 1 do
    begin
      code := codes[i];
      name := LanguageName(code);
      if name <> '' then
        name := '<span class="screen-reader-text"> ' + name + '</span>';
      if code = current then
        Result := Result + '<li><span class="is-current" aria-current="true" lang="' + code +
          '">' + UpperCase(code) + name + '</span></li>'
      else
        Result := Result + '<li><a href="' + HTMLEncode(URLWithLanguage(code)) +
          '" hreflang="' + code + '" lang="' + code + '" rel="nofollow">' + UpperCase(code) +
          name + '</a></li>';
    end;
    Result := Result + '</ul></nav>';
  finally
    codes.Free;
  end;
end;

end.
