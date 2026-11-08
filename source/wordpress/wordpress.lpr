program wordpress;

{$mode objfpc}{$H+}

uses
  {$IFNDEF Windows}cthreads, {$ENDIF}
  fastplaz_app,
  SysUtils,
  fastplaz_handler,
  common,
  html_lib,
  main,
  routes,
  wordpress_featuredimage_model,
  wordpress_news_model,
  wordpress_nggallery_model,
  wordpress_options_model,
  wordpress_pages_model,
  wordpress_tags_model,
  wordpress_terms_model,
  wordpress_category_controller,
  wordpress_tags_controller,
  wordpress_pages_controller,
  wordpress_news_controller;

{$R *.res}

begin
  Application.Title := string( Config.GetValue(_SYSTEM_SITENAME, 'FastPlaz for Wordpress'));
  Application.Email := string( Config.GetValue(_SYSTEM_WEBMASTER_EMAIL, 'webmaster@' + GetEnvironmentVariable('SERVER_NAME')));
  Application.DefaultModuleName := string( Config.GetValue(_SYSTEM_MODULE_DEFAULT, 'main'));
  Application.ModuleVariable := string( Config.GetValue(_SYSTEM_MODULE_VARIABLE, 'mod'));
  Application.AllowDefaultModule := True;
  Application.RedirectOnErrorURL := string( Config.GetValue(_SYSTEM_ERROR_URL, '/'));
  Application.RedirectOnError := Config.GetValue(_SYSTEM_ERROR_REDIRECT, False);

  Application.OnGetModule := @FastPlasAppandler.OnGetModule;
  Application.PreferModuleName := True;
  {$if FPC_FULLVERSION >= 30004}
  Application.LegacyRouting := True;
  {$endif}

  // startup banner, standalone mode only; see OnStandaloneBanner to change it
  ShowStandaloneBanner;

  Application.Initialize;
  Application.Run;
end.
