# mod_img2url

Converts stanzes with embedded images or audio sent by the [AstraChat](http://astrachat.com/download.aspx) clients to XEP-0363 (HTTP File Upload).
Files will be written to the http_upload directory and an external link will be send to the recipient instead of the (possibly large) file.
The module will strip binaries early, so they don't get archived.


## PREREQUISITES
Requires the mod_http_upload prosody module installed.

It is recommended to set `http_external_url` in `prosody.cfg.lua` to something like:

```
http_external_url = "https://example.org:5281/"
```

The module will build the url from (`http_external_url` || basic http url) + (config setting `img2url_url` || "/upload")


## INSTALL
- Clone the repo to the prosody plugins directory, e.g.
> git clone https://github.com/lixmal/mod_img2url.git /etc/prosody/plugins/mod_img2url

- Enable in `prosody.cfg.lua`:
    ```
    modules_enabled = {
       'img2url';
    }
    ```

## TODO
- Match more mime types
