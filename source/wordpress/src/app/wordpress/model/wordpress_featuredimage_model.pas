unit wordpress_featuredimage_model;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, database_lib;

type

  { TFeaturedimage }

  TFeaturedimage = class(TSimpleModel)
  private
  public
    constructor Create(const DefaultTableName: string = '');
    function GetFeaturedImageURLByID(const NewsID: integer): string;
    function GetFeaturedImageURLByPermalink(const NewsID: integer): string;
  end;

implementation

uses fastplaz_handler, common, wordpress_nggallery_model;

constructor TFeaturedimage.Create(const DefaultTableName: string = '');
begin
  inherited Create('postmeta');
end;

function TFeaturedimage.GetFeaturedImageURLByID(const NewsID: integer): string;
var
  meta_value_string: string;
  wpnggallery: TWPNGGallery;
begin
  Result := '';
  Find(['meta_key=''_thumbnail_id''', 'post_id=' + i2s(NewsID)]);
  if Data.RecordCount = 0 then
    Exit;
  meta_value_string := Data.FieldValues['meta_value'];

  // if nggallery
  if Pos('ngg-', meta_value_string) > 0 then
  begin
    meta_value_string := StringReplace(meta_value_string, 'ngg-', '', [rfReplaceAll]);
    wpnggallery := TWPNGGallery.Create();
    wpnggallery.AddJoin('ngg_gallery', 'gid', 'galleryid', ['path']);
    wpnggallery.FindFirst([AppData.tablePrefix + '_ngg_pictures.pid=' + meta_value_string],
      '', 'filename,alttext');
    if wpnggallery.Data.RecordCount > 0 then
      Result := wpnggallery.Value['path'].AsString + '/' + wpnggallery.Value['filename'].AsString;

    FreeAndNil(wpnggallery);
    Exit;
  end;
  // if nggallery - end

  Find(['meta_key=''_wp_attached_file''', 'post_id=' + meta_value_string]);
  if Data.RecordCount = 0 then
    Exit;
  Result := 'wp-content/uploads/' + Data.FieldValues['meta_value'];
end;

function TFeaturedimage.GetFeaturedImageURLByPermalink(const NewsID: integer): string;
begin
  Result := '';
end;

end.
