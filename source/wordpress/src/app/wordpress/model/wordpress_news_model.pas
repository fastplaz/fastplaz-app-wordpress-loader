unit wordpress_news_model;

{$mode objfpc}{$H+}

interface

uses
  database_lib,
  Classes, SysUtils;

type

  { TWordpressNews }

  TWordpressNews = class(TSimpleModel)
  private
    function GetCountPosts: integer;
  public
    constructor Create(const DefaultTableName: string = '');
    function FindByTags(const TagsName: string): boolean;
    procedure AddHit(const ID: integer);
    function SearchNews(const Keyword: string): boolean;

    property CountPosts: integer read GetCountPosts;
  end;


implementation

uses fastplaz_handler, common, wordpress_tags_model;

{ TWordpressNews }

function TWordpressNews.GetCountPosts: integer;
begin
  if Data.Active then
    Data.Close;
  Data.SQL.Text := 'SELECT COUNT(*) as countposts FROM ' + AppData.tablePrefix +
    'posts WHERE post_status = "publish" AND post_type = "post"';
  Data.Open;
  if RecordCount > 0 then
    Result := Value['countposts'];
end;

constructor TWordpressNews.Create(const DefaultTableName: string);
begin
  inherited Create('posts');
end;

function TWordpressNews.FindByTags(const TagsName: string): boolean;
var
  tag_id: integer;
begin
  if Data.Active then
    Data.Close;
  if TagsName = '' then
    Exit;

  // find tag
  with TWordpressTags.Create() do
  begin
    AddInnerJoin( 'term_taxonomy', 'term_id', 'terms.term_id', ['term_taxonomy_id']);
    Find([AppData.tablePrefix + 'terms.slug = "' + TagsName + '"', AppData.tablePrefix +
      'term_taxonomy.taxonomy = "post_tag"']);
    if RecordCount = 0 then
    begin
      Result := False;
      Free;
      Exit;
    end;
    tag_id := Value['term_taxonomy_id'];
    Free;
  end;

  AddInnerJoin( 'term_relationships', 'object_id', 'posts.ID', []);
  GroupBy(AppData.tablePrefix + 'posts.ID');
  Find([AppData.tablePrefix + 'term_relationships.term_taxonomy_id IN (' + i2s(tag_id) + ')',
    AppData.tablePrefix + 'posts.post_type = "post"', AppData.tablePrefix + 'posts.post_status = "publish"'],
    AppData.tablePrefix + 'posts.post_date DESC', 10);

  Result := True;
end;

procedure TWordpressNews.AddHit(const ID: integer);
begin
  // prepare for add hit counter
end;

function TWordpressNews.SearchNews(const Keyword: string): boolean;
begin
  AddInnerJoin( 'term_relationships', 'object_id', 'posts.ID', []);
  GroupBy( AppData.tablePrefix + 'posts.ID');
  Find([
    '((' +
    AppData.tablePrefix + 'posts.post_title LIKE ''%' + Keyword + '%'')OR (' +
    AppData.tablePrefix + 'posts.post_content LIKE ''%' + Keyword + '%''))',
    AppData.tablePrefix + 'posts.post_type IN (''post'', ''page'', ''attachment'', ''hs_faq'')', '(' +
    AppData.tablePrefix + 'posts.post_status = ''publish'' OR ' +
    AppData.tablePrefix + 'posts.post_author = 1 AND ' +
    AppData.tablePrefix + 'posts.post_status = ''private'')'],
    AppData.tablePrefix + 'posts.post_title LIKE ''%' + Keyword + '%'' DESC, ' +
    AppData.tablePrefix + 'posts.post_date DESC', 10
    );
end;


end.
