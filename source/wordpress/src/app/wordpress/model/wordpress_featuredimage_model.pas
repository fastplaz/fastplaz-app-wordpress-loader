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
  image_id: integer;
  wpnggallery: TWPNGGallery;
begin
  Result := '';
  Find(['meta_key=''_thumbnail_id''', 'post_id=' + i2s(NewsID)]);
  if Data.RecordCount = 0 then
    Exit;
  meta_value_string := string(Data.FieldValues['meta_value']);

  // if nggallery
  if Pos('ngg-', meta_value_string) > 0 then
  begin
    meta_value_string := StringReplace(meta_value_string, 'ngg-', '', [rfReplaceAll]);
    image_id := s2i(meta_value_string);
    if image_id <= 0 then
      Exit;
    wpnggallery := TWPNGGallery.Create();
    wpnggallery.AddJoin('ngg_gallery', 'gid', 'galleryid', ['path']);
    wpnggallery.FindFirst([AppData.tablePrefix + 'ngg_pictures.pid=' + i2s(image_id)],
      '', 'filename,alttext');
    if wpnggallery.Data.RecordCount > 0 then
      Result := string(wpnggallery.Value['path']) + '/' + string(wpnggallery.Value['filename']);

    FreeAndNil(wpnggallery);
    Exit;
  end;
  // if nggallery - end

  image_id := s2i(meta_value_string);
  if image_id <= 0 then
    Exit;
  Find(['meta_key=''_wp_attached_file''', 'post_id=' + i2s(image_id)]);
  if Data.RecordCount = 0 then
    Exit;
  Result := 'wp-content/uploads/' + string(Data.FieldValues['meta_value']);
end;

function TFeaturedimage.GetFeaturedImageURLByPermalink(const NewsID: integer): string;
begin
  Result := '';
end;

end.
