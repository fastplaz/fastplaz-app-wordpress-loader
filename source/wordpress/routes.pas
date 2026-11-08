unit routes;

{$mode objfpc}{$H+}
{$include define.inc}

interface

uses
  Classes, SysUtils, fastplaz_handler;

implementation

uses info_controller, main
  {$ifdef wordpress}
  , wordpress_news_controller, wordpress_category_controller,
  wordpress_pages_controller, wordpress_tags_controller
  {$endif}
  ;

{
  Every route has an anchored pattern, so it works the same way in both modes:
  - CGI behind Apache: .htaccess rewrites the friendly URL to ?mod=...,
    or passes it as PATH_INFO (wordpress.bin/category/foo/)
  - standalone HTTP: there is no .htaccess, the patterns below do the
    rewriting (named groups become _GET[...] variables)

  Patterns are matched in the order they are added; the first one wins.
  Only GET (and HEAD) is accepted, other methods get "405 Method Not Allowed".
}
initialization
  Route.Add('main', '^/((?P<lang>id|en|us)/?)?$', TMainModule, 'GET');
  Route.Add('info', '^/info/?$', TInfoModule, 'GET');

  {$ifdef wordpress}
  // /2014/04/the-permalink/
  Route.Add('wpnews', '^/(?P<year>[0-9]{4})/(?P<month>[0-9]{2})/(?P<permalink>[^/]+)/?$',
    TWPNewsWebModule, 'GET');
  // /2014/04/  and  /news/  (latest news)
  Route.Add('wpnewsarchive', '^/((?P<year>[0-9]{4})/(?P<month>[0-9]{2})|news|wpnews)/?$',
    TWPNewsWebModule, 'GET');
  // /category/the-slug/
  Route.Add('category', '^/category/(?P<name>[A-Za-z0-9=_-]+)/?$',
    TWPCategoryWebModule, 'GET');
  // /tag/the-slug/  and  /tags/the-slug/
  Route.Add('tag', '^/tags?/(?P<tag>[A-Za-z0-9=_-]+)/?$', TWPTagsWebModule, 'GET');
  // /pages/parent/child/
  Route.Add('pages', '^/pages/.+', TWPPagesWebModule, 'GET');
  {$endif}

end.
