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

uses common, fastplaz_handler, logutil_lib, theme_controller, html_lib;

{ TWPNGGallery }

procedure TWPNGGallery.ngTagController(Sender: TObject; const TagString: string; TagParams: TStringList;
  out ReplaceText: string);
var
  tags: TStrings;
  id: integer;
  src, alt: string;
begin
  ReplaceText := TagString;
  tags := Explode(TagString, ' ');
  try
    if tags.Count = 0 then
      Exit;

    case tags[0] of
      'singlepic':
      begin
        // the parameters come from the post content: numbers only
        id := s2i(tags.Values['id']);
        if id <= 0 then
          Exit;
        AddJoin('ngg_gallery', 'gid', 'galleryid', ['path']);
        FindFirst([AppData.tablePrefix + 'ngg_pictures.pid=' + i2s(id)],
          '', 'filename,alttext');
        if Data.RecordCount > 0 then
        begin
          src := BaseURL + FPath + '/' + string(Value['path']) + '/' + string(Value['filename']);
          alt := HTMLEncode(string(Value['alttext']));
          ReplaceText := '<div><img src="' + src + '"';
          if s2i(tags.Values['w']) > 0 then
            ReplaceText := ReplaceText + ' width="' + i2s(s2i(tags.Values['w'])) + '"';
          if s2i(tags.Values['h']) > 0 then
            ReplaceText := ReplaceText + ' height="' + i2s(s2i(tags.Values['h'])) + '"';
          case tags.Values['float'] of
            'left', 'right', 'center':
              ReplaceText := ReplaceText + ' class="ngg-singlepic float_' + tags.Values['float'] + '"';
          end;
          ReplaceText := ReplaceText + ' alt="' + alt + '"';
          ReplaceText := ReplaceText + ' title="' + alt + '"';
          ReplaceText := ReplaceText + '></div>';
        end;
      end;
    end;
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
