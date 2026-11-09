
FastPlaz App - Wordpress Loader
===================================

This app was built with the FastPlaz framework, an open source Pascal web
framework. It reads an existing WordPress database and serves the site with
its own themes, without running PHP.

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

Other build scripts in `source/wordpress`:

- `build-wsl.sh`: builds the Linux binary from WSL, compiling on the native
  WSL filesystem because `/mnt/*` is slow.
- `build-docker.sh project`: builds inside Docker (`luri/free-pascal`) so the
  binary runs on hosting servers with an old glibc (cPanel/CloudLinux 8).


INSTALLATION
------------

- Extract this file to your webroot directory
- Copy `config/config-example.json` to `config/config.json` and fill in:
  - `database/default`: the WordPress database, including the table `prefix`
  - `systems/theme`: one of the folders in `public_html/themes`
  - `wordpress`: `base_url` and `upload_url` of the original WordPress site,
    and `plugins/polylang` if the site uses Polylang
  - `hero_banner`, `right_top_banner`: optional banners (wideworld theme)


URLS
----

| URL                          | Page                          |
|------------------------------|-------------------------------|
| `/`, `/id/`, `/en/`          | home page                     |
| `/2014/04/the-post/`         | single post                   |
| `/2014/04/`, `/news/`        | post archive                  |
| `/category/slug/`            | category                      |
| `/tag/slug/`                 | tag                           |
| `/pages/parent/child/`       | WordPress page                |
| `/sitemap.xml`               | sitemap for search engines    |
| `/peta-situs/`               | sitemap page for visitors     |


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


SITES USING THIS APP
--------------------

- Portal Pencak Silat Indonesia, https://silatindonesia.com
- Perkumpulan Panahan Berkuda Indonesia (KPBI), https://ihasa.id
