program wordpress;

{$mode objfpc}{$H+}

uses
  fpcgi, sysutils, fastplaz_handler, common, html_lib, main, routes, wordpress_featuredimage_model,
  wordpress_news_model, wordpress_nggallery_model, wordpress_options_model, wordpress_pages_model, wordpress_tags_model,
  wordpress_terms_model, wordpress_category_controller, wordpress_tags_controller, wordpress_pages_controller,
  wordpress_news_controller;

{$R *.res}

begin
  Application.Title:='FastPlaz for Wordpress';
  Application.Email := Config.GetValue(_SYSTEM_WEBMASTER_EMAIL,'webmaster@' + GetEnvironmentVariable('SERVER_NAME'));
  Application.DefaultModuleName := Config.GetValue(_SYSTEM_MODULE_DEFAULT, 'main');
  Application.ModuleVariable := Config.GetValue(_SYSTEM_MODULE_VARIABLE, 'mod');
  Application.AllowDefaultModule := True;
  Application.RedirectOnErrorURL := Config.GetValue(_SYSTEM_ERROR_URL, '/');
  Application.RedirectOnError:= Config.GetValue( _SYSTEM_ERROR_REDIRECT, false);

  Application.OnGetModule := @FastPlasAppandler.OnGetModule;
  Application.PreferModuleName := True;

  Application.Initialize;
  Application.Run;
end.
