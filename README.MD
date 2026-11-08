
FastPlaz App - Wordpress Loader
===================================

This app was build with FastPlaz framework,
open source pascal web framework.

REQUIREMENTS
------------

- FastPlaz 2026 "Hero" or newer (`fastplaz_app`, `TSimpleModel.QuoteValue`)
- Free Pascal 3.2.x
- MySQL client library (libmysql)
- One of:
  - Web Server (apache) with CGI Support, or
  - nothing: the app runs as its own HTTP server (standalone mode)


BUILD
-----

The FastPlaz library is expected in `../../../vendors/fastplaz` (relative to
`source/wordpress`); change `extra.cfg` if yours is elsewhere.

    cd source/wordpress
    ./compile.sh          # Windows: compile.bat

The binary is written to `public_html/wordpress.bin`. Opening
`wordpress.lpi` in Lazarus works too.


INSTALLATION
------------

- Extract this file to your webroot directory
- configure file "config/config.json"


RUN MODES
---------

One binary, two modes; no code change is needed to switch.

### CGI (Apache)

Apache starts `wordpress.bin` as CGI (`GATEWAY_INTERFACE` is set), and
`public_html/.htaccess` rewrites the friendly URLs. Nothing else to do.

### Standalone HTTP

    cd public_html
    ./wordpress.bin                     # http://127.0.0.1:17845/
    ./wordpress.bin --port=8081         # other options: --address, --static=on|off,
                                        # --max-requests=N, --root=<dir>, --mode=cgi|http

The routes in `source/wordpress/routes.pas` replace the `.htaccess` rewrite
rules, so `/2014/04/the-post/`, `/category/slug/`, `/tag/slug/` and
`/pages/parent/child/` work the same way. Settings are in
`config/config.json`, `systems/server`. Behind nginx or Apache as a reverse
proxy, keep `address` at `127.0.0.1`, set `systems/trust_proxy` to `true`,
and do not let the proxy serve `config/` and `ztemp/`. See
`docs/STANDALONE-deployment.md` in the FastPlaz repository.

