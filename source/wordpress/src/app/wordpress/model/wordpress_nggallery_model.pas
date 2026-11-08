unit wordpress_nggallery_model;

{$mode objfpc}{$H+}

interface

uses
  database_lib, fpTemplate,
  Classes, SysUtils;

type

  { TWPNGGallery }

  TWPNGGallery = class(TSimpleModel)
  private
    FBaseURL: string;
    FPath: string;
    procedure ngTagController(Sender: TObject; const TagString: string; TagParams: TStringList;
      Out ReplaceText: string);
  public
    constructor Create(const DefaultTableName: string = '');
    destructor Destroy; override;
    property Path: string read FPath write FPath;
    property BaseURL: string read FBaseURL write FBaseURL;
    function Render(const Content: string): string;
  end;

var
  WPNGGallery: TWPNGGallery;

implementation

uses common, fastplaz_handler, logutil_lib, theme_controller, html_lib, base64, wordpress_site_lib;

{ TWPNGGallery }

// "300" -> 300, "100%" -> 100 with IsPercent, anything else -> 0
function SizeValue(const AValue: string; out IsPercent: boolean): integer;
var
  s: string;
begin
  s := Trim(AValue);
  IsPercent := (s <> '') and (s[Length(s)] = '%');
  if IsPercent then
    SetLength(s, Length(s) - 1);
  Result := StrToIntDef(s, 0);
  if (Result < 0) or (IsPercent and (Result > 100)) then
    Result := 0;
end;

// first integer stored under Key in NextGEN meta_data. Older versions store
// a php serialized array (s:5:"width";i:800;), newer ones base64 encoded
// json ({"width":800,...}).
function SerializedInt(const Data, Key: string): integer;
var
  p, q: integer;
  s, marker: string;
begin
  Result := 0;
  s := Trim(Data);
  if (s <> '') and not (s[1] in ['a', '{']) then
  try
    s := DecodeStringBase64(s);
  except
    Exit;
  end;
  marker := 's:' + IntToStr(Length(Key)) + ':"' + Key + '";i:';
  p := Pos(marker, s);
  if p = 0 then
  begin
    marker := '"' + Key + '":';
    p := Pos(marker, s);
  end;
  if p = 0 then
    Exit;
  p := p + Length(marker);
  while (p <= Length(s)) and (s[p] in [' ', '"']) do
    Inc(p);
  q := p;
  while (q <= Length(s)) and (s[q] in ['0'..'9']) do
    Inc(q);
  Result := StrToIntDef(Copy(s, p, q - p), 0);
end;

// NextGEN Gallery shortcodes in the post content.
// [singlepic id=116 w=100% h= float=center] -> the picture with pid 116
procedure TWPNGGallery.ngTagController(Sender: TObject; const TagString: string; TagParams: TStringList;
  out ReplaceText: string);
var
  tags: TStrings;
  id, w, h, natural_w, natural_h: integer;
  w_percent, h_percent: boolean;
  gallery_path, src, alt, img, align, style: string;
begin
  // not ours (any other "[...]" in the page): leave it as it was
  ReplaceText := '[' + TagString + ']';
  tags := Explode(TagString, ' ');
  try
    if (tags.Count = 0) or (tags[0] <> 'singlepic') then
      Exit;

    // a picture that does not exist (any more) shows nothing, not the shortcode
    ReplaceText := '';
    // the parameters come from the post content: numbers only
    id := s2i(tags.Values['id']);
    if id <= 0 then
      Exit;
    AddJoin('ngg_gallery', 'gid', 'ngg_pictures.galleryid', ['path']);
    FindFirst([AppData.tablePrefix + 'ngg_pictures.pid=' + i2s(id)],
      '', 'filename,alttext,meta_data');
    if Data.RecordCount = 0 then
      Exit;

    // the gallery path is relative to the WordPress root ("wp-content/gallery/event/")
    gallery_path := Trim(string(Value['path']));
    while (gallery_path <> '') and (gallery_path[1] = '/') do
      System.Delete(gallery_path, 1, 1);
    while (gallery_path <> '') and (gallery_path[Length(gallery_path)] = '/') do
      System.Delete(gallery_path, Length(gallery_path), 1);
    src := WPUploadURL(gallery_path + '/' + string(Value['filename']));
    alt := HTMLEncode(string(Value['alttext']));

    // real size from the NextGEN metadata: the browser reserves the space
    natural_w := SerializedInt(string(Value['meta_data']), 'width');
    natural_h := SerializedInt(string(Value['meta_data']), 'height');

    w := SizeValue(tags.Values['w'], w_percent);
    h := SizeValue(tags.Values['h'], h_percent);
    style := '';
    if w_percent and (w > 0) then
      style := style + 'width:' + i2s(w) + '%;';
    if h_percent and (h > 0) then
      style := style + 'height:' + i2s(h) + '%;';

    img := '<img src="' + HTMLEncode(src) + '" alt="' + alt + '"';
    if (w > 0) and not w_percent then
    begin
      img := img + ' width="' + i2s(w) + '"';
      if (h > 0) and not h_percent then
        img := img + ' height="' + i2s(h) + '"'
      else if (natural_w > 0) and (natural_h > 0) then
        img := img + ' height="' + i2s(Round(w * natural_h / natural_w)) + '"';
    end
    else if (natural_w > 0) and (natural_h > 0) then
      img := img + ' width="' + i2s(natural_w) + '" height="' + i2s(natural_h) + '"';
    if style <> '' then
      img := img + ' style="' + style + '"';
    img := img + ' loading="lazy" decoding="async">';

    // float=left/right/center -> the theme's WordPress alignment classes
    case tags.Values['float'] of
      'left': align := ' alignleft';
      'right': align := ' alignright';
      'center': align := ' aligncenter';
    else
      align := '';
    end;
    ReplaceText := '<figure class="ngg-singlepic' + align + '">' + img + '</figure>';
  finally
    FreeAndNil(tags);
  end;
end;

constructor TWPNGGallery.Create(const DefaultTableName: string);
begin
  inherited Create('ngg_pictures');
  Path := string(Config.GetValue('wordpress/path', ''));
  BaseURL := string(Config.GetValue('wordpress/base_url', ''));
  if BaseURL = '' then
  begin
    // works in both modes: in standalone mode the process environment has
    // no SERVER_NAME, it comes from the request
    BaseURL := 'http://' + _SERVER['SERVER_NAME'];
  end;
end;

destructor TWPNGGallery.Destroy;
begin
  inherited Destroy;
end;

function TWPNGGallery.Render(const Content: string): string;
var
  template: TFPTemplate;
begin
  Result := Content;
  template := TFPTemplate.Create;
  template.Template := Content;
  template.AllowTagParams := True;
  template.StartDelimiter := '[';
  template.EndDelimiter := ']';
  template.ParamValueSeparator := '=';
  template.OnReplaceTag := @ngTagController;
  Result := template.GetContent;
  FreeAndNil(template);
end;

initialization
  //WPNGGallery:= TWPNGGallery.Create;

finalization
  //FreeAndNil( WPNGGallery);

end.
