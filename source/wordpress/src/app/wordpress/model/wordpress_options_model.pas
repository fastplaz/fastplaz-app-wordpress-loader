unit wordpress_options_model;

{$mode objfpc}{$H+}

interface

uses
  database_lib,
  Classes, SysUtils;

type

  { TWordpressOptions }

  TWordpressOptions = class(TSimpleModel)
  public
    constructor Create(const DefaultTableName: string = '');
  end;


implementation

uses fastplaz_handler, common;

{ TWordpressOptions }

constructor TWordpressOptions.Create(const DefaultTableName: string);
begin
  //inherited Create(AppData.tablePrefix + '_options');
  inherited Create( 'options');
end;

end.

