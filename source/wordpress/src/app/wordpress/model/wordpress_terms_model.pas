unit wordpress_terms_model;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, database_lib;

type

  { TWordpressTerms }

  TWordpressTerms = class(TSimpleModel)
  public
    constructor Create(const DefaultTableName: string = '');
    function GetObjectTerms(const ObjectID: integer; const Taxonomy: array of string): boolean;
  end;

implementation

uses common, fastplaz_handler;

{ TWordpressTerms }

constructor TWordpressTerms.Create(const DefaultTableName: string);
begin
  inherited Create('terms');
end;

{
example:
Terms.GetObjectTerms( News['ID'].AsInteger, ['post_tag']);
}
function TWordpressTerms.GetObjectTerms(const ObjectID: integer; const Taxonomy: array of string): boolean;
var
  i: integer;
  where: string;
begin
  Result := False;
  where := '';
  for i := Low(Taxonomy) to High(Taxonomy) do
  begin
    if where = '' then
      where := '"' + Taxonomy[i] + '"'
    else
      where := where + ',"' + Taxonomy[i] + '"';
  end;
  where := AppData.tablePrefix + 'term_taxonomy.taxonomy IN (' + where + ')';

  AddInnerJoin('term_taxonomy', 'term_id', 'terms.term_id', ['count']);
  AddInnerJoin('term_relationships', 'term_taxonomy_id', 'term_taxonomy.term_taxonomy_id', []);
  Find([where, AppData.tablePrefix + 'term_relationships.object_id=' + i2s(ObjectID)],
    AppData.tablePrefix + 'terms.name ASC');
  if RecordCount > 0 then
    Result := True;
end;

end.
