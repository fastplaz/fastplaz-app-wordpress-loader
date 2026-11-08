unit wordpress_site_lib;

{
  Site identity read from WordPress itself (Settings > General and
  Appearance > Customize > Site Identity), so the header and the share
  metadata follow the WordPress site instead of config.json:
  - blogname / blogdescription  : site title and tagline
  - site_logo or theme_mods_*   : logo (attachment id)
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
function WPSiteLogo(out URL: string; out Width, Height: integer): boolean;
// <img> of the site logo, '' when the site has no logo
function WPSiteLogoHTML(const CssClass: string = 'site-logo'): string;
// text safe for a meta content="" attribute: no tags, no quotes, one line
function MetaText(const Text: string; MaxLength: integer = 200): string;
// sets the 404 status and returns the "page not found" content
function NotFoundContent: string;

implementation

uses fastplaz_app, fastplaz_handler, common, html_lib, RegExpr,
  wordpress_options_model, wordpress_featuredimage_model;

const
  UPLOADS = 'wp-content/uploads/';

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

function WPSiteLogo(out URL: string; out Width, Height: integer): boolean;
var
  logo_id: integer;
  meta: string;
begin
  URL := '';
  Width := 0;
  Height := 0;
  logo_id := SiteLogoID;
  if logo_id <= 0 then
    Exit(False);

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
end;

function WPSiteLogoHTML(const CssClass: string): string;
var
  url, size: string;
  w, h: integer;
begin
  Result := '';
  if not WPSiteLogo(url, w, h) then
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
    '<h1 class="entry-title">Halaman tidak ditemukan</h1>' +
    '<p>Alamat yang Anda buka tidak ada, atau beritanya sudah dipindahkan.</p>' +
    '<form role="search" method="get" class="feed-search" action="/">' +
    '<label class="screen-reader-text" for="notfound-search-field">Cari berita:</label>' +
    '<input type="search" id="notfound-search-field" name="s" placeholder="Cari berita&hellip;">' +
    '<button type="submit">Cari</button></form>' +
    '<p class="not-found-home"><a href="/">Lihat berita terbaru</a></p>' +
    '</section>';
end;

end.
